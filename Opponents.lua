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
local function opponent(level, portrait, charmer, style, venom)
	return { name = charmer, portrait = portrait, charmer = charmer, style = styles[style], venom = math.floor(venom / 3), health = 40 + 5 * level }
end

local list = {
	{ "opponents/garden_keeper.png", "Tide Priestess", "defensive", 2 },
	{ "opponents/pond_skulker.png", "Yuki Frostveil", "balanced", 2 },
	{ "opponents/venom_rookie.png", "Dr. Fang", "aggro", 6 },
	{ "opponents/dune_wanderer.png", "Ember Queen", "balanced", 4 },
	{ "opponents/crypt_warden.png", "Yuki Frostveil", "defensive", 1 },
	{ "opponents/reed_stalker.png", "Ember Queen", "balanced", 4 },
	{ "opponents/fang_brawler.png", "Dr. Fang", "aggro", 1 },
	{ "opponents/bog_hermit.png", "Tide Priestess", "defensive", 3 },
	{ "opponents/tide_priestess.png", "Tide Priestess", "balanced", 0 },
	{ "opponents/constrictor.png", "Warden Basalt", "defensive", 1 },
	{ "opponents/mist_witch.png", "Yuki Frostveil", "balanced", 0 },
	{ "opponents/cinder_monk.png", "Ember Queen", "balanced", 0 },
	{ "opponents/ember_queen.png", "Ember Queen", "aggro", 0 },
	{ "opponents/canyon_duelist.png", "Yuki Frostveil", "balanced", 1 },
	{ "opponents/night_stalker.png", "Yuki Frostveil", "aggro", 0 },
	{ "opponents/golden_heir.png", "Dr. Fang", "balanced", 0 },
	{ "opponents/emerald_emperor.png", "Tide Priestess", "balanced", 4 },
	{ "opponents/viper_king.png", "Ember Queen", "balanced", 0 },
}

-- Level 1 fights with the starter snakes the player begins with; every level after swaps one more worst snake (lowest
-- attack + defense) for a slightly better one of the same type
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

local opponents = {}
for level, e in ipairs(list) do
	opponents[level] = opponent(level, e[1], e[2], e[3], e[4])
	-- the deck is built on first use: CardData cannot be required while Assets is still loading (it would be a require loop)
	setmetatable(opponents[level], { __index = function(entry, key)
		if key == "deck" then
			local deck = { unpack(require("CardData").starters) }
			for _ = 2, level do
				upgrade(deck)
			end
			rawset(entry, "deck", deck)
			return deck
		end
	end })
end
return opponents
