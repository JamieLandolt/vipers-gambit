local love = require("love")
local lg = love.graphics
local card = require("Card")
local data = require("CardData")
local opponents = require("Opponents")
local challenges = require("Challenges")
local collection = require("Collection")
local effects = require("Effects")
local abilities = require("Abilities")
local powers = require("Powers")
local charmers = require("Charmers")
local tutorial = require("Tutorial")
local achievements = require("Achievements")

local play = {}
play.charm_used = { Player = false, Opponent = false } -- one charm per turn
play.charm_cd = { Player = 0, Opponent = 0 } -- turns of its owner still to wait after a charm (its cooldown)

local MAX_VENOM, HAND_SIZE, STARTING_HEALTH = 10, 5, 50
play.MAX_VENOM = MAX_VENOM
play.ai_delay = 0.7 -- seconds between opponent actions (set by Settings)

-- The turn log (drawn when switched on in Settings): the last few things that happened
play.log = {}
function play.note(text)
	table.insert(play.log, text)
	if #play.log > 9 then
		table.remove(play.log, 1)
	end
end

function play.name_of(c)
	return c and (c.card_path:sub(1, -5):gsub("_", " ")) or "a snake"
end

local sector_width, sector_height = 240, 270
-- x, y, width, height, sector
play.field_hitboxes = {
	{ 245, 15, sector_width, sector_height, 1 },
	{ 245 + sector_width - 10, 15, sector_width + 5, sector_height, 2 },
	{ 245 + sector_width * 2 - 5, 15, sector_width - 5, sector_height, 3 },
	{ 245 + sector_width * 3 - 10, 15, sector_width, sector_height, 4 },
	{ 245, 285, sector_width, sector_height, 5 },
	{ 245 + sector_width - 10, 285, sector_width + 5, sector_height, 6 },
	{ 245 + sector_width * 2 - 5, 285, sector_width - 5, sector_height, 7 },
	{ 245 + sector_width * 3 - 10, 285, sector_width, sector_height, 8 },
}

-- Centre of a played snake's art in a sector (the cell's middle, above the attack and health badges at its foot)
function play.slot_centre(sector)
	local box = play.field_hitboxes[sector]
	return box[1] + box[3] / 2, box[2] + 125
end

play.bar_y = { Opponent = 30, Player = 500 }

-- A campaign opponent's card is shown in its briefing once it has been played against you
function play.reveal(is_opponent, played)
	if is_opponent and play.level > 0 and not play.versus then
		collection.mark_hint("foe" .. play.level .. "_" .. played.card_path:sub(1, -5))
	end
end

-- Says what just happened at a spot on the field: a ring bursts there and a label shows above it
function play.callout(text, cx, cy, colour)
	effects.add("callout", { text = text, cx = cx, cy = cy, colour = colour })
end

local function place_effect(placed, sector)
	play.note((sector > 4 and "You play " or "Opponent plays ") .. play.name_of(placed))
	if sector <= 4 then
		local seen = "seen_" .. placed.card_path:sub(1, -5)
		if collection.hint_seen(seen) then
			local x, y = play.slot_centre(sector)
			play.callout("Opponent plays " .. play.name_of(placed):gsub("_", " "), x, y)
		else -- first time you see this snake: a close-up with its stats and ability
			collection.mark_hint(seen)
			effects.add("spotlight", { card = placed })
			play.ai_hold = effects.settled and effects.settled() + 0.3 or nil
		end
	end
	play.reveal(sector <= 4, placed)
	placed.fresh = true -- some abilities only work the turn a snake is played
	if data.border_of(placed) == "Rainbow" and data.get_stats(placed).kind == "snake" then -- its +1/+1 starts the moment it is played
		placed.bonus, placed.hp = (placed.bonus or 0) + 1, (placed.hp or data.get_stats(placed).defense) + 1
	end
	local cx, cy = play.slot_centre(sector)
	effects.add("place", { card = placed, cx = cx, cy = cy })
	play.check_end()
end

-- Each lane (column) accepts two snake types. The player can swap them around on the Lanes screen;
-- lane_chips[lane] is the two types in order and lane_types[lane] the same as a set for lookups.
local DEFAULT_CHIPS = { { "Land", "Water" }, { "Water", "Tree" }, { "Tree", "Spirit" }, { "Land", "Spirit" } }
play.lane_chips, play.lane_types = {}, {}

local function set_lanes(chips)
	for lane = 1, 4 do
		play.lane_chips[lane] = { chips[lane][1], chips[lane][2] }
		play.lane_types[lane] = { [chips[lane][1]] = true, [chips[lane][2]] = true }
	end
end

local function save_lanes()
	local lines = {}
	for lane = 1, 4 do
		lines[lane] = play.lane_chips[lane][1] .. "," .. play.lane_chips[lane][2]
	end
	love.filesystem.write("lanes.txt", table.concat(lines, "\n"))
end

function play.load_lanes()
	local chips, valid = {}, { Land = true, Water = true, Tree = true, Spirit = true }
	for line in (love.filesystem.read("lanes.txt") or ""):gmatch("[^\n]+") do
		local a, b = line:match("^(%a+),(%a+)$")
		if a and valid[a] and valid[b] then
			table.insert(chips, { a, b })
		end
	end
	set_lanes(#chips == 4 and chips or DEFAULT_CHIPS)
end

function play.reset_lanes()
	set_lanes(DEFAULT_CHIPS)
	save_lanes()
end

-- Ready-made lane layouts, picked with buttons on the Lanes screen
play.LANE_PRESETS = {
	{ name = "Default", chips = DEFAULT_CHIPS },
	{ name = "All Land", chips = { { "Land", "Land" }, { "Land", "Land" }, { "Land", "Land" }, { "Land", "Land" } } },
	{ name = "All Water", chips = { { "Water", "Water" }, { "Water", "Water" }, { "Water", "Water" }, { "Water", "Water" } } },
	{ name = "All Tree", chips = { { "Tree", "Tree" }, { "Tree", "Tree" }, { "Tree", "Tree" }, { "Tree", "Tree" } } },
	{ name = "All Spirit", chips = { { "Spirit", "Spirit" }, { "Spirit", "Spirit" }, { "Spirit", "Spirit" }, { "Spirit", "Spirit" } } },
	{ name = "Pairs", chips = { { "Land", "Water" }, { "Land", "Water" }, { "Tree", "Spirit" }, { "Tree", "Spirit" } } },
}

function play.apply_lane_preset(index)
	set_lanes(play.LANE_PRESETS[index].chips)
	save_lanes()
end

-- Changes a lane's type to the next one (Land, Water, Tree, Spirit, then round again); any combination is allowed
local ORDER = { "Land", "Water", "Tree", "Spirit" }
function play.cycle_lane_type(lane, slot)
	local chips = play.lane_chips
	for i, name in ipairs(ORDER) do
		if name == chips[lane][slot] then
			chips[lane][slot] = ORDER[i % #ORDER + 1]
			break
		end
	end
	set_lanes(chips)
	save_lanes()
end

set_lanes(DEFAULT_CHIPS)

function play.lane_accepts(card, slot)
	local snake_type = data.get_type(card)
	return snake_type == "Rainbow" or play.lane_types[(slot - 1) % 4 + 1][snake_type] == true
end

-- Versus matches use the default lanes for both players (the player's own layout comes back afterwards)
function play.versus_lanes(on)
	if on then
		set_lanes(DEFAULT_CHIPS)
	else
		play.load_lanes()
	end
end

function play.is_hitbox(x, y, hitbox)
	local rx = x * reference_window_width / lg.getWidth()
	local ry = y * reference_window_height / lg.getHeight()
	return rx > hitbox[1] and rx <= hitbox[1] + hitbox[3] and ry > hitbox[2] and ry <= hitbox[2] + hitbox[4]
end

local function hand_of(side)
	return side == "Player" and player_hand or opponent_hand
end

local profile = opponents[1]

-- Draws random cards from `deck` (names) into the hand; deck_borders[i] is that copy's border if it is a variant
-- The player's deck; during the guided first match only plain (border-less) snakes are drawn
local function player_deck()
	local deck, deck_borders = collection.deck()
	if not tutorial.active then
		return deck, deck_borders
	end
	local plain = {}
	for i, name in ipairs(deck) do
		if data.stats_by_name[name].border == "Basic" and not (deck_borders and deck_borders[i]) then
			plain[#plain + 1] = name
		end
	end
	if #plain == 0 then
		return deck, deck_borders
	end
	return plain, nil
end

-- Hands stay sorted by type (then cost), so the lanes they fit are easy to find
local TYPE_ORDER = { Land = 1, Water = 2, Tree = 3, Spirit = 4, Rainbow = 5, Brew = 6, Spell = 7 }
local function sort_hand(hand)
	table.sort(hand, function(a, b)
		local ta, tb = TYPE_ORDER[data.get_type(a)] or 9, TYPE_ORDER[data.get_type(b)] or 9
		if ta ~= tb then
			return ta < tb
		end
		local ca, cb = data.get_stats(a).cost, data.get_stats(b).cost
		if ca ~= cb then
			return ca < cb
		end
		return a.card_path < b.card_path
	end)
end
play.sort_hand = sort_hand

-- Each side draws from a shuffled pile of its deck: up to `size` cards, but always at least one a turn
-- (hands hold up to 8), until the pile runs out
local function fill_hand(side, hand, deck, size, deck_borders)
	play.pile = play.pile or {}
	local pile = play.pile[side]
	if not pile then
		pile = {}
		for i = 1, #deck do
			table.insert(pile, math.random(1, #pile + 1), i)
		end
		play.pile[side] = pile
	end
	for _ = 1, math.max((size or HAND_SIZE) - #hand, 1) do
		local index = #hand < 8 and table.remove(pile)
		if index then
			table.insert(hand, card(deck[index] .. ".png", img_widths, img_heights, deck_borders and deck_borders[index] or nil))
		end
	end
	sort_hand(hand)
end

local function owner_of(slot)
	return slot > 4 and "Player" or "Opponent"
end

local function float(slot, text, delay)
	local cx, cy = play.slot_centre(slot)
	effects.add("float", { x = cx, y = cy, text = text, delay = delay or 0 })
end

-- Floating text over a side's health bar
function play.float_bar(side, text, delay)
	effects.add("float", { x = 1315, y = play.bar_y[side], text = text, delay = delay or 0, colour = { 0.4, 1, 0.5 } })
end
play.float = float

-- Endless rematches: the opponent's snakes come out stronger the further the rank
local function scale_up(c)
	local s = play.challenge and play.challenge.scale
	if s then
		local st = data.get_stats(c)
		c.bonus, c.hp = (c.bonus or 0) + math.floor(st.attack * (s - 1) + 0.5), math.floor(st.defense * s + 0.5)
	end
end

local function destroy(slot, delay)
	local cx, cy = play.slot_centre(slot)
	local dead = played_cards[slot]
	if play.level ~= 0 then
		if slot > 4 then
			play.lost_snake = true
		else
			achievements.add("kills")
		end
	end
	play.note((slot > 4 and "Your " or "Enemy ") .. play.name_of(dead) .. " is destroyed")
	effects.add("sound", { name = "kill", delay = delay or 0 })
	effects.shake(6, delay)
	effects.add("dead", { card = dead, sector = slot, cx = cx, cy = cy, delay = delay or 0 })
	played_cards[slot] = nil
end
play.destroy = destroy

-- Sacrifice one of your snakes for free: it dies (a choice, so it does not count as a snake lost in battle)
function play.sacrifice(slot)
	if not played_cards[slot] or slot <= 4 or play.versus then
		return
	end
	local lost = play.lost_snake
	destroy(slot)
	play.lost_snake = lost
end

-- Has either side run out of health? Ends the match if so.
-- The end screen waits for the last attack's effects to play out (play.ending is when it opens)
local function end_match()
	local settled = effects.settled
	if settled then
		play.ending = settled() + 0.8
	else
		update_game_state("ended")
	end
end

function play.update_ending()
	if play.ending and time >= play.ending then
		play.ending = nil
		update_game_state("ended")
	end
end

function play.check_end()
	if play.ending then
		return true
	end
	for side, hp in pairs(health) do
		health[side] = math.max(hp, 0)
		if hp <= 0 then
			winner = side == "Player" and "Opponent" or "Player"
			if play.versus then -- no campaign progress, just a small reward
				collection.last_reward = play.forfeited and 0 or collection.reward(winner == "Player", 0, 0.5)
				end_match()
				return true
			end
			level_unlocked, charmer_unlocked = nil, nil -- set when this win opens the next level, or a new charmer
			if tutorial.active then -- the guided first match ends with the match
				tutorial.finish()
			end
			if winner == "Player" and play.level == unlocked and unlocked < #opponents then
				unlocked, level_unlocked = unlocked + 1, unlocked + 1
				local charmer = require("Charmers").list[(unlocked - 1) / require("LevelNodes").per_region + 1]
				charmer_unlocked = charmer and charmer.name
				charmer_guide = charmer_unlocked and true or nil -- circles Back, Gameplay and Charmers until the player opens Charmers
				collection.save()
			end
			if winner == "Player" and play.level > 0 then
				collection.record_win(play.level, play.challenge)
				achievements.add("wins")
				achievements.set("best_level", play.level)
				if not play.lost_snake then
					achievements.set("flawless", 1)
				end
			end
			if winner == "Player" and play.level == #opponents then
				love.filesystem.write("finale.txt", "1") -- the last level has no \"next level\" to show it was beaten
			end
			collection.last_reward = collection.reward(winner == "Player", play.level, play.challenge and play.challenge.mult)
			end_match()
			return true
		end
	end
	return false
end

-- Leaving a campaign match in its first 30 seconds costs nothing
function play.free_exit()
	return not play.versus and not tutorial.active and play.started and time - play.started < 30
end

-- Start of a side's turn: venom and hand refill, then each of its snakes' border effects
function play.start_turn()
	play.charm_used[turn] = false
	play.charm_cd[turn] = math.max(0, play.charm_cd[turn] - 1)
	max_venom[turn] = math.min(max_venom[turn] + 1, MAX_VENOM)
	venom[turn] = math.min(venom[turn] + max_venom[turn], MAX_VENOM) -- unspent venom carries over
	if turn == "Player" then
		local deck, deck_borders = player_deck()
		fill_hand("Player", player_hand, deck, play.challenge and play.challenge.hand_size or nil, deck_borders)
	else
		fill_hand("Opponent", opponent_hand, profile.deck, nil, profile.deck_borders)
	end

	for slot = turn == "Player" and 5 or 1, turn == "Player" and 8 or 4 do
		local c = played_cards[slot]
		if c then
			c.used = nil
			require("Brews").turn(play, c, slot)
			local border = data.border_of(c)
			if border == "Rainbow" then
				c.bonus, c.hp = (c.bonus or 0) + 1, (c.hp or data.get_stats(c).defense) + 1
				float(slot, "+1/+1")
			end
			if c.poison then
				c.hp = (c.hp or data.get_stats(c).defense) - 1
				c.poison = c.poison > 1 and c.poison - 1 or nil
				float(slot, "poison")
				if c.hp <= 0 then
					destroy(slot)
				end
			end
		end
	end
end

-- What the next match against a level is: the plain fight the first time, then its three challenges in order, then
-- endless rematches whose health, venom and snake strength keep rising with every win.
function play.next_fight(level)
	if not collection.beaten_base(level) then
		return nil
	end
	local list = challenges[level]
	local done = collection.challenges_done(level)
	if done < #list then
		return list[done + 1]
	end
	local rank, last = collection.endless(level) + 1, list[#list]
	local e = {}
	for k, v in pairs(last) do
		e[k] = v
	end
	e.tier, e.endless, e.scale = nil, rank, 1 + 0.1 * rank
	e.opp_health, e.opp_venom = (last.opp_health or 1) * (1 + 0.25 * rank), (last.opp_venom or 0) + rank
	e.name = "Endless " .. rank
	e.text = ("Enemy health x%.1f, +%d venom, snakes %d%% stronger"):format(e.opp_health, e.opp_venom, rank * 10) .. (last.player_health and "; your health -20%" or "")
	e.mult = math.min(last.mult * (1 + 0.15 * rank), 12)
	return e
end

-- Starts a match from the level screen
-- Can the level be picked?
function play.level_open(level)
	return level <= unlocked
end

function play.begin(level)
	play.end_versus()
	local guided = level == 1 and not tutorial.done -- the first match is guided; each later level teaches one new thing
	if not guided and not collection.spend_vials(1) then -- every other match costs a venom vial
		collection.message, collection.message_t = "Out of venom vials! They refill over time.", time
		return false
	end
	if guided then
		tutorial.start()
	else
		tutorial.active = false
	end
	play.new_game(level, play.next_fight(level))
	if not guided then
		tutorial.tip(level)
	end
	animation, animation_time = true, 0
	update_animation_screen("playing")
	return true
end

-- `challenge` (an entry of Challenges.lua) is only passed for levels already beaten
function play.new_game(level, challenge)
	play.level, play.challenge = level, challenge
	local c = challenge or {}
	profile = opponents[level] or opponents[1]
	turn = "Player"
	local mine, theirs = math.floor(STARTING_HEALTH * (c.player_health or 1)) + collection.health_bonus(), math.floor((profile.health or STARTING_HEALTH) * (c.opp_health or 1))
	max_health = { Player = mine, Opponent = theirs }
	health = { Player = mine, Opponent = theirs }
	max_venom = { Player = 1, Opponent = 1 + (profile.venom or 0) + (c.opp_venom or 0) } -- start_turn adds the first point, so turn 1 has 2
	venom = { Player = 0, Opponent = 0 }
	played_cards, player_hand, opponent_hand, play.pile = {}, {}, {}, {}
	held_card, winner, confirm_forfeit, play.ending, play.ai_hold, play.forfeited = nil, nil, false, nil, nil, false
	play.log, play.lost_snake, play.started = {}, false, time
	play.charm_used, play.charm_cd = { Player = false, Opponent = false }, { Player = 0, Opponent = 0 }
	effects.clear()
	for i, name in ipairs(c.opp_start or {}) do -- challenge: the opponent begins with snakes already in play
		played_cards[i] = card(name .. ".png", img_widths, img_heights)
		scale_up(played_cards[i])
	end
	play.start_turn()
end

-- Versus: the host runs the match and plays the guest's moves as the Opponent (see Versus.lua)
-- `guest` is the guest's hello: its deck (names), borders (per copy) and charmer
function play.new_versus(guest)
	play.versus = "host"
	versus_charmer = guest.charmer
	play.versus_lanes(true)
	play.new_game(-1)
	profile = { name = "Opponent", deck = guest.deck, deck_borders = guest.borders, health = STARTING_HEALTH, venom = 0 }
end

-- The guest only mirrors what the host sends; its Player side is the host's Opponent
function play.new_guest(host_charmer)
	play.versus, play.level, play.challenge = "guest", -1, nil
	versus_charmer = host_charmer
	play.versus_lanes(true)
	turn = "Opponent"
	max_health, health = { Player = STARTING_HEALTH, Opponent = STARTING_HEALTH }, { Player = STARTING_HEALTH, Opponent = STARTING_HEALTH }
	max_venom, venom = { Player = 1, Opponent = 1 }, { Player = 0, Opponent = 0 }
	played_cards, player_hand, opponent_hand, play.pile = {}, {}, {}, {}
	held_card, winner, confirm_forfeit, play.ending, play.ai_hold, play.forfeited = nil, nil, false, nil, nil, false
	play.log, play.lost_snake = {}, false
	play.charm_used, play.charm_cd = { Player = false, Opponent = false }, { Player = 0, Opponent = 0 }
	card_hitboxes = {}
	effects.clear()
end

-- Leaves versus mode (the connection is closed by Versus.leave)
function play.end_versus()
	if play.versus then
		play.versus, versus_charmer = nil, nil
		play.versus_lanes(false)
	end
end

-- Host: the guest (the Opponent) plays hand card `name` onto host slot `slot` (1-4); brews need one of its
-- snakes, spells need no slot. Anything illegal is ignored.
function play.versus_card(index, name, slot)
	local c = opponent_hand[index]
	if not c or c.card_path ~= name then
		for i, other in ipairs(opponent_hand) do
			if other.card_path == name then
				index, c = i, other
				break
			end
		end
	end
	if not c or turn ~= "Opponent" then
		return false
	end
	local st = data.get_stats(c)
	if st.cost > venom.Opponent then
		return false
	end
	local on_board = type(slot) == "number" and slot >= 1 and slot <= 4 and played_cards[slot]
	if st.kind == "snake" then
		if type(slot) ~= "number" or slot < 1 or slot > 4 or played_cards[slot] or not play.lane_accepts(c, slot) then
			return false
		end
		table.remove(opponent_hand, index)
		venom.Opponent = venom.Opponent - st.cost
		played_cards[slot] = c
		place_effect(c, slot)
		return true
	end
	local Brews = require("Brews")
	local def, done = Brews.by_name[name:sub(1, -5)], false
	if st.kind == "brew" then
		done = on_board and not on_board.brew and Brews.drink(play, def, slot)
	else
		done = def.cast(play, "Opponent") ~= false
		play.flash = { colour = def.colour, t = time }
	end
	if done then
		play.note("Opponent uses " .. play.name_of(c))
		effects.add("sound", { name = st.kind == "brew" and "brew" or "spell" })
		table.remove(opponent_hand, index)
		venom.Opponent = venom.Opponent - st.cost
		play.check_end()
	end
	return done
end

-- Damages a side's health directly
-- Damage is worked out at once, but the numbers on screen only drop when the blow lands: each pending loss is kept here
-- until its time, and shown_health / shown_hp add it back meanwhile
local lag = {}

local function lose_later(who, amount, delay, stat) -- stat: "hp" (default) or "atk"; a negative amount is a gain
	if delay and delay > 0 and amount ~= 0 then
		lag[#lag + 1] = { who = who, amount = amount, at = time + delay, stat = stat or "hp" }
	end
end
play.defer = lose_later

local function pending(who, stat)
	local total = 0
	for i = #lag, 1, -1 do
		if lag[i].at <= time then
			table.remove(lag, i)
		elseif lag[i].who == who and lag[i].stat == (stat or "hp") then
			total = total + lag[i].amount
		end
	end
	return total
end

function play.shown_health(side)
	return health[side] + pending(side)
end

function play.shown_hp(card)
	return (card.hp or data.get_stats(card).defense) + pending(card)
end

-- A snake's attack as shown: a gain from a blow that has not landed yet is not counted
function play.shown_attack(card, sector)
	return abilities.attack(card, sector) - pending(card, "atk")
end

function play.hurt(side, amount, delay)
	lose_later(side, amount, delay)
	health[side] = health[side] - amount
	play.note((side == "Player" and "You take " or "Opponent takes ") .. amount .. " damage")
	if amount >= 3 then
		effects.shake(math.min(amount, 10) * 0.8, delay)
	end
	effects.add("hp", { side = side, delay = delay or 0 })
	effects.add("float", { x = 1315, y = play.bar_y[side], text = "-" .. amount, delay = delay or 0 })
end

-- Damages a snake outright (no border effects or mitigation)
function play.wound(slot, amount)
	local c = played_cards[slot]
	local cx, cy = play.slot_centre(slot)
	c.hp = (c.hp or data.get_stats(c).defense) - amount
	effects.add("hit", { card = c, cx = cx, cy = cy })
	float(slot, "-" .. amount)
	if c.hp <= 0 then
		destroy(slot)
	end
end

-- Discards a side's hand and draws a fresh one
-- Draws one more card into a side's hand (hands hold up to 8), if its pile has any left
function play.draw_extra(side)
	local deck, deck_borders = profile.deck, profile.deck_borders
	if side == "Player" then
		deck, deck_borders = player_deck()
	end
	local hand = hand_of(side)
	fill_hand(side, hand, deck, #hand + 1, deck_borders)
end

function play.redraw(side)
	local hand = hand_of(side)
	for i = #hand, 1, -1 do
		hand[i] = nil
	end
	card_hitboxes = {}
	play.pile = play.pile or {}
	play.pile[side] = nil -- a redraw reshuffles the whole deck
	if side == "Player" then
		local deck, deck_borders = player_deck()
		fill_hand(side, hand, deck, play.challenge and play.challenge.hand_size or nil, deck_borders)
	else
		fill_hand(side, hand, profile.deck, nil, profile.deck_borders)
	end
end

-- Hits the card in `slot` (or that side's health if the lane is empty) for `attack`, with the
-- attacker's border effects. `delay` times the visuals to the lunge that caused it.
function play.hit(attacker, slot, attack, delay)
	play.fx_delay = delay -- pop-ups and stat changes caused by this blow wait for it to land (see Powers.lua)
	play.hit_now(attacker, slot, attack, delay)
	play.fx_delay = nil
end

function play.hit_now(attacker, slot, attack, delay)
	local defender, owner = played_cards[slot], owner_of(slot)
	local cx, cy = play.slot_centre(slot)
	if not defender then
		play.hurt(owner, attack, delay)
		return
	end

	local damage = abilities.mitigate(defender, slot, attack)
	lose_later(defender, damage, delay)
	defender.hp = (defender.hp or data.get_stats(defender).defense) - damage
	effects.add("hit", { card = defender, cx = cx, cy = cy, delay = delay, border = data.border_of(attacker) })
	effects.add("float", { x = cx, y = cy, text = damage > 0 and "-" .. damage or "blocked", delay = delay })
	effects.add("sound", { name = "hit", delay = delay })
	play.note(play.name_of(attacker) .. " hits " .. play.name_of(defender) .. (damage > 0 and " for " .. damage or " (blocked)"))
	if damage > 0 then
	end

	local border = data.border_of(attacker)
	if damage > 0 then
		if border == "Venom" or attacker.brew == "venom" then
			defender.poison, defender.fx_at = 2, time + (delay or 0)
		elseif attacker.brew == "frost" then
			defender.frozen, defender.fx_at = true, time + (delay or 0)
		end
	end
	if attacker.brew == "leech" and damage > 0 then
		for s, c in pairs(played_cards) do
			if c == attacker then
				require("Brews").heal(play, s, attacker, 3)
			end
		end
	end
	if defender.hp <= 0 then
		if defender.hp < 0 then -- damage beyond the kill goes through to the owner's health (doubled by Fire)
			play.hurt(owner, math.ceil(-defender.hp * (attacker.brew == "fire" and 1.5 or 1)), delay)
		end
		destroy(slot, delay)
	end

	local thorns = abilities.thorns(defender)
	if thorns > 0 and damage > 0 then
		for s, c in pairs(played_cards) do
			if c == attacker then
				attacker.hp = (attacker.hp or data.get_stats(attacker).defense) - thorns
				float(s, "-" .. thorns, delay)
				if attacker.hp <= 0 then
					destroy(s, delay)
				end
			end
		end
	end
end

-- Lane duels: the active side's cards hit whatever is opposite them (slot +/- 4); an empty
-- lane hits health. Frozen snakes sit the attack out.
function play.resolve_combat(side)
	for column = 1, 4 do
		local slot = side == "Player" and column + 4 or column
		local attacker = played_cards[slot]
		if attacker then
			-- Lanes play out one after another; the blow lands when the lunge peaks
			local delay = (column - 1) * 0.3
			if attacker.frozen then
				attacker.frozen = nil
				float(slot, "frozen", delay)
			else
				effects.add("lunge", { card = attacker, dir = side == "Player" and -1 or 1, delay = delay })
				play.hit(attacker, side == "Player" and column or column + 4, abilities.attack(attacker, slot), delay + 0.17)
			end
		end
	end
	-- This turn's extra attack runs out now, but it stays on the card while the attacks play out
	local wait = effects.settled and math.max(effects.settled() - time, 0) or 0
	for slot, c in pairs(played_cards) do
		local before = abilities.attack(c, slot)
		c.temp, c.fresh = nil, nil
		lose_later(c, abilities.attack(c, slot) - before, wait, "atk")
	end
end

local ABILITY_COLOUR = {
	strike = { 1, 0.35, 0.3 }, drain = { 0.85, 0.2, 0.5 }, heal = { 0.4, 1, 0.55 }, shield = { 0.55, 0.8, 1 },
	empower = { 1, 0.6, 0.2 }, cripple = { 0.6, 0.4, 0.9 }, power = { 0.9, 0.5, 1 }, refresh = { 1, 0.95, 0.4 }, bolster = { 1, 0.8, 0.3 },
}

-- Pay venom to use the snake in `slot`'s activated ability (once per turn)
function play.activate(slot)
	if play.versus == "guest" then
		return slot > 4 and require("Versus").send({ k = "act", slot = slot - 4 })
	end
	local card = played_cards[slot]
	local side = owner_of(slot)
	if not card or turn ~= side or not abilities.ready(card, side) then
		return false
	end
	local ab = abilities.active(card)
	local kind, n, cost = ab.kind, ab.args[1], ab.args[2]
	local defense = data.get_stats(card).defense
	venom[side] = venom[side] - cost
	card.used = true
	play.note(play.name_of(card) .. " uses its ability")
	local ax, ay = play.slot_centre(slot)
	play.callout(nil, ax, ay, ABILITY_COLOUR[kind])

	local ahead = slot > 4 and slot - 4 or slot + 4
	if kind == "strike" or kind == "drain" then
		play.hit(card, ahead, n, 0)
		if kind == "drain" then
			card.hp = math.min((card.hp or defense) + n, defense)
		end
	elseif kind == "heal" then
		card.hp = math.min((card.hp or defense) + n, defense)
	elseif kind == "shield" then
		card.shield = (card.shield or 0) + n
	elseif kind == "empower" then
		card.bonus = (card.bonus or 0) + n
	elseif kind == "power" then
		powers.use(card, slot)
	elseif kind == "cripple" then
		local foe = played_cards[ahead]
		foe.bonus = (foe.bonus or 0) - n
		float(ahead, "-" .. n .. " atk")
	elseif kind == "refresh" then -- other snakes may use their abilities again (not other refreshers, so it can't loop)
		for other = side == "Player" and 5 or 1, side == "Player" and 8 or 4 do
			local c = played_cards[other]
			if c and c ~= card and c.used and abilities.active(c).kind ~= "refresh" then
				c.used = nil
				float(other, "ready again")
			end
		end
	elseif kind == "bolster" then
		for _, f in ipairs(abilities.neighbours(slot)) do
			f.card.temp = (f.card.temp or 0) + n
			float(f.slot, "+" .. n .. " atk")
		end
	end
	play_sound(hover_sound)
	play.check_end()
	return true
end

-- Can this side use its charmer's charm right now?
-- Charms are introduced at level 4 (versus matches have them from the start); before that neither side has one
local CHARM_LEVEL = 4
function play.charms_open(level)
	return play.versus ~= nil or (level or play.level) >= CHARM_LEVEL
end

function play.charm_ready(side)
	return play.charms_open() and turn == side and not play.charm_used[side] and play.charm_cd[side] <= 0 and not (side == "Player" and play.challenge and play.challenge.no_charm) and venom[side] >= charmers.of(side, play.level).cost
		and (side ~= "Player" or tutorial.allows("charm"))
end

-- Pay venom for the charm (once per turn); does nothing if the charm would have no effect
function play.use_charm(side)
	if play.versus == "guest" then
		return play.charm_ready("Player") and require("Versus").send({ k = "charm" })
	end
	local charmer = charmers.of(side, play.level)
	if not play.charm_ready(side) or not charmer.apply(play, side) then
		return false
	end
	venom[side] = venom[side] - charmer.cost
	play.charm_used[side] = true
	play.charm_cd[side] = charmer.cooldown + 1 -- counts down at the start of each of its owner's turns
	play.charm_pulse = { side = side, t = time, colour = charmer.colour or { 1, 1, 1 } } -- drawn round the charmer (see render.playing)
	play.note((side == "Player" and "You use " or "Opponent uses ") .. charmer.charm)
	play.float_bar(side, charmer.charm)
	if side == "Opponent" then
		play.callout("Opponent uses " .. charmer.charm, 1315, play.bar_y.Opponent, charmer.colour)
	end
	play_sound(hover_sound)
	play.check_end()
	return true
end

function play.end_turn()
	if play.versus == "guest" then
		return require("Versus").send({ k = "end" })
	end
	play.resolve_combat(turn)
	if play.check_end() then
		return
	end
	local next_side = turn == "Player" and "Opponent" or "Player"
	if effects.settled and not play.versus then
		-- the new turn only starts (venom, hand, border effects like Rainbow's) once the attacks have finished playing
		play.next_turn = { side = next_side, at = effects.settled() + 0.4 }
		turn = "Waiting"
		return
	end
	play.begin_turn(next_side)
end

function play.begin_turn(side)
	turn = side
	if turn == "Opponent" then -- let the player's attacks finish before the opponent plays anything
		play.ai_hold = effects.settled and effects.settled() + 0.8 or nil -- (headless tests and the sim have no effects to wait for)
	end
	play.note("-- " .. (turn == "Player" and "Your" or "Opponent's") .. " turn --")
	play.start_turn()
end

-- Uses the first affordable brew or spell in a side's hand (the AI and the sim bots): brews go on the side's strongest
-- snake without one, spells are cast. Returns true if one was used.
function play.use_support(side)
	local hand, Brews = hand_of(side), require("Brews")
	for i, c in ipairs(hand) do
		local st = data.get_stats(c)
		if (st.kind == "brew" or st.kind == "spell") and st.cost <= venom[side] then
			local def, done = Brews.by_name[c.card_path:sub(1, -5)], false
			if st.kind == "brew" then
				local best
				for slot = side == "Player" and 5 or 1, side == "Player" and 8 or 4 do
					local s = played_cards[slot]
					if s and not s.brew and (not best or data.get_stats(s).attack > data.get_stats(played_cards[best]).attack) then
						best = slot
					end
				end
				done = best and Brews.drink(play, def, best)
			else
				done = def.cast(play, side) ~= false
				play.flash = { colour = def.colour, t = time }
			end
			if done then
				play.note((side == "Player" and "You use " or "Opponent uses ") .. play.name_of(c))
				play.reveal(side == "Opponent", c)
				effects.add("sound", { name = st.kind == "brew" and "brew" or "spell" })
				if side == "Opponent" then
					play.callout("Opponent uses " .. play.name_of(c):gsub("_", " "), 720, 230, def.colour)
				end
				table.remove(hand, i)
				venom[side] = venom[side] - st.cost
				play.check_end()
				return true
			end
		end
	end
	return false
end

-- AI: plays the highest scoring affordable (card, empty lane) pair, using the level's style weights
local function ai_play_card()
	if play.use_support("Opponent") then
		return true
	end
	local w, best_score, best_card, best_slot = profile.style, -math.huge
	for i, c in ipairs(opponent_hand) do
		local stats = data.get_stats(c)
		if stats.cost <= venom.Opponent then
			for slot = 1, 4 do
				if not played_cards[slot] and play.lane_accepts(c, slot) then
					local score = w.attack * stats.attack + w.defense * stats.defense + w.cost * stats.cost
					score = score + (played_cards[slot + 4] and w.block or w.open) + math.random() -- random breaks ties
					if score > best_score then
						best_score, best_card, best_slot = score, i, slot
					end
				end
			end
		end
	end
	if not best_card then
		return false
	end

	local c = table.remove(opponent_hand, best_card)
	venom.Opponent = venom.Opponent - data.get_stats(c).cost
	played_cards[best_slot] = c
	scale_up(c)
	place_effect(c, best_slot)
	return true
end

-- Spends leftover venom on a snake's activated ability
local function ai_activate()
	for slot = 1, 4 do
		local c = played_cards[slot]
		if c and abilities.ready(c, "Opponent") then
			local ab = abilities.active(c)
			if ab.kind ~= "bolster" or #abilities.neighbours(slot) > 0 then
				return play.activate(slot)
			end
		end
	end
	return false
end

local ai_timer = 0

-- One action per play.ai_delay so the player can follow what the opponent does
function play.opponent_turn(dt)
	local waiting = play.next_turn
	if turn == "Waiting" and waiting then -- between turns: the next one starts when the attacks have finished playing
		if time >= waiting.at then
			play.next_turn = nil
			play.begin_turn(waiting.side)
		end
		return
	end
	if time < (play.ai_hold or 0) then
		return
	end
	ai_timer = ai_timer + dt
	if ai_timer < play.ai_delay + 0.4 then -- (a little slower than the setting, so each action can be followed)
		return
	end
	ai_timer = 0
	if not ai_play_card() and not ai_activate() and not play.use_charm("Opponent") then
		play.end_turn()
	end
end

-- The player may only drop onto an empty slot in their own half (5-8)
local function can_play(held, sector)
	return sector > 4 and not played_cards[sector] and play.lane_accepts(held, sector) and data.get_stats(held).cost <= venom.Player
end

local function field_sector_under_mouse()
	for _, hitbox in ipairs(play.field_hitboxes) do
		if play.is_hitbox(mouse.x, mouse.y, hitbox) then
			return hitbox[5]
		end
	end
end

-- A brew is drunk by the player's snake it is dropped on; a spell works wherever it is dropped over the field.
-- Returns true if the card was used up.
local function use_consumable(held, sector)
	local st = data.get_stats(held)
	local def = require("Brews").by_name[held.card_path:sub(1, -5)]
	local mx, my = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
	local function refuse(text)
		effects.add("float", { x = mx, y = my - 40, text = text })
	end
	if st.cost > venom.Player then
		refuse("not enough venom")
		return false
	end
	if st.kind == "brew" then
		if not (sector and sector > 4 and played_cards[sector]) then
			refuse("drop it on one of your snakes")
			return false
		end
		require("Brews").drink(play, def, sector)
		achievements.add("brews")
		effects.add("sound", { name = "brew" })
		play.note("You use " .. play.name_of(held))
	else
		if def.target == "enemy" and not (sector and sector <= 4 and played_cards[sector]) then
			if sector or (mx > 245 and my < 560) then
				refuse("drop it on an enemy snake")
			end
			return false
		end
		if not (sector or (mx > 245 and my < 560)) then
			return false -- dropped away from the field
		end
		if def.cast(play, "Player", sector) == false then
			refuse("no effect")
			return false
		end
		play.flash = { colour = def.colour, t = time }
		effects.add("float", { x = 720, y = 300, text = def.name:gsub("_", " ") })
		achievements.add("spells")
		effects.add("sound", { name = "spell" })
		play.note("You cast " .. play.name_of(held))
	end
	venom.Player = venom.Player - st.cost
	play.check_end()
	return true
end

-- If mouse is let go while a card is held, play it or put it back in the hand
function play.place_card()
	if love.mouse.isDown(1) or not held_card then
		return
	end
	local sector = field_sector_under_mouse()
	if time - (held_since or 0) < 0.25 and math.abs(mouse.x - held_at[1]) + math.abs(mouse.y - held_at[2]) < 12 then
		-- a quick click rather than a drag: the snake just goes back to the hand
		table.insert(player_hand, math.min(held_index or #player_hand + 1, #player_hand + 1), held_card)
		sort_hand(player_hand)
		held_card = nil
		play_sound(hover_sound)
		return
	elseif play.versus == "guest" then
		if require("Versus").place(held_card, sector) then
			held_card = nil
			play_sound(hover_sound)
			return
		end
	elseif data.get_stats(held_card).kind ~= "snake" then
		if use_consumable(held_card, sector) then
			held_card = nil
			play_sound(hover_sound)
			return
		end
	elseif sector and can_play(held_card, sector) then
		played_cards[sector] = held_card
		place_effect(held_card, sector)
		venom.Player = venom.Player - data.get_stats(held_card).cost
		held_card = nil
		play_sound(hover_sound)
		return
	end

	-- If card is dropped but not played
	-- It glides back from where it was let go to its old place in the hand
	held_card.glide_x = mouse.x * reference_window_width / lg.getWidth() - img_widths / 2
	held_card.glide_y = mouse.y * reference_window_height / lg.getHeight() - img_heights / 2
	held_card.glide_t = time
	table.insert(player_hand, math.min(held_index or #player_hand + 1, #player_hand + 1), held_card)
	sort_hand(player_hand)
	held_card = nil
	play_sound(hover_sound)
end

return play
