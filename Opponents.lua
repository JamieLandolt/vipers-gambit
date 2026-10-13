-- One entry per level; each has its own portrait (assets/opponents or assets/characters) and the charm of the
-- charmer it fights with. Health is 45 + 5 per level. Tweak `deck` (card names, at least 6), `style` (AI weights) and
-- `venom` (extra starting venom) freely. Defaults were tuned with a bot player, aiming for a win rate falling from ~80% to ~40%.
-- The AI scores every (card, lane) pair as:
--   attack*ATK + defense*DEF + cost*COST + (block if the lane faces a player card, else open)
local styles = {
	aggro = { attack = 2, defense = 0, cost = 0.5, block = 0, open = 3 },
	defensive = { attack = 0, defense = 2, cost = 0.5, block = 3, open = 0 },
	balanced = { attack = 1, defense = 1, cost = 0.5, block = 2, open = 1 },
}

local function opponent(level, name, portrait, charmer, style, venom, deck)
	return { name = name, portrait = portrait, charmer = charmer, style = styles[style], venom = venom, deck = deck, health = 45 + 5 * level }
end

local list = {
	{ "Garden Keeper", "opponents/garden_keeper.png", "Brother Moss", "defensive", 1, { "Garter_Snake", "Corn_Snake", "Vine_Snake", "Rock_Snake", "Mud_Snake", "Coral_Snake" } },
	{ "Pond Skulker", "opponents/pond_skulker.png", "Yuki Frostveil", "balanced", 0, { "Sea_Snake", "Corn_Snake", "Fern_Snake", "Skeleton_Snake", "Ball_Python", "Garter_Snake" } },
	{ "Venom Rookie", "opponents/venom_rookie.png", "Dr. Fang", "aggro", 3, { "Dust_Adder", "Grass_Snake", "Jelly_Snake", "Sea_Snake", "Skinny_Snake", "Rock_Snake" } },
	{ "Dune Wanderer", "opponents/dune_wanderer.png", "Baba Jaro", "balanced", 1, { "Horned_Viper", "Clay_Snake", "Dirt_Snake", "Rock_Snake", "Dune_Viper", "Hog_Nosed_Snake" } },
	{ "Josh", "characters/josh.jpg", "Josh", "aggro", 0, { "Bamboo_Pit_Viper", "Cottonmouth", "Prairie_Rattler", "Moray_Viper", "Kelp_Snake", "Cursed_Snake" } },
	{ "Crypt Warden", "opponents/crypt_warden.png", "Madame Zora", "defensive", 1, { "Stone_Constrictor", "Bull_Snake", "Mesa_Adder", "Dune_Viper", "Ghost_Snake", "Dusk_Snake" } },
	{ "Reed Stalker", "opponents/reed_stalker.png", "Raja Kaal", "balanced", 1, { "Kingsnake", "Tree_Boa", "Orchid_Snake", "Liana_Snake", "Tide_Snake", "Dusk_Snake" } },
	{ "Michael", "characters/michael.jpg", "Michael", "aggro", 0, { "Dune_Viper", "Cannibal_Snake", "Bone_Viper", "Parrot_Snake", "Prism_Adder", "Candy_Snake" } },
	{ "Fang Brawler", "opponents/fang_brawler.png", "Dr. Fang", "aggro", 0, { "Kingsnake", "Bamboo_Pit_Viper", "Toxic_Snake", "Brook_Snake", "Cottonmouth", "Copperhead" } },
	{ "Bog Hermit", "opponents/bog_hermit.png", "Brother Moss", "defensive", 0, { "Mossback_Python", "Boa_Constrictor", "Extra_Long_Python", "Banshee_Serpent", "Ripple_Snake", "Cottonmouth" } },
	{ "Tide Priestess", "opponents/tide_priestess.png", "Yuki Frostveil", "balanced", 0, { "Sandstorm_Asp", "Lagoon_Python", "Siren_Snake", "Shadow_Snake", "Amber_Tree_Viper", "Lich_Snake" } },
	{ "Constrictor", "opponents/constrictor.png", "Baba Jaro", "defensive", 1, { "Basalt_Serpent", "Blossom_Boa", "Bushmaster", "Lich_Snake", "Abyssal_Eel", "Mossback_Python" } },
	{ "Mist Witch", "opponents/mist_witch.png", "Madame Zora", "balanced", 0, { "Skeleton_Snake", "Grave_Snake", "Zombie_Snake", "Lich_Snake", "Phantom_Racer", "Kelp_Snake", "Lava_Snake" } },
	{ "Cinder Monk", "opponents/cinder_monk.png", "Raja Kaal", "balanced", 0, { "Tempest_Serpent", "Glacier_Adder", "Sunset_Boa", "Golden_Snake", "Gaboon_Viper", "Siren_Snake", "Horned_Viper" } },
	{ "Ember Queen", "opponents/ember_queen.png", "Raja Kaal", "aggro", 0, { "Jormungandr", "Gaboon_Viper", "Dusk_Snake", "Storm_Leviathan", "Extra_Long_Python", "Frost_Cobra", "Cobra" } },
	{ "Canyon Duelist", "opponents/canyon_duelist.png", "Yuki Frostveil", "balanced", 1, { "Cobra", "King_Cobra", "Albino_Cobra", "Nagaraja", "Basalt_Serpent", "Bushmaster" } },
	{ "Night Stalker", "opponents/night_stalker.png", "Madame Zora", "aggro", 0, { "Quetzalcoatl", "Gaboon_Viper", "Jormungandr", "Boa_Constrictor", "Basalt_Serpent", "Obsidian_Wyrm", "Chromatic_Wyrm" } },
	{ "Golden Heir", "opponents/golden_heir.png", "Dr. Fang", "balanced", 0, { "Mossback_Python", "Venom_Vine", "Jormungandr", "Zombie_Snake", "Jungle_Racer", "Liana_Snake" } },
	{ "Emerald Emperor", "opponents/emerald_emperor.png", "Brother Moss", "balanced", 0, { "Bushmaster", "Tiger_Snake", "Ouroboros", "King_Cobra", "Venom_Vine", "Copperhead" } },
	{ "The Viper King", "opponents/viper_king.png", "Raja Kaal", "balanced", 0, { "Rattlesnake", "Boa_Constrictor", "Abyssal_Eel", "Elderwood_Wyrm", "Reaper_Serpent", "Gaboon_Viper", "Jormungandr" } },
}

local opponents = {}
for level, e in ipairs(list) do
	opponents[level] = opponent(level, e[1], e[2], e[3], e[4], e[5], e[6])
end
return opponents
