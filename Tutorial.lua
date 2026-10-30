local love = require("love")
local lg = love.graphics

-- A short guided first match (level 1). Each step waits for the player to do
-- something (done) or to press Next (next = true); the match itself runs on the normal rules.
local tutorial = { active = false, step = 1, done = love.filesystem.getInfo("tutorial1.txt") ~= nil }

local ended_turns = 0 -- how many times the player has pressed End Turn
local last_turn

-- Where things are, for the pointers: rectangles { x, y, w, h } in reference-window units
local function box_of(slot) return require("Play").field_hitboxes[slot] end

local function hand_rect(pick) -- the first hand card the test accepts, as its visible rectangle
	for _, c in ipairs(player_hand) do
		local hb = card_hitboxes[c]
		if hb and pick(c) then
			return { hb[1], hb[2], img_widths * 0.8, hb[4] }, c
		end
	end
end

local function button_rect(name)
	local b = buttons.playing[name]
	return { b.x, b.y, b.width, b.height }
end

local function played_where(test)
	for slot = 5, 8 do
		if played_cards[slot] and test(played_cards[slot]) then
			return slot
		end
	end
end

local function has_border(c) return require("CardData").border_of(c) ~= "Basic" end

-- Each step waits for the player to do something (done), to press Next (next), or either (both). `point` lists what to circle.
-- The End Turn, ability and Charm controls stay locked until their step (see tutorial.allows).
local basic = {
	{ text = "Drag a snake onto your side of the field.",
		point = function()
			local r = hand_rect(function() return true end)
			return { r, { 245, 285, 950, 270 } }
		end,
		done = function() return played_where(function() return true end) ~= nil end },
	{ text = "Each lane fits only the types named on its slots.", next = true,
		point = function()
			local list = {}
			for slot = 5, 8 do
				local b = box_of(slot)
				list[#list + 1] = { b[1] + 4, b[2] + 2, 170, 28 }
			end
			return list
		end },
	{ text = "The star number is its rarity: more stars means a rarer, stronger snake.", next = true,
		point = function()
			local r = hand_rect(function() return true end)
			return r and { { r[1] + r[3] * 0.6, r[2] + r[4] * 0.02, r[3] * 0.4, r[4] * 0.12 } } or {}
		end },
	{ text = "These are your venom vials. Venom is what you spend to play cards.", next = true,
		point = function() return { { 170, 482, 76, 76 } } end },
	{ text = "Each card shows its venom cost in the top left corner.", next = true,
		point = function()
			local r = hand_rect(function() return true end)
			return r and { { r[1] + r[3] * 0.02, r[2] + r[4] * 0.02, r[3] * 0.4, r[4] * 0.12 } } or {}
		end },
	{ text = "The sword is its attack, the heart its health. A snake hits the snake opposite it, or the enemy's health if the lane is empty.", next = true,
		point = function()
			local r = hand_rect(function() return true end)
			return r and { { r[1] + r[3] * 0.02, r[2] + r[4] * 0.85, r[3] * 0.96, r[4] * 0.13 } } or {}
		end },
	{ text = "Rest the mouse on any snake, in your hand or on the field, to see its stats and ability.", next = true,
		point = function()
			local r = hand_rect(function() return true end)
			return r and { r } or {}
		end },
	{ text = "Your venom refills at the start of every turn, and you get 1 more than last turn. Unspent venom carries over, up to 10.", next = true,
		point = function() return { { 170, 482, 76, 76 } } end },
	{ text = "Press End Turn. Your snakes hit the snake opposite, or their health.",
		point = function() return { button_rect("End Turn") } end,
		done = function() return ended_turns >= 1 end },
	{ text = "Now the enemy plays. Then it is your turn.", next = true },
	{ text = "Empty their health bar to win!", next = true,
		point = function() return { { 1210, require("Play").bar_y.Opponent, 210, 40 } } end },
}

local TRAY = { 245, 570, 950, 285 } -- the hand, for lessons about cards that may not be in it yet

-- Short lessons for later levels, each shown the first time that level is played (mechanics are introduced one at a time)
local function hand_border() return hand_rect(has_border) end
local tips = {
	[2] = { { text = "Borders: the coloured frame on a card gives a snake a passive effect.", next = true,
			point = function() local r = hand_border() or hand_rect(function() return true end); return r and { r } or {} end },
		{ text = "Snakes can come out of packs with a border. Rest the mouse on a snake to read what its border does.", next = true, point = function() local r = hand_border() or hand_rect(function() return true end); return r and { r } or {} end } },
	[3] = { { text = "Abilities: every snake has one, and you pay venom to use it. Hover a snake on the field to read its ability here.", next = true,
			point = function() return { { 1200, 325, 235, 170 } } end },
		{ text = "A ! over your snake means you can pay venom to use its ability. Click the snake. Once per turn.", next = true,
			point = function() return { { 245, 285, 950, 270 } } end },
		{ text = "Sacrifice: drag one of your snakes from the field onto your hand and let go. It dies for free, which clears its lane for a better snake.", next = true,
			point = function() return { { 245, 285, 950, 270 }, TRAY } end } },
	[4] = { { text = "Charm: your charmer's own power. It costs venom, then needs a few turns to recharge.", next = true,
			point = function() return { button_rect("Charm") } end },
		{ text = "Every charmer's charm is different. Pick yours from the main menu.", next = true,
			point = function() return { { 1215, 548, 215, 72 } } end },
		{ text = "Charms and snakes can poison or freeze: poisoned snakes lose health each turn, frozen ones skip their next attack.", next = true,
			point = function() return { { 245, 15, 950, 270 } } end } },
	[5] = { { text = "Brews and spells are cards too. A brew goes onto one of your snakes and lasts while it lives.", next = true,
			point = function() local r = hand_rect(function(c) return require("CardData").get_stats(c).kind == "brew" end); return r and { r } or { TRAY } end },
		{ text = "A spell works at once, and the card is used up. Most work anywhere on the field; some, like Fireball, are dropped on the enemy snake you choose.", next = true,
			point = function() local r = hand_rect(function(c) return require("CardData").get_stats(c).kind == "spell" end); return r and { r } or { TRAY } end } },
	[6] = { { text = "Enemies have a charm too. Watch their charmer: it can strike in the middle of a turn.", next = true,
			point = function() return { { 1215, 78, 215, 72 } } end } },
}
local steps = basic

-- Only the first match (level 1) locks the controls; the later lessons just point things out
local UNLOCK = { end_turn = 9, ability = 11, charm = 11 }

function tutorial.allows(control)
	return not tutorial.active or tutorial.step >= UNLOCK[control]
end

function tutorial.start()
	steps = basic
	tutorial.active, tutorial.step, ended_turns, last_turn, shown = true, 1, 0, "Player", nil
end

-- Starts a level's lesson the first time that level is played, if it has one: the screen dims around what is being
-- introduced (see Coach.lua), with a few words beside it
function tutorial.tip(level)
	local lesson, coach_steps = tips[level], {}
	for _, step in ipairs(lesson or {}) do
		coach_steps[#coach_steps + 1] = { text = step.text, rect = function() return (step.point and step.point() or {})[1] or TRAY end }
	end
	if lesson then
		require("Coach").start("lesson" .. level, coach_steps)
	end
end

function tutorial.finish()
	tutorial.active, tutorial.done = false, true
	love.filesystem.write("tutorial1.txt", "done")
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

-- Each lesson step shows for half a second before it can be skipped
local READ_TIME = 0.5
local shown, shown_at = nil, 0

local function wait_left()
	if shown ~= tutorial.step then
		shown, shown_at = tutorial.step, time
	end
	return math.max(0, READ_TIME - (time - shown_at))
end

-- Pressing the Next button
function tutorial.advance()
	local step = steps[tutorial.step]
	if tutorial.active and step and step.next and wait_left() == 0 then
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
	return tutorial.active and steps[tutorial.step] and steps[tutorial.step].next and wait_left() == 0
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

-- Pulsing rings and a bobbing arrow on whatever the current step is talking about (drawn over the board)
function tutorial.draw_pointers()
	local step = steps[tutorial.step]
	if not (tutorial.active and step and step.point) then
		return
	end
	local pulse = 0.5 + 0.5 * math.sin(motion_time * 6)
	for _, r in ipairs(step.point()) do
		lg.setColor(1, 0.9, 0.2, 0.55 + 0.45 * pulse)
		lg.setLineWidth(4)
		lg.rectangle("line", r[1] - 6 - 3 * pulse, r[2] - 6 - 3 * pulse, r[3] + 12 + 6 * pulse, r[4] + 12 + 6 * pulse, 14, 14)
		local ax, ay = r[1] + r[3] / 2, r[2] - 12 - 6 * pulse
		if ay < 40 then
			ay = r[2] + r[4] + 12 + 6 * pulse
			lg.polygon("fill", ax, ay - 14, ax - 12, ay + 8, ax + 12, ay + 8)
		else
			lg.polygon("fill", ax, ay, ax - 12, ay - 22, ax + 12, ay - 22)
		end
	end
	lg.setLineWidth(1)
	lg.setColor(1, 1, 1)
end

return tutorial
