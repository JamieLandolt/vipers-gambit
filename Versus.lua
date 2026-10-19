local love = require("love")
local enet = require("enet")
local play = require("Play")
local collection = require("Collection")
local data = require("CardData")
local card = require("Card")
local charmers = require("Charmers")

-- Two-player matches over the network (enet, direct by IP). The host runs the match and plays the guest's moves as
-- the Opponent; the guest sends what it wants to do and mirrors the host's snapshots, so its own side is "Player".
--   guest -> host: hello (deck), then intents { k = "play" | "act" | "charm" | "end" | "forfeit" }
--   host -> guest: start (the host's charmer), then a snapshot whenever something changed
local versus = { mode = nil, status = "", ip = love.filesystem.read("versus_ip.txt") or "127.0.0.1" }
local PORT, MIN_DECK, MAX_DECK = 47625, 5, 200 -- (before a deck is chosen every owned snake is in it)

local host, peer -- the enet host, and the other player's connection
local queue, last_sent = {}, nil
local sent_final = false

-- A tiny serialiser for nested tables of numbers, strings and booleans (never runs received data as code)
local function encode(v, out)
	local t = type(v)
	if t == "number" then
		out[#out + 1] = "n" .. string.format("%.17g", v) .. ";"
	elseif t == "boolean" then
		out[#out + 1] = v and "T" or "F"
	elseif t == "string" then
		out[#out + 1] = "s" .. #v .. ":" .. v
	elseif t == "table" then
		out[#out + 1] = "{"
		for k, x in pairs(v) do
			local kt, xt = type(k), type(x)
			if (kt == "string" or kt == "number") and (xt == "number" or xt == "string" or xt == "boolean" or xt == "table") then
				encode(k, out)
				encode(x, out)
			end
		end
		out[#out + 1] = "}"
	end
end

local function decode(s, i, depth)
	local c = s:sub(i, i)
	if c == "n" then
		local e = s:find(";", i, true)
		return tonumber(s:sub(i + 1, e - 1)) or error("bad number"), e + 1
	elseif c == "T" or c == "F" then
		return c == "T", i + 1
	elseif c == "s" then
		local e = s:find(":", i, true)
		local len = tonumber(s:sub(i + 1, e - 1))
		if not len or e + len > #s then
			error("bad string")
		end
		return s:sub(e + 1, e + len), e + len + 1
	elseif c == "{" and depth < 8 then
		local t = {}
		i = i + 1
		while s:sub(i, i) ~= "}" do
			local k, v
			k, i = decode(s, i, depth + 1)
			v, i = decode(s, i, depth + 1)
			t[k] = v
		end
		return t, i + 1
	end
	error("bad data")
end

versus.encode = function(v)
	local out = {}
	encode(v, out)
	return table.concat(out)
end
versus.decode = function(s)
	local ok, v = pcall(decode, s, 1, 0)
	return ok and type(v) == "table" and v or nil
end

function versus.send(message)
	if peer then
		peer:send(versus.encode(message), 0, "reliable")
		return true
	end
	return false
end

-- This machine's address on the local network, for the host to read out
function versus.local_ip()
	local ok, ip = pcall(function()
		local udp = require("socket").udp()
		udp:setpeername("8.8.8.8", 80) -- no packet is sent; it only picks the outgoing interface
		local address = udp:getsockname()
		udp:close()
		return address
	end)
	return ok and ip or "unknown"
end

local function flip(side)
	return side == "Player" and "Opponent" or "Player"
end

-- Fields that are only about this machine's animations
local LOCAL = { card_object = true, draw = true, card_path = true, border = true, card_width = true, card_height = true, glide_x = true, glide_y = true, glide_t = true, brew_t = true }

local function dump_card(c)
	local d = { path = c.card_path, border = c.border }
	for k, v in pairs(c) do
		local t = type(v)
		if not LOCAL[k] and (t == "number" or t == "string" or t == "boolean") then
			d[k] = v
		end
	end
	return d
end

-- The match as the host sees it
local function snapshot()
	local cards, hand = {}, {}
	for slot, c in pairs(played_cards) do
		cards[slot] = dump_card(c)
	end
	for i, c in ipairs(opponent_hand) do
		hand[i] = dump_card(c)
	end
	return {
		turn = turn, winner = winner or false, health = health, max_health = max_health, venom = venom, max_venom = max_venom,
		charm_used = play.charm_used, charm_cd = play.charm_cd, cards = cards, hand = hand,
	}
end

local function make_card(d)
	local c = card(d.path, img_widths, img_heights, d.border or nil)
	for k, v in pairs(d) do
		if k ~= "path" and k ~= "border" then
			c[k] = v
		end
	end
	return c
end

local function same_hand(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i].card_path ~= b[i].path or a[i].border ~= (b[i].border or nil) then
			return false
		end
	end
	return true
end

-- Guest: end the match here (the host's last snapshot, or a forfeit, or a dropped connection)
function versus.finish(winning_side)
	if game.state["playing"] then
		winner = winning_side
		collection.last_reward = play.forfeited and 0 or collection.reward(winner == "Player", 0, 0.5)
		update_game_state("ended")
	end
end

-- Guest: show the host's snapshot with the sides swapped
local function apply(snap)
	turn = flip(snap.turn)
	local function swap(t)
		return { Player = t.Opponent, Opponent = t.Player }
	end
	health, max_health, venom, max_venom = swap(snap.health), swap(snap.max_health), swap(snap.venom), swap(snap.max_venom)
	play.charm_used = swap(snap.charm_used)
	play.charm_cd = swap(snap.charm_cd)
	local fresh = {}
	for slot, d in pairs(snap.cards) do
		local at = slot > 4 and slot - 4 or slot + 4
		local old = played_cards[at]
		if old and old.card_path == d.path and old.border == (d.border or nil) then
			for k, v in pairs(old) do -- keep the object (its animations), but take the host's numbers
				if not LOCAL[k] and type(v) ~= "function" and type(v) ~= "userdata" then
					old[k] = nil
				end
			end
			for k, v in pairs(d) do
				if k ~= "path" and k ~= "border" then
					old[k] = v
				end
			end
			fresh[at] = old
		else
			fresh[at] = make_card(d)
		end
	end
	played_cards = fresh
	local mine = player_hand
	if held_card then -- the card being dragged is still part of the hand
		mine = { unpack(player_hand) }
		table.insert(mine, math.min(held_index or #mine + 1, #mine + 1), held_card)
	end
	if not same_hand(mine, snap.hand) then
		player_hand, card_hitboxes, held_card = {}, {}, nil
		for i, d in ipairs(snap.hand) do
			player_hand[i] = make_card(d)
		end
	end
	if snap.winner then
		versus.finish(flip(snap.winner))
	end
end

-- Guest: a held card was dropped on `sector`; sends the move if it is legal and takes the card out of the hand
-- (the host's next snapshot corrects anything it refused)
function versus.place(held, sector)
	local st = data.get_stats(held)
	if st.cost > venom.Player then
		return false
	end
	local slot
	if st.kind == "snake" then
		if not (sector and sector > 4 and not played_cards[sector] and play.lane_accepts(held, sector)) then
			return false
		end
		slot = sector - 4
		played_cards[sector] = held
		held.fresh = true
	elseif st.kind == "brew" then
		if not (sector and sector > 4 and played_cards[sector]) then
			return false
		end
		slot = sector - 4
	else
		local mx, my = mouse.x * reference_window_width / love.graphics.getWidth(), mouse.y * reference_window_height / love.graphics.getHeight()
		if not (sector or (mx > 245 and my < 560)) then
			return false
		end
		slot = sector and sector - 4 or nil
	end
	venom.Player = venom.Player - st.cost
	versus.send({ k = "play", name = held.card_path, slot = slot, i = held_index })
	return true
end

-- Host: carry out one of the guest's intents (it only counts on the guest's turn)
local function run(m)
	if m.k == "forfeit" then
		health.Opponent = 0
		play.check_end()
	elseif turn ~= "Opponent" or not game.state["playing"] then
		return
	elseif m.k == "play" and type(m.name) == "string" and data.stats_by_name[m.name:sub(1, -5)] then
		play.versus_card(tonumber(m.i) or 0, m.name, tonumber(m.slot))
	elseif m.k == "act" and tonumber(m.slot) and m.slot >= 1 and m.slot <= 4 then
		play.activate(m.slot)
	elseif m.k == "charm" then
		play.use_charm("Opponent")
	elseif m.k == "end" then
		play.end_turn()
	end
end

-- The decks a player brings: names and each copy's border
local function my_hello()
	local deck, borders = collection.deck()
	return { k = "hello", deck = deck, borders = borders or {}, charmer = chosen_avatar }
end

local function valid_hello(m)
	if m.k ~= "hello" or type(m.deck) ~= "table" or #m.deck < MIN_DECK or #m.deck > MAX_DECK or type(m.charmer) ~= "string" or not charmers.by_name[m.charmer] then
		return false
	end
	for i = 1, #m.deck do
		if type(m.deck[i]) ~= "string" or not data.stats_by_name[m.deck[i]] then
			return false
		end
	end
	m.borders = type(m.borders) == "table" and m.borders or {}
	return true
end

local function start_match(s)
	last_sent, sent_final = nil, false
	update_game_state("playing")
	versus.status = s
end

local function received(m)
	if m.k == "hello" and play.versus == nil and versus.mode == "host" then
		if valid_hello(m) then
			play.new_versus(m)
			versus.send({ k = "start", charmer = chosen_avatar })
			start_match("playing")
		else
			versus.status = "The other player's deck was not valid"
		end
	elseif m.k == "start" and versus.mode == "join" and type(m.charmer) == "string" then
		play.new_guest(m.charmer)
		start_match("playing")
	elseif m.k == "state" and play.versus == "guest" and game.state["playing"] and type(m.s) == "table" then
		pcall(apply, m.s)
	elseif play.versus == "host" then
		table.insert(queue, m)
	end
end

function versus.leave()
	if peer then
		pcall(function() peer:disconnect_now() end)
	end
	if host then
		pcall(function() host:flush() end)
	end
	host, peer, queue = nil, nil, {}
	versus.mode, versus.status = nil, ""
	play.end_versus()
end

local function dropped()
	peer = nil
	if play.versus and game.state["playing"] then
		if play.versus == "host" then
			health.Opponent = 0
			play.check_end()
		else
			versus.finish("Player")
		end
		versus.status = "The other player left"
	elseif not play.versus then
		versus.status = versus.mode == "join" and "Could not connect" or "The other player left"
	end
end

function versus.host()
	if #collection.deck() < MIN_DECK then
		versus.status = "Your deck needs at least " .. MIN_DECK .. " cards"
		return
	end
	versus.leave()
	local ok, h = pcall(enet.host_create, "*:" .. PORT, 1)
	if not (ok and h) then
		versus.status = "Could not open port " .. PORT
		return
	end
	host, versus.mode, versus.status = h, "host", "Waiting for a player to join"
end

function versus.join(ip)
	if #collection.deck() < MIN_DECK then
		versus.status = "Your deck needs at least " .. MIN_DECK .. " cards"
		return
	end
	versus.leave()
	local ok, h = pcall(enet.host_create)
	local connected, p = pcall(function() return h:connect(ip .. ":" .. PORT, 1) end)
	if not (ok and h and connected and p) then
		versus.status = "That address does not work"
		return
	end
	love.filesystem.write("versus_ip.txt", ip)
	host, peer, versus.mode, versus.status = h, p, "join", "Connecting..."
end

-- Called every frame
function versus.update()
	if not host then
		return
	end
	local ok, event = pcall(function() return host:service(0) end)
	while ok and event do
		if event.type == "connect" then
			peer = event.peer
			if versus.mode == "join" then
				versus.send(my_hello())
				versus.status = "Waiting for the host"
			end
		elseif event.type == "receive" then
			local m = versus.decode(event.data)
			if m then
				received(m)
			end
		elseif event.type == "disconnect" then
			dropped()
		end
		ok, event = pcall(function() return host:service(0) end)
	end
	if play.versus == "host" then
		while #queue > 0 do
			run(table.remove(queue, 1))
		end
		if not sent_final and (game.state["playing"] or game.state["ended"]) then
			local s = versus.encode({ k = "state", s = snapshot() })
			if peer and s ~= last_sent then
				last_sent = s
				peer:send(s, 0, "reliable")
			end
			sent_final = game.state["ended"]
		end
	end
end

function versus.textinput(text)
	if versus.mode == nil or versus.mode == "join" and not peer then
		if #versus.ip < 40 and text:match("^[%w%.:%-]+$") then
			versus.ip = versus.ip .. text
		end
	end
end

function versus.backspace()
	versus.ip = versus.ip:sub(1, -2)
end

return versus
