local love = require("love")
local data = require("CardData")

local collection = { unlock_all = false, pack_size = 3 }

-- Snakes you can never pull from a pack (only the unlock-all override shows them)
local UNOBTAINABLE = { "Cobra", "King_Cobra", "Albino_Cobra", "Blood_Cobra", "Frost_Cobra", "Golden_Snake" }
-- Only T1 snakes, covering every lane type; the other T1s and everything else come from packs
local STARTERS = { "Snake", "Dirt_Snake", "Garter_Snake", "Mud_Snake", "Grass_Snake", "Brown_Snake", "Pale_Snake", "Coral_Snake" }

collection.MIN_DECK, collection.MAX_DECK = 8, 20
collection.deck_mode = false -- the collection screen is editing the deck

local owned, last_pack = {}, "-"
local deck_set -- names in the player's chosen deck; nil until they first edit it (then every owned snake is the deck)

local function today()
	return os.date("%Y-%m-%d")
end

-- save.txt lines: highest level, unlock-all flag, date of the last pack, then owned snakes
function collection.save()
	local lines = { tostring(unlocked), collection.unlock_all and "1" or "0", last_pack }
	for name in pairs(owned) do
		table.insert(lines, name)
	end
	love.filesystem.write("save.txt", table.concat(lines, "\n"))
end

function collection.load()
	local lines = {}
	for line in (love.filesystem.read("save.txt") or ""):gmatch("[^\n]+") do
		table.insert(lines, line)
	end
	unlocked = tonumber(lines[1]) or 1
	collection.unlock_all = lines[2] == "1"
	last_pack = lines[3] or "-"
	owned = {}
	for _, name in ipairs(STARTERS) do
		owned[name] = true
	end
	for i = 4, #lines do
		owned[lines[i]] = data.stats_by_name[lines[i]] and true or nil -- (names of removed snakes are dropped)
	end

	-- deck.txt: one snake name per line
	local saved = love.filesystem.read("deck.txt")
	deck_set = nil
	if saved then
		deck_set = {}
		for name in saved:gmatch("[^\n]+") do
			deck_set[name] = data.stats_by_name[name] and true or nil
		end
	end
end

local function save_deck()
	local names = {}
	for name in pairs(deck_set) do
		table.insert(names, name)
	end
	love.filesystem.write("deck.txt", table.concat(names, "\n"))
end

-- Wipes progress back to a new game (settings are kept)
function collection.reset()
	unlocked, collection.unlock_all, last_pack, owned, deck_set = 1, false, "-", {}, nil
	love.filesystem.remove("deck.txt")
	for _, name in ipairs(STARTERS) do
		owned[name] = true
	end
	collection.save()
end

function collection.has(name)
	return collection.unlock_all or owned[name] == true
end

function collection.toggle_unlock_all()
	collection.unlock_all = not collection.unlock_all
	collection.save()
end

local function stat(name, field)
	local stats = data.get_stats({ card_path = name .. ".png" })
	return stats and stats[field] or 0
end

-- Owned snakes that are in the chosen deck
local function chosen()
	local list = {}
	for _, name in ipairs(data.deck) do
		if deck_set[name] and collection.has(name) then
			table.insert(list, name)
		end
	end
	return list
end

function collection.in_deck(name)
	return collection.has(name) and (deck_set == nil or deck_set[name] == true)
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
	deck_set = {}
	for i = 1, math.min(#names, collection.MAX_DECK) do
		deck_set[names[i]] = true
	end
	save_deck()
end

-- Adds or removes a snake; returns a message when the change isn't allowed
function collection.toggle_deck(name)
	if deck_set[name] and collection.has(name) then
		if collection.deck_count() <= collection.MIN_DECK then
			return "A deck needs at least " .. collection.MIN_DECK .. " snakes"
		end
		deck_set[name] = nil
	else
		if collection.deck_count() >= collection.MAX_DECK then
			return "Your deck is full (" .. collection.MAX_DECK .. " snakes)"
		end
		deck_set[name] = true
	end
	save_deck()
end

-- The snakes the player draws their hand from: the chosen deck, or every owned snake before one is chosen
function collection.deck()
	if deck_set then
		local list = chosen()
		if #list >= collection.MIN_DECK then
			return list
		end
	end
	local deck = {}
	for _, name in ipairs(data.deck) do
		if collection.has(name) then
			table.insert(deck, name)
		end
	end
	return deck
end


local SORTS = {
	{ "Name", function(name) return name end },
	{ "Cost", function(name) return stat(name, "cost") end },
	{ "Attack", function(name) return stat(name, "attack") end },
	{ "Defense", function(name) return stat(name, "defense") end },
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

function collection.pack_ready()
	return last_pack ~= today()
end

-- One pack per day: pack_size new snakes you don't own yet. Returns their names (empty if none are left).
function collection.open_pack()
	local pool = {}
	for _, name in ipairs(data.deck) do
		if not owned[name] and not contains(UNOBTAINABLE, name) then
			table.insert(pool, name)
		end
	end
	local pulled = {}
	while #pulled < collection.pack_size and #pool > 0 do
		local name = table.remove(pool, math.random(#pool))
		owned[name] = true
		table.insert(pulled, name)
		if deck_set and collection.deck_count() < collection.MAX_DECK then
			deck_set[name] = true -- new snakes join the deck while it has room
		end
	end
	if deck_set then
		save_deck()
	end
	last_pack = today()
	collection.save()
	return pulled
end

return collection
