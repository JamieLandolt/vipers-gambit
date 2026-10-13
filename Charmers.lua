local love = require("love")

-- Charmers: each has one charm, used once per turn for `cost` venom (Play.use_charm).
-- apply(play, side) does the effect and returns false if it would do nothing (then it costs nothing).
-- The chosen charmer is the global chosen_avatar; each campaign level's opponent has its own, below.
-- (CardData and Abilities are required lazily: Assets loads this file for the portraits)
local charmers = {}

local function foe(side)
	return side == "Player" and "Opponent" or "Player"
end

-- Occupied slots of a side as a list of { slot, card }
local function snakes(side)
	local found = {}
	for slot = side == "Player" and 5 or 1, side == "Player" and 8 or 4 do
		if played_cards[slot] then
			table.insert(found, { slot, played_cards[slot] })
		end
	end
	return found
end

-- Runs fn(slot, card) on every snake of a side; true if there were any
local function each(side, fn)
	local list = snakes(side)
	for _, s in ipairs(list) do
		fn(s[1], s[2])
	end
	return #list > 0
end

local function defense(card)
	return require("CardData").get_stats(card).defense
end

charmers.list = {
	{ name = "Raja Kaal", portrait = "raja.png", charm = "Poison Piper", cost = 4, text = "Poison every enemy snake.",
		apply = function(play, side)
			return each(foe(side), function(slot, card)
				card.poison = 2
				play.float(slot, "poison")
			end)
		end },
	{ name = "Yuki Frostveil", portrait = "yuki.png", charm = "Frost Flute", cost = 3, text = "Freeze the strongest enemy snake.",
		apply = function(play, side)
			local best, best_slot, best_attack = nil, nil, -1
			each(foe(side), function(slot, card)
				local attack = require("Abilities").attack(card, slot)
				if attack > best_attack then
					best, best_slot, best_attack = card, slot, attack
				end
			end)
			if best then
				best.frozen = true
				play.float(best_slot, "frozen")
			end
			return best ~= nil
		end },
	{ name = "Brother Moss", portrait = "moss.png", charm = "Heal Hymn", cost = 3, text = "Heal all your snakes for 3.",
		apply = function(play, side)
			local healed = false
			each(side, function(slot, card)
				local hp = card.hp or defense(card)
				if hp < defense(card) then
					card.hp, healed = math.min(hp + 3, defense(card)), true
					play.float(slot, "+3 hp")
				end
			end)
			return healed
		end },
	{ name = "Dr. Fang", portrait = "fang.png", charm = "Venom Surge", cost = 1, text = "Pay 1 venom, gain 3.",
		apply = function(play, side)
			if venom[side] >= play.MAX_VENOM then
				return false
			end
			venom[side] = math.min(venom[side] + 3, play.MAX_VENOM)
			play.float_bar(side, "+3 venom")
			return true
		end },
	{ name = "Madame Zora", portrait = "zora.png", charm = "Mesmerise", cost = 3, text = "Enemy snakes shuffle one lane over.",
		apply = function(play, side)
			local base = side == "Player" and 1 or 5
			local moved = {}
			for i = 0, 3 do
				moved[(i + 1) % 4] = played_cards[base + i]
			end
			if #snakes(foe(side)) < 2 then
				return false
			end
			for i = 0, 3 do
				played_cards[base + i] = moved[i]
				if moved[i] then
					play.float(base + i, "mesmerised")
				end
			end
			return true
		end },
	{ name = "Baba Jaro", portrait = "baba.png", charm = "Snake Cloak", cost = 4, text = "Give all your snakes a 2 point shield.",
		apply = function(play, side)
			return each(side, function(slot, card)
				card.shield = (card.shield or 0) + 2
				play.float(slot, "+2 shield")
			end)
		end },
	{ name = "Jamie", portrait = "jamie.jpg", charm = "Gambit", cost = 2, text = "Discard your hand and draw a new one.",
		apply = function(play, side)
			play.redraw(side)
			return true
		end },
	{ name = "Alem", portrait = "alem.jpg", charm = "Sharpen", cost = 4, text = "All your snakes gain +1 attack for good.",
		apply = function(play, side)
			return each(side, function(slot, card)
				card.bonus = (card.bonus or 0) + 1
				play.float(slot, "+1 atk")
			end)
		end },
	{ name = "Gabe", portrait = "gabe.jpg", charm = "Cheap Shot", cost = 3, text = "Deal 4 damage to the enemy snake charmer.",
		apply = function(play, side)
			play.hurt(foe(side), 4)
			return true
		end },
	{ name = "Darcy", portrait = "darcy.jpg", charm = "Rejuvenate", cost = 3, text = "Heal yourself for 8.",
		apply = function(play, side)
			if health[side] >= max_health[side] then
				return false
			end
			health[side] = math.min(health[side] + 8, max_health[side])
			play.float_bar(side, "+8")
			return true
		end },
	{ name = "Josh", portrait = "josh.jpg", charm = "Fury", cost = 3, text = "All your snakes get +3 attack this turn.",
		apply = function(play, side)
			return each(side, function(slot, card)
				card.temp = (card.temp or 0) + 3
				play.float(slot, "+3 atk")
			end)
		end },
	{ name = "Michael", portrait = "michael.jpg", charm = "Bile Spray", cost = 5, text = "Hit every enemy snake for 2.",
		apply = function(play, side)
			return each(foe(side), function(slot)
				play.wound(slot, 2)
			end)
		end },
}

charmers.by_name = {}
for _, c in ipairs(charmers.list) do
	charmers.by_name[c.name] = c
end

-- Who each campaign opponent fights with, by level
charmers.opponent_charmers = {
	"Brother Moss", "Yuki Frostveil", "Dr. Fang", "Baba Jaro", "Madame Zora",
	"Josh", "Alem", "Michael", "Gabe", "Raja Kaal",
}

function charmers.of(side, level)
	return charmers.by_name[side == "Player" and chosen_avatar or charmers.opponent_charmers[level] or "Brother Moss"] or charmers.list[1]
end

-- The player's pick is remembered in its own file so save.txt keeps its format
function charmers.save()
	love.filesystem.write("charmer.txt", chosen_avatar)
end

function charmers.load()
	local saved = love.filesystem.read("charmer.txt")
	if saved and charmers.by_name[saved] then
		chosen_avatar = saved
	end
end

return charmers
