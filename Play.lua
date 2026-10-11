local love = require("love")
local lg = love.graphics
local card = require("Card")
local data = require("CardData")
local opponents = require("Opponents")

local play = {}

local MAX_VENOM, HAND_SIZE, STARTING_HEALTH, AI_DELAY = 10, 5, 20, 0.7

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

function play.is_hitbox(x, y, hitbox)
	local rx = x * reference_window_width / lg.getWidth()
	local ry = y * reference_window_height / lg.getHeight()
	return rx > hitbox[1] and rx <= hitbox[1] + hitbox[3] and ry > hitbox[2] and ry <= hitbox[2] + hitbox[4]
end

local function hand_of(side)
	return side == "Player" and player_hand or opponent_hand
end

local profile = opponents[1]

local function fill_hand(hand, deck)
	local chosen = {}
	while #hand < HAND_SIZE do
		local index = math.random(1, #deck)
		if not contains(chosen, index) then
			table.insert(hand, card(deck[index] .. ".png", img_widths, img_heights))
			table.insert(chosen, index)
		end
	end
end

function play.start_turn()
	max_venom[turn] = math.min(max_venom[turn] + 1, MAX_VENOM)
	venom[turn] = max_venom[turn]
	fill_hand(hand_of(turn), turn == "Player" and data.deck or profile.deck)
end

function play.new_game(level)
	profile = opponents[level] or opponents[1]
	turn = "Player"
	health = { Player = STARTING_HEALTH, Opponent = STARTING_HEALTH }
	max_venom = { Player = 1, Opponent = 1 } -- start_turn adds the first point, so turn 1 has 2
	venom = { Player = 0, Opponent = 0 }
	played_cards, player_hand, opponent_hand = {}, {}, {}
	held_card, winner = nil, nil
	play.start_turn()
end

-- Lane duels: the active side's cards hit the card opposite them (slot +/- 4), which
-- loses defense equal to the attack and is destroyed at 0. An empty lane hits health.
function play.resolve_combat(side)
	local other = side == "Player" and "Opponent" or "Player"
	for column = 1, 4 do
		local attacker = played_cards[side == "Player" and column + 4 or column]
		local defender_slot = side == "Player" and column or column + 4
		local defender = played_cards[defender_slot]
		if attacker then
			local attack = data.get_stats(attacker).attack
			if defender then
				defender.hp = (defender.hp or data.get_stats(defender).defense) - attack
				if defender.hp <= 0 then
					played_cards[defender_slot] = nil
				end
			else
				health[other] = health[other] - attack
			end
		end
	end
end

function play.end_turn()
	play.resolve_combat(turn)
	for side, hp in pairs(health) do
		health[side] = math.max(hp, 0)
		if hp <= 0 then
			winner = side == "Player" and "Opponent" or "Player"
			update_game_state("ended")
			return
		end
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
				if not played_cards[slot] then
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
	return true
end

local ai_timer = 0

-- One action per AI_DELAY so the player can follow what the opponent does
function play.opponent_turn(dt)
	ai_timer = ai_timer + dt
	if ai_timer < AI_DELAY then
		return
	end
	ai_timer = 0
	if not ai_play_card() then
		play.end_turn()
	end
end

-- The player may only drop onto an empty slot in their own half (5-8)
local function can_play(held, sector)
	return sector > 4 and not played_cards[sector] and data.get_stats(held).cost <= venom.Player
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
		info_card = held_card
	elseif sector and can_play(held_card, sector) then
		played_cards[sector] = held_card
		venom.Player = venom.Player - data.get_stats(held_card).cost
		held_card = nil
		play_sound(hover_sound)
		return
	end

	-- If card is dropped but not played
	table.insert(player_hand, held_card)
	held_card = nil
	play_sound(hover_sound)
end

return play
