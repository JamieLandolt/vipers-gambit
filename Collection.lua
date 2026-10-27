local love = require("love")
local data = require("CardData")

local collection = { unlock_all = false, pack_size = 3, eyes = 0, pack_new = {}, sacrifice_mode = false, sacrificing = {} }

-- Three packs. Serpent (snakes) and Support (brews and spells) share one free pick a day; Elite holds only 3 to 5 star snakes.
-- The chance of each rarity (1 to 5, out of 100) and of a bordered snake slide from `early` (no opponent beaten) to `late`
-- (all beaten); see collection.odds.
collection.PACKS = {
	{ name = "Serpent Pack", kind = "snake", cost = 40, daily = true, colour = { 0.3, 0.75, 0.35 },
		early = { 70, 25, 5, 0, 0 }, late = { 30, 35, 25, 9, 1 }, border = { 0.6, 0.6 } },
	{ name = "Support Pack", kind = "support", cost = 30, daily = true, colour = { 0.5, 0.6, 1 },
		early = { 65, 30, 5, 0, 0 }, late = { 30, 40, 22, 8, 0 }, border = { 0, 0 } },
	{ name = "Elite Pack", kind = "snake", cost = 250, floor = 3, colour = { 1, 0.8, 0.2 },
		early = { 0, 0, 80, 19, 1 }, late = { 0, 0, 40, 45, 15 }, border = { 0.6, 0.6 } },
}
-- Reward packs from achievements: tokens[i] free openings of pack i (tokens.txt, "a b c")
local tokens = {}
for i in ipairs(collection.PACKS) do
	tokens[i] = 0
end
local rivals -- per-opponent record, loaded on first use (see load_rivals)
collection.SACRIFICE = 3 -- same-tier snakes given up for one snake of the next tier
collection.pack_kind = 0 -- the pack just opened (an index in PACKS), or 0 for a summon

-- Snakes you can never pull from a pack (only the unlock-all override shows them)
local UNOBTAINABLE = { "Cobra", "King_Cobra", "Albino_Cobra", "Blood_Cobra", "Frost_Cobra", "Golden_Snake" }
-- Only T1 snakes, covering every lane type; the other T1s and everything else come from packs
local STARTERS = data.starters

collection.MIN_DECK, collection.MAX_DECK = 8, 20
collection.deck_mode = false -- the collection screen is editing the deck

local owned, last_pack = {}, "-"
-- variants[name][border] = how many of your copies of a snake carry a border other than its own (they are counted in owned[name] too)
local variants = {}
local BORDERS = { "Venom", "Fire", "Shadow", "Rainbow", "Stone" }
local BORDERS_SET = {}
for _, border in ipairs(BORDERS) do
	BORDERS_SET[border] = true
end
local deck_pick = {} -- deck_pick[name][border] = how many of the deck's copies carry that border (none listed: variants first)
local deck_set -- names in the player's chosen deck; nil until they first edit it (then every owned snake is the deck)

-- How far through the campaign you are: 0 with nothing beaten, 1 with every opponent beaten
local function progress()
	return math.min(math.max((unlocked - 1) / (#require("Opponents") - 1), 0), 1)
end

-- The pack's current rarity weights (percent, rarity 1 to 5) and chance of a bordered snake
function collection.odds(pack)
	local p, weights = progress(), {}
	for r = 1, 5 do
		weights[r] = math.floor(pack.early[r] + (pack.late[r] - pack.early[r]) * p + 0.5)
	end
	return weights, pack.border[1] + (pack.border[2] - pack.border[1]) * p
end

local function today()
	return os.date("%Y-%m-%d")
end

-- save.txt lines: highest level, unlock-all flag, date of the last pack, snake eyes, then "name count" per owned snake
function collection.save()
	local lines = { tostring(unlocked), collection.unlock_all and "1" or "0", last_pack, tostring(collection.eyes) }
	for name, count in pairs(owned) do
		table.insert(lines, name .. " " .. count)
	end
	for name, kinds in pairs(variants) do
		for border, count in pairs(kinds) do
			table.insert(lines, name .. "@" .. border .. " " .. count) -- (variant copies are also counted in the snake's total above)
		end
	end
	love.filesystem.write("save.txt", table.concat(lines, "\n"))
end

function collection.load()
	collection.load_tokens()
	local lines = {}
	for line in (love.filesystem.read("save.txt") or ""):gmatch("[^\n]+") do
		table.insert(lines, line)
	end
	unlocked = math.min(tonumber(lines[1]) or 1, #require("Opponents"))
	collection.unlock_all = lines[2] == "1"
	last_pack = lines[3] or "-"
	owned, variants = {}, {}
	local first = 5
	collection.eyes = tonumber(lines[4]) or 0
	if not tonumber(lines[4]) then
		first = 4 -- older saves list one snake per line and have no snake eyes
	end
	for i = first, #lines do
		local name, count = lines[i]:match("^(%S+) ?(%d*)$")
		local base, border = (name or ""):match("^(.-)@(.+)$")
		if base then
			if data.stats_by_name[base] and BORDERS_SET[border] then
				variants[base] = variants[base] or {}
				variants[base][border] = tonumber(count) or 1
			end
		elseif name and data.stats_by_name[name] then -- (names of removed snakes are dropped)
			owned[name] = tonumber(count) or 1
		end
	end
	for _, name in ipairs(STARTERS) do
		owned[name] = owned[name] or 1
	end
	for name, kinds in pairs(variants) do -- a variant copy must be one of the copies owned
		local room = owned[name] or 0
		for border, count in pairs(kinds) do
			kinds[border] = math.min(count, room)
			room = room - kinds[border]
		end
	end


	-- deck.txt: one snake name per line
	local saved = love.filesystem.read("deck.txt")
	deck_set, deck_pick = nil, {}
	if saved then
		deck_set = {}
		for name in saved:gmatch("[^\n]+") do
			local base, count, picks = name:match("^(%S+) ?(%d*) ?(%S*)$")
			deck_set[base] = data.stats_by_name[base] and (tonumber(count) or 1) or nil
			if deck_set[base] and picks ~= "" then
				deck_pick[base] = {}
				for border, n in picks:gmatch("(%a+)=(%d+)") do
					deck_pick[base][border] = tonumber(n)
				end
			end
		end
	end
end

local function save_deck()
	local names = {}
	for name, count in pairs(deck_set) do
		local picks = {}
		for border, n in pairs(deck_pick[name] or {}) do
			table.insert(picks, border .. "=" .. n)
		end
		table.insert(names, name .. " " .. count .. (deck_pick[name] and " " .. (#picks > 0 and table.concat(picks, ",") or "-") or ""))
	end
	love.filesystem.write("deck.txt", table.concat(names, "\n"))
end

-- Wipes progress back to a new game (settings are kept)
function collection.reset()
	unlocked, collection.unlock_all, last_pack, owned, variants, deck_set, collection.eyes = 1, false, "-", {}, {}, nil, 0
	deck_pick = {}
	chosen_avatar = require("Charmers").list[1].name
	love.filesystem.remove("deck.txt")
	love.filesystem.remove("finale.txt")
	love.filesystem.remove("hints.txt")
	love.filesystem.remove("recipes.txt")
	love.filesystem.remove("challenges.txt")
	love.filesystem.remove("vials.txt")
	love.filesystem.remove("tutorial1.txt")
	require("Tutorial").done = false
	vials, vials_since = collection.VIALS_MAX, os.time()
	require("Achievements").reset()
	for i in ipairs(tokens) do
		tokens[i] = 0
	end
	love.filesystem.remove("tokens.txt")
	collection.seen, rivals = nil, nil
	love.filesystem.remove("rivals.txt")
	love.filesystem.remove("charmer_wins.txt")
	charmer_wins = nil
	for _, name in ipairs(STARTERS) do
		owned[name] = 1
	end
	collection.save()
end

-- How many copies of a snake you own (unlock-all shows one of every snake)
function collection.count(name)
	return owned[name] or (collection.unlock_all and 1 or 0)
end

function collection.has(name)
	return collection.count(name) > 0
end

-- Copies of a snake that carry a border other than its natural one, and how many that is in all
local function variant_total(name)
	local n = 0
	for _, count in pairs(variants[name] or {}) do
		n = n + count
	end
	return n
end

-- The borders you own copies of for a snake, as { border, count } (its own border first); with unlock-all you "own" one natural copy
function collection.variant_list(name)
	local list = {}
	local natural = data.stats_by_name[name].border
	if collection.count(name) - variant_total(name) > 0 then
		table.insert(list, { natural, collection.count(name) - variant_total(name) })
	end
	for _, border in ipairs(BORDERS) do
		local count = (variants[name] or {})[border]
		if count and count > 0 then
			table.insert(list, { border, count })
		end
	end
	return list
end

-- One border per copy for k copies of a snake in a deck or hand: variant copies first, then false for natural ones
-- (`picks` is the deck's own choice of how many of each border; the natural copies come after those, then any other variants)
local function copy_borders(name, k, picks)
	local pool, rest = {}, {}
	for _, border in ipairs(BORDERS) do
		local have = (variants[name] or {})[border] or 0
		local want = picks and math.min(picks[border] or 0, have) or have
		for _ = 1, want do
			table.insert(pool, border)
		end
		for _ = 1, have - want do
			table.insert(rest, border)
		end
	end
	for _ = 1, picks and collection.count(name) - variant_total(name) or 0 do
		table.insert(pool, false)
	end
	for _, border in ipairs(rest) do
		table.insert(pool, border)
	end
	local list = {}
	for i = 1, k do
		list[i] = pool[i] or false
	end
	return list
end

function collection.toggle_unlock_all()
	collection.unlock_all = not collection.unlock_all
	collection.save()
end

local function stat(name, field)
	local stats = data.get_stats({ card_path = name .. ".png" })
	return stats and stats[field] or 0
end

-- The chosen deck as a list of names, one entry per copy
local function chosen()
	local list, list_borders = {}, {}
	for _, name in ipairs(data.deck) do
		local k = math.min(deck_set[name] or 0, collection.count(name))
		for i, border in ipairs(copy_borders(name, k, deck_pick[name])) do
			table.insert(list, name)
			table.insert(list_borders, border)
		end
	end
	return list, list_borders
end

collection.chosen = chosen

-- Auto-fill: an even deck of the strongest owned snakes, PER_TYPE copies of each lane type (Rainbow snakes fit any lane, so
-- they are left out); if that leaves fewer than MIN_DECK, the strongest of the rest fill it
collection.PER_TYPE = 3
function collection.auto_deck()
	local names = {}
	for _, name in ipairs(data.deck) do
		if collection.has(name) and stat(name, "kind") == "snake" then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		return stat(a, "rarity") > stat(b, "rarity") or (stat(a, "rarity") == stat(b, "rarity") and a < b)
	end)
	deck_set, deck_pick = {}, {}
	local size, per_type = 0, {}
	local function add(name)
		deck_set[name] = (deck_set[name] or 0) + 1
		size = size + 1
	end
	for _, name in ipairs(names) do
		local kind = data.get_type({ card_path = name .. ".png" })
		for _ = 1, collection.count(name) do
			if kind ~= "Rainbow" and (per_type[kind] or 0) < collection.PER_TYPE then
				per_type[kind] = (per_type[kind] or 0) + 1
				add(name)
			end
		end
	end
	for _, name in ipairs(names) do -- too few of some types to reach the minimum: top up with the strongest left
		while size < collection.MIN_DECK and (deck_set[name] or 0) < collection.count(name) do
			add(name)
		end
	end
	save_deck()
end

-- Copies of a snake in the deck (before a deck is chosen, every copy you own is in it)
function collection.in_deck(name)
	return deck_set == nil and collection.count(name) or math.min(deck_set[name] or 0, collection.count(name))
end

function collection.deck_count()
	return deck_set and #chosen() or 0
end

-- First time editing: start from the strongest owned snakes, up to the size limit
function collection.start_deck_edit()
	if deck_set then
		return
	end
	local names = {}
	for _, name in ipairs(data.deck) do
		if collection.has(name) then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		return stat(a, "rarity") > stat(b, "rarity") or (stat(a, "rarity") == stat(b, "rarity") and a < b)
	end)
	deck_set, deck_pick = {}, {}
	local size = 0
	for _, name in ipairs(names) do
		for _ = 1, collection.count(name) do
			if size < collection.MAX_DECK then
				deck_set[name] = (deck_set[name] or 0) + 1
				size = size + 1
			end
		end
	end
	save_deck()
end

-- The borders a snake can go in the deck with, as { key (false for its own), border, avail, n (copies in the deck) }, its own first
function collection.deck_kinds(name)
	local counts = {}
	for _, border in ipairs(copy_borders(name, collection.in_deck(name), deck_pick[name])) do
		counts[border or ""] = (counts[border or ""] or 0) + 1
	end
	local kinds, natural = {}, collection.count(name) - variant_total(name)
	if natural > 0 then
		table.insert(kinds, { key = false, border = data.stats_by_name[name].border, avail = natural, n = counts[""] or 0 })
	end
	for _, border in ipairs(BORDERS) do
		local have = (variants[name] or {})[border] or 0
		if have > 0 then
			table.insert(kinds, { key = border, border = border, avail = have, n = counts[border] or 0 })
		end
	end
	return kinds
end

-- A click adds a copy with the given border (false: its own), or removes them all once every such copy you own is in;
-- mode "remove" takes one copy out and mode "all" puts every copy you own in (as far as the deck has room).
-- Returns a message when it isn't allowed
function collection.toggle_deck(name, key, mode)
	local kinds = collection.deck_kinds(name)
	local kind = kinds[1]
	for _, k in ipairs(kinds) do
		kind = k.key == (key or false) and k or kind
	end
	local size = collection.deck_count()
	if mode == "all" then
		local room = collection.MAX_DECK - size
		for _, k in ipairs(kinds) do
			local add = math.min(k.avail - k.n, room)
			k.n, room = k.n + add, room - add
		end
		if room == collection.MAX_DECK - size then
			return "Your deck is full (" .. collection.MAX_DECK .. " snakes)"
		end
	elseif mode == "remove" then
		if not key then -- no border chosen: take out the last kind that is in the deck
			for _, k in ipairs(kinds) do
				kind = k.n > 0 and k or kind
			end
		end
		if kind.n == 0 then
			return
		elseif size <= collection.MIN_DECK then
			return "A deck needs at least " .. collection.MIN_DECK .. " snakes"
		end
		kind.n = kind.n - 1
	elseif kind.n < kind.avail then
		if size >= collection.MAX_DECK then
			return "Your deck is full (" .. collection.MAX_DECK .. " snakes)"
		end
		kind.n = kind.n + 1
	else
		if size - kind.n < collection.MIN_DECK then
			return "A deck needs at least " .. collection.MIN_DECK .. " snakes"
		end
		kind.n = 0
	end
	local total, picks = 0, {}
	for _, k in ipairs(kinds) do
		total = total + k.n
		if k.key then
			picks[k.key] = k.n
		end
	end
	deck_set[name] = total > 0 and total or nil
	deck_pick[name] = total > 0 and picks or nil
	save_deck()
end

-- The snakes the player draws their hand from (one entry per copy): the chosen deck, or everything owned before one is chosen.
-- The second result lists each copy's border (false for a snake's own).
function collection.deck()
	if deck_set then
		local list, list_borders = chosen()
		if #list >= collection.MIN_DECK then
			return list, list_borders
		end
	end
	local deck, deck_borders = {}, {}
	for _, name in ipairs(data.deck) do
		for _, border in ipairs(copy_borders(name, collection.count(name))) do
			table.insert(deck, name)
			table.insert(deck_borders, border)
		end
	end
	return deck, deck_borders
end

local SORTS = {
	{ "Name", function(name) return name end },
	{ "Cost", function(name) return stat(name, "cost") end },
	{ "Attack", function(name) return stat(name, "attack") end },
	{ "Health", function(name) return stat(name, "defense") end },
	{ "Rarity", function(name) return stat(name, "rarity") end },
}
local sort_mode, order, ordered_for = 1, nil, nil

function collection.sort_name()
	return SORTS[sort_mode][1]
end

function collection.next_sort()
	sort_mode = sort_mode % #SORTS + 1
	order = nil
end

-- Indices into names (e.g. assets.card_names) in the current display order; ties fall back to name
function collection.order(names)
	if not order or ordered_for ~= names then
		local key = SORTS[sort_mode][2]
		order, ordered_for = {}, names
		for i = 1, #names do
			order[i] = i
		end
		table.sort(order, function(a, b)
			local ka, kb = key(names[a]), key(names[b])
			if ka ~= kb then
				return ka < kb
			end
			return names[a] < names[b]
		end)
	end
	return order
end

-- Collection filters: each icon on the collection screen switches one kind of card on or off
collection.FILTER_GROUPS = {
	{ id = "kind", keys = { "snake", "brew", "spell" } },
	{ id = "type", keys = { "Land", "Water", "Tree", "Spirit", "Rainbow" } },
	{ id = "tier", keys = { 1, 2, 3, 4, 5 } },
	{ id = "own", keys = { "owned", "missing" } },
}
local filter_off = {} -- ["kind:brew"] = true while switched off

function collection.filter_on(group, key)
	return not filter_off[group .. ":" .. key]
end

function collection.toggle_filter(group, key)
	local id = group .. ":" .. key
	filter_off[id] = not filter_off[id] or nil
end

function collection.filtering()
	return next(filter_off) ~= nil
end

function collection.clear_filters()
	filter_off = {}
end

-- Is the card shown with the current filters? (the lane type filter only applies to snakes)
function collection.shown(name)
	if collection.deck_mode and not collection.has(name) then
		return false -- the deck page only lists what you own
	end
	local kind = stat(name, "kind")
	if not collection.filter_on("kind", kind) or not collection.filter_on("tier", stat(name, "rarity")) then
		return false
	end
	if kind == "snake" and not collection.filter_on("type", data.card_types[name]) then
		return false
	end
	return collection.filter_on("own", collection.has(name) and "owned" or "missing")
end

function collection.owned_count()
	local n = 0
	for _, name in ipairs(data.deck) do
		n = n + (collection.has(name) and 1 or 0)
	end
	return n
end

-- How many copies of snakes you own carry the border (the ones with their own natural border included)
function collection.border_count(border)
	local n = 0
	for name, count in pairs(owned) do
		local st = data.stats_by_name[name]
		local variant = variant_total(name)
		if st.border == border then
			n = n + count - variant
		end
		n = n + ((variants[name] or {})[border] or 0)
	end
	return n
end

-- Your snakes wearing a border, as { name, count } in card order
function collection.border_holders(border)
	local list = {}
	for _, name in ipairs(data.deck) do
		local n = ((variants[name] or {})[border] or 0)
		if data.stats_by_name[name].border == border then
			n = n + collection.count(name) - variant_total(name)
		end
		if n > 0 then
			table.insert(list, { name, n })
		end
	end
	return list
end

-- Charmer levels: wins with each charmer (charmer_wins.txt, one "name wins" line each). Every 3 wins with a charmer is a
-- level for that charmer (up to level 10), and each level gives it 5 more health in battle.
collection.WINS_PER_LEVEL, collection.BONUS_HEALTH, collection.MAX_LEVEL = 3, 5, 10
local charmer_wins

local function load_charmer_wins()
	if not charmer_wins then
		charmer_wins = {}
		for name, wins in (love.filesystem.read("charmer_wins.txt") or ""):gmatch("([^\n]-) (%d+)\n?") do
			charmer_wins[name] = tonumber(wins)
		end
	end
	return charmer_wins
end

function collection.charmer_wins(name)
	return load_charmer_wins()[name] or 0
end

function collection.charmer_level(name)
	return math.min(1 + math.floor(collection.charmer_wins(name) / collection.WINS_PER_LEVEL), collection.MAX_LEVEL)
end

-- Wins towards the next level, out of how many it takes (nil at the top level)
function collection.level_progress(name)
	if collection.charmer_level(name) >= collection.MAX_LEVEL then
		return nil
	end
	return collection.charmer_wins(name) % collection.WINS_PER_LEVEL, collection.WINS_PER_LEVEL
end

-- The extra health a charmer has from its level
function collection.health_bonus(name)
	return (collection.charmer_level(name or "") - 1) * collection.BONUS_HEALTH
end

function collection.add_charmer_win(name)
	local all = load_charmer_wins()
	local before = collection.charmer_level(name)
	all[name] = (all[name] or 0) + 1
	collection.last_level_up = collection.charmer_level(name) > before and { name = name, level = collection.charmer_level(name) } or nil
	local lines = {}
	for n, wins in pairs(all) do
		lines[#lines + 1] = n .. " " .. wins
	end
	love.filesystem.write("charmer_wins.txt", table.concat(lines, "\n") .. "\n")
end

-- Record against each opponent (rivals.txt, one "level wins challenges endless" line per level): matches won, how many of the
-- level's three challenges are cleared, and endless rematches won. Saves from before challenges had tiers (challenges.txt) count as one.
local function load_rivals()
	if rivals then
		return rivals
	end
	rivals = {}
	local text = love.filesystem.read("rivals.txt")
	if text then
		for level, wins, chal, endless in text:gmatch("(%d+) (%d+) (%d+) (%d+)") do
			rivals[tonumber(level)] = { wins = tonumber(wins), chal = tonumber(chal), endless = tonumber(endless) }
		end
	else
		for level in (love.filesystem.read("challenges.txt") or ""):gmatch("%d+") do
			rivals[tonumber(level)] = { wins = 1, chal = 1, endless = 0 }
		end
	end
	return rivals
end

local function rival(level)
	local all = load_rivals()
	all[level] = all[level] or { wins = 0, chal = 0, endless = 0 }
	return all[level]
end

function collection.wins(level) return rival(level).wins end
function collection.challenges_done(level) return rival(level).chal end
function collection.endless(level) return rival(level).endless end

-- Has the plain level been beaten? (older saves only have the unlocked level to go by)
function collection.beaten_base(level)
	return level > 0 and (rival(level).wins > 0 or level < unlocked or (level == #require("Opponents") and love.filesystem.getInfo("finale.txt") ~= nil))
end

-- A win over `level` (`challenge` is the fight's challenge table, if it was one)
function collection.record_win(level, challenge)
	local r = rival(level)
	collection.add_charmer_win(chosen_avatar)
	collection.drop_snake(level, r.wins == 0)
	r.wins = r.wins + 1
	if challenge and challenge.endless then
		r.endless = r.endless + 1
	elseif challenge and challenge.tier == r.chal + 1 then
		r.chal = r.chal + 1
	end
	local lines, best, chals, endless = {}, 0, 0, 0
	for l, v in pairs(rivals) do
		lines[#lines + 1] = l .. " " .. v.wins .. " " .. v.chal .. " " .. v.endless
		best, chals, endless = math.max(best, v.wins), chals + v.chal, endless + v.endless
	end
	love.filesystem.write("rivals.txt", table.concat(lines, "\n"))
	local ach = require("Achievements")
	ach.set("rival_wins", best)
	ach.set("challenges", chals)
	ach.set("endless", endless)
end

-- Imbuing opens up once you have beaten the 10th opponent, and so does the Snake God's altar (sacrifice)
-- Deck building opens after the 3rd opponent
function collection.deck_unlocked()
	return collection.unlock_all or unlocked >= 4
end

-- Achievements open after the 7th opponent
function collection.achievements_unlocked()
	return collection.unlock_all or unlocked >= 8
end

-- The collection opens on a page of sections (snakes, brews, spells, borders); `section` is the kind being browsed
collection.section, collection.return_to = nil, nil
function collection.landing()
	return not collection.deck_mode and not collection.sacrifice_mode and not collection.section
end

function collection.open_section(kind)
	collection.clear_filters()
	for _, other in ipairs({ "snake", "brew", "spell" }) do
		if other ~= kind then
			collection.toggle_filter("kind", other)
		end
	end
	collection.section = kind
end

function collection.imbue_unlocked()
	return collection.unlock_all or unlocked >= 11
end

function collection.sacrifice_unlocked()
	return collection.unlock_all or unlocked >= 11
end

-- One-time tips: hints.txt lists the ones already shown
function collection.hint_seen(key)
	if not collection.seen then
		collection.seen = {}
		for line in (love.filesystem.read("hints.txt") or ""):gmatch("[^\n]+") do
			collection.seen[line] = true
		end
	end
	return collection.seen[key]
end

function collection.mark_hint(key)
	collection.hint_seen(key)
	collection.seen[key] = true
	local keys = {}
	for k in pairs(collection.seen) do
		table.insert(keys, k)
	end
	love.filesystem.write("hints.txt", table.concat(keys, "\n"))
end

function collection.pack_ready()
	return last_pack ~= today()
end

local function save_tokens()
	love.filesystem.write("tokens.txt", table.concat(tokens, " "))
end
function collection.load_tokens()
	local i = 0
	for n in (love.filesystem.read("tokens.txt") or ""):gmatch("%d+") do
		i = i + 1
		tokens[i] = tokens[i] and tonumber(n) or nil
	end
end
function collection.give_pack(index)
	tokens[index] = tokens[index] + 1
	save_tokens()
end
function collection.tokens(index)
	return tokens[index]
end

-- Does opening this pack right now use up a reward pack (rather than the free daily one)?
local function uses_token(index)
	return tokens[index] > 0 and not (collection.PACKS[index].daily and collection.pack_ready())
end

-- Snake eyes the pack costs right now: the first Serpent or Support pack each day is free, and so are reward packs
function collection.price(index)
	local pack = collection.PACKS[index]
	return (pack.daily and collection.pack_ready() or tokens[index] > 0) and 0 or pack.cost
end

local function add_copy(name, border)
	collection.start_deck_edit() -- fix the deck as it is, so new snakes only join it when the player puts them in
	owned[name] = (owned[name] or 0) + 1
	if border and border ~= data.stats_by_name[name].border then
		variants[name] = variants[name] or {}
		variants[name][border] = (variants[name][border] or 0) + 1
	end
end

-- Cards that can be pulled or summoned, by rarity: snakes, or (kind "support") brews and spells
local function obtainable(kind)
	local pool = { {}, {}, {}, {}, {} }
	for _, name in ipairs(data.deck) do
		if not contains(UNOBTAINABLE, name) and (stat(name, "kind") == "snake") == (kind == "snake") then
			table.insert(pool[stat(name, "rarity")], name)
		end
	end
	return pool
end

-- A random snake of the rarity, or the nearest lower one that has any
-- A random border for a snake that is not the one it already has
local function random_border(name)
	local choices = {}
	for _, border in ipairs(BORDERS) do
		if border ~= data.stats_by_name[name].border then
			table.insert(choices, border)
		end
	end
	return choices[math.random(#choices)]
end

local MILESTONE_TIER = { [3] = 3, [10] = 4 } -- level -> tier of the snake its first win gives
collection.MILESTONE_TIER = MILESTONE_TIER

-- The three snakes a win over `level` can give. All the snakes below mythic (except your starters) are ranked by attack plus
-- health and spread evenly over the 18 levels, three each and never repeated, so every level unlocks different snakes and
-- later levels give stronger ones.
local reward_ladder
function collection.level_rewards(level)
	if not reward_ladder then
		local ranked = {}
		for tier = 1, 4 do
			for _, name in ipairs(obtainable("snake")[tier]) do
				if not contains(STARTERS, name) then
					ranked[#ranked + 1] = name
				end
			end
		end
		table.sort(ranked, function(a, b)
			local ta, tb = stat(a, "attack") + stat(a, "defense"), stat(b, "attack") + stat(b, "defense")
			return ta < tb or (ta == tb and a < b)
		end)
		local slots = 3 * #require("Opponents")
		reward_ladder = {}
		for i = 1, slots do
			reward_ladder[i] = ranked[math.floor(1 + (i - 1) * (#ranked - 1) / (slots - 1) + 0.5)]
		end
	end
	return { unpack(reward_ladder, 3 * level - 2, 3 * level) }
end

-- Every win drops one of the level's three reward snakes (a third each) with a random border. The first win over level 3 or
-- 10 also gives a snake of a set tier, on top of that.
function collection.drop_snake(level, first)
	local snakes = collection.level_rewards(level)
	collection.last_snake, collection.last_bonus = nil, nil
	local function give(name)
		local border = random_border(name)
		add_copy(name, border)
		return { name = name, border = border }
	end
	if #snakes > 0 then
		collection.last_snake = give(snakes[math.random(#snakes)])
	end
	if first and MILESTONE_TIER[level] then
		local pool = obtainable("snake")[MILESTONE_TIER[level]]
		collection.last_bonus = give(pool[math.random(#pool)])
	end
	collection.save()
end

local function random_of(pool, rarity, floor)
	while #pool[rarity] == 0 and rarity > (floor or 1) do
		rarity = rarity - 1
	end
	return pool[rarity][math.random(#pool[rarity])]
end

-- Opens pack number index (duplicates are fine) and returns the snakes pulled, or nil and the reason it can't be opened.
function collection.open_pack(index)
	local pack = collection.PACKS[index]
	local price = collection.price(index)
	if collection.eyes < price then
		return nil, "Not enough snake eyes"
	end
	local token = uses_token(index)
	local weights, border_chance = collection.odds(pack)
	local pool, pulled = obtainable(pack.kind), {}
	collection.pack_new, collection.pack_borders = {}, {}
	for _ = 1, collection.pack_size do
		local roll, rarity = math.random() * 100, pack.floor or 1
		for r, weight in ipairs(weights) do
			if roll < weight then
				rarity = r
				break
			end
			roll = roll - weight
		end
		local name = random_of(pool, rarity, pack.floor)
		collection.pack_new[name] = collection.pack_new[name] or not collection.has(name) or nil
		local border = math.random() < border_chance and stat(name, "kind") == "snake" and BORDERS[math.random(#BORDERS)] or nil -- 12% each of the five; a snake's own border just stays as it is
		add_copy(name, border)
		table.insert(pulled, name)
		table.insert(collection.pack_borders, border or data.stats_by_name[name].border)
	end
	collection.eyes = collection.eyes - price
	if token then
		tokens[index] = tokens[index] - 1
		save_tokens()
	elseif pack.daily and price == 0 then
		last_pack = today()
	end
	collection.pack_kind = index
	require("Achievements").add("packs")
	require("Achievements").set("owned", collection.owned_count())
	if deck_set then
		save_deck()
	end
	collection.save()
	return pulled
end

-- Venom vials: every campaign match costs 1, and it comes back over time (even while the game is closed).
-- vials.txt holds "<points> <time the next point started refilling>". The first, guided match is free.
collection.VIALS_MAX, collection.VIALS_REGEN = 5, 300 -- most you can hold, and seconds per point
local vials, vials_since = collection.VIALS_MAX, os.time()

local function refill()
	local now = os.time()
	if vials >= collection.VIALS_MAX then
		vials_since = now
		return
	end
	local gained = math.floor((now - vials_since) / collection.VIALS_REGEN)
	if gained > 0 then
		vials = math.min(vials + gained, collection.VIALS_MAX)
		vials_since = vials >= collection.VIALS_MAX and now or vials_since + gained * collection.VIALS_REGEN
	end
end

function collection.load_vials()
	local points, since = (love.filesystem.read("vials.txt") or ""):match("^(%d+) (%d+)$")
	if points then
		vials, vials_since = math.min(tonumber(points), collection.VIALS_MAX), tonumber(since)
	end
	refill()
end

function collection.vials()
	refill()
	return vials
end

-- Seconds until the next venom vial (nil when full)
function collection.vials_wait()
	refill()
	return vials < collection.VIALS_MAX and math.max(0, collection.VIALS_REGEN - (os.time() - vials_since)) or nil
end

function collection.spend_vials(amount)
	refill()
	if vials < amount then
		return false
	end
	if vials >= collection.VIALS_MAX then
		vials_since = os.time()
	end
	vials = vials - amount
	love.filesystem.write("vials.txt", vials .. " " .. vials_since)
	return true
end

-- Snake eyes for finishing a match
function collection.payout(won, level, mult)
	return won and math.floor((20 + 10 * level) * (mult or 1)) or 5
end

function collection.reward(won, level, mult)
	local eyes = collection.payout(won, level, mult)
	collection.eyes = collection.eyes + eyes
	collection.save()
	return eyes
end

-- Sacrifice: pick SACRIFICE snakes of one tier (clicking again takes one back), then summon a snake a tier higher
local function selected(name)
	local n = 0
	for _, picked in ipairs(collection.sacrificing) do
		n = n + (picked == name and 1 or 0)
	end
	return n
end
collection.selected = selected

function collection.pick_sacrifice(name)
	local list = collection.sacrificing
	local spare = (owned[name] or 0) - (contains(STARTERS, name) and 1 or 0) - selected(name)
	if selected(name) > 0 and spare <= 0 then
		for i, picked in ipairs(list) do
			if picked == name then
				table.remove(list, i)
				return
			end
		end
	end
	if stat(name, "kind") ~= "snake" then
		return "Only snakes can be imbued"
	elseif stat(name, "rarity") >= 5 then
		return "Mythic snakes can't be imbued"
	elseif #list >= collection.SACRIFICE then
		return "Already " .. collection.SACRIFICE .. " chosen: press Imbue"
	elseif #list > 0 and list[1] ~= name then
		return "Imbue needs " .. collection.SACRIFICE .. " copies of the same snake"
	elseif spare <= 0 then
		return "You need a spare copy to imbue with this one"
	end
	table.insert(list, name)
end

function collection.can_summon()
	return #collection.sacrificing == collection.SACRIFICE
end

-- Three copies of the same snake are imbued instead: they become one copy with a guaranteed random new border
function collection.is_imbue()
	local list = collection.sacrificing
	return #list == collection.SACRIFICE and list[1] == list[2] and list[2] == list[3] and stat(list[1], "kind") == "snake"
end

-- Gives up a copy of a snake (a plain one first, then a variant)
local function remove_copy(name)
	local had_plain = owned[name] - variant_total(name) > 0
	owned[name] = owned[name] - 1
	if not had_plain then
		for _, border in ipairs(BORDERS) do
			local kinds = variants[name]
			if kinds and (kinds[border] or 0) > 0 then
				kinds[border] = kinds[border] - 1
				break
			end
		end
	end
	if owned[name] == 0 then
		owned[name], variants[name] = nil, nil
	end
end

-- Imbue: gives up three copies of one snake for one copy of it with a random new border; returns its name
function collection.summon()
	local list = collection.sacrificing
	local result = list[1]
	local border = random_border(result)
	for _, name in ipairs(list) do
		remove_copy(name)
		if deck_set and (deck_set[name] or 0) > (owned[name] or 0) then
			deck_set[name] = owned[name]
		end
	end
	collection.pack_new = {}
	collection.pack_borders = { border }
	add_copy(result, border)
	collection.sacrificing, collection.pack_kind = {}, 0
	require("Achievements").add("imbues")
	if deck_set then
		save_deck()
	end
	collection.save()
	return { result }
end

-- The Snake God's recipes: specific snakes in, one specific snake out. A recipe is only shown while you own everything it asks for.
local recipes, recipe_for
function collection.recipes()
	if not recipes then
		local exclude = {}
		for _, name in ipairs(STARTERS) do
			table.insert(exclude, name)
		end
		for _, name in ipairs(UNOBTAINABLE) do
			table.insert(exclude, name)
		end
		recipes, recipe_for = require("Recipes")(data, exclude)
	end
	return recipes, recipe_for
end

function collection.can_sacrifice(recipe)
	for _, name in ipairs(recipe.give) do
		if (owned[name] or 0) < 1 then
			return false
		end
	end
	return true
end

-- A recipe only shows while you own every snake it asks for (one copy of each is enough)
function collection.recipe_known(recipe)
	return collection.unlock_all or collection.can_sacrifice(recipe)
end

-- Performs a recipe: gives up its snakes for its reward; returns { reward } or nil if you no longer own what it asks for
function collection.sacrifice_recipe(recipe)
	if not collection.can_sacrifice(recipe) then
		return nil
	end
	for _, name in ipairs(recipe.give) do
		remove_copy(name)
		if deck_set and (deck_set[name] or 0) > (owned[name] or 0) then
			deck_set[name] = owned[name]
		end
	end
	collection.pack_new = { [recipe.get] = not collection.has(recipe.get) or nil }
	collection.pack_borders = { data.stats_by_name[recipe.get].border }
	add_copy(recipe.get)
	collection.pack_kind = 0
	if deck_set then
		save_deck()
	end
	collection.save()
	return { recipe.get }
end

return collection
