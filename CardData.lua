local stats = require("Stats")
local abilities = require("Abilities")
local powers = require("Powers")
local lore = require("Lore")

local card_stats = {
	Snake = stats(2, 3, 2, "N/A", "Basic", 1, nil, "N/A"),
	Big_Snake = stats(3, 3, 10, "N/A", "Basic", 2, nil, "N/A"),
	Anaconda = stats(6, 8, 8, "N/A", "Basic", 3, nil, "N/A"),
	Copperhead = stats(5, 10, 5, "N/A", "Basic", 3, nil, "N/A"),
	Zombie_Snake = stats(3, 5, 5, "N/A", "Basic", 2, nil, "N/A"),
	Cannibal_Snake = stats(3, 12, 3, "N/A", "Basic", 2, nil, "N/A"),
	Cobra = stats(4, 8, 15, "N/A", "Basic", 4, nil, "N/A"),
	Extra_Long_Python = stats(5, 9, 13, "N/A", "Basic", 3, nil, "N/A"),
	King_Cobra = stats(4, 8, 15, "N/A", "Basic", 4, nil, "N/A"),
	Albino_Cobra = stats(4, 9, 12, "N/A", "Basic", 4, nil, "N/A"),
	Blood_Cobra = stats(5, 12, 8, "N/A", "Basic", 4, nil, "N/A"),
	Frost_Cobra = stats(4, 6, 14, "N/A", "Basic", 4, nil, "N/A"),
	Rattlesnake = stats(5, 10, 5, "N/A", "Basic", 3, nil, "N/A"),
	Coral_Snake = stats(2, 3, 2, "N/A", "Basic", 1, nil, "N/A"),
	Garter_Snake = stats(1, 2, 3, "N/A", "Basic", 1, nil, "N/A"),
	Kingsnake = stats(3, 5, 6, "N/A", "Basic", 2, nil, "N/A"),
	Boa_Constrictor = stats(5, 7, 14, "N/A", "Basic", 3, nil, "N/A"),
	Ball_Python = stats(3, 3, 9, "N/A", "Basic", 2, nil, "N/A"),
	Tree_Boa = stats(4, 7, 6, "N/A", "Basic", 2, nil, "N/A"),
	Sea_Snake = stats(2, 4, 3, "N/A", "Basic", 1, nil, "N/A"),
	Golden_Snake = stats(6, 10, 10, "N/A", "Basic", 3, nil, "N/A"),
	Black_Mamba = stats(4, 11, 3, "N/A", "Basic", 3, nil, "N/A"),
	Horned_Viper = stats(3, 6, 4, "N/A", "Basic", 2, nil, "N/A"),
	Gaboon_Viper = stats(6, 12, 11, "N/A", "Basic", 3, nil, "N/A"),
	Vine_Snake = stats(1, 4, 1, "N/A", "Basic", 1, nil, "N/A"),
	Lava_Snake = stats(5, 11, 6, "N/A", "Basic", 3, nil, "N/A"),
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
	Land = { "Snake", "Big_Snake", "Cannibal_Snake", "Cobra", "King_Cobra", "Albino_Cobra", "Horned_Viper", "Grey_Snake", "Dirt_Snake", "Sand_Snake" },
	Water = { "Anaconda", "Extra_Long_Python", "Frost_Cobra", "Sea_Snake", "Toxic_Snake", "Mud_Snake", "Ball_Python", "Garter_Snake", "Copperhead" },
	Tree = { "Boa_Constrictor", "Tree_Boa", "Vine_Snake", "Grass_Snake", "Worm_Snake", "Black_Mamba", "Kingsnake", "Corn_Snake", "Brown_Snake" },
	Rainbow = { "Coral_Snake", "Rattlesnake", "Gaboon_Viper", "Golden_Snake" }, -- fits any lane
	Spirit = { "Zombie_Snake", "Skeleton_Snake", "Ghost_Snake", "Shadow_Snake", "Lava_Snake", "Blood_Cobra", "Pale_Snake" },
}
for _, new in ipairs(require("NewCards")) do
	card_stats[new.name] = stats(new.cost, new.attack, new.defense, "N/A", new.border, new.rarity, nil, new.lore)
	type_lists[new.type] = type_lists[new.type] or {}
	table.insert(type_lists[new.type], new.name)
end
local card_types = {}
for snake_type, names in pairs(type_lists) do
	for _, name in ipairs(names) do
		card_types[name] = snake_type
	end
end

-- Snakes are tougher than their listed defense (the legendaries are already set as intended)
local HEALTH_SCALE = 1.5
local MIN_ATTACK = 2

local deck = {}
for name, st in pairs(card_stats) do
	st.attack = math.max(st.attack, MIN_ATTACK)
	if st.rarity < 5 then
		st.defense = math.ceil(st.defense * HEALTH_SCALE)
	end
	table.insert(deck, name)
	if powers.of[name] then
		st.ability = powers.of[name].text -- hand-made and unique, applied through Powers.lua
	else
		st.ability_code = st.ability_code or abilities.assign(name, card_types[name], st.rarity)
		st.ability = abilities.describe(st.ability_code)
	end
	st.lore = lore[name] or st.lore
	st.tier = lore.tiers[st.rarity]
end
table.sort(deck)

local function get_stats(card)
	return card_stats[string.sub(card.card_path, 1, -5)]
end

local function get_type(card)
	return card_types[string.sub(card.card_path, 1, -5)]
end

return { deck = deck, get_stats = get_stats, get_type = get_type, card_types = card_types, stats_by_name = card_stats }
