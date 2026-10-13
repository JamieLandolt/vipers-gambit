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

local steps = {
	{ text = "Welcome, Charmer! Drag a snake from your hand onto a glowing slot on your side of the field.",
		done = function()
			for slot = 5, 8 do
				if played_cards[slot] then
					return true
				end
			end
		end },
	{ text = "Each lane only fits certain snake types: read the label on every slot. Rainbow snakes fit any lane.", next = true },
	{ text = "Snakes cost venom (the meter at the left). It grows by 1 every turn. Now press End Turn to attack.",
		done = function() return ended_turns >= 1 end },
	{ text = "Your snakes hit the card in the lane opposite them, or the enemy's health if the lane is empty. Then the enemy takes its turn.", next = true },
	{ text = "Keep playing snakes and pressing End Turn. A snake with a ! can use its ability for venom: click it. Hover any snake to read its ability and border.", next = true },
	{ text = "Reduce the enemy's health to 0 to win. Good luck!", next = true },
}

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
	lg.printf(step.text, assets.small_font, x + 12, y + 40, w - 24)
end

return tutorial
