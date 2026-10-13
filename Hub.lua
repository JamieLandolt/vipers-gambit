local love = require("love")
local lg = love.graphics

-- The main menu: a snake-infested temple (Play) with an icon for each other screen around it, and the chosen
-- charmer standing beside it. Positions are in reference-window units (x = centre, y = the sprite's bottom).
local collection = require("Collection")
local hub = { popup = false }

local ITEMS = {
	{ id = "play", sprite = "temple", x = 780, y = 745, scale = 0.9, label = "Play", state = "level_select" },
	{ id = "charmer", x = 400, y = 765, scale = 0.55, label = "Charmer", state = "character_select" },
	{ id = "packs", sprite = "chest", x = 215, y = 470, scale = 0.75, label = "Packs", state = "shop", float = true },
	{ id = "book", sprite = "book", x = 1180, y = 400, scale = 0.75, label = "Collection", state = "collection", float = true },
	{ id = "altar", sprite = "altar", x = 95, y = 735, scale = 0.7, label = "Sacrifice", state = "altar", float = true },
	{ id = "basket", sprite = "basket", x = 1150, y = 745, scale = 0.65, label = "Deck & Lanes", popup = true },
	{ id = "gear", sprite = "gear", x = 1340, y = 600, scale = 0.7, label = "Settings", state = "settings", float = true },
}

local images = {}

local function image_of(item)
	local file
	if item.id == "charmer" then
		file = "assets/characters/stand_" .. require("Charmers").of("Player").portrait:gsub("%..+$", "") .. ".png"
	else
		file = "assets/menu/" .. item.sprite .. ".png"
	end
	if not images[file] then
		images[file] = lg.newImage(file)
		images[file]:setFilter("nearest", "nearest")
	end
	return images[file]
end

local function box(item)
	local image = image_of(item)
	local w, h = image:getWidth() * item.scale, image:getHeight() * item.scale
	return item.x - w / 2, item.y - h, w, h
end

-- The item under a window position, if any
function hub.at(window_x, window_y)
	local x, y = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	for i = #ITEMS, 1, -1 do
		local bx, by, bw, bh = box(ITEMS[i])
		if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
			return ITEMS[i]
		end
	end
end

function hub.click(item)
	play_sound(hover_sound)
	local collection = require("Collection")
	collection.sacrifice_mode, collection.sacrificing, collection.deck_mode = false, {}, false
	scroll_offset_y = 0
	if item.popup then
		hub.popup = true
	else
		if item.state == "shop" then
			shop_return = "menu"
		elseif item.state == "collection" then -- always open the plain collection, not a leftover deck or sacrifice mode
			collection.deck_mode, collection.sacrifice_mode, collection.sacrificing = false, false, {}
		end
		animation, animation_time = true, 0
		update_animation_screen(item.state)
	end
end

function hub.draw(t)
	local assets = require("Assets")
	local hovered = not hub.popup and hub.at(mouse.x, mouse.y)
	local fade = math.max(0, math.min(1, (t - 0.4) / 0.8))
	for i, item in ipairs(ITEMS) do
		local image = image_of(item)
		local bob = item.float and math.sin(time * 1.8 + i * 1.3) * 8 or 0
		local grow = hovered == item and 1.06 or 1
		local scale = item.scale * grow
		local x, y = item.x - image:getWidth() * scale / 2, item.y - image:getHeight() * scale + bob
		lg.setColor(1, 1, 1, fade)
		lg.draw(image, x, y, 0, scale)
		if hovered == item then -- glow
			lg.setBlendMode("add")
			lg.setColor(1, 1, 1, 0.22 * fade)
			lg.draw(image, x, y, 0, scale)
			lg.setBlendMode("alpha")
		end
		local label_y = item.y + (item.float and 22 or 8)
		lg.setColor(0, 0, 0, 0.55 * fade)
		local text_w = assets.small_font:getWidth(item.label) + 24
		lg.rectangle("fill", item.x - text_w / 2, label_y - 2, text_w, 36, 8, 8)
		lg.setColor(hovered == item and { 0.7, 1, 0.45, fade } or { 0.98, 0.94, 0.7, fade })
		lg.printf(item.label, assets.small_font, item.x - 150, label_y, 300, "center")
	end
	lg.setColor(1, 1, 1)

	if hub.popup then
		lg.setColor(0, 0, 0, 0.7)
		lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
		lg.setColor(1, 1, 1)
		lg.printf("Deck & Lanes", assets.font, 0, reference_window_height / 2 - 150, reference_window_width, "center")
		for _, name in ipairs({ "Deck", "Lanes", "Cancel" }) do
			buttons.hub_popup[name]:draw()
		end
	end
end

return hub
