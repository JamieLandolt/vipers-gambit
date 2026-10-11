-- One entry per level. Tweak `deck` (card names, at least 6), `style` (AI weights), `health` and
-- `venom` (extra starting venom) freely. Defaults were tuned with a bot player, aiming for a win rate falling from ~80% to ~40%.
-- The AI scores every (card, lane) pair as:
--   attack*ATK + defense*DEF + cost*COST + (block if the lane faces a player card, else open)
local styles = {
	aggro = { attack = 2, defense = 0, cost = 0.5, block = 0, open = 3 },
	defensive = { attack = 0, defense = 2, cost = 0.5, block = 3, open = 0 },
	balanced = { attack = 1, defense = 1, cost = 0.5, block = 2, open = 1 },
}

local function opponent(name, style, health, venom, deck)
	return { name = name, style = styles[style], health = health, venom = venom, deck = deck }
end

return {
	opponent("Garden Keeper", "defensive", 6, 0, { "Garter_Snake", "Corn_Snake", "Vine_Snake", "Snake", "Well_Fed_Snake", "Coral_Snake" }),
	opponent("Pond Skulker", "balanced", 8, 0, { "Sea_Snake", "Corn_Snake", "Snake", "Skeleton_Snake", "Ball_Python", "Garter_Snake" }),
	opponent("Venom Rookie", "aggro", 9, 0, { "Baby_Snake", "Vine_Snake", "Horned_Viper", "Toxic_Snake", "Coral_Snake", "Sea_Snake" }),
	opponent("Crypt Warden", "defensive", 11, 1, { "Zombie_Snake", "Skeleton_Snake", "Ghost_Snake", "Ball_Python", "Kingsnake", "Big_Snake" }),
	opponent("Reed Stalker", "balanced", 10, 2, { "Kingsnake", "Tree_Boa", "Horned_Viper", "Toxic_Snake", "Zombie_Snake", "Ghost_Snake" }),
	opponent("Fang Brawler", "aggro", 18, 0, { "Cannibal_Snake", "Baby_Snake", "Toxic_Snake", "Black_Mamba", "Horned_Viper", "Rattlesnake" }),
	opponent("Constrictor", "defensive", 30, 1, { "Boa_Constrictor", "Extra_Long_Python", "Big_Snake", "Anaconda", "Ball_Python", "Ghost_Snake" }),
	opponent("Ember Queen", "aggro", 23, 1, { "Lava_Snake", "Black_Mamba", "Copperhead", "Rattlesnake", "Shadow_Snake", "Gaboon_Viper" }),
	opponent("Golden Heir", "balanced", 9, 2, { "Golden_Snake", "Gaboon_Viper", "Anaconda", "Shadow_Snake", "Copperhead", "Boa_Constrictor" }),
	opponent("The Viper King", "balanced", 33, 1, { "King_Cobra", "Albino_Cobra", "Blood_Cobra", "Frost_Cobra", "Cobra", "Golden_Snake" }),
}
