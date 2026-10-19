-- Minimal headless checks. Run from the project root:  luajit tests/test.lua
package.path = "./?.lua;" .. package.path
local files = {}
package.preload["love"] = function()
	return { graphics = {}, mouse = {}, keyboard = {}, filesystem = {
		write = function(name, s) files[name] = s end, read = function(name) return files[name] end,
		getInfo = function() end, remove = function(name) files[name] = nil end } }
end
package.preload["Effects"] = function() return { add = function() end, clear = function() end, shake = function() end } end
package.preload["Card"] = function() return function(p, _, _, border) return { card_path = p, border = border } end end
package.preload["Collection"] = function()
	return { deck = function() return { "Sand_Snake", "Dirt_Snake", "Garter_Snake", "Mud_Snake", "Grass_Snake", "Brown_Snake" } end,
		save = function() end, mark_hint = function() end, give_pack = function() end, record_win = function() end, health_bonus = function() return 0 end, beaten_base = function() return true end, challenges_done = function() return 3 end, endless = function() return 2 end, wins = function() return 0 end, reward = function() return 0 end, mark_challenge = function() end, challenge_done = function() return false end }
end
local data, play = require("CardData"), require("Play")
function contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function update_game_state(s) state = s end
function play_sound() end
img_widths, img_heights, unlocked, time = 1, 1, 1, 0
local fails = 0
local function check(label, ok) if not ok then fails = fails + 1; print("FAIL " .. label) end end

-- data: every card has art, every opponent deck uses real cards
local function exists(path) local f = io.open(path, "rb"); if f then f:close() end return f ~= nil end
for _, name in ipairs(data.deck) do check("art for " .. name, exists("assets/Snake_Cards/" .. name .. ".png")) end
local opponents = require("Opponents")
check("18 levels with 3 challenges each", #opponents == 18 and #require("Challenges") == 18 and #require("Challenges")[7] == 3)
for level, o in ipairs(opponents) do
	check("level " .. level .. " health", o.health >= 40 + 5 * level)
	check("level " .. level .. " deck", #o.deck >= 6)
	for _, name in ipairs(o.deck) do check("level " .. level .. " card " .. name, data.stats_by_name[name] ~= nil) end
end
for name, st in pairs(data.stats_by_name) do check("ability text for " .. name, st.kind ~= "snake" or (st.ability or ""):len() > 0) end

-- the opponent AI drinks a brew and a spell, and whole matches finish at every level
chosen_avatar = require("Charmers").list[1].name
play.new_game(10)
local function card(name) return require("Card")(name .. ".png") end
played_cards[1] = card("Cobra")
opponent_hand = { card("Rage_Draught"), card("Lightning_Storm") }
venom.Opponent = 10
local hp = health.Player
check("AI drinks", play.use_support("Opponent") and played_cards[1].brew == "rage")
played_cards[5] = card("Stone_Constrictor")
check("AI casts", play.use_support("Opponent") and played_cards[5].hp ~= nil and played_cards[5].hp < data.get_stats(played_cards[5]).defense)
for level = 1, 20 do
	play.new_game(level)
	local turns = 0
	while state ~= "ended" and turns < 300 do
		turns = turns + 1
		if turn == "Player" then
			play.use_support("Player")
			play.end_turn()
		else
			repeat play.opponent_turn(1) until turn == "Player" or state == "ended"
		end
	end
	check("level " .. level .. " match ends", state == "ended")
	state = nil
end

-- 30 brews and 30 spells, each one works without errors
local Brews = require("Brews")
local nb, ns = 0, 0
for _, def in ipairs(Brews.list) do
	play.new_game(10)
	turn = "Player"
	for slot = 1, 8 do played_cards[slot] = card(slot % 2 == 0 and "Cobra" or "Sand_Snake") end
	played_cards[5].hp = 2
	venom.Player = 10
	local ok, err = pcall(function()
		if def.kind == "brew" then
			nb = nb + 1
			check(def.name .. " drinks", Brews.drink(play, def, 5))
			Brews.turn(play, played_cards[5], 5)
		else
			ns = ns + 1
			def.cast(play, "Player")
			def.cast(play, "Opponent")
		end
	end)
	check(def.name .. " runs: " .. tostring(err), ok)
end
check("30 brews and 30 spells", nb == 30 and ns == 30)

-- endless rematches scale up
local fight = play.next_fight(3)
check("endless rank 3 scales", fight and fight.endless == 3 and fight.scale > 1.25 and fight.opp_health > (require("Challenges")[3][3].opp_health or 1))
play.new_game(3, fight)
local before = health.Opponent
check("endless health", before > opponents[3].health * 2)

-- achievements
local ach = require("Achievements")
ach.reset()
ach.add("wins")
check("achievement toast", ach.queue[1] and ach.queue[1][1] == "first_win" and ach.count() == 1)


-- damage shows when the blow lands
time = 100
play.new_game(2)
played_cards[1] = card("Garter_Snake")
local hp0 = data.get_stats(played_cards[1]).defense
play.hit(card("Garter_Snake"), 1, 2, 1)
check("hp worked out at once", played_cards[1].hp == hp0 - 2)
check("shown hp lags until the hit", play.shown_hp(played_cards[1]) == hp0)
local was = health.Opponent
play.hurt("Opponent", 3, 0.5)
check("health shown lags", play.shown_health("Opponent") == was and health.Opponent == was - 3)
time = 101.2
check("shown hp catches up", play.shown_hp(played_cards[1]) == hp0 - 2 and play.shown_health("Opponent") == was - 3)
time = 0

-- Fireball hits the enemy snake it is dropped on (the AI still picks the strongest)
play.new_game(5)
played_cards[1], played_cards[2] = card("Garter_Snake"), card("Colossus_Python")
local weak_hp, strong_hp = data.get_stats(played_cards[1]).defense, data.get_stats(played_cards[2]).defense
require("Brews").by_name.Fireball.cast(play, "Player", 1)
check("fireball hits the chosen snake", played_cards[1] == nil or (played_cards[1].hp or weak_hp) < weak_hp)
check("fireball leaves the other alone", (played_cards[2].hp or strong_hp) == strong_hp)
require("Brews").by_name.Fireball.cast(play, "Player")
check("no target picks the strongest", (played_cards[2].hp or strong_hp) < strong_hp)
-- Every snake has an ability paid for in venom
local data, abilities = require("CardData"), require("Abilities")
for _, name in ipairs(data.deck) do
	if data.stats_by_name[name].kind == "snake" then
		check(name .. " has a venom ability", abilities.active(card(name)) ~= nil)
	end
end

-- A hurt Zombie Snake pays venom to return to its owner's hand without pushing another card out
played_cards = {}
played_cards[6] = card("Zombie_Snake")
played_cards[6].hp = 1
venom.Player = 5
local before = #player_hand
check("zombie is ready when hurt", abilities.ready(played_cards[6], "Player"))
play.activate(6)
check("zombie joins the hand", #player_hand == before + 1 and played_cards[6] == nil)
play.start_turn()
check("zombie stays after the next draw", #player_hand >= before + 1)

-- Cripple takes attack from the snake opposite
played_cards[5], played_cards[1] = card("Cobra"), card("Cobra")
played_cards[5].used = nil
local atk = abilities.attack(played_cards[1], 1)
play.activate(5)
check("power takes effect", played_cards[1].bonus == -4 and abilities.attack(played_cards[1], 1) == math.max(atk - 4, 0))
-- Sacrificing is free and the snake dies
played_cards[7] = card("Cobra")
local venom_before = venom.Player
play.sacrifice(7)
check("sacrifice removes the snake for free", played_cards[7] == nil and venom.Player == venom_before)
-- A turn always draws a card, even with a full hand, until the deck runs out
play.new_game(1)
local sizes = {}
for _ = 1, 4 do
	sizes[#sizes + 1] = #player_hand
	play.start_turn()
end
check("hand grows past 5 until the 6 card deck runs out", sizes[1] == 5 and sizes[2] == 6 and sizes[3] == 6 and sizes[4] == 6)
print(fails == 0 and "all tests passed" or fails .. " FAILED")
os.exit(fails == 0 and 0 or 1)
