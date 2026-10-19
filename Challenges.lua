-- Each level has three challenges, fought in order once the level is beaten (the Play button picks the next one by itself),
-- then endless rematches that keep scaling (play.next_fight). Challenge 1 is written out below; II and III are made harder from it.
-- A challenge replays the level with a handicap for `mult` times the reward.
-- Rules: opp_health / player_health (health multipliers), opp_venom (extra starting venom), hand_size (your hand),
-- no_charm (your Charm is locked), opp_start (snakes the opponent begins with in play).
-- Multipliers come from `MODE=chal luajit tools/sim.lua`: roughly the base win rate over the challenge win rate.
local base = {
	{ name = "Overgrown", text = "The enemy has 150% more health", opp_health = 2.5, mult = 1.5 },
	{ name = "Deep Water", text = "Your health is cut to 45%", player_health = 0.45, mult = 3 },
	{ name = "Hot Blood", text = "Enemy +8 venom and 60% more health", opp_venom = 8, opp_health = 1.6, mult = 1.5 },
	{ name = "Mirage", text = "Your hand is only 2 snakes", hand_size = 2, mult = 1.75 },
	{ name = "Silenced Crypt", text = "Your Charm is locked, enemy health +50%", no_charm = true, opp_health = 1.5, mult = 1.5 },
	{ name = "Hunter's Mark", text = "Enemy health +40%, and a hand of 4", opp_health = 1.4, hand_size = 4, mult = 1.5 },
	{ name = "Fang Frenzy", text = "The enemy starts with a Cottonmouth in play", opp_start = { "Cottonmouth" }, mult = 3 },
	{ name = "Mossy Fortress", text = "The enemy has 80% more health", opp_health = 1.8, mult = 1.5 },
	{ name = "Rival's Edge", text = "Charm locked, enemy health +30%", no_charm = true, opp_health = 1.3, mult = 1.5 },
	{ name = "Coiled Grip", text = "Your health is cut to 60%", player_health = 0.6, mult = 2.5 },
	{ name = "Fog of War", text = "A hand of 3, enemy health +20%", hand_size = 3, opp_health = 1.2, mult = 2 },
	{ name = "Mending Spite", text = "Enemy health +50%, your Charm locked", opp_health = 1.5, no_charm = true, mult = 2.5 },
	{ name = "Blazing Throne", text = "The enemy starts with a Bark Snake in play", opp_start = { "Bark_Snake" }, mult = 2 },
	{ name = "Duel at Dawn", text = "Your health 80%, a hand of 4", player_health = 0.8, hand_size = 4, mult = 2 },
	{ name = "Last Laugh", text = "The enemy has 40% more health", opp_health = 1.4, mult = 2 },
	{ name = "Gilded Guard", text = "Enemy health +20%, a hand of 4", opp_health = 1.2, hand_size = 4, mult = 1.5 },
	{ name = "Final Wager", text = "Charm locked, your health 70%", no_charm = true, player_health = 0.7, mult = 3.5 },
	{ name = "Crown of Thorns", text = "Enemy health +30%, a hand of 4", opp_health = 1.3, hand_size = 4, mult = 3.5 },
}

local function round(x) return math.floor(x * 4 + 0.5) / 4 end

-- Challenge II: the enemy has 10% more health. Challenge III: 20% more, and your hand is at most 4.
local function harder(c, step)
	local d = {}
	for k, v in pairs(c) do d[k] = v end
	d.opp_health = (c.opp_health or 1) * (step == 2 and 1.1 or 1.2)
	d.name = c.name .. (step == 2 and " II" or " III")
	d.text = c.text .. (step == 2 and "; enemy +10% health" or "; enemy +20% health, your hand of 4")
	d.mult = round(c.mult * (step == 2 and 1.3 or 1.7))
	if step == 3 then
		d.hand_size = math.min(c.hand_size or 5, 4)
	end
	return d
end

local list = {}
for level, c in ipairs(base) do
	list[level] = { c, harder(c, 2), harder(c, 3) }
	for i, ch in ipairs(list[level]) do ch.tier = i end
end
return list
