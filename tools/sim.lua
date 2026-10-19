-- Headless balance simulator. Run from the project root:  luajit tools/sim.lua
--   (default)      bot player vs each level's AI: win rate, match length, stalemates
--   MODE=matrix    ability power: win-rate contribution of each ability kind x tier (mirror decks)
--   N=<games>      games per cell (default 300 for levels, 600 for matrix)
--   ALL=1          level mode: the player's deck is every card instead of the starter deck
--   EXTRA=<n>      level mode: the starter deck plus n random other snakes (opened packs)
--   PROGRESS=<n>   level mode: at level L the player owns the starters plus n*L random snakes and plays the best 20 of them
--   LEVELS=a,b,c   level mode: only these levels (e.g. LEVELS=9,12)
--   MODE=chal      each level's challenge (TIER=1-3, default 1) vs the plain level (with PROGRESS): win rates and a suggested reward multiplier
--   FRAC=<0-1>     matrix mode: share of a deck's snakes that carry the ability (default 0.5)
package.path = "./?.lua;" .. package.path
package.preload["love"] = function() return { graphics = {}, mouse = {}, filesystem = { write = function() end, getInfo = function() end } } end
package.preload["Effects"] = function() return { add = function() end, clear = function() end, shake = function() end } end
package.preload["Achievements"] = function() return { add = function() end, set = function() end } end
package.preload["Card"] = function() return function(p) return { card_path = p } end end
local data = require("CardData")
local abilities = require("Abilities")
local SUPPORTS = {}
for i = #data.deck, 1, -1 do -- the deck pool is snakes only; brews and spells are added to the bot's deck by SUPPORT=<n> (default 0)
	if data.stats_by_name[data.deck[i]].kind ~= "snake" then table.insert(SUPPORTS, table.remove(data.deck, i)) end
end
local STARTERS = { "Sand_Snake", "Dirt_Snake", "Garter_Snake", "Mud_Snake", "Grass_Snake", "Brown_Snake", "Pale_Snake", "Coral_Snake" }
local player_deck = os.getenv("ALL") and data.deck or STARTERS
if os.getenv("EXTRA") then -- starters plus N random other snakes: a player who has opened some packs
	math.randomseed(7)
	player_deck = { unpack(STARTERS) }
	local owned, pool = {}, {}
	for _, name in ipairs(STARTERS) do owned[name] = true end
	for _, name in ipairs(data.deck) do
		if not owned[name] then pool[#pool + 1] = name end
	end
	for _ = 1, tonumber(os.getenv("EXTRA")) do player_deck[#player_deck + 1] = table.remove(pool, math.random(#pool)) end
end
package.preload["Collection"] = function() return { deck = function() return player_deck end, save = function() end, mark_hint = function() end, reward = function() return 0 end, record_win = function() end, beaten_base = function() return true end, challenges_done = function() return 0 end, endless = function() return 0 end, wins = function() return 0 end } end
function contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function update_game_state(s) state = s end
function play_sound() end
img_widths, img_heights = 1, 1
unlocked = 1
local play, opponents = require("Play"), require("Opponents")
chosen_avatar = os.getenv("CHARMER") or require("Charmers").list[1].name
local TURN_CAP = 200

-- One side's scripted turn: spend venom on the best-scoring snakes, then on abilities
local W = { attack = 1, defense = 1, cost = 0.5, block = 2, open = 1 }
local function bot_turn(side)
	local base, ahead = side == "Player" and 4 or 0, side == "Player" and -4 or 4
	local hand = side == "Player" and player_hand or opponent_hand
	while play.use_support(side) do end
	while true do
		local best, bi, bslot = -1e9
		for i, c in ipairs(hand) do
			local st = data.get_stats(c)
			if st.cost <= venom[side] then
				for slot = base + 1, base + 4 do
					if not played_cards[slot] and play.lane_accepts(c, slot) then
						local sc = W.attack * st.attack + W.defense * st.defense + W.cost * st.cost
							+ (played_cards[slot + ahead] and W.block or W.open) + math.random()
						if sc > best then best, bi, bslot = sc, i, slot end
					end
				end
			end
		end
		if not bi then break end
		local c = table.remove(hand, bi)
		venom[side] = venom[side] - data.get_stats(c).cost
		played_cards[bslot] = c
		played_cards[bslot].fresh = true
	end
	for slot = base + 1, base + 4 do
		local c = played_cards[slot]
		if c and not os.getenv('NOACT') and abilities.ready(c, side) then
			local ab = abilities.active(c)
			if ab.kind ~= "bolster" or #abilities.neighbours(slot) > 0 then
				play.activate(slot)
			end
		end
	end
	if os.getenv("CHARMER") and side == "Player" then -- CHARMER=<name>: the bot player also uses that charmer's charm each turn
		play.use_charm(side)
	end
end

-- Plays one match. kind of each side: "bot" or "ai" (the game's own opponent AI). Returns winner, turns.
local function match(level, opp_kind, challenge)
	state = nil
	play.new_game(level, challenge)
	local turns = 0
	while state ~= "ended" and turns < TURN_CAP do
		turns = turns + 1
		if turn == "Player" then
			bot_turn("Player")
			if state ~= "ended" then play.end_turn() end
		elseif opp_kind == "ai" then
			repeat
				local before = turns
				play.opponent_turn(1)
			until turn == "Player" or state == "ended"
		else
			bot_turn("Opponent")
			if state ~= "ended" then play.end_turn() end
		end
	end
	return state == "ended" and winner or nil, turns
end

local N = tonumber(os.getenv("N"))

-- A player with a growing collection: the starters plus `per_level` random snakes a level, deck = the best 20 by stats per cost
local function progress_deck(level, per_level)
	local owned, pool = { unpack(STARTERS) }, {}
	local have = {}
	for _, name in ipairs(STARTERS) do have[name] = true end
	for _, name in ipairs(data.deck) do
		if not have[name] then pool[#pool + 1] = name end
	end
	for _ = 1, math.min(#pool, math.floor(per_level * level + 0.5)) do owned[#owned + 1] = table.remove(pool, math.random(#pool)) end
	local function value(name)
		local st = data.stats_by_name[name]
		return (st.attack + 0.6 * st.defense) / math.sqrt(st.cost + 1)
	end
	table.sort(owned, function(a, b) return value(a) > value(b) end)
	local deck = {}
	for i = 1, math.min(20, #owned) do deck[i] = owned[i] end
	for i = 1, tonumber(os.getenv("SUPPORT")) or 0 do -- a couple of brews or spells (random, up to tier 3) in place of the weakest snakes
		local pick = SUPPORTS[math.random(#SUPPORTS)]
		if data.stats_by_name[pick].rarity <= 3 and not contains(deck, pick) and #deck > 2 then deck[#deck + 1 - i] = pick end
	end
	return deck
end

if os.getenv("MODE") == "chal" then
	N = N or 300
	math.randomseed(5)
	local per_level = tonumber(os.getenv("PROGRESS")) or 2.5
	local challenges = require("Challenges")
	local only = {}
	for l in (os.getenv("LEVELS") or ""):gmatch("%d+") do only[tonumber(l)] = true end
	for level = 1, #opponents do
	if not next(only) or only[level] then
		local base, hard = 0, 0
		for _ = 1, N do
			player_deck = progress_deck(level, per_level)
			base = base + (match(level, "ai") == "Player" and 1 or 0)
			hard = hard + (match(level, "ai", challenges[level][tonumber(os.getenv("TIER")) or 1]) == "Player" and 1 or 0)
		end
		base, hard = 100 * base / N, 100 * hard / N
		local suggest = hard <= 0 and 5 or math.max(1.25, math.min(5, math.floor(base / hard * 4 + 0.5) / 4))
		print(("%d\t%s\tbase %d%%\tchallenge %d%%\tmult %s (now %s)"):format(level, challenges[level][tonumber(os.getenv("TIER")) or 1].name, base, hard, suggest, challenges[level][tonumber(os.getenv("TIER")) or 1].mult))
	end
	end
	return
end

if os.getenv("MODE") == "search" then
	-- Random search for a level's deck: tries CANDS random decks (rarity within a window around the level, deck size 6-7) and
	-- starting venoms, keeps the one whose win rate is closest to the line from WIN_FIRST to WIN_LAST, and prints it.
	-- MODE=search LEVELS=17,18 PROGRESS=3.5 luajit tools/sim.lua
	local first, last = tonumber(os.getenv("WIN_FIRST")) or 88, tonumber(os.getenv("WIN_LAST")) or 40
	local per_level, cands, quick = tonumber(os.getenv("PROGRESS")) or 3.5, tonumber(os.getenv("CANDS")) or 200, 80
	math.randomseed(21)
	for l in (os.getenv("LEVELS") or ""):gmatch("%d+") do
		local level = tonumber(l)
		local target = first + (last - first) * (level - 1) / (#opponents - 1)
		local lo, hi = math.max(1, math.ceil(level / 5) - 2), math.min(5, math.ceil(level / 4) + 1)
		local pool = {}
		for _, name in ipairs(data.deck) do
			local r = data.stats_by_name[name].rarity
			if r >= lo and r <= hi then pool[#pool + 1] = name end
		end
		local function rate(n)
			local wins = 0
			for _ = 1, n do
				player_deck = progress_deck(level, per_level)
				wins = wins + (match(level, "ai") == "Player" and 1 or 0)
			end
			return 100 * wins / n
		end
		local o = opponents[level]
		local scored = {}
		for _ = 1, cands do
			local deck, used = {}, {}
			for _ = 1, 6 + math.random(0, 1) do
				local pick
				repeat pick = pool[math.random(#pool)] until not used[pick]
				used[pick] = true
				deck[#deck + 1] = pick
			end
			o.deck, o.venom = deck, math.random(0, 3)
			scored[#scored + 1] = { deck = deck, venom = o.venom, w = rate(quick) }
		end
		table.sort(scored, function(a, b) return math.abs(a.w - target) < math.abs(b.w - target) end)
		local best, best_gap = nil, 1e9
		for i = 1, math.min(4, #scored) do -- re-test the closest few with more games
			o.deck, o.venom = scored[i].deck, scored[i].venom
			local w = rate(300)
			if math.abs(w - target) < best_gap then best, best_gap = { deck = scored[i].deck, venom = scored[i].venom, w = w }, math.abs(w - target) end
		end
		print(("%d\t%s\tvenom %d\twin %d%% (target %d)\t{ \"%s\" }"):format(level, o.name, best.venom, best.w, target, table.concat(best.deck, "\", \"")))
	end
	return
end

if os.getenv("MODE") == "theme" then
	-- Builds each level's deck from a themed pool (a lane type, a border or name words, plus the opponent's own brews and spells)
	-- and picks the deck and starting venom whose win rate (with PROGRESS) is closest to the WIN_FIRST..WIN_LAST line.
	-- Prints Opponents.lua-style lines. Run:  MODE=theme PROGRESS=3.5 LEVELS=8,9 luajit tools/sim.lua
	N = N or 60
	math.randomseed(11)
	local first, last = tonumber(os.getenv("WIN_FIRST")) or 88, tonumber(os.getenv("WIN_LAST")) or 40
	local per_level = tonumber(os.getenv("PROGRESS")) or 3.5
	local THEMES = { -- level = { type, border, name words, supports }
		[4] = { type = "Land", sup = { "Stoneskin_Tonic" } }, [5] = { border = "Venom", sup = { "Rage_Draught" } },
		[6] = { type = "Spirit", sup = { "Ghost_Tonic" } }, [7] = { type = "Tree", sup = { "Regrowth_Brew" } },
		[8] = { type = "Rainbow", sup = { "Rage_Draught", "Arcane_Insight" } }, [9] = { border = "Venom", sup = { "Venom_Elixir", "Stoneskin_Tonic" } },
		[10] = { type = "Water", sup = { "Healing_Rain", "Regrowth_Brew" } }, [11] = { type = "Water", border = "Frost", sup = { "Frostbrew", "Frost_Nova" } },
		[12] = { words = "Boa Python Constrictor Basalt Stone", sup = { "Guardian_Ward", "Stoneskin_Tonic" } },
		[13] = { type = "Spirit", sup = { "Smoke_Draught", "Ghost_Tonic" } }, [14] = { border = "Fire", sup = { "Rage_Draught", "Lightning_Storm" } },
		[15] = { border = "Fire", sup = { "Lightning_Storm", "Rage_Draught" } }, [16] = { words = "Cobra Adder", sup = { "Smoke_Draught", "Arcane_Insight" } },
		[17] = { border = "Shadow", sup = { "Frost_Nova", "Ghost_Tonic" } }, [18] = { border = "Gold", sup = { "Guardian_Ward", "Stoneskin_Tonic" } },
		[19] = { type = "Tree", sup = { "Venom_Elixir", "Regrowth_Brew" } }, [20] = { words = "Viper Wyrm Serpent Nagaraja", sup = { "Meteor_Strike", "Frost_Nova" } },
	}
	local fillers = {}
	for _, name in ipairs(data.deck) do
		if data.stats_by_name[name].rarity == 1 then fillers[#fillers + 1] = name end
	end
	local only = {}
	for l in (os.getenv("LEVELS") or ""):gmatch("%d+") do only[tonumber(l)] = true end
	local function rate(level, n)
		local wins = 0
		for _ = 1, n do
			player_deck = progress_deck(level, per_level)
			wins = wins + (match(level, "ai") == "Player" and 1 or 0)
		end
		return 100 * wins / n
	end
	for level = 4, #opponents do
	local th = THEMES[level]
	if th and (not next(only) or only[level]) then
		local pool = {}
		for _, name in ipairs(data.deck) do
			local st, r = data.stats_by_name[name], data.stats_by_name[name].rarity
			local hit = (th.type and data.card_types[name] == th.type) or (th.border and st.border == th.border)
			for word in (th.words or ""):gmatch("%S+") do hit = hit or name:find(word) end
			if hit and r <= math.ceil(level / 4) + 1 and st.cost <= 6 then pool[#pool + 1] = name end
		end
		local target, best, best_gap = first + (last - first) * (level - 1) / (#opponents - 1)
		local o = opponents[level]
		for _ = 1, 150 do
			local deck, used = {}, {}
			for _ = 1, math.random(2, 4) do
				local pick = pool[math.random(#pool)]
				if not used[pick] then used[pick] = true; deck[#deck + 1] = pick end
			end
			for _ = 1, math.random(2, 3) do -- cheap filler so late decks can be weak enough (the opponent's health does the climbing)
				local pick = fillers[math.random(#fillers)]
				if not used[pick] then used[pick] = true; deck[#deck + 1] = pick end
			end
			for i = 1, math.random(1, #th.sup) do deck[#deck + 1] = th.sup[i] end
			if #deck >= 6 then
				o.deck, o.venom = deck, math.random(0, 4)
				local w = rate(level, N)
				if math.abs(w - target) < (best_gap or 1e9) then best, best_gap = { deck = deck, venom = o.venom, w = w }, math.abs(w - target) end
			end
		end
		o.deck, o.venom = best.deck, best.venom
		local w = rate(level, 200)
		print(("%d\t%s\tvenom %d\twin %d%% (target %d)\t{ \"%s\" }"):format(level, o.name, best.venom, w, target, table.concat(best.deck, "\", \"")))
	end
	end
	return
end

if os.getenv("MODE") == "venom" then
	-- Keeps every deck as written and picks each level's starting venom (0-8) whose win rate (with PROGRESS) is closest to the
	-- WIN_FIRST..WIN_LAST line; prints "level venom win%". Run:  MODE=venom PROGRESS=3.5 luajit tools/sim.lua
	N = N or 150
	math.randomseed(3)
	local first, last = tonumber(os.getenv("WIN_FIRST")) or 88, tonumber(os.getenv("WIN_LAST")) or 40
	local per_level = tonumber(os.getenv("PROGRESS")) or 2.5
	local only = {}
	for l in (os.getenv("LEVELS") or ""):gmatch("%d+") do only[tonumber(l)] = true end
	for level = 1, #opponents do
	if not next(only) or only[level] then
		if os.getenv("DECK") then -- DECK=a,b,c with a single LEVELS value: try that deck
			opponents[level].deck = {}
			for name in os.getenv("DECK"):gmatch("[^,]+") do table.insert(opponents[level].deck, name) end
		end
		local target, best, best_gap, best_w = first + (last - first) * (level - 1) / (#opponents - 1)
		for v = 0, 8 do
			opponents[level].venom = v
			local wins = 0
			for _ = 1, N do
				player_deck = progress_deck(level, per_level)
				wins = wins + (match(level, "ai") == "Player" and 1 or 0)
			end
			local w = 100 * wins / N
			if not best_gap or math.abs(w - target) < best_gap then best, best_gap, best_w = v, math.abs(w - target), w end
		end
		print(("%d\t%d\t%d%% (target %d)"):format(level, best, best_w, target))
	end
	end
	return
end

if os.getenv("MODE") == "tune" then
	-- Adjusts each level's opponent deck and starting venom until the bot's win rate (with PROGRESS) follows a line from
	-- WIN_FIRST% at level 1 to WIN_LAST% at the last level; prints Opponents.lua-style lines. Run:  MODE=tune PROGRESS=2.5 luajit tools/sim.lua
	N = N or 150
	math.randomseed(3)
	local first, last = tonumber(os.getenv("WIN_FIRST")) or 88, tonumber(os.getenv("WIN_LAST")) or 40
	local per_level = tonumber(os.getenv("PROGRESS")) or 2.5
	local function power(name)
		local st = data.stats_by_name[name]
		return st.attack + 0.5 * st.defense + 0.3 * st.cost
	end
	local by_type = {}
	for _, name in ipairs(data.deck) do
		local t = data.card_types[name]
		by_type[t] = by_type[t] or {}
		table.insert(by_type[t], name)
	end
	for _, list in pairs(by_type) do table.sort(list, function(a, b) return power(a) < power(b) end) end
	local function rate(level)
		local wins = 0
		for _ = 1, N do
			player_deck = progress_deck(level, per_level)
			wins = wins + (match(level, "ai") == "Player" and 1 or 0)
		end
		return 100 * wins / N
	end
	local level_now = 1
	local function allowed(name) -- keeps late decks from filling with hatchlings and early ones from using legendaries
		local r = data.stats_by_name[name].rarity
		return r >= math.max(1, math.ceil(level_now / 5) - 1) and r <= math.ceil(level_now / 4) + 1
	end
	local function shift(deck, dir) -- swaps the weakest (dir 1) or strongest (dir -1) snake for its neighbour in power order within its type
		local order = {}
		for i, name in ipairs(deck) do order[i] = i end
		table.sort(order, function(a, b) return power(deck[a]) < power(deck[b]) end)
		for _, i in ipairs(dir == 1 and order or { unpack(order, 1) }) do
			local list = by_type[data.card_types[deck[i]]] or {}
			for k, name in ipairs(list) do
				if name == deck[i] then
					local step = list[k + dir]
					if step and not contains(deck, step) and allowed(step) then deck[i] = step return true end
				end
			end
		end
		return false
	end
	for level = 1, #opponents do
		local target = first + (last - first) * (level - 1) / (#opponents - 1)
		local o = opponents[level]
		level_now = level
		local best, best_gap = nil, 1e9
		for _ = 1, 24 do
			local w = rate(level)
			local gap = math.abs(w - target)
			if gap < best_gap then best, best_gap = { deck = { unpack(o.deck) }, venom = o.venom, w = w }, gap end
			if gap <= 6 then break end
			for _ = 1, math.min(3, math.floor(gap / 10) + 1) do -- bigger gaps take bigger steps
				if w > target then -- too easy: a stronger snake, or more venom every other step
					if _ % 2 == 0 and o.venom < 6 then o.venom = o.venom + 1 elseif not shift(o.deck, 1) then o.venom = math.min(8, o.venom + 1) end
				else
					if _ % 2 == 0 and o.venom > 0 then o.venom = o.venom - 1 elseif not shift(o.deck, -1) then o.venom = math.max(0, o.venom - 1) end
				end
			end
		end
		print(("%d\t%s\tvenom %d\twin %d%% (target %d)\t{ \"%s\" }"):format(level, o.name, best.venom, best.w, target, table.concat(best.deck, "\", \"")))
	end
	return
end

if os.getenv("MODE") ~= "matrix" then
	N = N or 300
	math.randomseed(1)
	local total_turns, capped, games = 0, 0, 0
	local row = {}
	local only = {}
	for l in (os.getenv("LEVELS") or ""):gmatch("%d+") do only[tonumber(l)] = true end
	for level = 1, #opponents do
	if not next(only) or only[level] then
		local wins = 0
		for _ = 1, N do
			if os.getenv("PROGRESS") then player_deck = progress_deck(level, tonumber(os.getenv("PROGRESS"))) end
			local w, t = match(level, "ai")
			wins = wins + (w == "Player" and 1 or 0)
			total_turns, games = total_turns + t, games + 1
			if not w then capped = capped + 1 end
		end
		row[#row + 1] = ("L%d %d%%"):format(level, math.floor(100 * wins / N + 0.5))
	end
	end
	print("win rate by level: " .. table.concat(row, "  "))
	print(("avg length %.1f turns (%.1f rounds), %d/%d hit the %d-turn cap"):format(total_turns / games, total_turns / games / 2, capped, games, TURN_CAP))
	return
end

-- ---------- matrix mode ----------
N = N or 600
local FRAC = tonumber(os.getenv("FRAC")) or 0.5
local KINDS = { "strike", "drain", "heal", "shield", "empower", "bolster", "pack", "adj", "lane", "first", "lone", "armor", "guard", "thorns" }
if os.getenv("KINDS") then -- e.g. KINDS=strike,heal
	KINDS = {}
	for k in os.getenv("KINDS"):gmatch("[^,]+") do table.insert(KINDS, k) end
end
local tiers = { 1, 2, 3, 4, 5 }
local by_tier = {}
for _, name in ipairs(data.deck) do
	local r = data.stats_by_name[name].rarity
	by_tier[r] = by_tier[r] or {}
	table.insert(by_tier[r], name)
end

local made = 0
local function clone(src, scale, code)
	made = made + 1
	local name = "Sim" .. made
	local s = data.stats_by_name[src]
	local function sc(v) return math.max(1, math.floor(v * scale + 0.5)) end
	data.stats_by_name[name] = {
		cost = math.min(10, sc(s.cost)), attack = sc(s.attack), defense = sc(s.defense),
		border = "Basic", rarity = s.rarity, ability_code = code, ability = "", lore = "",
	}
	data.card_types[name] = data.card_types[src]
	return name
end

-- Template snakes for a tier: the real ones; tiers with none (5) scale up the tier below, and
-- anything under 10 snakes is padded with slightly bigger / smaller copies
local function template(t)
	local list, src, scale = {}, t, 1
	while not by_tier[src] and src > 1 do src, scale = src - 1, scale * 1.35 end
	for _, n in ipairs(by_tier[src]) do table.insert(list, { n, scale }) end
	local factors, i = { 1.15, 0.87, 1.3 }, 0
	while #list < 10 do
		i = i + 1
		table.insert(list, { by_tier[src][(i - 1) % #by_tier[src] + 1], scale * factors[(i - 1) % 3 + 1] })
	end
	return list
end

local function code_for(kind, t, snake_type)
	if kind == "adj" then kind = "adj:" .. (snake_type == "Rainbow" and "Any" or snake_type) end
	if kind == "lane" then kind = "lane:" .. (snake_type == "Rainbow" and "Land" or snake_type) end
	if os.getenv("FORCE") then return os.getenv("FORCE") end
	return abilities.build(kind, t)
end

-- A deck of the tier's snakes; those picked by FRAC carry `code_t` for `kind`
local function deck_of(tmpl, kind, code_t)
	local deck = {}
	for i, e in ipairs(tmpl) do
		local code
		if kind and (i * 0.6180339) % 1 < FRAC then code = code_for(kind, code_t, data.card_types[e[1]]) end
		table.insert(deck, clone(e[1], e[2], code))
	end
	return deck
end

-- Win rate (%) of deck A against deck B, alternating who goes first
local stats = { turns = 0, games = 0, capped = 0 }
local function versus(a, b)
	opponents[1].venom = 0
	local wins = 0
	for g = 1, N do
		local a_first = g % 2 == 0
		player_deck, opponents[1].deck = a_first and a or b, a_first and b or a
		local w, t = match(1, "bot")
		stats.turns, stats.games = stats.turns + t, stats.games + 1
		if not w then
			stats.capped = stats.capped + 1
			wins = wins + 0.5
		elseif (w == "Player") == a_first then
			wins = wins + 1
			if os.getenv("DBG") then stats[a_first and "pw" or "ow"] = (stats[a_first and "pw" or "ow"] or 0) + 1 end
		end
	end
	return 100 * wins / N
end

math.randomseed(7)
local full = not os.getenv("TIERS")
if full then
	io.write("sanity (no abilities, mirror): ")
	for _, t in ipairs(tiers) do
		local tm = template(t)
		io.write(("T%d %.0f%%  "):format(t, versus(deck_of(tm), deck_of(tm))))
	end
	print()
end
print(("\nwin-rate contribution in points (ability on %d%% of a deck's snakes vs same deck with none); N=%d"):format(FRAC * 100, N))
local head = ("%-8s"):format("kind")
for _, t in ipairs(tiers) do head = head .. ("%7s"):format("T" .. t) end
print(head .. (full and " |    avg | T5 code vs T1 code on a T3 deck" or ""))
local col_sum = {}
for _, kind in ipairs(KINDS) do
	local row, sum = {}, 0
	for _, t in ipairs(tiers) do
		local tm = template(t)
		local c = versus(deck_of(tm, kind, t), deck_of(tm)) - 50
		row[#row + 1] = ("%+7.1f"):format(c)
		sum, col_sum[t] = sum + c, (col_sum[t] or 0) + c
	end
	local line = ("%-8s%s"):format(kind, table.concat(row, ""))
	if full then
		local tm = template(3)
		line = line .. (" | %+6.1f | %.0f%%"):format(sum / #tiers, versus(deck_of(tm, kind, 5), deck_of(tm, kind, 1)))
	end
	print(line)
end
local avg = {}
for _, t in ipairs(tiers) do avg[#avg + 1] = ("%+7.1f"):format(col_sum[t] / #KINDS) end
print(("%-8s%s"):format("mean", table.concat(avg, "")))
print(("avg match length %.1f turns (%.1f rounds); %d/%d games hit the %d-turn cap"):format(stats.turns / stats.games, stats.turns / stats.games / 2, stats.capped, stats.games, TURN_CAP))
