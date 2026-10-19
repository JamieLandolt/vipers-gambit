local love = require("love")

-- Achievements are goals on a few counters, saved as stat=number lines in achievements.txt.
-- ach.add / ach.set raise a counter; an achievement pops up (ach.toast) the moment its goal is reached.
local ach = { stats = {}, queue = {}, toast = nil }

-- { id, name, description, counter, goal, reward pack (1 Serpent, 2 Support, 3 Elite) }
ach.list = {
	{ "first_win", "First Blood", "Win a match", "wins", 1, 1 },
	{ "wins_10", "Veteran", "Win 10 matches", "wins", 10, 1 },
	{ "level_10", "Halfway There", "Beat the 10th opponent", "best_level", 10, 1 },
	{ "level_20", "Viper King", "Beat the final opponent", "best_level", 18, 3 },
	{ "challenge_1", "Challenger", "Complete a challenge", "challenges", 1, 1 },
	{ "challenge_5", "Daredevil", "Complete 5 challenges", "challenges", 5, 3 },
	{ "kills_50", "Snake Slayer", "Defeat 50 snakes", "kills", 50, 1 },
	{ "brews_5", "Brewmaster", "Drink 5 brews", "brews", 5, 2 },
	{ "spells_5", "Spellcaster", "Cast 5 spells", "spells", 5, 2 },
	{ "packs_10", "Pack Rat", "Open 10 packs", "packs", 10, 2 },
	{ "owned_25", "Collector", "Own 25 different snakes", "owned", 25, 1 },
	{ "owned_75", "Curator", "Own 75 different snakes", "owned", 75, 3 },
	{ "imbue", "Imbued", "Imbue a snake with a new border", "imbues", 1, 2 },
	{ "rematch", "Rematch", "Beat the same opponent 3 times", "rival_wins", 3, 1 },
	{ "nemesis", "Nemesis", "Beat the same opponent 10 times", "rival_wins", 10, 3 },
	{ "endless_5", "Unending", "Win 5 endless rematches", "endless", 5, 3 },
	{ "flawless", "Untouched", "Win a match without losing a snake", "flawless", 1, 3 },
}

ach.PACK_NAMES = { "Serpent Pack", "Support Pack", "Elite Pack" }

function ach.load()
	for k, v in (love.filesystem.read("achievements.txt") or ""):gmatch("(%w+)=(%d+)") do
		ach.stats[k] = tonumber(v)
	end
end

local function save()
	local lines = {}
	for k, v in pairs(ach.stats) do
		lines[#lines + 1] = k .. "=" .. v
	end
	love.filesystem.write("achievements.txt", table.concat(lines, "\n"))
end

function ach.set(counter, value)
	if require("Collection").unlock_all then -- the testing override must not hand out reward packs
		return
	end
	local old = ach.stats[counter] or 0
	if value <= old then
		return
	end
	ach.stats[counter] = value
	for _, a in ipairs(ach.list) do
		if a[4] == counter and old < a[5] and value >= a[5] then
			table.insert(ach.queue, a)
			require("Collection").give_pack(a[6])
		end
	end
	save()
end

function ach.add(counter, n)
	ach.set(counter, (ach.stats[counter] or 0) + (n or 1))
end

function ach.progress(a)
	return math.min(ach.stats[a[4]] or 0, a[5]), a[5]
end

function ach.count()
	local n = 0
	for _, a in ipairs(ach.list) do
		if (ach.stats[a[4]] or 0) >= a[5] then
			n = n + 1
		end
	end
	return n
end

-- The banner to draw now (each shows for 3.5 seconds), or nil
function ach.current()
	if not ach.toast and ach.queue[1] then
		ach.toast = { a = table.remove(ach.queue, 1), t = time }
		require("Sounds").play("achievement")
	end
	if ach.toast and time - ach.toast.t > 3.5 then
		ach.toast = nil
	end
	return ach.toast
end

function ach.reset()
	ach.stats, ach.queue, ach.toast = {}, {}, nil
	love.filesystem.remove("achievements.txt")
end

return ach
