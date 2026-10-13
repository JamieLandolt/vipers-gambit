-- Headless balance simulator. Run from the project root:  luajit tools/sim.lua
--   (default)      bot player vs each level's AI: win rate, match length, stalemates
--   MODE=matrix    ability power: win-rate contribution of each ability kind x tier (mirror decks)
--   N=<games>      games per cell (default 300 for levels, 600 for matrix)
--   ALL=1          level mode: the player's deck is every card instead of the starter deck
--   EXTRA=<n>      level mode: the starter deck plus n random other snakes (opened packs)
--   FRAC=<0-1>     matrix mode: share of a deck's snakes that carry the ability (default 0.5)
package.path = "./?.lua;" .. package.path
package.preload["love"] = function() return { graphics = {}, mouse = {}, filesystem = {} } end
package.preload["Effects"] = function() return { add = function() end, clear = function() end } end
package.preload["Card"] = function() return function(p) return { card_path = p } end end
local data = require("CardData")
local abilities = require("Abilities")
local STARTERS = { "Snake", "Dirt_Snake", "Garter_Snake", "Mud_Snake", "Grass_Snake", "Brown_Snake", "Pale_Snake", "Coral_Snake" }
local player_deck = os.getenv("ALL") and data.deck or STARTERS
if os.getenv("EXTRA") then -- starters plus N random other snakes: a player who has opened some packs
	math.randomseed(7)
	player_deck = { unpack(STARTERS) }
	local owned, pool = {}, {}
	for _, name in ipairs(STARTERS) do owned[name] = true end
	for _, name in ipairs(data.deck) do
		if not owned[name] then pool[#pool + 1] = name end
	end
	for _ = 1, tonumber(os.getenv("EXTRA")) do player_deck[#player_deck + 1] = table.remove(pool, math.random(#pool)) end
end
package.preload["Collection"] = function() return { deck = function() return player_deck end, save = function() end } end
function contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function update_game_state(s) state = s end
function play_sound() end
img_widths, img_heights = 1, 1
unlocked = 1
local play, opponents = require("Play"), require("Opponents")
local TURN_CAP = 200

-- One side's scripted turn: spend venom on the best-scoring snakes, then on abilities
local W = { attack = 1, defense = 1, cost = 0.5, block = 2, open = 1 }
local function bot_turn(side)
	local base, ahead = side == "Player" and 4 or 0, side == "Player" and -4 or 4
	local hand = side == "Player" and player_hand or opponent_hand
	while true do
		local best, bi, bslot = -1e9
		for i, c in ipairs(hand) do
			local st = data.get_stats(c)
			if st.cost <= venom[side] then
				for slot = base + 1, base + 4 do
					if not played_cards[slot] and play.lane_accepts(c, slot) then
						local sc = W.attack * st.attack + W.defense * st.defense + W.cost * st.cost
							+ (played_cards[slot + ahead] and W.block or W.open) + math.random()
						if sc > best then best, bi, bslot = sc, i, slot end
					end
				end
			end
		end
		if not bi then break end
		local c = table.remove(hand, bi)
		venom[side] = venom[side] - data.get_stats(c).cost
		played_cards[bslot] = c
		played_cards[bslot].fresh = true
	end
	for slot = base + 1, base + 4 do
		local c = played_cards[slot]
		if c and not os.getenv('NOACT') and abilities.ready(c, side) then
			local ab = abilities.active(c)
			if ab.kind ~= "bolster" or #abilities.neighbours(slot) > 0 then
				play.activate(slot)
			end
		end
	end
end

-- Plays one match. kind of each side: "bot" or "ai" (the game's own opponent AI). Returns winner, turns.
local function match(level, opp_kind)
	state = nil
	play.new_game(level)
	local turns = 0
	while state ~= "ended" and turns < TURN_CAP do
		turns = turns + 1
		if turn == "Player" then
			bot_turn("Player")
			if state ~= "ended" then play.end_turn() end
		elseif opp_kind == "ai" then
			repeat
				local before = turns
				play.opponent_turn(1)
			until turn == "Player" or state == "ended"
		else
			bot_turn("Opponent")
			if state ~= "ended" then play.end_turn() end
		end
	end
	return state == "ended" and winner or nil, turns
end

local N = tonumber(os.getenv("N"))

if os.getenv("MODE") ~= "matrix" then
	N = N or 300
	math.randomseed(1)
	local total_turns, capped, games = 0, 0, 0
	local row = {}
	for level = 1, #opponents do
		local wins = 0
		for _ = 1, N do
			local w, t = match(level, "ai")
			wins = wins + (w == "Player" and 1 or 0)
			total_turns, games = total_turns + t, games + 1
			if not w then capped = capped + 1 end
		end
		row[#row + 1] = ("L%d %d%%"):format(level, math.floor(100 * wins / N + 0.5))
	end
	print("win rate by level: " .. table.concat(row, "  "))
	print(("avg length %.1f turns (%.1f rounds), %d/%d hit the %d-turn cap"):format(total_turns / games, total_turns / games / 2, capped, games, TURN_CAP))
	return
end

-- ---------- matrix mode ----------
N = N or 600
local FRAC = tonumber(os.getenv("FRAC")) or 0.5
local KINDS = { "strike", "drain", "heal", "shield", "empower", "bolster", "pack", "adj", "lane", "first", "lone", "armor", "guard", "thorns" }
if os.getenv("KINDS") then -- e.g. KINDS=strike,heal
	KINDS = {}
	for k in os.getenv("KINDS"):gmatch("[^,]+") do table.insert(KINDS, k) end
end
local by_tier = {}
for _, name in ipairs(data.deck) do
	local r = data.stats_by_name[name].rarity
	by_tier[r] = by_tier[r] or {}
	table.insert(by_tier[r], name)
end

local made = 0
local function clone(src, scale, code)
	made = made + 1
	local name = "Sim" .. made
	local s = data.stats_by_name[src]
	local function sc(v) return math.max(1, math.floor(v * scale + 0.5)) end
	data.stats_by_name[name] = {
		cost = math.min(10, sc(s.cost)), attack = sc(s.attack), defense = sc(s.defense),
		border = "Basic", rarity = s.rarity, ability_code = code, ability = "", lore = "",
	}
	data.card_types[name] = data.card_types[src]
	return name
end

-- Template snakes for a tier: the real ones; tiers with none (5) scale up the tier below, and
-- anything under 10 snakes is padded with slightly bigger / smaller copies
local function template(t)
	local list, src, scale = {}, t, 1
	while not by_tier[src] and src > 1 do src, scale = src - 1, scale * 1.35 end
	for _, n in ipairs(by_tier[src]) do table.insert(list, { n, scale }) end
	local factors, i = { 1.15, 0.87, 1.3 }, 0
	while #list < 10 do
		i = i + 1
		table.insert(list, { by_tier[src][(i - 1) % #by_tier[src] + 1], scale * factors[(i - 1) % 3 + 1] })
	end
	return list
end

local function code_for(kind, t, snake_type)
	if kind == "adj" then kind = "adj:" .. (snake_type == "Rainbow" and "Any" or snake_type) end
	if kind == "lane" then kind = "lane:" .. (snake_type == "Rainbow" and "Land" or snake_type) end
	if os.getenv("FORCE") then return os.getenv("FORCE") end
	return abilities.build(kind, t)
end

-- A deck of the tier's snakes; those picked by FRAC carry `code_t` for `kind`
local function deck_of(tmpl, kind, code_t)
	local deck = {}
	for i, e in ipairs(tmpl) do
		local code
		if kind and (i * 0.6180339) % 1 < FRAC then code = code_for(kind, code_t, data.card_types[e[1]]) end
		table.insert(deck, clone(e[1], e[2], code))
	end
	return deck
end

-- Win rate (%) of deck A against deck B, alternating who goes first
local stats = { turns = 0, games = 0, capped = 0 }
local function versus(a, b)
	opponents[1].venom = 0
	local wins = 0
	for g = 1, N do
		local a_first = g % 2 == 0
		player_deck, opponents[1].deck = a_first and a or b, a_first and b or a
		local w, t = match(1, "bot")
		stats.turns, stats.games = stats.turns + t, stats.games + 1
		if not w then
			stats.capped = stats.capped + 1
			wins = wins + 0.5
		elseif (w == "Player") == a_first then
			wins = wins + 1
			if os.getenv("DBG") then stats[a_first and "pw" or "ow"] = (stats[a_first and "pw" or "ow"] or 0) + 1 end
		end
	end
	return 100 * wins / N
end

math.randomseed(7)
local full = not os.getenv("TIERS")
if full then
	io.write("sanity (no abilities, mirror): ")
	for _, t in ipairs(tiers) do
		local tm = template(t)
		io.write(("T%d %.0f%%  "):format(t, versus(deck_of(tm), deck_of(tm))))
	end
	print()
end
print(("\nwin-rate contribution in points (ability on %d%% of a deck's snakes vs same deck with none); N=%d"):format(FRAC * 100, N))
local head = ("%-8s"):format("kind")
for _, t in ipairs(tiers) do head = head .. ("%7s"):format("T" .. t) end
print(head .. (full and " |    avg | T5 code vs T1 code on a T3 deck" or ""))
local col_sum = {}
for _, kind in ipairs(KINDS) do
	local row, sum = {}, 0
	for _, t in ipairs(tiers) do
		local tm = template(t)
		local c = versus(deck_of(tm, kind, t), deck_of(tm)) - 50
		row[#row + 1] = ("%+7.1f"):format(c)
		sum, col_sum[t] = sum + c, (col_sum[t] or 0) + c
	end
	local line = ("%-8s%s"):format(kind, table.concat(row, ""))
	if full then
		local tm = template(3)
		line = line .. (" | %+6.1f | %.0f%%"):format(sum / #tiers, versus(deck_of(tm, kind, 5), deck_of(tm, kind, 1)))
	end
	print(line)
end
local avg = {}
for _, t in ipairs(tiers) do avg[#avg + 1] = ("%+7.1f"):format(col_sum[t] / #KINDS) end
print(("%-8s%s"):format("mean", table.concat(avg, "")))
print(("avg match length %.1f turns (%.1f rounds); %d/%d games hit the %d-turn cap"):format(stats.turns / stats.games, stats.turns / stats.games / 2, stats.capped, stats.games, TURN_CAP))
