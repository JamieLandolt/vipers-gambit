local love = require("love")
local lg = love.graphics

-- A short guided match (level 0 on the level snake). Each step waits for the player to do
-- something (done) or to press Next (next = true); the match itself runs on the normal rules.
local tutorial = { active = false, step = 1, done = love.filesystem.getInfo("tutorial.txt") ~= nil }

-- The tutorial opponent: a cheap defensive deck and only 10 health, so the match is quick
tutorial.profile = {
	name = "Tutorial Snake",
	style = { attack = 0, defense = 2, cost = 0.5, block = 3, open = 0 },
	venom = 0,
	health = 10,
	deck = { "Garter_Snake", "Corn_Snake", "Vine_Snake", "Snake", "Pond_Snake", "Leaf_Snake" },
}

local ended_turns = 0 -- how many times the player has pressed End Turn
local last_turn

-- The tutorial player only has these four snakes: a plain one, a Venom-border one, a Rainbow one and one with an ability
tutorial.player_deck = { "Skinny_Snake", "Orchid_Snake", "Candy_Snake", "Brown_Snake" }

-- Each step waits for the player to do something (done), to press Next (next), or either (both).
-- The End Turn, ability and Charm controls stay locked until their step (see tutorial.allows).
local steps = {
	{ text = "Welcome, Charmer! Drag a snake from your hand onto a lit slot on your side of the field.",
		done = function()
			for slot = 5, 8 do
				if played_cards[slot] then
					return true
				end
			end
		end },
	{ text = "Lanes: each lane only fits certain snake types, named on every slot (the lane's look matches: sand, water, leaves, mist). Rainbow snakes fit any lane.", next = true },
	{ text = "Borders: the coloured frame on a card gives a passive effect. Venom poisons, Fire doubles overkill damage to health, Frost freezes, Shadow dodges the first hit, Gold earns venom, Rainbow grows. Play your green-framed snake and hover it.",
		done = function()
			for slot = 5, 8 do
				local c = played_cards[slot]
				if c and require("CardData").get_stats(c).border ~= "Basic" then
					return true
				end
			end
		end },
	{ text = "Rarity: the bars under a card show its tier, from 1 (Hatchling) up to 5 (Mythic, the legendaries). Rarer snakes are stronger and cost more venom.", next = true },
	{ text = "Venom: the meter at the left pays for snakes. You get 1 more each turn.", next = true },
	{ text = "Now press End Turn. Your snakes attack the card in the lane opposite them, or the enemy's health if the lane is empty. Damage left over after a kill hits their health too.",
		done = function() return ended_turns >= 1 end },
	{ text = "The enemy takes its turn, then it is yours again.", next = true },
	{ text = "Abilities: a snake with a ! can use an ability for venom. Click it. Hover any snake to read its ability.",
		done = function()
			for slot = 5, 8 do
				if played_cards[slot] and played_cards[slot].used then
					return true
				end
			end
		end, next = true },
	{ text = "Charm: your charmer's Charm button, right of the field, is a power you can use once a turn for venom. Try it!",
		done = function() return require("Play").charm_used.Player end, next = true },
	{ text = "Reduce the enemy's health to 0 to win. Good luck!", next = true },
}

-- Locked controls: the step number at which each unlocks
local UNLOCK = { end_turn = 6, ability = 8, charm = 9 }

function tutorial.allows(control)
	return not tutorial.active or tutorial.step >= UNLOCK[control]
end

function tutorial.start()
	tutorial.active, tutorial.step, ended_turns, last_turn = true, 1, 0, "Player"
end

function tutorial.finish()
	tutorial.active, tutorial.done = false, true
	love.filesystem.write("tutorial.txt", "done")
end

-- Called every frame during a match
function tutorial.update()
	if not tutorial.active then
		return
	end
	if turn ~= last_turn then
		ended_turns = ended_turns + (turn == "Opponent" and 1 or 0)
		last_turn = turn
	end
	local step = steps[tutorial.step]
	if step and step.done and step.done() then
		tutorial.step = tutorial.step + 1
	end
end

-- Pressing the Next button
function tutorial.advance()
	local step = steps[tutorial.step]
	if tutorial.active and step and step.next then
		tutorial.step = tutorial.step + 1
		if tutorial.step > #steps then
			tutorial.active = false
		end
	end
end

-- Lane type labels show once the tutorial reaches its lane step
function tutorial.show_labels()
	return tutorial.active and tutorial.step >= 2
end

function tutorial.needs_next()
	return tutorial.active and steps[tutorial.step] and steps[tutorial.step].next
end

-- A panel in the free space left of the field
function tutorial.draw()
	local step = steps[tutorial.step]
	if not (tutorial.active and step) then
		return
	end
	local assets = require("Assets")
	local x, y, w, h = 8, 110, 228, 360
	lg.setColor(0, 0, 0, 0.85)
	lg.rectangle("fill", x, y, w, h, 8, 8)
	lg.setColor(0.45, 0.8, 0.3)
	lg.setLineWidth(4)
	lg.rectangle("line", x, y, w, h, 8, 8)
	lg.setLineWidth(1)
	lg.setColor(1, 1, 1)
	lg.printf("Tutorial " .. tutorial.step .. "/" .. #steps, assets.debug_font, x + 10, y + 8, w - 20, "center")
	lg.printf(step.text, assets.debug_font, x + 12, y + 36, w - 24)
end

return tutorial
