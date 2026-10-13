local love = require("love")
local lg = love.graphics

-- Every card has a border; each one gives the snake a different passive effect (applied in Play.lua).
local borders = {
	Basic = { text = "No special effect" },
	Venom = { colour = { 0.45, 0.9, 0.2 }, text = "Poison: its hits poison the target for 2 turns (-1 defense each turn)" },
	Fire = { colour = { 1, 0.5, 0.1 }, text = "Scorch: damage beyond a kill carries through to the owner's health" },
	Frost = { colour = { 0.5, 0.85, 1 }, text = "Chill: snakes it hits can't attack on their next turn" },
	Shadow = { colour = { 0.65, 0.35, 0.95 }, text = "Phantom: ignores the first hit it takes" },
	Gold = { colour = { 1, 0.85, 0.2 }, text = "Wealth: +1 venom each turn while on the field" },
	Rainbow = { text = "Prismatic: gains +1 attack and +1 defense every turn" },
}

function borders.text(name)
	return borders[name].text
end

local function colour(name)
	if name == "Rainbow" then
		local t = time * 1.5
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
	local t = time

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
function borders.draw(name, x, y, w, h, tier)
	if borders[name] and name ~= "Basic" then
		local c, pulse = colour(name), 0.5 + 0.5 * math.sin(time * 4)
		lg.setColor(c[1], c[2], c[3], 0.75 + 0.25 * pulse)
		lg.setLineWidth(5)
		lg.rectangle("line", x + 3, y + 3, w - 6, h - 6)
		lg.setColor(c[1], c[2], c[3], 0.4 + 0.5 * pulse)
		for _, corner in ipairs({ { 3, 3 }, { w - 3, 3 }, { 3, h - 3 }, { w - 3, h - 3 } }) do
			lg.circle("fill", x + corner[1], y + corner[2], 7)
		end
		lg.setLineWidth(1)
		lg.setColor(1, 1, 1)
	end
	if tier == 5 then
		legendary(x, y, w, h)
	end
end

return borders
