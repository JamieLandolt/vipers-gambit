local love = require("love")
local lg = love.graphics
local data = require("CardData")

-- The name written in the text panel of a card, in card-image units (165 x 320, panel from y = 190).
-- Abilities are not printed on the card: they are on the info page and the hover tooltip.
-- The name is drawn with a font made at its real on-screen size, at whole pixels. Scaling a pixel font up or down
-- smears it and drops its thin lines, so the font size changes with the card instead.
local cardtext = {}

local NAME_SIZE = 24 -- font size in card units
local fonts = {}

local function font_at(size)
	size = math.max(8, math.floor(size + 0.5))
	fonts[size] = fonts[size] or lg.newFont("assets/Jersey15-Regular.ttf", size, "none") -- (no hinting: it stripes the pixel font at some sizes)
	return fonts[size]
end

-- Screen pixels per card unit right now
local function unit()
	local x0 = lg.transformPoint(0, 0)
	return lg.transformPoint(1, 0) - x0
end

-- Prints text at whole pixels with a dark outline, using a font made at its real screen size. (x, y) is the middle of
-- the text, or its left or right edge at the middle height when `align` is "left" or "right". Returns the text's width in card units.
local function print_at(text, size, x, y, colour, align)
	local k = unit()
	local font = font_at(size * k)
	local width = font:getWidth(text)
	local sx, sy = lg.transformPoint(x, y)
	sx = sx - (align == "left" and 0 or align == "right" and width or width / 2)
	sx, sy = math.floor(sx + 0.5), math.floor(sy - font:getHeight() / 2 + 0.5)
	lg.push()
	lg.origin()
	lg.setColor(0, 0, 0, 0.85)
	for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
		lg.print(text, font, sx + d[1], sy + d[2])
	end
	lg.setColor(colour)
	lg.print(text, font, sx, sy)
	lg.pop()
	return width / k
end

-- The small icons are 16 card units tall; (x, y) is the top left
local function sword(x, y)
	lg.setColor(0, 0, 0, 0.85)
	lg.rectangle("fill", x + 5, y - 1, 6, 15)
	lg.rectangle("fill", x + 1, y + 10, 14, 6)
	lg.setColor(0.85, 0.88, 0.95)
	lg.rectangle("fill", x + 6, y, 4, 11)
	lg.setColor(0.9, 0.7, 0.2)
	lg.rectangle("fill", x + 2, y + 11, 12, 3)
	lg.rectangle("fill", x + 6, y + 14, 4, 2)
end

local function heart(x, y)
	for pass = 1, 2 do
		local g = pass == 1 and 1.5 or 0
		lg.setColor(pass == 1 and { 0, 0, 0, 0.85 } or { 0.92, 0.22, 0.3 })
		lg.circle("fill", x + 4.5, y + 4.5, 4.5 + g)
		lg.circle("fill", x + 11.5, y + 4.5, 4.5 + g)
		lg.polygon("fill", x - g, y + 6, x + 16 + g, y + 6, x + 8, y + 16 + g)
	end
end

local function drop(x, y) -- a venom drop
	for pass = 1, 2 do
		local g = pass == 1 and 1.5 or 0
		lg.setColor(pass == 1 and { 0, 0, 0, 0.85 } or { 0.45, 0.85, 0.25 })
		lg.circle("fill", x + 8, y + 10, 6 + g)
		lg.polygon("fill", x + 8, y - 1 - g, x + 2 - g, y + 8, x + 14 + g, y + 8)
	end
	lg.setColor(0.8, 1, 0.6, 0.8)
	lg.circle("fill", x + 6, y + 9, 1.5)
end

local STAR = {} -- a five-point star in a 16 x 16 box, as triangles (a star is concave, so it cannot be filled in one piece)
do
	local points = {}
	for i = 0, 9 do
		local radius, angle = i % 2 == 0 and 8 or 3.4, (i * 36 - 90) * math.pi / 180
		points[#points + 1], points[#points + 2] = 8 + radius * math.cos(angle), 8.5 + radius * math.sin(angle)
	end
	STAR = love.math.triangulate(points)
end

local function star(x, y)
	for pass = 1, 2 do
		lg.push()
		lg.translate(x + 8, y + 8)
		lg.scale(pass == 1 and 1.25 or 1)
		lg.translate(-8, -8)
		lg.setColor(pass == 1 and { 0, 0, 0, 0.85 } or { 1, 0.82, 0.2 })
		for _, triangle in ipairs(STAR) do
			lg.polygon("fill", triangle)
		end
		lg.pop()
	end
end

cardtext.star = star -- also used for the pack odds

local RED, BLUE, GREEN = { 1, 0.45, 0.4 }, { 0.6, 0.7, 1 }, { 0.6, 0.9, 0.35 }

-- A sword and the attack, bottom left; a heart and the defense, bottom right. `left` and `right` are the x positions of
-- the padded edges, `top` the y of the icons
local function stats_row(attack, defense, left, right, top)
	sword(left, top)
	print_at(tostring(attack), 30, left + 22, top + 9, RED, "left")
	local width = print_at(tostring(defense), 30, right, top + 9, BLUE, "right")
	heart(right - width - 22, top)
end

-- A drop and the venom cost, top left; the rarity and a star, top right
local function top_row(cost, rarity, left, right, top)
	drop(left, top)
	print_at(tostring(cost), 34, left + 22, top + 9, GREEN, "left")
	local width = print_at(tostring(rarity), 34, right, top + 9, { 1, 0.85, 0.3 }, "right")
	star(right - width - 22, top)
end

-- Attack and defense on a field lane (a 210 x 240 cell whose top left is (x, y)), in its bottom corners
function cardtext.lane(attack, defense, x, y)
	stats_row(attack, defense, x + 10, x + 200, y + 240 - 10 - 16)
end

function cardtext.draw(name, x, y)
	local st = data.stats_by_name[name]
	top_row(st.cost, st.rarity, x + 14, x + 151, y + 14)
	if st.kind == "snake" then
		stats_row(st.attack, st.defense, x + 14, x + 151, y + 320 - 14 - 16)
	end
	lg.setColor(0, 0, 0, 0.45)
	lg.rectangle("fill", x + 11, y + 192, 143, 30, 4, 4)
	lg.setColor(1, 1, 1)
	local title = name:gsub("_", " ")
	local k = unit()
	local size = NAME_SIZE * k
	local font = font_at(size)
	while font:getWidth(title) > 139 * k and size > 8 do -- long names get a smaller font to stay on one line
		size = size - 1
		font = font_at(size)
	end
	local sx, sy = lg.transformPoint(x + 82.5, y + 193 + (NAME_SIZE * k - font:getHeight()) / k / 2)
	lg.push()
	lg.origin()
	lg.print(title, font, math.floor(sx - font:getWidth(title) / 2 + 0.5), math.floor(sy + 0.5))
	lg.pop()
end

return cardtext
