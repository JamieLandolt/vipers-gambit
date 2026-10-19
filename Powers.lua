local effects = require("Effects")

-- One hand-made ability per snake, so no two snakes do the same thing. Stronger and costlier snakes get stronger ones.
-- Each entry has `text` plus any of these hooks (ctx = { card, slot, side, foe } where foe is the slot ahead):
--   play / turn (start of its owner's turn) / death / attack (before its hit) / hurt(ctx, attacker) / kill
--   bonus(ctx) = extra attack, reduce(ctx, damage) = damage taken, foe_attack = attack taken off the card ahead
local powers = { of = {} }

local MAX_VENOM = 10

local function name_of(card)
	return card.card_path:sub(1, -5)
end

local function owner(slot)
	return slot > 4 and "Player" or "Opponent"
end

local function ahead(slot)
	return slot > 4 and slot - 4 or slot + 4
end

local function other(side)
	return side == "Player" and "Opponent" or "Player"
end

local function slot_of(card)
	for slot, c in pairs(played_cards) do
		if c == card then
			return slot
		end
	end
end

local function defense_of(card)
	return require("CardData").get_stats(card).defense
end

local function float(slot, text, good)
	local cx, cy = require("Play").slot_centre(slot)
	effects.add("float", { x = cx, y = cy, text = text, colour = good and { 0.45, 1, 0.45 } or nil })
end

-- Permanent stat change; attack shows as 0 at least, defense can go past its printed value
local function buff(card, attack, defense)
	local slot = slot_of(card)
	card.bonus = (card.bonus or 0) + attack
	card.hp = (card.hp or defense_of(card)) + defense
	if slot then
		float(slot, (attack ~= 0 and (attack > 0 and "+" or "") .. attack .. " atk " or "") .. (defense ~= 0 and (defense > 0 and "+" or "") .. defense .. " health" or ""), attack + defense > 0)
	end
end

local function heal(card, amount)
	local max = defense_of(card)
	if (card.hp or max) < max then
		card.hp = math.min((card.hp or max) + amount, max)
		float(slot_of(card), "+" .. amount .. " health", true)
	end
end

local function hurt_card(slot, amount)
	local c = played_cards[slot]
	if c then
		c.hp = (c.hp or defense_of(c)) - amount
		local cx, cy = require("Play").slot_centre(slot)
		effects.add("hit", { card = c, cx = cx, cy = cy })
		float(slot, "-" .. amount)
		if c.hp <= 0 then
			require("Play").destroy(slot)
		end
	end
end

-- Swap a snake's attack and defense (never leaving it at 0 defense)
local function swap(card, slot)
	local attack = require("Abilities").attack(card, slot)
	local defense = card.hp or defense_of(card)
	card.bonus = (card.bonus or 0) + defense - attack
	card.hp = math.max(attack, 1)
	float(slot, "swapped", true)
end

local function foes_of(side)
	local list = {}
	for slot = side == "Player" and 1 or 5, side == "Player" and 4 or 8 do
		if played_cards[slot] then
			table.insert(list, { card = played_cards[slot], slot = slot })
		end
	end
	return list
end

local function allies_of(side)
	return foes_of(other(side))
end

local function add_venom(side, amount)
	venom[side] = math.min(venom[side] + amount, MAX_VENOM)
end

local function heal_side(side, amount)
	health[side] = math.min(health[side] + amount, max_health[side])
	effects.add("float", { x = 1315, y = require("Play").bar_y[side], text = "+" .. amount, colour = { 0.45, 1, 0.45 } })
end

local function hurt_side(side, amount)
	health[side] = health[side] - amount
	effects.add("hp", { side = side })
	effects.add("float", { x = 1315, y = require("Play").bar_y[side], text = "-" .. amount })
	require("Play").check_end()
end

local function neighbours(slot)
	return require("Abilities").neighbours(slot)
end

local P = powers.of

-- Tier 1
P.Coral_Snake = {
	text = "Whatever hits it permanently loses 1 attack",
	hurt = function(_, attacker)
		if attacker and slot_of(attacker) then
			buff(attacker, -1, 0)
		end
	end,
}
P.Garter_Snake = {
	text = "Neighbours gain 2 health when it is played",
	play = function(c)
		for _, n in ipairs(neighbours(c.slot)) do
			buff(n.card, 0, 2)
		end
	end,
}
P.Sea_Snake = {
	text = "The card ahead loses 1 attack when it is played",
	play = function(c)
		if played_cards[c.foe] then
			buff(played_cards[c.foe], -1, 0)
		end
	end,
}
P.Vine_Snake = { text = "While it lives, the card ahead has 2 less attack", foe_attack = 2 }
P.Corn_Snake = { text = "Gain 1 venom when it is played", play = function(c) add_venom(c.side, 1) end }
P.Grass_Snake = { text = "Deals 1 damage to the card ahead at the start of your turn", turn = function(c) hurt_card(c.foe, 1) end }
P.Brown_Snake = { text = "+1 attack", bonus = function() return 1 end }
P.Candy_Snake = { text = "Gain 1 venom when it is played", play = function(c) add_venom(c.side, 1) end }
P.Grey_Snake = {
	text = "Hardens: +1 health each turn, up to 3 times",
	turn = function(c)
		if (c.card.stone or 0) < 3 then
			c.card.stone = (c.card.stone or 0) + 1
			buff(c.card, 0, 1)
		end
	end,
}
P.Sand_Snake = {
	text = "Neighbours gain 1 attack when it is destroyed",
	death = function(c)
		for _, n in ipairs(neighbours(c.slot)) do
			buff(n.card, 1, 0)
		end
	end,
}
P.Mud_Snake = { text = "Gain 1 attack each time it is hit", hurt = function(c) buff(c.card, 1, 0) end }
P.Pale_Snake = { text = "Deals 1 damage to the enemy's health when played", play = function(c) hurt_side(other(c.side), 1) end }
P.Worm_Snake = { text = "Gain 1 venom when it is destroyed", death = function(c) add_venom(c.side, 1) end }

-- Tier 2
P.Zombie_Snake = {
	text = "Returns to your hand when destroyed",
	death = function(c)
		local hand = c.side == "Player" and player_hand or opponent_hand
		table.insert(hand, require("Card")(name_of(c.card) .. ".png", img_widths, img_heights))
	end,
}
P.Cannibal_Snake = {
	text = "Feast: +2 attack and heals 3 when it destroys a snake",
	kill = function(c)
		buff(c.card, 2, 0)
		heal(c.card, 3)
	end,
}
P.Kingsnake = { text = "Heals 3 health when it destroys a snake", kill = function(c) heal_side(c.side, 3) end }
P.Ball_Python = {
	text = "Neighbours gain 4 health when it is played",
	play = function(c)
		for _, n in ipairs(neighbours(c.slot)) do
			buff(n.card, 0, 4)
		end
	end,
}
P.Tree_Boa = { text = "Drop strike: +4 attack the turn it is played", bonus = function(c) return c.card.fresh and 4 or 0 end }
P.Horned_Viper = {
	text = "Attackers take 2 damage",
	hurt = function(_, attacker)
		local slot = attacker and slot_of(attacker)
		if slot then
			hurt_card(slot, 2)
		end
	end,
}
P.Skeleton_Snake = { text = "Deals 2 damage to the card ahead when destroyed", death = function(c) hurt_card(c.foe, 2) end }
P.Ghost_Snake = {
	text = "Wail: every enemy snake loses 1 attack when it is played",
	play = function(c)
		for _, f in ipairs(foes_of(other(c.side) == "Player" and "Opponent" or "Player")) do
			buff(f.card, -1, 0)
		end
	end,
}
P.Toxic_Snake = {
	text = "Fumes: every enemy snake takes 1 damage at the start of your turn",
	turn = function(c)
		for slot = c.side == "Player" and 1 or 5, c.side == "Player" and 4 or 8 do
			hurt_card(slot, 1)
		end
	end,
}

-- Tier 3
P.Copperhead = { text = "Deals 3 damage to the enemy's health when it destroys a snake", kill = function(c) hurt_side(other(c.side), 3) end }
P.Extra_Long_Python = {
	text = "Squeezes: the card ahead permanently loses 2 attack each turn",
	turn = function(c)
		if played_cards[c.foe] then
			buff(played_cards[c.foe], -2, 0)
		end
	end,
}
P.Rattlesnake = {
	text = "Deafens the card ahead and its neighbours when played: they skip their next attack",
	play = function(c)
		local targets = { { card = played_cards[c.foe], slot = c.foe } }
		for _, n in ipairs(neighbours(c.foe)) do
			table.insert(targets, n)
		end
		for _, t in ipairs(targets) do
			if t.card then
				t.card.frozen = true
				float(t.slot, "deafened")
			end
		end
	end,
}
P.Boa_Constrictor = {
	text = "Embrace: heals each neighbour 2 health at the start of your turn",
	turn = function(c)
		for _, n in ipairs(neighbours(c.slot)) do
			heal(n.card, 2)
		end
	end,
}
P.Golden_Snake = {
	text = "Gilded gift: gain 3 venom and heal 5 health when played",
	play = function(c)
		add_venom(c.side, 3)
		heal_side(c.side, 5)
	end,
}
P.Black_Mamba = { text = "Deals 3 damage to the enemy's health every time it attacks", attack = function(c) hurt_side(other(c.side), 3) end }
P.Gaboon_Viper = {
	text = "Spits venom: poisons every enemy snake for 2 turns when played",
	play = function(c)
		for _, f in ipairs(foes_of(other(c.side) == "Player" and "Opponent" or "Player")) do
			f.card.poison = 2
			float(f.slot, "poisoned")
		end
	end,
}
P.Lava_Snake = {
	text = "Eruption: deals 4 damage to every enemy snake when destroyed",
	death = function(c)
		for slot = c.side == "Player" and 1 or 5, c.side == "Player" and 4 or 8 do
			hurt_card(slot, 4)
		end
	end,
}
P.Shadow_Snake = {
	text = "Inversion: swaps the attack and health of the card ahead when played",
	play = function(c)
		if played_cards[c.foe] then
			swap(played_cards[c.foe], c.foe)
		end
	end,
}

-- Tier 4
P.Cobra = {
	text = "Hypnotic gaze: the card ahead permanently loses 3 attack whenever it attacks",
	attack = function(c)
		if played_cards[c.foe] then
			buff(played_cards[c.foe], -3, 0)
		end
	end,
}
P.King_Cobra = {
	text = "Royal command: all your other snakes gain 2 attack when it is played",
	play = function(c)
		for _, a in ipairs(allies_of(c.side)) do
			if a.card ~= c.card then
				buff(a.card, 2, 0)
			end
		end
	end,
}
P.Albino_Cobra = {
	text = "Moon curse: swaps attack and health of the enemy with the most attack at the start of your turn",
	turn = function(c)
		local best
		for _, f in ipairs(foes_of(other(c.side) == "Player" and "Opponent" or "Player")) do
			if not best or require("Abilities").attack(f.card, f.slot) > require("Abilities").attack(best.card, best.slot) then
				best = f
			end
		end
		if best then
			swap(best.card, best.slot)
		end
	end,
}
P.Blood_Cobra = {
	text = "Blood rite: all your snakes gain 1 attack when it destroys a snake",
	kill = function(c)
		for _, a in ipairs(allies_of(c.side)) do
			buff(a.card, 1, 0)
		end
	end,
}
P.Frost_Cobra = {
	text = "Whiteout: freezes a random enemy snake at the start of your turn",
	turn = function(c)
		local list = foes_of(other(c.side) == "Player" and "Opponent" or "Player")
		if #list > 0 then
			local pick = list[math.random(#list)]
			pick.card.frozen = true
			float(pick.slot, "frozen")
		end
	end,
}

-- Tier 5 (the five legendaries)
P.Jormungandr = {
	text = "Tidal ring: deals 3 damage to every enemy snake and heals you 2 health at the start of your turn",
	turn = function(c)
		for slot = c.side == "Player" and 1 or 5, c.side == "Player" and 4 or 8 do
			hurt_card(slot, 3)
		end
		heal_side(c.side, 2)
	end,
}
P.Quetzalcoatl = {
	text = "Dawn: when played, all your snakes heal 5 health and gain 1 attack, and you gain 2 venom",
	play = function(c)
		for _, a in ipairs(allies_of(c.side)) do
			heal(a.card, 5)
			buff(a.card, 1, 0)
		end
		add_venom(c.side, 2)
	end,
}
P.Apophis = {
	text = "Swallows the sun: devours the card ahead when played and gains its attack",
	play = function(c)
		local foe = played_cards[c.foe]
		if foe then
			buff(c.card, require("Abilities").attack(foe, c.foe), 0)
			float(c.foe, "devoured")
			require("Play").destroy(c.foe)
		end
	end,
}
P.Ouroboros = {
	text = "Rebirth: fully heals and gains 1 attack and 1 health at the start of your turn",
	turn = function(c)
		heal(c.card, 99)
		buff(c.card, 1, 1)
	end,
}
P.Nagaraja = {
	text = "Hooded guard: the card ahead has 3 less attack, and your other snakes gain 3 health when it is played",
	foe_attack = 3,
	play = function(c)
		for _, a in ipairs(allies_of(c.side)) do
			if a.card ~= c.card then
				buff(a.card, 0, 3)
			end
		end
	end,
}

local function context(card, slot)
	return { card = card, slot = slot, side = owner(slot), foe = ahead(slot) }
end

-- Runs one of a snake's hooks, if it has it
function powers.trigger(event, card, slot, extra)
	local power = card and slot and P[name_of(card)]
	if power and power[event] then
		power[event](context(card, slot), extra)
	end
end

-- Extra attack from a snake's own passive and from the card opposite it
function powers.attack_bonus(card, slot)
	local total = 0
	local power = P[name_of(card)]
	if power and power.bonus then
		total = total + power.bonus(context(card, slot))
	end
	local foe = played_cards[ahead(slot)]
	local foe_power = foe and P[name_of(foe)]
	if foe_power and foe_power.foe_attack then
		total = total - foe_power.foe_attack
	end
	return total
end

function powers.reduce(card, slot, damage)
	local power = P[name_of(card)]
	return power and power.reduce and power.reduce(context(card, slot), damage) or damage
end

return powers
