local love = require("love")
local lg = love.graphics

-- The Lanes screen: each of the 4 lanes takes two snake types. Drag a type onto another to swap them.
local lane_editor = {}

local COLOURS = { Land = { 0.85, 0.62, 0.3 }, Water = { 0.3, 0.6, 1 }, Tree = { 0.3, 0.75, 0.35 }, Spirit = { 0.7, 0.5, 1 } }
local LANE_W, CHIP_H = 290, 100
local drag -- { lane, slot } of the chip being dragged

-- Lane terrain: Lane_Tiles.png holds every (left type, right type) pair, drawn by tools/draw_field.py atlas
local TYPE_INDEX = { Land = 0, Water = 1, Tree = 2, Spirit = 3 }
local TILE_W, TILE_H = 210, 240
local quads = {}

-- Draws the terrain for a lane whose left half is `left` and right half is `right` (row 1 or 2)
function lane_editor.draw_tile(left, right, row, x, y, scale)
	local assets = require("Assets")
	local key = left .. right .. row
	quads[key] = quads[key] or lg.newQuad((TYPE_INDEX[left] * 2 + row - 1) * TILE_W, TYPE_INDEX[right] * TILE_H, TILE_W, TILE_H, assets.lane_tiles)
	lg.setColor(1, 1, 1)
	lg.draw(assets.lane_tiles, quads[key], x, y, 0, scale or 1)
end

local function chip_box(lane, slot)
	return 110 + (lane - 1) * 330, 250 + (slot - 1) * 130, LANE_W, CHIP_H
end

-- The lane and slot of the chip at a reference-space position
local function chip_at(rx, ry)
	for lane = 1, 4 do
		for slot = 1, 2 do
			local x, y, w, h = chip_box(lane, slot)
			if rx >= x and rx <= x + w and ry >= y and ry <= y + h then
				return lane, slot
			end
		end
	end
end

local function reference(x, y)
	return x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
end

function lane_editor.press(x, y)
	local lane, slot = chip_at(reference(x, y))
	drag = lane and { lane, slot }
end

function lane_editor.release(x, y)
	if not drag then
		return
	end
	local lane, slot = chip_at(reference(x, y))
	if lane and (lane ~= drag[1] or slot ~= drag[2]) then
		require("Play").swap_lane_types(drag[1], drag[2], lane, slot)
		play_sound(hover_sound)
	end
	drag = nil
end

local function chip(snake_type, x, y, w, h, alpha)
	local c = COLOURS[snake_type]
	lg.setColor(c[1], c[2], c[3], alpha)
	lg.rectangle("fill", x, y, w, h, 10, 10)
	lg.setColor(1, 1, 1, alpha)
	lg.setLineWidth(4)
	lg.rectangle("line", x, y, w, h, 10, 10)
	lg.setLineWidth(1)
	lg.setColor(0, 0, 0, alpha)
	lg.printf(snake_type, require("Assets").font, x, y + h / 2 - 25, w, "center")
end

function lane_editor.draw()
	local assets, play = require("Assets"), require("Play")
	local rx, ry = reference(mouse.x, mouse.y)
	if drag and not love.mouse.isDown(1) then
		drag = nil
	end

	lg.setColor(1, 1, 1)
	lg.printf("Customise Lanes", assets.font, 0, 25, reference_window_width, "center")
	lg.printf("Drag a lane type onto another to swap them. You and your opponent both play by these lanes; Rainbow snakes fit anywhere.", assets.small_font, 150, 95, reference_window_width - 300, "center")

	local hover_lane, hover_slot = chip_at(rx, ry)
	for lane = 1, 4 do
		local x = chip_box(lane, 1)
		lg.setColor(1, 1, 1)
		lg.printf("Lane " .. lane, assets.small_font, x, 200, LANE_W, "center")
		for slot = 1, 2 do
			local cx, cy, w, h = chip_box(lane, slot)
			local dragged = drag and drag[1] == lane and drag[2] == slot
			chip(play.lane_chips[lane][slot], cx, cy, w, h, dragged and 0.25 or (hover_lane == lane and hover_slot == slot and 1 or 0.85))
		end
	end
	for lane = 1, 4 do -- a small preview of each lane's terrain: the top type is the left half
		local x = chip_box(lane, 1)
		lane_editor.draw_tile(play.lane_chips[lane][1], play.lane_chips[lane][2], 1, x + (LANE_W - 126) / 2, 470, 0.6)
	end
	if drag then
		chip(play.lane_chips[drag[1]][drag[2]], rx - LANE_W / 2, ry - CHIP_H / 2, LANE_W, CHIP_H, 0.95)
	end

	-- How many snakes of each type are in the deck, so the lanes can be matched to it
	local counts = { Land = 0, Water = 0, Tree = 0, Spirit = 0, Rainbow = 0 }
	local data = require("CardData")
	for _, name in ipairs(require("Collection").deck()) do
		local kind = data.card_types[name]
		if counts[kind] then -- (brews and spells have no lane)
			counts[kind] = counts[kind] + 1
		end
	end
	lg.setColor(1, 1, 1)
	lg.printf(("Your deck: %d Land, %d Water, %d Tree, %d Spirit, %d Rainbow"):format(counts.Land, counts.Water, counts.Tree, counts.Spirit, counts.Rainbow), assets.small_font, 0, 640, reference_window_width, "center")
	lg.setColor(1, 1, 1)
end

return lane_editor
