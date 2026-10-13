-- One entry per level. Tweak `deck` (card names, at least 6), `style` (AI weights) and
-- `venom` (extra starting venom) freely. Defaults were tuned with a bot player, aiming for a win rate falling from ~80% to ~40%.
-- The AI scores every (card, lane) pair as:
--   attack*ATK + defense*DEF + cost*COST + (block if the lane faces a player card, else open)
local styles = {
	aggro = { attack = 2, defense = 0, cost = 0.5, block = 0, open = 3 },
	defensive = { attack = 0, defense = 2, cost = 0.5, block = 3, open = 0 },
	balanced = { attack = 1, defense = 1, cost = 0.5, block = 2, open = 1 },
}

local function opponent(name, style, venom, deck)
	return { name = name, style = styles[style], venom = venom, deck = deck }
end

return {
	opponent("Garden Keeper", "defensive", 0, { "Garter_Snake", "Corn_Snake", "Vine_Snake", "Snake", "Well_Fed_Snake", "Coral_Snake" }),
	opponent("Pond Skulker", "balanced", 0, { "Sea_Snake", "Corn_Snake", "Snake", "Skeleton_Snake", "Ball_Python", "Garter_Snake" }),
	opponent("Venom Rookie", "aggro", 0, { "Baby_Snake", "Vine_Snake", "Coral_Snake", "Sea_Snake", "Skinny_Snake", "Scrub_Racer" }),
	opponent("Crypt Warden", "defensive", 1, { "Stone_Constrictor", "Bull_Snake", "Mesa_Adder", "Iron_Snake", "Zombie_Snake", "Ghost_Snake" }),
	opponent("Reed Stalker", "balanced", 1, { "Kingsnake", "Tree_Boa", "Jungle_Racer", "Liana_Snake", "Tide_Snake", "Dusk_Snake" }),
	opponent("Fang Brawler", "aggro", 1, { "Bamboo_Pit_Viper", "Cottonmouth", "Prairie_Rattler", "Moray_Viper", "Cursed_Snake", "Gaboon_Viper" }),
	opponent("Constrictor", "defensive", 2, { "Bull_Snake", "Emerald_Boa", "Lagoon_Python", "Stone_Constrictor", "Boa_Constrictor", "Ghost_Snake" }),
	opponent("Ember Queen", "aggro", 1, { "Lava_Snake", "Black_Mamba", "Copperhead", "Rattlesnake", "Shadow_Snake", "Gaboon_Viper" }),
	opponent("Golden Heir", "balanced", 1, { "Golden_Snake", "Gaboon_Viper", "Anaconda", "Shadow_Snake", "Copperhead", "Boa_Constrictor" }),
	opponent("The Viper King", "balanced", 1, { "King_Cobra", "Albino_Cobra", "Blood_Cobra", "Frost_Cobra", "Cobra", "Golden_Snake" }),
}
