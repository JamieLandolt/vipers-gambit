local love = require("love")
local lg = love.graphics

-- Every card has a border; each one gives the snake a different passive effect (applied in Play.lua).
local borders = {
	Basic = { text = "No special effect" },
	Venom = { colour = { 0.45, 0.9, 0.2 }, text = "Poison: its hits poison the target for 2 turns (-1 defense each turn)" },
	Fire = { colour = { 1, 0.5, 0.1 }, text = "Scorch: damage beyond a kill hits the owner's health 1.5x (rounded up)" },
	Shadow = { colour = { 0.65, 0.35, 0.95 }, text = "Shrouded: 1.5x defense (rounded up)" },
	Rainbow = { text = "Prismatic: gains +1 attack and +1 defense every turn" },
	Stone = { colour = { 0.65, 0.65, 0.7 }, text = "Fortified: takes 2 less damage from every hit" },
	-- Support cards (brews and spells) have their own frames: a double line with flask-shaped or star-shaped corners
	Brew = { colour = { 0.3, 0.95, 0.7 }, text = "Support: a brew, drunk by one of your snakes" },
	Spell = { colour = { 0.5, 0.65, 1 }, text = "Support: a spell, cast over the field" },
}

-- The clock the border animations run on (frozen by the Reduce motion setting)
local function now()
	return reduce_motion and 1.3 or time
end

function borders.text(name)
	return borders[name].text
end

-- "Shadow border (Shrouded): 1.5x defense (rounded up)"
function borders.describe(name)
	local effect, rest = borders[name].text:match("^(.-): (.*)$")
	return effect and (name .. " border (" .. effect .. "): " .. rest) or (name .. " border: " .. borders[name].text)
end

local function colour(name)
	if name == "Rainbow" then
		local t = now() * 1.5
		return { 0.6 + 0.4 * math.sin(t), 0.6 + 0.4 * math.sin(t + 2.1), 0.6 + 0.4 * math.sin(t + 4.2) }
	end
	return borders[name].colour
end

-- Legendary (T5) presentation: holographic sweep shader, orbiting glow, thick prismatic frame, pixel sparkles
local HOLO = [[
extern number t;
extern vec4 rect;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
vec4 effect(vec4 col, Image tex, vec2 uv, vec2 sc) {
	vec2 p = floor((sc - rect.xy) / 4.0) / (rect.zw / 4.0);
	float d = p.x * 0.7 + p.y * 0.5;
	float band = floor(fract(d * 1.5 - t * 0.25) * 6.0) / 6.0;
	vec3 c = hue(band) * 0.11;
	float sweep = fract(d * 0.8 - t * 0.35);
	float streak = step(0.0, 0.07 - abs(sweep - 0.5)) * 0.28 + step(0.0, 0.02 - abs(sweep - 0.5)) * 0.2;
	return vec4(c + vec3(streak), 1.0) * col;
}
]]
local shader, shaderFailed

local function hue(h)
	return 0.55 + 0.45 * math.sin(h * 6.283), 0.55 + 0.45 * math.sin(h * 6.283 + 2.094), 0.55 + 0.45 * math.sin(h * 6.283 + 4.189)
end

local function rnd(n)
	local v = math.sin(n * 12.9898) * 43758.5453
	return v - math.floor(v)
end

local function legendary(x, y, w, h)
	local oldR, oldG, oldB, oldA = lg.getColor()
	local oldBlend, oldAlpha = lg.getBlendMode()
	local oldLine, oldShader = lg.getLineWidth(), lg.getShader()
	local t = now()

	-- holographic sweep (additive), inside the card
	lg.setBlendMode("add")
	if not shader and not shaderFailed then
		local ok, s = pcall(lg.newShader, HOLO)
		if ok then
			shader = s
		else
			shaderFailed = true
		end
	end
	if shader then
		-- the game draws under lg.scale, so convert to screen pixels for the shader's pixel coordinates
		local px, py = lg.transformPoint(x, y)
		local qx, qy = lg.transformPoint(x + w, y + h)
		shader:send("t", t)
		shader:send("rect", { px, py, qx - px, qy - py })
		lg.setShader(shader)
		lg.setColor(1, 1, 1, 1)
		lg.rectangle("fill", x + 2, y + 2, w - 4, h - 4)
		lg.setShader()
	else
		local sy = ((t * 0.4) % 1.4 - 0.2) * h
		lg.setColor(1, 0.9, 0.6, 0.12)
		lg.rectangle("fill", x + 2, math.max(y + 2, y + sy - 12), w - 4, 24)
	end

	-- outer glow: a few pixels of rings plus lights chasing round the perimeter
	local pulse = 0.5 + 0.5 * math.sin(t * 2)
	lg.setLineWidth(1)
	for i = 1, 4 do
		lg.setColor(1, 0.85, 0.3, (0.3 - i * 0.06) * (0.6 + 0.4 * pulse))
		lg.rectangle("line", x - i + 0.5, y - i + 0.5, w + 2 * i - 1, h + 2 * i - 1)
	end
	local per, n = 2 * (w + h), 10
	for i = 0, n - 1 do
		local d = ((i / n) + t * 0.08) % 1 * per
		local px, py
		if d < w then
			px, py = x + d, y - 3
		elseif d < w + h then
			px, py = x + w, y + d - w
		elseif d < 2 * w + h then
			px, py = x + w - (d - w - h), y + h
		else
			px, py = x - 3, y + h - (d - 2 * w - h)
		end
		local r, g, b = hue(i / n + t * 0.1)
		lg.setColor(r, g, b, 0.6)
		lg.rectangle("fill", math.floor(px), math.floor(py), 3, 3)
	end

	-- thick frame: gold base with a prismatic inner band
	lg.setBlendMode("alpha")
	lg.setLineWidth(5)
	lg.setColor(1, 0.8 + 0.1 * pulse, 0.2, 1)
	lg.rectangle("line", x + 3.5, y + 3.5, w - 7, h - 7)
	local seg = 8
	for i = 0, math.floor((w - 12) / seg) - 1 do
		local r, g, b = hue(i * 0.07 - t * 0.4)
		lg.setColor(r, g, b, 1)
		lg.rectangle("fill", x + 6 + i * seg, y + 6, seg, 2)
		lg.rectangle("fill", x + 6 + i * seg, y + h - 8, seg, 2)
	end
	for i = 0, math.floor((h - 12) / seg) - 1 do
		local r, g, b = hue(i * 0.07 + 0.5 - t * 0.4)
		lg.setColor(r, g, b, 1)
		lg.rectangle("fill", x + 6, y + 6 + i * seg, 2, seg)
		lg.rectangle("fill", x + w - 8, y + 6 + i * seg, 2, seg)
	end
	lg.setColor(1, 1, 1, 0.9)
	for _, c in ipairs({ { 2, 2 }, { w - 8, 2 }, { 2, h - 8 }, { w - 8, h - 8 } }) do
		lg.rectangle("fill", x + c[1], y + c[2], 6, 6)
	end

	-- twinkling square sparkles at deterministic spots
	lg.setBlendMode("add")
	local seed = x * 0.37 + y * 0.71
	for i = 1, 9 do
		local base = t * 0.6 + rnd(seed + i)
		local ph, cycle = base % 1, math.floor(base)
		local sx = x + 8 + math.floor(rnd(seed + i * 7.1 + cycle) * (w - 16))
		local sy = y + 8 + math.floor(rnd(seed + i * 3.3 + cycle * 1.7) * (h - 16))
		local s = math.sin(ph * math.pi)
		local arm = math.floor(s * 5)
		if arm > 0 then
			lg.setColor(1, 1, 0.85, s)
			lg.rectangle("fill", sx - arm, sy, arm * 2 + 1, 1)
			lg.rectangle("fill", sx, sy - arm, 1, arm * 2 + 1)
			lg.setColor(1, 1, 1, s)
			lg.rectangle("fill", sx - 1, sy - 1, 3, 3)
		end
	end

	lg.setShader(oldShader)
	lg.setBlendMode(oldBlend, oldAlpha)
	lg.setLineWidth(oldLine)
	lg.setColor(oldR, oldG, oldB, oldA)
end

-- Frame drawn just inside the card's edge; the corners pulse so each border reads at a glance.
-- tier (rarity, optional): 5 adds the legendary treatment on top.
-- The support frame: a double line, with a round flask corner for brews and a four-point star for spells
local function support(name, x, y, w, h)
	local c, pulse = colour(name), 0.5 + 0.5 * math.sin(now() * 3)
	lg.setColor(c[1], c[2], c[3], 0.8 + 0.2 * pulse)
	lg.setLineWidth(3)
	lg.rectangle("line", x + 3, y + 3, w - 6, h - 6, 10, 10)
	lg.setLineWidth(1)
	lg.setColor(c[1], c[2], c[3], 0.45)
	lg.rectangle("line", x + 9, y + 9, w - 18, h - 18, 6, 6)
	lg.setColor(c[1], c[2], c[3], 0.7 + 0.3 * pulse)
	for _, corner in ipairs({ { 9, 9 }, { w - 9, 9 }, { 9, h - 9 }, { w - 9, h - 9 } }) do
		local cx, cy = x + corner[1], y + corner[2]
		if name == "Brew" then
			lg.circle("fill", cx, cy, 6)
		else
			lg.polygon("fill", cx, cy - 8, cx + 3, cy - 3, cx + 8, cy, cx + 3, cy + 3, cx, cy + 8, cx - 3, cy + 3, cx - 8, cy, cx - 3, cy - 3)
		end
	end
	lg.setColor(1, 1, 1)
end

-- Each border is drawn as the thing it stands for, using a few shapes along the card's edges
local function along(x, y, w, h, step, fn)
	local i = 0
	for px = x + 16, x + w - 16, step do
		i = i + 1
		fn(px, y + 3, 0, 1, i)
		fn(px, y + h - 3, 0, -1, i + 50)
	end
	for py = y + 16, y + h - 16, step do
		i = i + 1
		fn(x + 3, py, 1, 0, i + 100)
		fn(x + w - 3, py, -1, 0, i + 150)
	end
end

local function spike(px, py, dx, dy, base, len)
	local tx, ty = math.abs(dy), math.abs(dx)
	lg.polygon("fill", px - tx * base, py - ty * base, px + tx * base, py + ty * base, px + dx * len, py + dy * len)
end

local CORNER = 18 -- matches the corner radius cut into the card art (tools/recolour_cards.py uses 20)

local THEMES = {
	Basic = function(x, y, w, h, t)
		lg.setColor(0.55, 0.5, 0.42)
		lg.setLineWidth(2)
		lg.rectangle("line", x + 3, y + 3, w - 6, h - 6, 4, 4)
	end,
	Venom = function(x, y, w, h, t) -- toxic green frame: slime dripping from the top, bubbles rising from the bottom
		lg.setColor(0.15, 0.45, 0.1)
		lg.setLineWidth(5)
		lg.rectangle("line", x + 3, y + 3, w - 6, h - 6, CORNER, CORNER)
		lg.setColor(0.45, 0.9, 0.15)
		for i = 1, 6 do
			local px = x + 22 + (i - 1) * (w - 44) / 5
			local len = 10 + 16 * (0.5 + 0.5 * math.sin(t * 1.2 + i * 2.3))
			lg.setLineWidth(4)
			lg.line(px, y + 4, px, y + 4 + len)
			lg.circle("fill", px, y + 4 + len, 5)
		end
		lg.setLineWidth(1.5)
		lg.setColor(0.7, 1, 0.4)
		for i = 1, 7 do
			local rise = (t * 0.35 + rnd(i)) % 1
			local bx = x + 16 + rnd(i * 3.7) * (w - 32) + 3 * math.sin(t * 3 + i)
			lg.circle("line", bx, y + h - 8 - rise * 40, 2 + 3 * rnd(i * 1.3))
		end
	end,
	Fire = function(x, y, w, h, t) -- flames licking up the card
		lg.setColor(0.7, 0.15, 0.05)
		lg.setLineWidth(4)
		lg.rectangle("line", x + 3, y + 3, w - 6, h - 6, CORNER, CORNER)
		along(x, y, w, h, 14, function(px, py, dx, dy, i)
			local len = 11 + 8 * math.sin(t * 7 + i * 1.9)
			lg.setColor(1, 0.4, 0.05)
			spike(px, py, dx, dy, 7, len)
			lg.setColor(1, 0.85, 0.2)
			spike(px, py, dx, dy, 3.5, len * 0.6)
		end)
	end,
	Shadow = function(x, y, w, h, t) -- a black frame with writhing tendrils and watching eyes
		lg.setColor(0.04, 0.02, 0.08)
		lg.setLineWidth(9)
		lg.rectangle("line", x + 4, y + 4, w - 8, h - 8, CORNER, CORNER)
		lg.setColor(0.4, 0.15, 0.65, 0.9)
		lg.setLineWidth(3)
		for i = 1, 14 do
			local pts = {}
			local side = i % 4
			local base = 20 + rnd(i * 2.1) * ((side < 2 and w or h) - 40)
			for k = 0, 12 do
				local d = k * 5
				local sway = 8 * math.sin(t * 2 + i + k * 0.7)
				if side == 0 then
					pts[#pts + 1], pts[#pts + 2] = x + base + sway, y + 4 + d
				elseif side == 1 then
					pts[#pts + 1], pts[#pts + 2] = x + base + sway, y + h - 4 - d
				elseif side == 2 then
					pts[#pts + 1], pts[#pts + 2] = x + 4 + d, y + base + sway
				else
					pts[#pts + 1], pts[#pts + 2] = x + w - 4 - d, y + base + sway
				end
			end
			lg.line(pts)
		end
		local blink = (math.sin(t * 1.3) > 0.9) and 0.2 or 1
		for _, ex in ipairs({ w / 2 - 22, w / 2 + 22 }) do
			lg.setColor(0.8, 0.3, 1)
			lg.ellipse("fill", x + ex, y + 26, 9, 5 * blink)
			lg.setColor(0, 0, 0)
			lg.ellipse("fill", x + ex, y + 26, 2.5, 5 * blink)
		end
	end,
	Rainbow = function(x, y, w, h, t) -- a band of shifting colours
		local seg = 8
		for i = 0, math.floor((w - 8) / seg) - 1 do
			lg.setColor(hue(i * 0.07 - t * 0.4))
			lg.rectangle("fill", x + 4 + i * seg, y + 3, seg, 6)
			lg.rectangle("fill", x + 4 + i * seg, y + h - 9, seg, 6)
		end
		for i = 0, math.floor((h - 8) / seg) - 1 do
			lg.setColor(hue(i * 0.07 + 0.5 - t * 0.4))
			lg.rectangle("fill", x + 3, y + 4 + i * seg, 6, seg)
			lg.rectangle("fill", x + w - 9, y + 4 + i * seg, 6, seg)
		end
	end,
	Stone = function(x, y, w, h, t) -- a wall of grey bricks
		local bw, bt = 22, 9
		local function brick(bx, by, bw2, bh, i)
			local g = 0.45 + 0.2 * rnd(i)
			lg.setColor(g, g, g + 0.04)
			lg.rectangle("fill", bx, by, bw2, bh)
			lg.setColor(0.18, 0.18, 0.2)
			lg.setLineWidth(1)
			lg.rectangle("line", bx + 0.5, by + 0.5, bw2 - 1, bh - 1)
		end
		local i = 0
		for px = x, x + w - 1, bw do
			i = i + 1
			local bw2 = math.min(bw, x + w - px)
			brick(px, y, bw2, bt, i)
			brick(px, y + h - bt, bw2, bt, i + 40)
		end
		for py = y + bt, y + h - bt - 1, bw do
			i = i + 1
			local bh = math.min(bw, y + h - bt - py)
			brick(x, py, bt, bh, i)
			brick(x + w - bt, py, bt, bh, i + 40)
		end
	end,
}

function borders.draw(name, x, y, w, h, tier)
	if name == "Brew" or name == "Spell" then
		support(name, x, y, w, h)
		return
	end
	if THEMES[name] then
		-- everything is clipped to the card's rounded outline
		lg.stencil(function() lg.rectangle("fill", x, y, w, h, CORNER + 2, CORNER + 2) end, "replace", 1, true)
		lg.setStencilTest("greater", 0)
		THEMES[name](x, y, w, h, now())
		lg.setStencilTest()
		lg.setLineWidth(1)
		lg.setColor(1, 1, 1)
	end
	if tier == 5 then
		legendary(x, y, w, h)
	end
end

-- The border's colour right now (animated for Rainbow), or nil for Basic; used for glowing outlines on the board
function borders.colour(name)
	return name ~= "Basic" and borders[name] and colour(name) or nil
end

return borders
