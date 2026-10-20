local stats = require("Stats")
local abilities = require("Abilities")
local powers = require("Powers")
local lore = require("Lore")

local card_stats = {
	Copperhead = stats(4, 10, 5, "N/A", "Basic", 3, nil, "N/A"),
	Zombie_Snake = stats(3, 5, 5, "N/A", "Basic", 2, nil, "N/A"),
	Cannibal_Snake = stats(3, 12, 3, "N/A", "Basic", 2, nil, "N/A"),
	Cobra = stats(4, 8, 15, "N/A", "Basic", 4, nil, "N/A"),
	Extra_Long_Python = stats(5, 9, 13, "N/A", "Basic", 3, nil, "N/A"),
	King_Cobra = stats(4, 8, 15, "N/A", "Basic", 4, nil, "N/A"),
	Albino_Cobra = stats(4, 9, 12, "N/A", "Basic", 4, nil, "N/A"),
	Blood_Cobra = stats(5, 12, 8, "N/A", "Basic", 4, nil, "N/A"),
	Frost_Cobra = stats(4, 6, 14, "N/A", "Basic", 4, nil, "N/A"),
	Rattlesnake = stats(4, 10, 5, "N/A", "Basic", 3, nil, "N/A"),
	Coral_Snake = stats(2, 3, 2, "N/A", "Basic", 1, nil, "N/A"),
	Garter_Snake = stats(1, 2, 3, "N/A", "Basic", 1, nil, "N/A"),
	Kingsnake = stats(3, 5, 6, "N/A", "Basic", 2, nil, "N/A"),
	Boa_Constrictor = stats(5, 7, 14, "N/A", "Basic", 3, nil, "N/A"),
	Ball_Python = stats(3, 3, 9, "N/A", "Basic", 2, nil, "N/A"),
	Tree_Boa = stats(4, 7, 6, "N/A", "Basic", 2, nil, "N/A"),
	Sea_Snake = stats(2, 4, 3, "N/A", "Basic", 1, nil, "N/A"),
	Golden_Snake = stats(5, 10, 10, "N/A", "Basic", 3, nil, "N/A"),
	Black_Mamba = stats(3, 11, 3, "N/A", "Basic", 3, nil, "N/A"),
	Horned_Viper = stats(3, 6, 4, "N/A", "Basic", 2, nil, "N/A"),
	Gaboon_Viper = stats(6, 12, 11, "N/A", "Basic", 3, nil, "N/A"),
	Vine_Snake = stats(1, 4, 1, "N/A", "Basic", 1, nil, "N/A"),
	Lava_Snake = stats(4, 11, 6, "N/A", "Basic", 3, nil, "N/A"),
	Shadow_Snake = stats(4, 9, 7, "N/A", "Basic", 3, nil, "N/A"),
	Skeleton_Snake = stats(2, 5, 5, "N/A", "Basic", 2, nil, "N/A"),
	Ghost_Snake = stats(3, 4, 8, "N/A", "Basic", 2, nil, "N/A"),
	Toxic_Snake = stats(3, 8, 4, "N/A", "Basic", 2, nil, "N/A"),
	Corn_Snake = stats(2, 4, 3, "N/A", "Basic", 1, nil, "N/A"),
	Grass_Snake = stats(1, 1, 2, "N/A", "Basic", 1, nil, "N/A"),
	Brown_Snake = stats(1, 2, 1, "N/A", "Basic", 1, nil, "N/A"),
	Grey_Snake = stats(1, 1, 3, "N/A", "Basic", 1, nil, "N/A"),
	Dirt_Snake = stats(2, 2, 3, "N/A", "Basic", 1, nil, "N/A"),
	Sand_Snake = stats(1, 2, 2, "N/A", "Basic", 1, nil, "N/A"),
	Mud_Snake = stats(2, 2, 4, "N/A", "Basic", 1, nil, "N/A"),
	Pale_Snake = stats(1, 1, 1, "N/A", "Basic", 1, nil, "N/A"),
	Worm_Snake = stats(1, 1, 2, "N/A", "Basic", 1, nil, "N/A"),
}

-- Borders for the original snakes (the rest are Basic); new snakes bring their own from NewCards.lua
local borders = {
	Blood_Cobra = "Fire", Lava_Snake = "Fire", Frost_Cobra = "Frost", Albino_Cobra = "Frost", Sea_Snake = "Frost",
	Shadow_Snake = "Shadow", Ghost_Snake = "Shadow", Skeleton_Snake = "Shadow", Pale_Snake = "Shadow",
	Golden_Snake = "Gold", King_Cobra = "Gold", Cobra = "Venom", Toxic_Snake = "Venom", Black_Mamba = "Venom",
	Coral_Snake = "Venom", Rattlesnake = "Venom", Gaboon_Viper = "Venom", Horned_Viper = "Venom", Zombie_Snake = "Venom",
}
for name, border in pairs(borders) do
	card_stats[name].border = border
end

-- Each snake has one type; lanes only accept certain types (see play.lane_types), except Rainbow which fits any lane
local type_lists = {
	Land = { "Cannibal_Snake", "Cobra", "King_Cobra", "Albino_Cobra", "Horned_Viper", "Grey_Snake", "Dirt_Snake", "Sand_Snake" },
	Water = { "Extra_Long_Python", "Frost_Cobra", "Sea_Snake", "Toxic_Snake", "Mud_Snake", "Ball_Python", "Garter_Snake", "Copperhead" },
	Tree = { "Boa_Constrictor", "Tree_Boa", "Vine_Snake", "Grass_Snake", "Worm_Snake", "Black_Mamba", "Kingsnake", "Corn_Snake", "Brown_Snake" },
	Rainbow = { "Coral_Snake", "Rattlesnake", "Gaboon_Viper", "Golden_Snake" }, -- fits any lane
	Spirit = { "Zombie_Snake", "Skeleton_Snake", "Ghost_Snake", "Shadow_Snake", "Lava_Snake", "Blood_Cobra", "Pale_Snake" },
}
for _, new in ipairs(require("NewCards")) do
	card_stats[new.name] = stats(new.cost, new.attack, new.defense, "N/A", new.border, new.rarity, nil, new.lore)
	type_lists[new.type] = type_lists[new.type] or {}
	table.insert(type_lists[new.type], new.name)
end
-- Brews and spells (Brews.lua) are cards too: no attack or defense, and their own "type" for the card colours
for _, b in ipairs(require("Brews").list) do
	card_stats[b.name] = stats(b.cost, 0, 0, b.text, b.kind == "brew" and "Brew" or "Spell", b.rarity, nil, b.lore)
	card_stats[b.name].kind = b.kind
	local card_type = b.kind == "brew" and "Brew" or "Spell"
	type_lists[card_type] = type_lists[card_type] or {}
	table.insert(type_lists[card_type], b.name)
end
local card_types = {}
for snake_type, names in pairs(type_lists) do
	for _, name in ipairs(names) do
		card_types[name] = snake_type
	end
end

-- Hand-picked abilities in the Abilities.lua format (the rest are assigned by type and tier)
local ABILITY_OVERRIDES = {
	Chromatic_Wyrm = "refresh:1:3", -- the tier 4 Wyrm lets your other snakes use their abilities again
	Kaleido_Viper = "refresh:1:4",
	Jelly_Snake = "bolster:2:2", -- pay 2 venom: neighbours get +2 attack this turn
	Dirt_Snake = "heal:2:1", -- pay 1 venom to restore 2 health
}

-- Snakes are tougher than their listed defense (the legendaries are already set as intended)
local HEALTH_SCALE = 1.5
local MIN_ATTACK = 2

local REMOVED_BORDERS = { Frost = true, Gold = true, Thorn = true, Leech = true, Storm = true } -- old borders: those snakes are Basic now
local deck = {}
for name, st in pairs(card_stats) do
	st.kind = st.kind or "snake"
	if st.kind == "snake" then
		if REMOVED_BORDERS[st.border] then
			st.border = "Basic"
		end
		st.attack = math.max(st.attack, MIN_ATTACK)
		if st.rarity < 5 then
			st.defense = math.ceil(st.defense * HEALTH_SCALE)
		end
		if st.border == "Shadow" then
			st.defense = math.ceil(st.defense * 1.5)
		elseif st.border == "Fire" then
			st.attack = math.ceil(st.attack * 1.5)
		end
	end
	table.insert(deck, name)
	if st.kind == "snake" then -- (brews and spells carry their own text and lore, see Brews.lua)
		if powers.of[name] then
			st.ability = powers.text(name) -- hand-made and unique, applied through Powers.lua
		else
			if name ~= "One_Eyed_Python" then -- the one snake with no ability
				st.ability_code = ABILITY_OVERRIDES[name] or st.ability_code or abilities.assign(name, card_types[name], st.rarity)
				st.ability = abilities.describe(st.ability_code)
			end
		end
		st.lore = lore[name] or st.lore
	end
	st.tier = (st.kind == "snake" and lore.tiers or lore.support_tiers)[st.rarity]
end
table.sort(deck)

-- A Shadow-border copy of a snake with another border has 1.5x defense, and a Fire-border copy 1.5x attack (both rounded up);
-- cached per snake, so the stats shown are the stats it fights with
local border_stats = { Shadow = {}, Fire = {} }
local function get_stats(card)
	local name = string.sub(card.card_path, 1, -5)
	local st = card_stats[name]
	local cache = card.border and border_stats[card.border]
	if cache and st.border ~= card.border and st.kind == "snake" then
		if not cache[name] then
			local changed = card.border == "Shadow" and { defense = math.ceil(st.defense * 1.5) } or { attack = math.ceil(st.attack * 1.5) }
			cache[name] = setmetatable(changed, { __index = st })
		end
		return cache[name]
	end
	return st
end

local function get_type(card)
	return card_types[string.sub(card.card_path, 1, -5)]
end

-- A card's border: the one a variant copy carries (set on the card when drawn), else its snake's own
local function border_of(card)
	return card.border or get_stats(card).border
end

-- The snakes a new player starts with (and the opponent on level 1)
local starters = { "Sand_Snake", "Dirt_Snake", "Garter_Snake", "Mud_Snake", "Grass_Snake", "Brown_Snake", "Pale_Snake", "Coral_Snake" }

return { starters = starters, deck = deck, border_of = border_of, get_stats = get_stats, get_type = get_type, card_types = card_types, stats_by_name = card_stats }
