local love = require("love")
local lg = love.graphics
local assets = require("Assets")

-- Timed visual effects for the play screen. Game state changes instantly; effects only decorate it.
-- Kinds: place (card slams down), lunge (attacker darts at its target), hit (defender shakes),
-- dead (defender bursts), hp (health bar shakes) and float (rising damage number).
local effects = {}
local list = {}

local LIFE = { place = 0.7, lunge = 0.35, hit = 0.5, dead = 0.6, hp = 0.5, float = 0.9, sound = 0.3, shake = 0.35, callout = 1.4, spotlight = 3 }
local FALL = 0.25 -- how long a placed card takes to land

-- Floating texts that mean something get an icon, colour, particles and a sound of their own
local STYLES = {
	{ "blocked", { icon = "shield", colour = { 0.78, 0.84, 0.95 }, sound = "block", burst = "ring" } },
	{ "shield", { icon = "shield", colour = { 0.55, 0.8, 1 }, sound = "shield", burst = "ring" } },
	{ "poison", { icon = "drop", colour = { 0.6, 0.95, 0.3 }, sound = "poison", burst = "drip" } },
	{ "frozen", { icon = "flake", colour = { 0.65, 0.92, 1 }, sound = "freeze", burst = "ring" } },
	{ "^%+%d+/%+%d+", { icon = "star", colour = "rainbow", sound = "buff", burst = "sparkle" } },
	{ "atk", { icon = "sword", colour = { 1, 0.55, 0.25 }, sound = "buff", burst = "sparkle" } },
	{ "^%+%d+ hp", { icon = "heart", colour = { 0.4, 1, 0.55 }, sound = "heal", burst = "sparkle" } },
}

function effects.add(kind, fields)
	fields.kind, fields.t0 = kind, time + (fields.delay or 0)
	if kind == "float" and not fields.colour then
		for _, s in ipairs(STYLES) do
			if fields.text:find(s[1]) then
				fields.style = s[2]
				table.insert(list, { kind = "sound", name = s[2].sound, t0 = fields.t0 })
				break
			end
		end
	end
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

-- Small icons for styled floating texts, about 28 units across with (x, y) at the middle
local ICONS = {
	heart = function(x, y)
		lg.circle("fill", x - 7, y - 4, 8)
		lg.circle("fill", x + 7, y - 4, 8)
		lg.polygon("fill", x - 14.5, y - 1, x + 14.5, y - 1, x, y + 15)
	end,
	sword = function(x, y)
		lg.polygon("fill", x - 3, y - 15, x + 3, y - 15, x + 3, y + 6, x - 3, y + 6)
		lg.rectangle("fill", x - 10, y + 6, 20, 4)
		lg.rectangle("fill", x - 3, y + 10, 6, 6)
	end,
	shield = function(x, y)
		lg.polygon("fill", x - 13, y - 13, x + 13, y - 13, x + 13, y + 2, x, y + 16, x - 13, y + 2)
	end,
	drop = function(x, y)
		lg.circle("fill", x, y + 4, 10)
		lg.polygon("fill", x, y - 15, x - 9, y + 1, x + 9, y + 1)
	end,
	flake = function(x, y)
		lg.setLineWidth(4)
		for k = 0, 2 do
			local a = k * math.pi / 3
			lg.line(x - math.cos(a) * 14, y - math.sin(a) * 14, x + math.cos(a) * 14, y + math.sin(a) * 14)
		end
		lg.setLineWidth(1)
	end,
	star = function(x, y)
		for k = 0, 4 do
			local a, b = k * 1.2566 - 1.5708, k * 1.2566 + 1.5708 * 0.2
			lg.polygon("fill", x, y, x + math.cos(a - 0.3) * 14, y + math.sin(a - 0.3) * 14, x + math.cos(a + 0.3) * 14, y + math.sin(a + 0.3) * 14)
		end
	end,
}

-- A floating text with a style: pops in, an icon and glow beside it, and particles of its own kind
local function styled_float(e, age)
	local u = age / LIFE.float
	local c = e.style.colour
	if c == "rainbow" then
		c = { 0.6 + 0.4 * math.sin(time * 8), 0.6 + 0.4 * math.sin(time * 8 + 2.1), 0.6 + 0.4 * math.sin(time * 8 + 4.2) }
	end
	local pop = 1 + 0.5 * math.max(0, 1 - age * 6)
	local scale = 1.5 * pop
	local width = assets.font:getWidth(e.text) * scale
	local x, y = e.x - (width + 36) / 2, e.y - 60 * u
	local fade = 1 - u * u
	local ix, iy = x + 14, y + assets.font:getHeight() * scale / 2
	lg.setBlendMode("add") -- a glow behind the icon
	lg.setColor(c[1], c[2], c[3], 0.35 * fade)
	lg.circle("fill", ix, iy, 26 + 20 * (1 - u))
	lg.setBlendMode("alpha")
	local burst = e.style.burst
	if burst == "ring" then
		lg.setLineWidth(5 * (1 - u))
		lg.setColor(c[1], c[2], c[3], fade)
		lg.circle("line", e.x, e.y, 20 + 90 * u)
		lg.setLineWidth(1)
	elseif burst == "sparkle" then
		for k = 0, 5 do
			local a = k * 1.047 + 0.4
			local d = (30 + 40 * (k % 2)) * u + 10
			local sx, sy = ix + math.cos(a) * d, iy + math.sin(a) * d - 20 * u
			lg.setColor(1, 1, 0.85, fade)
			lg.rectangle("fill", sx - 1.5, sy - 6, 3, 12)
			lg.rectangle("fill", sx - 6, sy - 1.5, 12, 3)
		end
	elseif burst == "drip" then
		for k = 0, 3 do
			lg.setColor(c[1], c[2], c[3], fade)
			lg.circle("fill", ix - 18 + k * 12, iy + 10 + 40 * u * (0.6 + 0.2 * k), 4 * (1 - u))
		end
	end
	lg.setColor(0, 0, 0, fade) -- icon outline, then the icon
	lg.push()
	lg.translate(ix, iy)
	lg.scale(1.25 * pop)
	ICONS[e.style.icon](0, 0)
	lg.pop()
	lg.setColor(c[1], c[2], c[3], fade)
	lg.push()
	lg.translate(ix, iy)
	lg.scale(pop)
	ICONS[e.style.icon](0, 0)
	lg.pop()
	lg.setColor(0, 0, 0, fade)
	lg.print(e.text, assets.font, x + 36 + 3, y + 3, 0, scale)
	lg.setColor(c[1], c[2], c[3], fade)
	lg.print(e.text, assets.font, x + 36, y, 0, scale)
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
			elseif e.kind == "spotlight" then -- an opponent snake seen for the first time: the card close up on the left, its stats and ability on the right
				local data = require("CardData")
				local st = data.get_stats(e.card)
				local fade = math.min(age / 0.25, (LIFE.spotlight - age) / 0.4, 1)
				local slide = (1 - math.min(age / 0.3, 1)) * 120
				lg.setColor(0, 0, 0, 0.6 * fade)
				lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
				lg.push()
				lg.setColor(1, 1, 1, fade)
				e.card:draw(110 - slide, 110, 0, 2)
				lg.pop()
				local px, py, pw, ph = 600, 190, 760, 440
				lg.setColor(0.07, 0.04, 0.14, 0.95 * fade)
				lg.rectangle("fill", px + slide, py, pw, ph, 14, 14)
				lg.setColor(1, 0.85, 0.2, fade)
				lg.rectangle("line", px + slide, py, pw, ph, 14, 14)
				lg.setColor(1, 1, 1, fade)
				lg.print((e.card.card_path:sub(1, -5):gsub("_", " ")), assets.font, px + 35 + slide, py + 25)
				lg.setColor(0.4, 0.85, 0.4, fade)
				lg.print("Cost " .. st.cost, assets.small_font, px + 35 + slide, py + 130)
				lg.setColor(1, 0.4, 0.4, fade)
				lg.print("Attack " .. st.attack, assets.small_font, px + 235 + slide, py + 130)
				lg.setColor(0.45, 0.6, 1, fade)
				lg.print("Health " .. st.defense, assets.small_font, px + 465 + slide, py + 130)
				lg.setColor(1, 0.85, 0.2, fade)
				lg.print("Ability", assets.small_font, px + 35 + slide, py + 205)
				lg.setColor(1, 1, 1, fade)
				lg.printf(st.ability or "None", assets.small_font, px + 35 + slide, py + 255, pw - 70)
			elseif e.kind == "callout" then -- who did what: a ring bursting from the snake and a label above it
				local u = math.min(age / LIFE.callout, 1)
				local c = e.colour or { 1, 0.85, 0.3 }
				lg.setLineWidth(7 * (1 - u))
				lg.setColor(c[1], c[2], c[3], 1 - u)
				lg.circle("line", e.cx, e.cy, 20 + 150 * math.min(u * 1.6, 1))
				lg.setLineWidth(1)
				if not e.text then -- (an ability use is a ring and sparks in its colour, with no label)
					sparks(e.cx, e.cy, u, 10, c, 150)
				else
					local font = assets.small_font
					local w = font:getWidth(e.text) + 30
					local x, y = math.max(10, math.min(e.cx - w / 2, reference_window_width - w - 10)), math.max(10, e.cy - 150 - 12 * u)
					local fade = u < 0.8 and 1 or (1 - u) / 0.2
					lg.setColor(0, 0, 0, 0.8 * fade)
					lg.rectangle("fill", x, y, w, 34, 8, 8)
					lg.setColor(c[1], c[2], c[3], fade)
					lg.rectangle("line", x, y, w, 34, 8, 8)
					lg.setColor(1, 1, 1, fade)
					lg.print(e.text, font, x + 15, y + 5)
				end
			elseif e.kind == "float" and e.style then
				styled_float(e, age)
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
