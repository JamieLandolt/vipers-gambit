-- One entry per level; each has its own portrait (assets/opponents or assets/characters) and the charm of the
-- charmer it fights with. Health is 40 + 5 per level. Tweak `deck` (card names, at least 6), `style` (AI weights) and
-- `venom` (extra starting venom) freely. Defaults were tuned with a bot player, aiming for a win rate falling from ~80% to ~40%.
-- The AI scores every (card, lane) pair as:
--   attack*ATK + defense*DEF + cost*COST + (block if the lane faces a player card, else open)
local styles = {
	aggro = { attack = 2, defense = 0, cost = 0.5, block = 0, open = 3 },
	defensive = { attack = 0, defense = 2, cost = 0.5, block = 3, open = 0 },
	balanced = { attack = 1, defense = 1, cost = 0.5, block = 2, open = 1 },
}

-- Opponents start with a third of the listed extra venom (rounded down) and 5 less health than before, so early fights
-- cannot play more snakes on their first turns than the player can
local function opponent(level, name, portrait, charmer, style, venom, deck)
	return { name = name, portrait = portrait, charmer = charmer, style = styles[style], venom = math.floor(venom / 3), deck = deck, health = 40 + 5 * level }
end

local list = {
	{ "Garden Keeper", "opponents/garden_keeper.png", "Brother Moss", "defensive", 2, { "Garter_Snake", "Corn_Snake", "Vine_Snake", "Rock_Snake", "Mud_Snake", "Coral_Snake" } },
	{ "Pond Skulker", "opponents/pond_skulker.png", "Yuki Frostveil", "balanced", 2, { "Sea_Snake", "Corn_Snake", "Fern_Snake", "Skeleton_Snake", "Ball_Python", "Garter_Snake" } },
	{ "Venom Rookie", "opponents/venom_rookie.png", "Dr. Fang", "aggro", 6, { "Dust_Adder", "Grass_Snake", "Jelly_Snake", "Sea_Snake", "Skinny_Snake", "Rock_Snake" } },
	{ "Dune Wanderer", "opponents/dune_wanderer.png", "Baba Jaro", "balanced", 4, { "Rust_Viper", "Grey_Snake", "Prairie_Rattler", "Horned_Viper", "Skinny_Snake", "Hog_Nosed_Snake", "Stoneskin_Tonic" } },
	{ "Crypt Warden", "opponents/crypt_warden.png", "Madame Zora", "defensive", 1, { "Phantom_Racer", "Dusk_Snake", "Pale_Snake", "Dirt_Snake", "Mist_Snake", "Brown_Snake", "Ghost_Tonic" } },
	{ "Reed Stalker", "opponents/reed_stalker.png", "Raja Kaal", "balanced", 4, { "Worm_Snake", "Moss_Snake", "Mossback_Python", "Brown_Snake", "Candy_Snake", "Sand_Snake", "Regrowth_Brew" } },
	{ "Fang Brawler", "opponents/fang_brawler.png", "Dr. Fang", "aggro", 1, { "Canopy_Viper", "Black_Mamba", "Twig_Snake", "Sand_Snake", "Leaf_Snake", "Venom_Elixir" } },
	{ "Bog Hermit", "opponents/bog_hermit.png", "Brother Moss", "defensive", 3, { "Moray_Viper", "Frost_Cobra", "Copperhead", "Pond_Snake", "Worm_Snake", "Healing_Rain" } },
	{ "Tide Priestess", "opponents/tide_priestess.png", "Tide Priestess", "balanced", 0, { "Coral_Dragon", "Copperhead", "Frost_Cobra", "Ripple_Snake", "Scrub_Racer", "Twig_Snake", "Sand_Snake", "Frostbrew" } },
	{ "Constrictor", "opponents/constrictor.png", "Baba Jaro", "defensive", 1, { "Basalt_Serpent", "Extra_Long_Python", "Emerald_Boa", "Blossom_Boa", "Skinny_Snake", "Dirt_Snake", "Scrub_Racer", "Guardian_Ward", "Stoneskin_Tonic" } },
	{ "Mist Witch", "opponents/mist_witch.png", "Madame Zora", "balanced", 0, { "Banshee_Serpent", "Lich_Snake", "Wisp_Snake", "Eel_Snake", "Bark_Snake", "Dust_Adder", "Smoke_Draught" } },
	{ "Cinder Monk", "opponents/cinder_monk.png", "Raja Kaal", "balanced", 0, { "Blood_Cobra", "Clay_Snake", "Coral_Dragon", "Rust_Viper", "Sea_Snake", "Vine_Snake", "Ripple_Snake", "Rage_Draught", "Lightning_Storm" } },
	{ "Ember Queen", "opponents/ember_queen.png", "Ember Queen", "aggro", 0, { "Clay_Snake", "Tiger_Snake", "Basalt_Serpent", "Dust_Adder", "Orchid_Snake", "Lightning_Storm", "Rage_Draught" } },
	{ "Canyon Duelist", "opponents/canyon_duelist.png", "Yuki Frostveil", "balanced", 1, { "Wraith_Adder", "Prism_Adder", "Jelly_Snake", "Vine_Snake", "Brown_Snake", "Smoke_Draught", "Arcane_Insight" } },
	{ "Night Stalker", "opponents/night_stalker.png", "Madame Zora", "aggro", 0, { "Skeleton_Snake", "Nightmare_Adder", "Ash_Snake", "Brown_Snake", "Hog_Nosed_Snake", "Rock_Snake", "Frost_Nova", "Ghost_Tonic" } },
	{ "Golden Heir", "opponents/golden_heir.png", "Dr. Fang", "balanced", 0, { "Pearl_Serpent", "Quetzalcoatl", "Emerald_Boa", "Dirt_Snake", "Brook_Snake", "Rock_Snake", "Guardian_Ward", "Stoneskin_Tonic" } },
	{ "Emerald Emperor", "opponents/emerald_emperor.png", "Brother Moss", "balanced", 4, { "Kingsnake", "Emerald_Boa", "Moss_Snake", "Leaf_Snake", "Coral_Snake", "Confetti_Snake", "Venom_Elixir", "Regrowth_Brew" } },
	{ "The Viper King", "opponents/viper_king.png", "Raja Kaal", "balanced", 0, { "Basalt_Serpent", "Canopy_Viper", "Elderwood_Wyrm", "Wisp_Snake", "Brown_Snake", "Meteor_Strike" } },
}

-- Each time you face the same charmer again, its deck swaps its worst snake (lowest attack + defense) for a better one of the
-- same type, and it has 5 more health
local function upgrade(deck)
	local data = require("CardData")
	local function total(name) local s = data.stats_by_name[name]; return s.attack + s.defense end
	local worst, in_deck = 1, {}
	for i, name in ipairs(deck) do
		in_deck[name] = true
		if data.stats_by_name[name].kind == "snake" and (data.stats_by_name[deck[worst]].kind ~= "snake" or total(name) < total(deck[worst])) then
			worst = i
		end
	end
	local old, better = deck[worst], nil
	for _, name in ipairs(data.deck) do
		local s = data.stats_by_name[name]
		if s.kind == "snake" and s.rarity < 5 and not in_deck[name] and data.card_types[name] == data.card_types[old] and total(name) > total(old)
			and (not better or total(name) < total(better)) then
			better = name -- the smallest step up
		end
	end
	if better then
		deck[worst] = better
	end
end

local opponents, seen = {}, {}
for level, e in ipairs(list) do
	local deck = { unpack(e[6]) }
	local times = seen[e[3]] or 0 -- how many times this charmer has already been fought
	seen[e[3]] = times + 1
	for _ = 1, times do
		upgrade(deck)
	end
	opponents[level] = opponent(level, e[1], e[2], e[3], e[4], e[5], deck)
	opponents[level].health = opponents[level].health + 5 * times
end
return opponents
