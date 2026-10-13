local love = require("love")
local data = require("CardData")

local collection = { unlock_all = false, pack_size = 3 }

-- Snakes you can never pull from a pack (only the unlock-all override shows them)
local UNOBTAINABLE = { "Cobra", "King_Cobra", "Albino_Cobra", "Blood_Cobra", "Frost_Cobra", "Golden_Snake" }
-- Only T1 snakes, covering every lane type; the other T1s and everything else come from packs
local STARTERS = { "Snake", "Dirt_Snake", "Garter_Snake", "Mud_Snake", "Grass_Snake", "Brown_Snake", "Pale_Snake", "Coral_Snake" }

local owned, last_pack = {}, "-"

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
		owned[lines[i]] = true
	end
end

-- Wipes progress back to a new game (settings are kept)
function collection.reset()
	unlocked, collection.unlock_all, last_pack, owned = 1, false, "-", {}
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

-- The snakes the player draws their hand from
function collection.deck()
	local deck = {}
	for _, name in ipairs(data.deck) do
		if collection.has(name) then
			table.insert(deck, name)
		end
	end
	return deck
end

local function stat(name, field)
	local stats = data.get_stats({ card_path = name .. ".png" })
	return stats and stats[field] or 0
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
	end
	last_pack = today()
	collection.save()
	return pulled
end

return collection
