local effects = require("Effects")

-- One hand-made ability per snake, so no two snakes do the same thing, and each is paid for in venom (once per turn).
-- Stronger snakes cost more. Each entry has `cost`, `text` and `use(ctx)` (ctx = { card, slot, side, foe } where foe is the slot ahead),
-- plus an optional `ready(ctx)` when it needs a target.
local powers = { of = {} }

local MAX_VENOM = 10

local function name_of(card)
	return card.card_path:sub(1, -5)
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
	effects.add("float", { x = cx, y = cy, text = text, colour = good and { 0.45, 1, 0.45 } or nil, delay = require("Play").fx_delay })
end

-- Permanent stat change; attack shows as 0 at least, defense can go past its printed value
local function buff(card, attack, defense)
	local slot = slot_of(card)
	local play = require("Play")
	play.defer(card, attack, play.fx_delay, "atk") -- the numbers on the card change when the blow that caused this lands
	play.defer(card, -defense, play.fx_delay)
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

local function need_foe(c) return played_cards[c.foe] ~= nil end
local function need_neighbours(c) return #neighbours(c.slot) > 0 end
local function need_hurt(c) return (c.card.hp or defense_of(c.card)) < defense_of(c.card) end
local function need_enemy(c) return #foes_of(c.side) > 0 end

local function each_ally(c, fn, others_only)
	for _, a in ipairs(allies_of(c.side)) do
		if not (others_only and a.card == c.card) then
			fn(a)
		end
	end
end

local function each_foe(c, fn)
	for _, f in ipairs(foes_of(c.side)) do
		fn(f)
	end
end

-- Tier 1
P.Brown_Snake = { cost = 1, text = "+1 attack for good", use = function(c) buff(c.card, 1, 0) end }
P.Candy_Snake = { cost = 1, text = "gain 2 venom", use = function(c) add_venom(c.side, 2) end }
P.Coral_Snake = { cost = 1, text = "the card ahead permanently loses 1 attack", ready = need_foe, use = function(c) buff(played_cards[c.foe], -1, 0) end }
P.Corn_Snake = { cost = 1, text = "restore 2 of your health", use = function(c) heal_side(c.side, 2) end }
P.Garter_Snake = {
	cost = 1, text = "neighbours gain 2 health", ready = need_neighbours,
	use = function(c) for _, n in ipairs(neighbours(c.slot)) do buff(n.card, 0, 2) end end,
}
P.Grass_Snake = { cost = 1, text = "deal 1 damage to the card ahead", ready = need_foe, use = function(c) hurt_card(c.foe, 1) end }
P.Grey_Snake = { cost = 1, text = "+2 health for good", use = function(c) buff(c.card, 0, 2) end }
P.Mud_Snake = { cost = 2, text = "+1 attack and +2 health for good", use = function(c) buff(c.card, 1, 2) end }
P.Pale_Snake = { cost = 2, text = "deal 2 damage to the enemy's health", use = function(c) hurt_side(other(c.side), 2) end }
P.Sand_Snake = { cost = 1, text = "deal 1 damage to the enemy's health", use = function(c) hurt_side(other(c.side), 1) end }
P.Sea_Snake = { cost = 1, text = "all your snakes heal 1 health", use = function(c) each_ally(c, function(a) heal(a.card, 1) end) end }
P.Vine_Snake = {
	cost = 2, text = "neighbours gain a 2 point shield", ready = need_neighbours,
	use = function(c) for _, n in ipairs(neighbours(c.slot)) do n.card.shield = (n.card.shield or 0) + 2; float(n.slot, "+2 shield", true) end end,
}
P.Worm_Snake = { cost = 2, text = "fully heal", ready = need_hurt, use = function(c) heal(c.card, 99) end }

-- Tier 2
P.Zombie_Snake = {
	cost = 2, text = "return to your hand (when hurt)", ready = need_hurt,
	use = function(c)
		played_cards[c.slot] = nil
		table.insert(c.side == "Player" and player_hand or opponent_hand, require("Card")(name_of(c.card) .. ".png", img_widths, img_heights))
	end,
}
P.Cannibal_Snake = {
	cost = 2, text = "Feast: deal 3 damage to the card ahead; if it is destroyed, +2 attack and heal 3", ready = need_foe,
	use = function(c)
		hurt_card(c.foe, 3)
		if not played_cards[c.foe] then
			buff(c.card, 2, 0)
			heal(c.card, 3)
		end
	end,
}
P.Kingsnake = { cost = 2, text = "all your snakes heal 3 health", use = function(c) each_ally(c, function(a) heal(a.card, 3) end) end }
P.Ball_Python = {
	cost = 2, text = "neighbours gain 4 health", ready = need_neighbours,
	use = function(c) for _, n in ipairs(neighbours(c.slot)) do buff(n.card, 0, 4) end end,
}
P.Tree_Boa = { cost = 2, text = "Drop strike: +4 attack this turn", use = function(c) c.card.temp = (c.card.temp or 0) + 4; float(c.slot, "+4 atk", true) end }
P.Horned_Viper = { cost = 2, text = "deal 4 damage to the card ahead", ready = need_foe, use = function(c) hurt_card(c.foe, 4) end }
P.Skeleton_Snake = {
	cost = 2, text = "deal 2 damage to the card ahead and 2 to the enemy's health", ready = need_foe,
	use = function(c) hurt_card(c.foe, 2); hurt_side(other(c.side), 2) end,
}
P.Ghost_Snake = { cost = 2, text = "Wail: every enemy snake permanently loses 1 attack", ready = need_enemy, use = function(c) each_foe(c, function(f) buff(f.card, -1, 0) end) end }
P.Toxic_Snake = { cost = 3, text = "Fumes: every enemy snake takes 2 damage", ready = need_enemy, use = function(c) for slot = c.side == "Player" and 1 or 5, c.side == "Player" and 4 or 8 do hurt_card(slot, 2) end end }

-- Tier 3
P.Copperhead = {
	cost = 3, text = "deal 5 damage to the card ahead; if it is destroyed, 3 damage to the enemy's health", ready = need_foe,
	use = function(c)
		hurt_card(c.foe, 5)
		if not played_cards[c.foe] then
			hurt_side(other(c.side), 3)
		end
	end,
}
P.Extra_Long_Python = { cost = 2, text = "Squeeze: the card ahead permanently loses 2 attack", ready = need_foe, use = function(c) buff(played_cards[c.foe], -2, 0) end }
P.Rattlesnake = {
	cost = 3, text = "Deafen: the card ahead and its neighbours skip their next attack", ready = need_foe,
	use = function(c)
		local targets = { { card = played_cards[c.foe], slot = c.foe } }
		for _, n in ipairs(neighbours(c.foe)) do
			table.insert(targets, n)
		end
		for _, t in ipairs(targets) do
			t.card.frozen = true
			float(t.slot, "deafened")
		end
	end,
}
P.Boa_Constrictor = {
	cost = 3, text = "Embrace: heal each neighbour 4 health", ready = need_neighbours,
	use = function(c) for _, n in ipairs(neighbours(c.slot)) do heal(n.card, 4) end end,
}
P.Golden_Snake = { cost = 2, text = "Gilded gift: gain 3 venom and heal 5 of your health", use = function(c) add_venom(c.side, 3); heal_side(c.side, 5) end }
P.Black_Mamba = { cost = 3, text = "deal 4 damage to the enemy's health", use = function(c) hurt_side(other(c.side), 4) end }
P.Gaboon_Viper = {
	cost = 3, text = "Spit venom: poison every enemy snake for 2 turns", ready = need_enemy,
	use = function(c) each_foe(c, function(f) f.card.poison = 2; float(f.slot, "poisoned") end) end,
}
P.Lava_Snake = { cost = 3, text = "Eruption: every enemy snake takes 3 damage", ready = need_enemy, use = function(c) for slot = c.side == "Player" and 1 or 5, c.side == "Player" and 4 or 8 do hurt_card(slot, 3) end end }
P.Shadow_Snake = { cost = 3, text = "Inversion: swap the attack and health of the card ahead", ready = need_foe, use = function(c) swap(played_cards[c.foe], c.foe) end }

-- Tier 4
P.Cobra = { cost = 3, text = "Hypnotic gaze: the card ahead permanently loses 4 attack", ready = need_foe, use = function(c) buff(played_cards[c.foe], -4, 0) end }
P.King_Cobra = { cost = 4, text = "Royal command: all your other snakes gain 2 attack for good", use = function(c) each_ally(c, function(a) buff(a.card, 2, 0) end, true) end }
P.Albino_Cobra = {
	cost = 3, text = "Moon curse: swap the attack and health of the enemy with the most attack", ready = need_enemy,
	use = function(c)
		local best
		for _, f in ipairs(foes_of(c.side)) do
			if not best or require("Abilities").attack(f.card, f.slot) > require("Abilities").attack(best.card, best.slot) then
				best = f
			end
		end
		swap(best.card, best.slot)
	end,
}
P.Blood_Cobra = { cost = 3, text = "Blood rite: all your snakes gain 1 attack for good", use = function(c) each_ally(c, function(a) buff(a.card, 1, 0) end) end }
P.Frost_Cobra = {
	cost = 3, text = "Whiteout: freeze a random enemy snake so it skips its next attack", ready = need_enemy,
	use = function(c)
		local list = foes_of(c.side)
		local pick = list[math.random(#list)]
		pick.card.frozen = true
		float(pick.slot, "frozen")
	end,
}

-- Tier 5 (the five legendaries)
P.Jormungandr = {
	cost = 4, text = "Tidal ring: deal 3 damage to every enemy snake and restore 2 of your health",
	use = function(c)
		for slot = c.side == "Player" and 1 or 5, c.side == "Player" and 4 or 8 do
			hurt_card(slot, 3)
		end
		heal_side(c.side, 2)
	end,
}
P.Quetzalcoatl = {
	cost = 4, text = "Dawn: all your snakes heal 5 health and gain 1 attack, and you gain 2 venom",
	use = function(c)
		each_ally(c, function(a) heal(a.card, 5); buff(a.card, 1, 0) end)
		add_venom(c.side, 2)
	end,
}
P.Apophis = {
	cost = 4, text = "Swallow the sun: devour the card ahead and gain its attack", ready = need_foe,
	use = function(c)
		buff(c.card, require("Abilities").attack(played_cards[c.foe], c.foe), 0)
		float(c.foe, "devoured")
		require("Play").destroy(c.foe)
	end,
}
P.Ouroboros = { cost = 3, text = "Rebirth: fully heal and gain 1 attack and 1 health", use = function(c) heal(c.card, 99); buff(c.card, 1, 1) end }
P.Nagaraja = {
	cost = 4, text = "Hooded guard: the card ahead permanently loses 3 attack and your other snakes gain 3 health",
	use = function(c)
		if played_cards[c.foe] then
			buff(played_cards[c.foe], -3, 0)
		end
		each_ally(c, function(a) buff(a.card, 0, 3) end, true)
	end,
}

local function context(card, slot)
	return { card = card, slot = slot, side = slot > 4 and "Player" or "Opponent", foe = ahead(slot) }
end

function powers.cost(card)
	local power = P[name_of(card)]
	return power and power.cost
end

-- Can this snake's power be used now (apart from having the venom)?
function powers.ready(card, slot)
	local power = P[name_of(card)]
	return power ~= nil and (not power.ready or power.ready(context(card, slot)))
end

function powers.use(card, slot)
	P[name_of(card)].use(context(card, slot))
end

function powers.text(name)
	return ("Pay %d venom: %s"):format(P[name].cost, P[name].text)
end

return powers
