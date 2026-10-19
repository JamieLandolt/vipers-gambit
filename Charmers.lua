local love = require("love")

-- Charmers: each has one charm, used for `cost` venom at most once a turn and then not again for `cooldown` of its owner's turns (Play.use_charm).
-- apply(play, side) does the effect and returns false if it would do nothing (then it costs nothing).
-- The chosen charmer is the global chosen_avatar; each campaign level's opponent has its own, below.
-- (CardData and Abilities are required lazily: Assets loads this file for the portraits)
local charmers = {}

local function foe(side)
	return side == "Player" and "Opponent" or "Player"
end

-- Occupied slots of a side as a list of { slot, card }
local function snakes(side)
	local found = {}
	for slot = side == "Player" and 5 or 1, side == "Player" and 8 or 4 do
		if played_cards[slot] then
			table.insert(found, { slot, played_cards[slot] })
		end
	end
	return found
end

-- Runs fn(slot, card) on every snake of a side; true if there were any
local function each(side, fn)
	local list = snakes(side)
	for _, s in ipairs(list) do
		fn(s[1], s[2])
	end
	return #list > 0
end

local function defense(card)
	return require("CardData").get_stats(card).defense
end

charmers.list = {
	{ name = "Yuki Frostveil", portrait = "yuki.png", charm = "Frost Flute", cooldown = 1, cost = 3, text = "Freeze the strongest enemy snake.",
		apply = function(play, side)
			local best, best_slot, best_attack = nil, nil, -1
			each(foe(side), function(slot, card)
				local attack = require("Abilities").attack(card, slot)
				if attack > best_attack then
					best, best_slot, best_attack = card, slot, attack
				end
			end)
			if best then
				best.frozen = true
				play.float(best_slot, "frozen")
			end
			return best ~= nil
		end },
	{ name = "Dr. Fang", portrait = "fang.png", charm = "Venom Surge", cooldown = 2, cost = 1, text = "Pay 1 venom, gain 4.",
		apply = function(play, side)
			if venom[side] >= play.MAX_VENOM then
				return false
			end
			venom[side] = math.min(venom[side] + 4, play.MAX_VENOM)
			play.float_bar(side, "+4 venom")
			return true
		end },
	{ name = "Tide Priestess", portrait = "tide.png", charm = "Tidal Wave", cooldown = 2, cost = 3, text = "2 damage to every enemy snake.",
		apply = function(play, side)
			return each(foe(side), function(slot) play.wound(slot, 2) end)
		end },
	{ name = "Ember Queen", portrait = "ember.png", charm = "Cinder Blessing", cooldown = 3, cost = 4, text = "All your snakes gain 1 attack for good.",
		apply = function(play, side)
			return each(side, function(slot, card)
				card.bonus = (card.bonus or 0) + 1
				play.float(slot, "+1 atk")
			end)
		end },
	{ name = "Warden Basalt", portrait = "basalt.png", charm = "Granite Heart", cooldown = 3, cost = 3, text = "Heal your charmer for 8.",
		apply = function(play, side)
			if health[side] >= max_health[side] then
				return false
			end
			health[side] = math.min(health[side] + 8, max_health[side])
			play.float_bar(side, "+8 health")
			return true
		end },
}

-- The first charmer is open from the start; each later one opens once the region before it has been beaten
function charmers.region_needed(i)
	return require("LevelNodes").regions[i - 1].name
end

function charmers.is_unlocked(i)
	return i <= 1 or require("Collection").unlock_all or unlocked > (i - 1) * require("LevelNodes").per_region
end

charmers.by_name = {}
for _, c in ipairs(charmers.list) do
	charmers.by_name[c.name] = c
end

-- The charmer (and so the charm) an opponent fights with comes from its entry in Opponents.lua
function charmers.of(side, level)
	local name = chosen_avatar
	if side ~= "Player" then
		local opponent = require("Opponents")[level]
		name = versus_charmer or (opponent and opponent.charmer)
	end
	return charmers.by_name[name] or charmers.list[1]
end

-- Looks: a charmer with files <base>_1.png .. <base>_4.png (and stand_<base>_N.png) lets the player pick which one to use
charmers.skin = {} -- name -> chosen look (1 when not picked)

function charmers.skin_count(c)
	local base, n = c.portrait:gsub("%..+$", ""), 0
	while love.filesystem.getInfo("assets/characters/" .. base .. "_" .. (n + 1) .. ".png") do
		n = n + 1
	end
	return n
end

-- The portrait (or standing cut-out) file for a charmer's chosen look
function charmers.file(c, stand)
	local base, n = c.portrait:gsub("%..+$", ""), charmers.skin[c.name]
	local file = "assets/characters/" .. (stand and "stand_" or "") .. base .. (n and n > 1 and "_" .. n or "") .. ".png" -- (look 1 is the default file)
	if stand and not love.filesystem.getInfo(file) then
		return "assets/characters/" .. base .. ".png" -- no standing cut-out: use the portrait
	end
	return file
end

function charmers.set_skin(name, n)
	charmers.skin[name] = n
	require("Assets").avatars[name] = love.graphics.newImage(charmers.file(charmers.by_name[name]))
	charmers.save()
end

-- The player's pick is remembered in its own file so save.txt keeps its format: the charmer, then "name=look" lines
function charmers.save()
	local lines = { chosen_avatar }
	for name, n in pairs(charmers.skin) do
		lines[#lines + 1] = name .. "=" .. n
	end
	love.filesystem.write("charmer.txt", table.concat(lines, "\n"))
end

-- Every charmer can be chosen
charmers.PICKABLE = #charmers.list

function charmers.load()
	local text = love.filesystem.read("charmer.txt") or ""
	local saved = text:match("^[^\n]+")
	for name, n in text:gmatch("\n([^=\n]+)=(%d)") do
		local c = charmers.by_name[name]
		if c and tonumber(n) <= charmers.skin_count(c) then
			charmers.skin[name] = tonumber(n)
			require("Assets").avatars[name] = love.graphics.newImage(charmers.file(c))
		end
	end
	chosen_avatar = charmers.list[1].name
	for i = 1, charmers.PICKABLE do
		if charmers.list[i].name == saved then
			chosen_avatar = saved
		end
	end
end

return charmers
