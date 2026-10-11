local stats = require("Stats")

local card_stats = {
	Snake = stats(2, 3, 2, "N/A", "Basic", 1, nil, "N/A"),
	Big_Snake = stats(3, 3, 10, "N/A", "Basic", 2, nil, "N/A"),
	Baby_Snake = stats(1, 6, 1, "N/A", "Basic", 2, nil, "N/A"),
	Well_Fed_Snake = stats(2, 4, 2, "N/A", "Basic", 1, nil, "N/A"),
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

local deck = {}
for name in pairs(card_stats) do
	table.insert(deck, name)
end

local function get_stats(card)
	return card_stats[string.sub(card.card_path, 1, -5)]
end

return { deck = deck, get_stats = get_stats }
