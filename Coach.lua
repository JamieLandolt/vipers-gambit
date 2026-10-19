local love = require("love")
local lg = love.graphics

-- First-visit mini tutorials: the screen dims except for a ring round the part being explained, with a few words
-- beside it; any click moves to the next step. coach.start(key, steps) plays a lesson once (remembered in hints.txt).
-- A step is { rect = { x, y, w, h } (or a function returning one), text = "a few words" } in reference-window units.
local coach = { steps = nil, i = 1, t = 0 }
local READ_TIME = 0.5 -- a click only moves on after half a second, so a double click does not skip a step

function coach.start(key, steps)
	local collection = require("Collection")
	if coach.steps or collection.hint_seen(key) then
		return
	end
	collection.mark_hint(key)
	coach.steps, coach.i, coach.t = steps, 1, time
end

function coach.active()
	return coach.steps ~= nil
end

function coach.click()
	if time - coach.t < READ_TIME then
		return
	end
	coach.i, coach.t = coach.i + 1, time
	if coach.i > #coach.steps then
		coach.steps = nil
	end
end

function coach.draw()
	local step = coach.steps and coach.steps[coach.i]
	if not step then
		return
	end
	local assets = require("Assets")
	local r = type(step.rect) == "function" and step.rect() or step.rect
	local x, y, w, h = r[1] - 10, r[2] - 10, r[3] + 20, r[4] + 20
	lg.stencil(function() lg.rectangle("fill", x, y, w, h, 16, 16) end, "replace", 1)
	lg.setStencilTest("equal", 0)
	lg.setColor(0, 0, 0, 0.8)
	lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
	lg.setStencilTest()
	local pulse = 0.5 + 0.5 * math.sin(time * 6)
	lg.setColor(1, 0.9, 0.2, 0.7 + 0.3 * pulse)
	lg.setLineWidth(5)
	lg.rectangle("line", x - 2 * pulse, y - 2 * pulse, w + 4 * pulse, h + 4 * pulse, 16, 16)
	lg.setLineWidth(1)
	local font = assets.font:getWidth(step.text) <= 900 and assets.font or assets.small_font -- long lessons use the small font, wrapped
	local _, lines = font:getWrap(step.text, 900)
	local tw, th = math.min(font:getWidth(step.text), 900) + 40, #lines * font:getHeight() + 12
	local tx = math.max(10, math.min(x + w / 2 - tw / 2, reference_window_width - tw - 10))
	local ty = y + h + 14
	if ty + th > reference_window_height - 30 then
		ty = y - th - 14
	end
	lg.setColor(0.07, 0.04, 0.14, 0.96)
	lg.rectangle("fill", tx, ty, tw, th, 10, 10)
	lg.setColor(1, 0.9, 0.2)
	lg.rectangle("line", tx, ty, tw, th, 10, 10)
	lg.setColor(1, 1, 1)
	lg.printf(step.text, font, tx + 20, ty + 6, tw - 40, "left")
	lg.setColor(1, 1, 1, 0.6)
	lg.printf(coach.i .. "/" .. #coach.steps, assets.debug_font, 0, reference_window_height - 30, reference_window_width, "center")
	lg.setColor(1, 1, 1)
end

return coach
