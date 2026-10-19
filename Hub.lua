local love = require("love")
local lg = love.graphics

-- The main menu: a snake-infested temple (Play) with an icon for each other screen around it. Positions are in reference-window units (x = centre, y = the sprite's bottom).
local collection = require("Collection")
local hub = {}

local ITEMS = {
	{ id = "play", sprite = "temple", x = 780, y = 745, scale = 0.9, label = "Play", state = "play_menu" },
	{ id = "packs", sprite = "chest", x = 270, y = 770, scale = 0.85, label = "Packs", state = "shop", float = true },
	{ id = "book", sprite = "gameplay", x = 1130, y = 450, scale = 0.75, label = "Gameplay", state = "gameplay", float = true },
	{ id = "trophy", sprite = "trophy", x = 400, y = 480, scale = 0.85, label = "Achievements", state = "achievements", float = true },
	{ id = "gear", sprite = "gear", x = 1260, y = 740, scale = 0.7, label = "Settings", state = "settings", float = true },
}

-- What each locked thing inside the Play and Gameplay popups needs
local NEEDS = {
	Charmers = { "Beat the 2nd opponent to unlock Charmers", function() return collection.unlock_all or unlocked >= 3 end },
	Lanes = { "Beat the 2nd opponent to unlock Lanes", function() return collection.unlock_all or unlocked >= 3 end },
	Collection = { "Beat the 5th opponent to unlock the Collection", function() return collection.unlock_all or unlocked >= 6 end },
	Deck = { "Beat the 5th opponent to unlock deck building", function() return collection.deck_unlocked() end },
	Imbue = { "Beat the 10th opponent to unlock Imbue", function() return collection.imbue_unlocked() end },
	Sacrifice = { "Beat the 10th opponent to awaken the Snake God", function() return collection.sacrifice_unlocked() end },
	Versus = { "Beat the 10th opponent to unlock Versus", function() return collection.unlock_all or unlocked >= 11 end },
}

-- Why a popup button is locked, or nil if it works
function hub.locked(name)
	local need = NEEDS[name]
	return need and not need[2]() and need[1] or nil
end

-- The icons that get a "New!" tooltip when something inside them opens up: { key, text, test } in order
local RULES = {
	packs = { tips = { { "tip_packs", "New: Packs! Spend the snake eyes you win on new cards.", function() return unlocked >= 2 end } } },
	play = { tips = { { "tip_versus", "New: Versus!", function() return collection.unlock_all or unlocked >= 11 end } } },
	book = { tips = { { "tip_charmers", "New: Charmers and Lanes!", function() return collection.unlock_all or unlocked >= 3 end },
		{ "tip_book", "New: Collection!", function() return collection.unlock_all or unlocked >= 6 end },
		{ "tip_deck", "New: Deck building!", function() return collection.deck_unlocked() end },
		{ "tip_altar", "New: Imbue!", function() return collection.imbue_unlocked() end },
		{ "tip_sac", "New: Sacrifice!", function() return collection.sacrifice_unlocked() end } } },
}

local function item_open(item)
	return true
end

-- The tooltip waiting on an icon, if it is open and its tip has not been dismissed
local function pending_tip(item)
	local rule = RULES[item.id]
	if rule then
		for _, tip in ipairs(rule.tips) do
			if tip[3]() and not collection.hint_seen(tip[1]) then
				return tip
			end
		end
	end
end

local images = {}

local function image_of(item)
	local file
	if item.id == "charmer" then
		file = require("Charmers").file(require("Charmers").of("Player"), true)
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
	hub.note = nil
	for _, tip in ipairs(RULES[item.id] and RULES[item.id].tips or {}) do -- opening an icon dismisses its tooltips
		if tip[3]() then
			collection.mark_hint(tip[1])
		end
	end
	collection.sacrifice_mode, collection.sacrificing, collection.deck_mode = false, {}, false
	scroll_offset_y = 0
	do
		if item.state == "achievements" then
			achievements_return = "menu"
		elseif item.state == "shop" then
			shop_return = "menu"
		elseif item.state == "collection" then -- always open the collection's section page, not a leftover deck or sacrifice mode
			collection.deck_mode, collection.sacrifice_mode, collection.sacrificing = false, false, {}
			collection.section, collection.return_to = nil, nil
			collection.clear_filters()
		end
		animation, animation_time = true, 0
		update_animation_screen(item.state)
	end
end

-- Items with a tooltip waiting (the menu dims everything else until they are clicked or dismissed)
function hub.spotlight()
	local list = {}
	for _, item in ipairs(ITEMS) do
		if pending_tip(item) then
			list[#list + 1] = item
		end
	end
	return list
end

function hub.dismiss(items)
	for _, item in ipairs(items) do
		for _, tip in ipairs(RULES[item.id].tips) do
			if tip[3]() then
				collection.mark_hint(tip[1])
			end
		end
	end
end

-- The Gameplay and Play screens: an icon for each choice, reusing the actions in buttons.hub_popup. Screens opened
-- from them send Back to them (hub.home) instead of the main menu.
hub.return_to = nil
function hub.home()
	return hub.return_to or "menu"
end

local GAMEPLAY = {
	{ name = "Charmers", sprite = "charmer", x = 300, y = 390 },
	{ name = "Collection", sprite = "book", x = 720, y = 390 },
	{ name = "Deck", sprite = "basket", x = 1140, y = 390 },
	{ name = "Lanes", sprite = "lanes", x = 300, y = 760 },
	{ name = "Imbue", sprite = "imbue", x = 720, y = 760 },
	{ name = "Sacrifice", sprite = "altar", x = 1140, y = 760 },
}

local PLAY_MENU = {
	{ name = "Campaign", sprite = "campaign", x = 480, y = 560 },
	{ name = "Versus", sprite = "versus", x = 960, y = 560 },
}
local SCREENS = { gameplay = { title = "Gameplay", items = GAMEPLAY }, play_menu = { title = "Play", items = PLAY_MENU } }

local function gameplay_box(item)
	local image = image_of({ id = item.sprite == "charmer" and "charmer" or "x", sprite = item.sprite })
	local scale = math.min(250 / image:getHeight(), 280 / image:getWidth())
	local w, h = image:getWidth() * scale, image:getHeight() * scale
	return image, scale, item.x - w / 2, item.y - h, w, h
end

function hub.screen_at(screen, window_x, window_y)
	local x, y = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	for _, item in ipairs(SCREENS[screen].items) do
		local _, _, bx, by, bw, bh = gameplay_box(item)
		if x >= bx and x <= bx + bw + 0 and y >= by and y <= by + bh + 50 then
			return item
		end
	end
end

function hub.screen_click(screen, item)
	hub.return_to = screen
	play_sound(hover_sound)
	animation, animation_time = true, 0
	buttons.hub_popup[item.name].func()
end

function hub.draw_screen(screen)
	local assets = require("Assets")
	local hovered = hub.screen_at(screen, mouse.x, mouse.y)
	for i, item in ipairs(SCREENS[screen].items) do
		local image, scale, bx, by, bw, bh = gameplay_box(item)
		local locked = hub.locked(item.name)
		local grow = hovered == item and 1.06 or 1
		local bob = math.sin(time * 1.8 + i * 1.3) * 6
		lg.setColor(locked and 0.35 or 1, locked and 0.35 or 1, locked and 0.4 or 1)
		lg.draw(image, item.x - bw * grow / 2, by + bh - bh * grow + bob, 0, scale * grow)
		if hovered == item and not locked then
			lg.setBlendMode("add")
			lg.setColor(1, 1, 1, 0.22)
			lg.draw(image, item.x - bw * grow / 2, by + bh - bh * grow + bob, 0, scale * grow)
			lg.setBlendMode("alpha")
		end
		local label = item.name .. (locked and " (locked)" or "")
		local text_w = assets.small_font:getWidth(label) + 24
		lg.setColor(0, 0, 0, 0.55)
		lg.rectangle("fill", item.x - text_w / 2, item.y + 20, text_w, 36, 8, 8) -- (the same label as the main menu's icons)
		lg.setColor(hovered == item and { 0.7, 1, 0.45 } or { 0.98, 0.94, 0.7 })
		lg.printf(label, assets.small_font, item.x - 150, item.y + 22, 300, "center")
	end
	lg.setColor(1, 1, 1)
	if hub.note and time - hub.note_t < 2.5 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 110, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(hub.note, assets.small_font, 380, 122, 680, "center")
	end
end

function hub.draw(t)
	local assets = require("Assets")
	local hovered = hub.at(mouse.x, mouse.y)
	local fade = math.max(0, math.min(1, (t - 0.4) / 0.8))
	local spots = {}
	for i, item in ipairs(ITEMS) do
		local image = image_of(item)
		local bob = item.float and math.sin(time * 1.8 + i * 1.3) * 8 or 0
		local grow = hovered == item and 1.06 or 1
		local scale = item.scale * grow
		local x, y = item.x - image:getWidth() * scale / 2, item.y - image:getHeight() * scale + bob
		local locked = not item_open(item)
		lg.setColor(locked and 0.35 or 1, locked and 0.35 or 1, locked and 0.4 or 1, fade)
		lg.draw(image, x, y, 0, scale)
		if hovered == item and not locked then -- glow
			lg.setBlendMode("add")
			lg.setColor(1, 1, 1, 0.22 * fade)
			lg.draw(image, x, y, 0, scale)
			lg.setBlendMode("alpha")
		end
		if item.label then
			local label_y = item.y + (item.float and 22 or 8)
			lg.setColor(0, 0, 0, 0.55 * fade)
			local text_w = assets.small_font:getWidth(item.label) + 24
			lg.rectangle("fill", item.x - text_w / 2, label_y - 2, text_w, 36, 8, 8)
			lg.setColor(hovered == item and { 0.7, 1, 0.45, fade } or { 0.98, 0.94, 0.7, fade })
			lg.printf(item.label, assets.small_font, item.x - 150, label_y, 300, "center")
		end
		if pending_tip(item) and fade >= 1 then
			local bx, by, bw, bh = box(item)
			spots[#spots + 1] = { item = item, tip = pending_tip(item), x = bx + bw / 2, y = by + bh / 2 + bob, r = math.max(bw, bh) / 2 + 24 }
		end
	end
	if #spots > 0 then -- dim everything except a circle round each newly unlocked thing, with a note beside it
		lg.stencil(function()
			for _, s in ipairs(spots) do
				lg.circle("fill", s.x, s.y, s.r)
			end
		end, "replace", 1)
		lg.setStencilTest("equal", 0)
		lg.setColor(0, 0, 0, 0.75)
		lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
		lg.setStencilTest()
		local pulse = 0.5 + 0.5 * math.sin(time * 5)
		for _, s in ipairs(spots) do
			lg.setColor(1, 0.9, 0.2, 0.7 + 0.3 * pulse)
			lg.setLineWidth(5)
			lg.circle("line", s.x, s.y, s.r + 3 * pulse)
			lg.setLineWidth(1)
			local tw = 300
			local _, lines = assets.small_font:getWrap(s.tip[2], tw - 20)
			local th = #lines * 30 + 16
			local tx = math.max(10, math.min(s.x - tw / 2, reference_window_width - tw - 10))
			local ty = s.y - s.r - th - 12
			if ty < 10 then
				ty = s.y + s.r + 12
			end
			lg.setColor(0.07, 0.04, 0.14, 0.96)
			lg.rectangle("fill", tx, ty, tw, th, 10, 10)
			lg.setColor(1, 0.9, 0.2)
			lg.rectangle("line", tx, ty, tw, th, 10, 10)
			lg.setColor(1, 1, 1)
			lg.printf(s.tip[2], assets.small_font, tx + 10, ty + 8, tw - 20, "left")
		end
	end
	lg.setColor(1, 1, 1)
	if hub.note and time - hub.note_t < 2.5 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 40, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(hub.note, assets.small_font, 380, 52, 680, "center")
	end
end

return hub
