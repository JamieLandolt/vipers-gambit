-- Snake abilities. A card's ability_code is "kind:arg:arg", several joined with "|".
--   Activated (pay venom, once per turn): strike:N:C  heal:N:C  shield:N:C  empower:N:C  drain:N:C  bolster:N:C  refresh:1:C
--   Passive combos: pack:N  adj:Type:N  lone:N  first:N  lane:Type:N  guard:N  armor:N  thorns:N
-- N is the strength and C the venom cost. Rules live here; Play.lua applies them and shows the effects.
local abilities = {}

local ACTIVE = { strike = true, heal = true, shield = true, empower = true, drain = true, bolster = true, refresh = true }

local DESCRIPTIONS = {
	strike = function(a) return ("Pay %d venom: hit the card ahead for %d"):format(a[2], a[1]) end,
	heal = function(a) return ("Pay %d venom: restore %d health"):format(a[2], a[1]) end,
	shield = function(a) return ("Pay %d venom: gain a %d point shield"):format(a[2], a[1]) end,
	empower = function(a) return ("Pay %d venom: +%d attack for good"):format(a[2], a[1]) end,
	drain = function(a) return ("Pay %d venom: hit the card ahead for %d and heal that much"):format(a[2], a[1]) end,
	bolster = function(a) return ("Pay %d venom: neighbours get +%d attack this turn"):format(a[2], a[1]) end,
	refresh = function(a) return ("Pay %d venom: your other snakes can use their abilities again this turn"):format(a[2]) end,
	pack = function(a) return ("+%d attack for each other snake you have"):format(a[1]) end,
	adj = function(a) return ("+%d attack next to %s"):format(a[2], a[1] == "Any" and "any snake" or ("a " .. a[1] .. " snake")) end,
	lone = function(a) return ("+%d attack with no neighbours"):format(a[1]) end,
	first = function(a) return ("+%d attack the turn it is played"):format(a[1]) end,
	lane = function(a) return ("+%d attack in a %s lane"):format(a[2], a[1]) end,
	guard = function(a) return ("Neighbours take %d less damage"):format(a[1]) end,
	armor = function(a) return ("Takes %d less damage"):format(a[1]) end,
	thorns = function(a) return ("Attackers take %d damage"):format(a[1]) end,
}

local cache = {}

local function parse(code)
	if not code then
		return {}
	end
	if not cache[code] then
		local list = {}
		for part in code:gmatch("[^|]+") do
			local args = {}
			for arg in part:gmatch("[^:]+") do
				table.insert(args, tonumber(arg) or arg)
			end
			table.insert(list, { kind = table.remove(args, 1), args = args })
		end
		cache[code] = list
	end
	return cache[code]
end

function abilities.of(card)
	return parse(require("CardData").get_stats(card).ability_code)
end

function abilities.describe(code)
	local parts = {}
	for _, ab in ipairs(parse(code)) do
		table.insert(parts, DESCRIPTIONS[ab.kind](ab.args))
	end
	return table.concat(parts, " / ")
end

-- Friendly cards in the neighbouring columns of the same row
function abilities.neighbours(slot)
	local base, col, found = slot <= 4 and 0 or 4, (slot - 1) % 4 + 1, {}
	for _, c in ipairs({ col - 1, col + 1 }) do
		if c >= 1 and c <= 4 and played_cards[base + c] then
			table.insert(found, { card = played_cards[base + c], slot = base + c })
		end
	end
	return found
end

local function friends_on_field(slot)
	local count = 0
	for s = slot <= 4 and 1 or 5, slot <= 4 and 4 or 8 do
		count = count + (played_cards[s] and 1 or 0)
	end
	return count
end

-- Attack after permanent growth, this turn's boosts and passive combos
function abilities.attack(card, slot)
	local data = require("CardData")
	local total = data.get_stats(card).attack + (card.bonus or 0) + (card.temp or 0)
	local friends = abilities.neighbours(slot)
	for _, ab in ipairs(abilities.of(card)) do
		local k, a, b = ab.kind, ab.args[1], ab.args[2]
		if k == "pack" then
			total = total + a * (friends_on_field(slot) - 1)
		elseif k == "adj" then
			for _, f in ipairs(friends) do
				if a == "Any" or data.get_type(f.card) == a then
					total = total + b
					break
				end
			end
		elseif k == "lone" and #friends == 0 then
			total = total + a
		elseif k == "first" and card.fresh then
			total = total + a
		elseif k == "lane" and require("Play").lane_types[(slot - 1) % 4 + 1][a] then
			total = total + b
		end
	end
	local ahead = played_cards[slot > 4 and slot - 4 or slot + 4]
	if ahead and ahead.brew == "smoke" then -- the enemy snake opposite drank a Smoke Draught: its smoke covers this lane
		total = total - 2
	end
	return math.max(total + require("Powers").attack_bonus(card, slot), 0)
end

-- Damage that gets through armor, guards, shields and the Shadow border's free dodge
function abilities.mitigate(defender, slot, damage)
	if defender.brew == "phase" and not defender.phased then
		defender.phased = true
		return 0
	end
	damage = require("Powers").reduce(defender, slot, damage)
	if defender.brew == "stone" or require("CardData").border_of(defender) == "Stone" then
		damage = math.max(damage - 2, 1)
	end
	if defender.brew == "adamant" then
		damage = math.max(damage - 4, 1)
	end
	for _, ab in ipairs(abilities.of(defender)) do
		if ab.kind == "armor" then
			damage = math.max(damage - ab.args[1], 1)
		end
	end
	for _, f in ipairs(abilities.neighbours(slot)) do
		for _, ab in ipairs(abilities.of(f.card)) do
			if ab.kind == "guard" then
				damage = math.max(damage - ab.args[1], 1)
			end
		end
	end
	local soak = math.min(defender.shield or 0, damage)
	defender.shield = (defender.shield or 0) - soak
	return damage - soak
end

function abilities.thorns(card)
	local total = card.brew == "thorn" and 2 or 0
	for _, ab in ipairs(abilities.of(card)) do
		if ab.kind == "thorns" then
			total = total + ab.args[1]
		end
	end
	return total
end

function abilities.active(card)
	for _, ab in ipairs(abilities.of(card)) do
		if ACTIVE[ab.kind] then
			return ab
		end
	end
end

-- Can this card's activated ability be used right now?
function abilities.ready(card, side)
	local ab = abilities.active(card)
	if not ab or card.used or venom[side] < ab.args[2] then
		return false
	end
	if ab.kind == "refresh" then -- only worth using once another snake of yours has spent its ability
		for slot = side == "Player" and 5 or 1, side == "Player" and 8 or 4 do
			local other = played_cards[slot]
			if other and other ~= card and other.used then
				return true
			end
		end
		return false
	end
	local defense = require("CardData").get_stats(card).defense
	return ab.kind ~= "heal" or (card.hp or defense) < defense
end

local POOLS = {
	Land = { "strike", "pack", "bolster", "first", "lone" },
	Water = { "heal", "drain", "lane:Water", "armor", "adj:Water" },
	Tree = { "first", "adj:Tree", "guard", "heal", "pack" },
	Spirit = { "thorns", "drain", "shield", "adj:Spirit", "strike" },
	Rainbow = { "empower", "bolster", "adj:Any", "lone", "heal" },
}

-- Strength and venom cost per tier (1-5), tuned with tools/sim.lua so every kind is worth about the same.
-- Activated abilities are { strength, cost } pairs; passives are just the strength.
local STRIKE = { { 1, 2 }, { 2, 1 }, { 6, 1 }, { 10, 2 }, { 9, 2 } }
local DRAIN = { { 1, 4 }, { 2, 2 }, { 6, 2 }, { 8, 2 }, { 10, 3 } }
local HEAL = { { 2, 1 }, { 5, 1 }, { 11, 1 }, { 14, 1 }, { 24, 2 } }
local SHIELD = { { 1, 1 }, { 3, 1 }, { 9, 1 }, { 13, 1 }, { 15, 2 } }
local EMPOWER = { { 1, 5 }, { 2, 2 }, { 3, 2 }, { 7, 2 }, { 5, 3 } }
local BOLSTER = { { 1, 4 }, { 2, 1 }, { 3, 1 }, { 8, 2 }, { 8, 2 } }
local PACK = { 1, 1, 1, 2, 2 }
local FIRST = { 1, 3, 3, 4, 4 }
local LONE = { 3, 3, 4, 4, 6 }
local LANE = { 1, 1, 2, 3, 3 }
local ADJ = { 1, 2, 5, 6, 6 }
local ARMOR = { 1, 1, 2, 3, 4 }
local GUARD = { 1, 1, 3, 4, 5 }
local THORNS = { 1, 1, 2, 3, 4 }

local function build(kind, t)
	local function act(kind, row) return ("%s:%d:%d"):format(kind, row[t][1], row[t][2]) end
	local name, arg = kind:match("^(%a+):(%a+)$")
	if name == "lane" then
		return "lane:" .. arg .. ":" .. LANE[t]
	elseif name == "adj" then
		return "adj:" .. arg .. ":" .. ADJ[t]
	end
	local codes = {
		strike = act("strike", STRIKE), drain = act("drain", DRAIN), heal = act("heal", HEAL),
		shield = act("shield", SHIELD), empower = act("empower", EMPOWER), bolster = act("bolster", BOLSTER),
		pack = t == 1 and "lone:3" or "pack:" .. PACK[t], first = "first:" .. FIRST[t], lone = "lone:" .. LONE[t],
		armor = "armor:" .. ARMOR[t], guard = "guard:" .. GUARD[t], thorns = "thorns:" .. THORNS[t],
	}
	return codes[kind]
end

abilities.build = build -- exposed for tools/sim.lua

-- Every snake gets an ability that suits its type; the same name always gets the same one
function abilities.assign(name, snake_type, tier)
	local hash = 0
	for i = 1, #name do
		hash = (hash * 31 + name:byte(i)) % 1000003
	end
	local pool = POOLS[snake_type]
	return build(pool[hash % #pool + 1], tier)
end

return abilities
