local love = require("love")
local lg = love.graphics

-- Each snake type gives its lane a look of its own. A lane that takes two types shows both, split down the middle.
local lanes = {}

local function rect(r, g, b, a, x, y, w, h)
	lg.setColor(r, g, b, a)
	lg.rectangle("fill", x, y, w, h)
end

-- Deterministic scatter so decorations stay put between frames
local function scatter(i, x, y, size)
	return math.floor(x + (i * 47 + y) % size)
end

local looks = {
	Land = function(x, y, w, h)
		rect(0.8, 0.6, 0.3, 0.35, x, y, w, h)
		for i = 1, 16 do
			local size = i % 4 == 0 and 8 or 4
			local grey = i % 4 == 0
			rect(grey and 0.55 or 0.95, grey and 0.5 or 0.8, grey and 0.5 or 0.5, 0.75, scatter(i, x, y, w - size), scatter(i * 3, y, x, h - size), size, size)
		end
	end,

	Water = function(x, y, w, h)
		rect(0.2, 0.5, 0.95, 0.3, x, y, w, h)
		for row = 0, math.floor(h / 22) - 1 do
			for seg = 0, math.floor(w / 10) - 1 do
				local wave = math.sin(seg * 0.6 + time * 2 + row) * 3
				rect(0.7, 0.9, 1, 0.45, x + seg * 10, y + 14 + row * 22 + wave, 10, 3)
			end
		end
	end,

	Tree = function(x, y, w, h)
		rect(0.25, 0.7, 0.3, 0.28, x, y, w, h)
		for col = 0, math.floor(w / 26) - 1 do
			for seg = 0, math.floor(h / 6) - 1 do
				local sway = math.sin(time * 1.5 + seg * 0.25 + col) * 3
				rect(0.1, 0.4, 0.15, 0.55, x + 13 + col * 26 + sway, y + seg * 6, 4, 6)
			end
		end
		for i = 1, 10 do
			rect(0.55, 0.9, 0.4, 0.55, scatter(i, x, y, w - 6), scatter(i * 5, y, x, h - 6), 6, 6)
		end
	end,

	Spirit = function(x, y, w, h)
		rect(0.6, 0.4, 0.95, 0.35, x, y, w, h)
		for i = 1, 14 do
			local phase = (time * 0.2 + i / 14) % 1
			local size = 10 * (1 - phase) + 3
			rect(0.9, 0.85, 1, (1 - phase) * 0.85, scatter(i, x, y, w - 8) + math.sin(phase * 6 + i) * 8, y + h - phase * h, size, size)
		end
	end,
}

local ORDER = { "Land", "Water", "Tree", "Spirit" }

-- Draws a lane's look inside one field sector (box is play.field_hitboxes[n]; lane is its set of accepted types)
function lanes.draw(box, lane)
	local x, y, w, h = box[1] + 20, box[2] + 20, box[3] - 30, box[4] - 30
	local types = {}
	for _, snake_type in ipairs(ORDER) do
		if lane[snake_type] then
			table.insert(types, snake_type)
		end
	end
	local half = math.floor(w / 2)
	looks[types[1]](x, y, half, h)
	looks[types[2]](x + half, y, w - half, h)
	lg.setColor(1, 1, 1)
end

return lanes
