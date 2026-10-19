local love = require("love")
local lg = love.graphics
local assets = require("Assets")

-- Timed visual effects for the play screen. Game state changes instantly; effects only decorate it.
-- Kinds: place (card slams down), lunge (attacker darts at its target), hit (defender shakes),
-- dead (defender bursts), hp (health bar shakes) and float (rising damage number).
local effects = {}
local list = {}

local LIFE = { place = 0.7, lunge = 0.35, hit = 0.5, dead = 0.6, hp = 0.5, float = 0.9, sound = 0.3, shake = 0.35 }
local FALL = 0.25 -- how long a placed card takes to land

function effects.add(kind, fields)
	fields.kind, fields.t0 = kind, time + (fields.delay or 0)
	table.insert(list, fields)
end

-- Screen shake: `amount` pixels at its start, fading over 0.35 seconds (skipped by the Reduce motion setting)
function effects.shake(amount, delay)
	if not reduce_motion then
		effects.add("shake", { amount = amount, delay = delay })
	end
end

-- When the effects playing now will all have finished (so the end screen can wait for the last attack)
function effects.settled()
	local last = time
	for _, e in ipairs(list) do
		last = math.max(last, e.t0 + (LIFE[e.kind] or 0.5))
	end
	return last
end

function effects.clear()
	list = {}
end

-- How a card should be drawn right now: offset, scale multipliers, opacity and white flash
function effects.card(card)
	local dx, dy, sx, sy, alpha, flash = 0, 0, 1, 1, 1, 0
	for _, e in ipairs(list) do
		local age = time - e.t0
		if e.card == card and age >= 0 then
			if e.kind == "place" then
				if age < FALL then
					local p = age / FALL
					sx, sy, alpha = sx * (2 - p * p), sy * (2 - p * p), math.min(p * 3, 1)
				else
					local u = math.min((age - FALL) / 0.35, 1)
					local wobble = (1 - u) ^ 2 * math.cos(u * 14) * 0.18
					sx, sy, flash = sx * (1 + wobble), sy * (1 - wobble), math.max(flash, 1 - (age - FALL) * 8)
				end
			elseif e.kind == "lunge" and age < LIFE.lunge then
				local swing = math.sin(math.pi * age / LIFE.lunge)
				dy, sx, sy = dy + e.dir * 70 * swing, sx * (1 + 0.1 * swing), sy * (1 + 0.1 * swing)
			elseif e.kind == "hit" then
				local u = age / LIFE.hit
				dx, flash = dx + math.sin(age * 70) * 10 * (1 - u), math.max(flash, 1 - u * 2.5)
			elseif e.kind == "dead" then
				local u = math.min(age / 0.45, 1)
				alpha, sx, sy = alpha * (1 - u), sx * (1 + 0.3 * u), sy * (1 + 0.3 * u)
			end
		end
	end
	return dx, dy, sx, sy, alpha, flash
end

-- Cards that were just destroyed but are still bursting, so they can be drawn in their slot
function effects.ghosts()
	local ghosts = {}
	for _, e in ipairs(list) do
		if e.kind == "dead" and played_cards[e.sector] ~= e.card then
			table.insert(ghosts, e)
		end
	end
	return ghosts
end

-- Where the whole screen is nudged to right now
function effects.screen_offset()
	local dx, dy = 0, 0
	for _, e in ipairs(list) do
		local age = time - e.t0
		if e.kind == "shake" and age >= 0 then
			local u = 1 - age / LIFE.shake
			dx, dy = dx + math.sin(age * 90) * e.amount * u, dy + math.cos(age * 110) * e.amount * u
		end
	end
	return dx, dy
end

-- Horizontal shake and white flash for a side's health bar
function effects.bar(side)
	local dx, flash = 0, 0
	for _, e in ipairs(list) do
		local age = time - e.t0
		if e.kind == "hp" and e.side == side and age >= 0 then
			local u = age / LIFE.hp
			dx, flash = dx + math.sin(age * 70) * 8 * (1 - u), math.max(flash, 1 - u * 2)
		end
	end
	return dx, flash
end

local function sparks(cx, cy, u, count, colour, reach)
	local size = 12 * (1 - u) + 2
	for k = 0, count - 1 do
		local angle = k * 2 * math.pi / count + 0.3
		local distance = reach * (0.7 + 0.15 * (k % 3)) * u * (1 - 0.3 * u)
		lg.setColor(colour[1], colour[2], colour[3], 1 - u)
		lg.rectangle("fill", cx + math.cos(angle) * distance - size / 2, cy + math.sin(angle) * distance - size / 2, size, size)
	end
end

-- Drawn over the board: rings, sparks and damage numbers. Also drops finished effects.
function effects.draw()
	for i = #list, 1, -1 do
		if time > list[i].t0 + LIFE[list[i].kind] then
			table.remove(list, i)
		end
	end
	for _, e in ipairs(list) do
		local age = time - e.t0
		if age >= 0 then
			if e.kind == "place" and age > FALL then
				local u = math.min((age - FALL) / 0.45, 1)
				lg.setLineWidth(8 * (1 - u))
				lg.setColor(0.6, 0.9, 0.3, 1 - u)
				lg.circle("line", e.cx, e.cy, 30 + 170 * u)
				lg.setLineWidth(1)
				sparks(e.cx, e.cy, u, 12, { 1, 1, 0.7 }, 190)
			elseif e.kind == "hit" then
				-- sparks take the attacker's border colour (orange when it has none)
				local colour = e.border and require("Borders").colour(e.border) or { 1, 0.45, 0.2 }
				sparks(e.cx, e.cy, math.min(age / 0.4, 1), 8, colour, 110)
			elseif e.kind == "sound" and not e.done then
				e.done = true
				require("Sounds").play(e.name)
			elseif e.kind == "dead" then
				sparks(e.cx, e.cy, math.min(age / 0.5, 1), 14, { 0.9, 0.2, 0.2 }, 200)
			elseif e.kind == "float" then
				local u = age / LIFE.float
				local x, y = e.x - assets.font:getWidth(e.text) * 0.8, e.y - 70 * u
				lg.setColor(0, 0, 0, 1 - u)
				lg.print(e.text, assets.font, x + 3, y + 3, 0, 1.6)
				local colour = e.colour or { 1, 0.35, 0.3 }
				lg.setColor(colour[1], colour[2], colour[3], 1 - u)
				lg.print(e.text, assets.font, x, y, 0, 1.6)
			end
		end
	end
	lg.setColor(1, 1, 1)
end

return effects
