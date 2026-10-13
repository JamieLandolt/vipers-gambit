local love = require("love")
local lg = love.graphics
local card = require("Card")
local data = require("CardData")
local opponents = require("Opponents")
local collection = require("Collection")
local effects = require("Effects")
local abilities = require("Abilities")
local powers = require("Powers")
local charmers = require("Charmers")
local tutorial = require("Tutorial")

local play = {}
play.charm_used = { Player = false, Opponent = false } -- one charm per turn

local MAX_VENOM, HAND_SIZE, STARTING_HEALTH = 10, 5, 50
play.MAX_VENOM = MAX_VENOM
play.ai_delay = 0.7 -- seconds between opponent actions (set by Settings)

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

-- Centre of a played card in a sector (cards are drawn at 0.8 scale), and where each health bar sits
function play.slot_centre(sector)
	local box = play.field_hitboxes[sector]
	return box[1] + 54 + img_widths * 0.4, box[2] + 34 + img_heights * 0.4
end

play.bar_y = { Opponent = 30, Player = 500 }

local function place_effect(placed, sector)
	placed.fresh = true -- some abilities only work the turn a snake is played
	local cx, cy = play.slot_centre(sector)
	effects.add("place", { card = placed, cx = cx, cy = cy })
	powers.trigger("play", placed, sector)
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

-- Swaps two lane types, e.g. one dragged onto another
function play.swap_lane_types(lane_a, slot_a, lane_b, slot_b)
	local chips = play.lane_chips
	chips[lane_a][slot_a], chips[lane_b][slot_b] = chips[lane_b][slot_b], chips[lane_a][slot_a]
	set_lanes(chips)
	save_lanes()
end

set_lanes(DEFAULT_CHIPS)

function play.lane_accepts(card, slot)
	local snake_type = data.get_type(card)
	return snake_type == "Rainbow" or play.lane_types[(slot - 1) % 4 + 1][snake_type] == true
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

local function fill_hand(hand, deck, size)
	local chosen = {}
	while #hand < (size or HAND_SIZE) do
		local index = math.random(1, #deck)
		if not contains(chosen, index) then
			table.insert(hand, card(deck[index] .. ".png", img_widths, img_heights))
			table.insert(chosen, index)
		end
	end
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

local function destroy(slot, delay)
	local cx, cy = play.slot_centre(slot)
	local dead = played_cards[slot]
	effects.add("dead", { card = dead, sector = slot, cx = cx, cy = cy, delay = delay or 0 })
	played_cards[slot] = nil
	powers.trigger("death", dead, slot)
end
play.destroy = destroy

-- Has either side run out of health? Ends the match if so.
function play.check_end()
	for side, hp in pairs(health) do
		health[side] = math.max(hp, 0)
		if hp <= 0 then
			winner = side == "Player" and "Opponent" or "Player"
			level_unlocked = nil -- set when this win opens the next level
			if winner == "Player" and play.level == 0 then
				tutorial.finish()
			end
			if winner == "Player" and play.level == unlocked and unlocked < #opponents then
				unlocked, level_unlocked = unlocked + 1, unlocked + 1
				collection.save()
			end
			update_game_state("ended")
			return true
		end
	end
	return false
end

-- Start of a side's turn: venom and hand refill, then each of its snakes' border effects
function play.start_turn()
	play.charm_used[turn] = false
	max_venom[turn] = math.min(max_venom[turn] + 1, MAX_VENOM)
	venom[turn] = max_venom[turn]
	if play.level == 0 and turn == "Player" then
		fill_hand(player_hand, tutorial.player_deck, #tutorial.player_deck) -- the tutorial hand is fixed and small
	else
		fill_hand(hand_of(turn), turn == "Player" and collection.deck() or profile.deck)
	end

	for slot = turn == "Player" and 5 or 1, turn == "Player" and 8 or 4 do
		local c = played_cards[slot]
		if c then
			c.used = nil
			powers.trigger("turn", c, slot)
			local border = data.get_stats(c).border
			if border == "Gold" then
				venom[turn] = math.min(venom[turn] + 1, MAX_VENOM)
				float(slot, "+1 venom")
			elseif border == "Rainbow" then
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

function play.new_game(level)
	play.level = level
	profile = level == 0 and tutorial.profile or opponents[level] or opponents[1]
	turn = "Player"
	max_health = { Player = STARTING_HEALTH, Opponent = profile.health or STARTING_HEALTH }
	health = { Player = STARTING_HEALTH, Opponent = profile.health or STARTING_HEALTH }
	max_venom = { Player = level == 0 and 3 or 1, Opponent = 1 + (profile.venom or 0) } -- start_turn adds the first point, so turn 1 has 2
	venom = { Player = 0, Opponent = 0 }
	played_cards, player_hand, opponent_hand = {}, {}, {}
	held_card, winner, confirm_forfeit = nil, nil, false
	play.charm_used = { Player = false, Opponent = false }
	effects.clear()
	play.start_turn()
end

-- Damages a side's health directly
function play.hurt(side, amount, delay)
	health[side] = health[side] - amount
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
function play.redraw(side)
	local hand = hand_of(side)
	for i = #hand, 1, -1 do
		hand[i] = nil
	end
	card_hitboxes = {}
	if play.level == 0 and side == "Player" then
		fill_hand(hand, tutorial.player_deck, #tutorial.player_deck) -- the tutorial hand stays the four lesson snakes
	else
		fill_hand(hand, side == "Player" and collection.deck() or profile.deck)
	end
end

-- Hits the card in `slot` (or that side's health if the lane is empty) for `attack`, with the
-- attacker's border effects. `delay` times the visuals to the lunge that caused it.
function play.hit(attacker, slot, attack, delay)
	local defender, owner = played_cards[slot], owner_of(slot)
	local cx, cy = play.slot_centre(slot)
	if not defender then
		play.hurt(owner, attack, delay)
		return
	end

	local damage = abilities.mitigate(defender, slot, attack)
	defender.hp = (defender.hp or data.get_stats(defender).defense) - damage
	effects.add("hit", { card = defender, cx = cx, cy = cy, delay = delay })
	effects.add("float", { x = cx, y = cy, text = damage > 0 and "-" .. damage or "blocked", delay = delay })
	if damage > 0 then
		powers.trigger("hurt", defender, slot, attacker)
	end

	local border = data.get_stats(attacker).border
	if damage > 0 then
		if border == "Venom" then
			defender.poison = 2
		elseif border == "Frost" then
			defender.frozen = true
		end
	end
	if defender.hp <= 0 then
		if border == "Fire" and defender.hp < 0 then
			health[owner] = health[owner] + defender.hp -- the overkill carries through
		end
		destroy(slot, delay)
		for s, c in pairs(played_cards) do
			if c == attacker then
				powers.trigger("kill", attacker, s)
			end
		end
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
				powers.trigger("attack", attacker, slot)
				effects.add("lunge", { card = attacker, dir = side == "Player" and -1 or 1, delay = delay })
				play.hit(attacker, side == "Player" and column or column + 4, abilities.attack(attacker, slot), delay + 0.17)
			end
		end
	end
	for _, c in pairs(played_cards) do
		c.temp, c.fresh = nil, nil
	end
end

-- Pay venom to use the snake in `slot`'s activated ability (once per turn)
function play.activate(slot)
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
	elseif kind == "bolster" then
		for _, f in ipairs(abilities.neighbours(slot)) do
			f.card.temp = (f.card.temp or 0) + n
			float(f.slot, "+" .. n .. " atk")
		end
	end
	float(slot, kind)
	play_sound(hover_sound)
	play.check_end()
	return true
end

-- Can this side use its charmer's charm right now?
function play.charm_ready(side)
	return turn == side and not play.charm_used[side] and venom[side] >= charmers.of(side, play.level).cost
		and (side ~= "Player" or tutorial.allows("charm"))
end

-- Pay venom for the charm (once per turn); does nothing if the charm would have no effect
function play.use_charm(side)
	local charmer = charmers.of(side, play.level)
	if not play.charm_ready(side) or not charmer.apply(play, side) then
		return false
	end
	venom[side] = venom[side] - charmer.cost
	play.charm_used[side] = true
	play.float_bar(side, charmer.charm)
	play_sound(hover_sound)
	play.check_end()
	return true
end

function play.end_turn()
	play.resolve_combat(turn)
	if play.check_end() then
		return
	end
	turn = turn == "Player" and "Opponent" or "Player"
	play.start_turn()
end

-- AI: plays the highest scoring affordable (card, empty lane) pair, using the level's style weights
local function ai_play_card()
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
	ai_timer = ai_timer + dt
	if ai_timer < play.ai_delay then
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

-- If mouse is let go while a card is held, play it or put it back in the hand
function play.place_card()
	if love.mouse.isDown(1) or not held_card then
		return
	end
	local sector = field_sector_under_mouse()
	if mouse_over_info then
		update_game_state("info")
		info_card, info_return = held_card, "playing"
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
	held_card = nil
	play_sound(hover_sound)
end

return play
