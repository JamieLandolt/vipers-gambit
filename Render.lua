local love = require("love")
local lg = love.graphics
local assets = require("Assets")
local data = require("CardData")
local play = require("Play")
local effects = require("Effects")
local abilities = require("Abilities")
local borders = require("Borders")
local collection = require("Collection")
local opponents = require("Opponents")
local challenges = require("Challenges")
local hub = require("Hub")
local shader = require("Shader")
local title = require("Title")
local charmers = require("Charmers")
local tutorial = require("Tutorial")
local lane_editor = require("LaneEditor")
local settings = require("Settings")
local coach = require("Coach")

local render = {}

local BORDER_PAGE = { "Basic", "Venom", "Fire", "Shadow", "Rainbow", "Stone", "Brew", "Spell" }
local LOG_FONT = lg.newFont("assets/Jersey15-Regular.ttf", 17)

local purple = { 101 / 255, 52 / 255, 150 / 255 }
local green = { 116 / 255, 182 / 255, 82 / 255 }

local function background()
	lg.scale(3 / 4)
	lg.setColor(1, 1, 1)
	shader:send("time", time)
	lg.setShader(shader)
	lg.draw(assets.background, 0, 0)
	lg.setShader()
	lg.scale(4 / 3)
end

local menu_start, last_menu = 0, -1

-- The title drops in letter by letter while the menu slides down into its resting place
function render.menu()
	scroll_offset_y = 0
	background()
	if time - last_menu > 0.25 then
		menu_start = time
	end
	last_menu = time
	local t = time - menu_start

	title.draw(t)
	hub.draw(t)
end

-- The Gameplay screen: Charmers, Collection, Deck, Lanes, Imbue and Sacrifice, each with its icon
-- The Gameplay and Play screens: an icon for each choice
local function icon_screen(screen)
	scroll_offset_y = 0
	background()
	hub.draw_screen(screen)
	buttons[screen]["Back"]:draw()
end
function render.gameplay() icon_screen("gameplay") end
function render.play_menu() icon_screen("play_menu") end

-- The venom vials meter: a vial, how many you have, and the wait for the next one. (x, y) is the top left; it is 230 wide
local function draw_vials(x, y)
	local have, wait = collection.vials(), collection.vials_wait()
	lg.setColor(0, 0, 0, 0.7)
	lg.rectangle("fill", x, y, 230, 44, 8, 8)
	lg.setColor(0.8, 0.9, 1, 0.9) -- the glass
	lg.rectangle("fill", x + 21, y + 7, 10, 8)
	lg.circle("fill", x + 26, y + 29, 11)
	lg.setColor(0.4, 0.9, 0.25) -- the venom inside
	lg.circle("fill", x + 26, y + 30, 8)
	lg.rectangle("fill", x + 22, y + 15, 8, 8)
	lg.setColor(0.7, 0.45, 0.2) -- the cork
	lg.rectangle("fill", x + 21, y + 4, 10, 5)
	lg.setColor(1, 1, 1, have > 0 and 1 or 0.6)
	lg.print(have .. "/" .. collection.VIALS_MAX .. (wait and string.format("   +1 in %d:%02d", math.floor(wait / 60), wait % 60) or ""), assets.small_font, x + 52, y + 8)
	lg.setColor(1, 1, 1)
end

local eye_icon -- the snake-eye currency icon (loaded on first use)

-- Draws "<prefix><amount>" followed by the snake-eye icon, aligned left, center or right within x .. x + w; the caller sets the text colour
local function draw_eyes(prefix, amount, x, y, w, align, font)
	font = font or assets.small_font
	if not eye_icon then
		eye_icon = lg.newImage("assets/icons/snake_eye.png")
		eye_icon:setFilter("nearest", "nearest")
	end
	local r, g, b, a = lg.getColor()
	local text = prefix .. amount
	local icon_h = font:getHeight() * 0.7
	local scale = icon_h / eye_icon:getHeight()
	local total = font:getWidth(text) + 8 + eye_icon:getWidth() * scale
	local left = align == "right" and x + w - total or align == "center" and x + (w - total) / 2 or x
	lg.print(text, font, left, y)
	lg.setColor(1, 1, 1, a)
	lg.draw(eye_icon, left + font:getWidth(text) + 8, y + (font:getHeight() - icon_h) / 2 + 2, 0, scale)
	lg.setColor(r, g, b, a)
end

local RARITY_COLOUR = { { 0.75, 0.75, 0.75 }, { 0.4, 0.85, 0.4 }, { 0.4, 0.6, 1 }, { 0.75, 0.4, 1 }, { 1, 0.85, 0.2 } }

-- A titled block of wrapped text at (x, y); returns the y just below it
local function info_section(title, body, x, y, w, title_colour, body_colour)
	lg.setColor(title_colour)
	lg.print(title, assets.small_font, x, y)
	lg.setColor(body_colour)
	local _, lines = assets.small_font:getWrap(body, w)
	lg.printf(body, assets.small_font, x, y + 32, w)
	return y + 32 + #lines * assets.small_font:getHeight() + 22
end

-- A rounded stat box: small label above a big number or word
local function stat_chip(label, value, x, y, w, colour)
	lg.setColor(colour[1] * 0.25, colour[2] * 0.25, colour[3] * 0.25, 0.9)
	lg.rectangle("fill", x, y, w, 84, 10, 10)
	lg.setColor(colour)
	lg.setLineWidth(3)
	lg.rectangle("line", x, y, w, 84, 10, 10)
	lg.setLineWidth(1)
	lg.printf(label, assets.card_name_font, x, y + 6, w, "center")
	lg.setColor(1, 1, 1)
	lg.printf(tostring(value), assets.font, x, y + 28, w, "center")
end


-- The info popup used everywhere a card is looked at (pack results, snakes on the field, a clicked hand snake): the card on the
-- left in a glow of its tier colour, its details on the right. `hp` and `status` are for a snake that is on the field.
local POPUP_W, POPUP_SCALE = 600, 0.7
local function card_popup(card, x, y, hp, status)
	local st = data.get_stats(card)
	local name = card.card_path:sub(1, -5)
	local snake = st.kind == "snake"
	local tier = RARITY_COLOUR[st.rarity]
	local border = snake and data.border_of(card) or nil
	local cw, ch = img_widths * POPUP_SCALE, img_heights * POPUP_SCALE
	local tx, tw = x + cw + 36, POPUP_W - cw - 56
	local font = assets.small_font
	local function height(text, width)
		local _, lines = font:getWrap(text, width or tw)
		return #lines * font:getHeight()
	end
	local border_text = border and border ~= "Basic" and borders.describe(border)
	local status_h = 0
	for _, line in ipairs(status or {}) do
		status_h = status_h + height(line) + 6
	end
	local body_h = 34 + 34 + 52 + (border_text and height(border_text, tw - 18) + 20 or 0) + height(st.ability or "None") + 12
		+ (st.lore and height(st.lore) + 12 or 0) + status_h
	local h = math.max(ch + 40, body_h + 28)
	x = math.max(10, math.min(x, reference_window_width - POPUP_W - 10))
	y = math.max(10, math.min(y, reference_window_height - h - 10))
	tx = x + cw + 36
	local pulse = 0.5 + 0.5 * math.sin(time * 2.5)

	lg.setColor(0.07, 0.04, 0.14, 0.96)
	lg.rectangle("fill", x, y, POPUP_W, h, 14, 14)
	lg.setColor(tier[1], tier[2], tier[3], 0.7 + 0.3 * pulse)
	lg.setLineWidth(3)
	lg.rectangle("line", x, y, POPUP_W, h, 14, 14)
	lg.setLineWidth(1)

	local cx, cy = x + 20, y + 20
	lg.setBlendMode("add")
	for i = 1, 3 do
		lg.setColor(tier[1], tier[2], tier[3], (0.05 + 0.03 * pulse) * (4 - i))
		lg.rectangle("fill", cx - i * 6, cy - i * 6, cw + i * 12, ch + i * 12, 10, 10)
	end
	lg.setBlendMode("alpha")
	lg.push()
	lg.translate(cx, cy)
	lg.scale(POPUP_SCALE)
	lg.setColor(1, 1, 1)
	lg.draw(assets.card_by_name[name])
	require("CardText").draw(name, 0, 0)
	if snake then
		borders.draw(border, 0, 0, img_widths, img_heights, st.rarity)
	end
	lg.pop()

	local ty = y + 16
	lg.setColor(1, 1, 1)
	lg.print((name:gsub("_", " ")), font, tx, ty)
	ty = ty + 34
	lg.setColor(tier)
	lg.print("Tier " .. st.rarity .. (st.tier and (" " .. st.tier) or "") .. "  |  " .. (snake and ("Snake, " .. data.get_type(card)) or (st.kind == "brew" and "Brew" or "Spell")), font, tx, ty)
	ty = ty + 34
	local chips = { { "Cost", st.cost, { 0.4, 0.85, 0.4 } } }
	if snake then
		chips[2] = { "Attack", st.attack, { 1, 0.4, 0.4 } }
		chips[3] = { "Health", hp or st.defense, { 0.45, 0.6, 1 } }
	end
	local chip_w = (tw - 16) / 3
	for i, c in ipairs(chips) do
		local bx = tx + (i - 1) * (chip_w + 8)
		lg.setColor(c[3][1] * 0.25, c[3][2] * 0.25, c[3][3] * 0.25, 0.9)
		lg.rectangle("fill", bx, ty, chip_w, 40, 8, 8)
		lg.setColor(c[3])
		lg.rectangle("line", bx, ty, chip_w, 40, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(c[1] .. " " .. c[2], font, bx, ty + 6, chip_w, "center")
	end
	ty = ty + 52
	if border_text then
		local colour = borders.colour(border) or { 0.7, 0.7, 0.7 }
		local bh = height(border_text, tw - 18) + 12
		lg.setColor(colour[1] * 0.2, colour[2] * 0.2, colour[3] * 0.2, 0.9)
		lg.rectangle("fill", tx, ty, tw, bh, 6, 6)
		lg.setColor(colour)
		lg.rectangle("fill", tx, ty, 5, bh, 3, 3)
		lg.printf(border_text, font, tx + 14, ty + 6, tw - 18)
		ty = ty + bh + 8
	end
	lg.setColor(1, 0.85, 0.2)
	lg.printf(st.ability or "None", font, tx, ty, tw)
	ty = ty + height(st.ability or "None") + 12
	if st.lore then
		lg.setColor(0.7, 0.75, 0.95)
		lg.printf(st.lore, font, tx, ty, tw)
		ty = ty + height(st.lore) + 12
	end
	lg.setColor(1, 0.6, 0.5)
	for _, line in ipairs(status or {}) do
		lg.printf(line, font, tx, ty, tw)
		ty = ty + height(line) + 6
	end
end

-- The collection screen: filter icons along the top, the card grid on the left (about 60% of the screen)
-- and the hovered card's details in the pane on the right.
local GRID_X, GRID_Y, GRID_W, GRID_BOTTOM = 40, 155, 840, 858
local CARD_SCALE, CELL_GAP = 0.62, 14
local function cell_size()
	return img_widths * CARD_SCALE, img_heights * CARD_SCALE
end

-- Calls fn(index, x, y) for each shown card in the grid (x, y = top-left corner), in the current sort order
local function each_collection_card(fn)
	local cw, ch = cell_size()
	local per_row = math.floor((GRID_W + CELL_GAP) / (cw + CELL_GAP))
	local shown = 0
	for _, name in ipairs(assets.card_names) do
		shown = shown + (collection.shown(name) and 1 or 0)
	end
	local rows = math.ceil(shown / per_row)
	local top = math.max(math.min(scroll_offset_y * 5, 0), GRID_BOTTOM - GRID_Y - rows * (ch + CELL_GAP)) + GRID_Y
	local n = 0
	for _, i in ipairs(collection.order(assets.card_names)) do
		if collection.shown(assets.card_names[i]) then
			fn(i, GRID_X + (n % per_row) * (cw + CELL_GAP), top + math.floor(n / per_row) * (ch + CELL_GAP))
			n = n + 1
		end
	end
end

-- A tip shown for a few seconds the first time a screen is used (never again after that)
local hint_since = {}
local function show_hint(key, text)
	if collection.hint_seen(key) and not hint_since[key] then
		return
	end
	if not hint_since[key] then
		hint_since[key] = time
		collection.mark_hint(key)
		require("Sounds").play("hint")
	end
	local age = time - hint_since[key]
	if age < 9 then
		local alpha = math.min(1, (9 - age) * 2)
		lg.setColor(0.1, 0.05, 0.2, 0.9 * alpha)
		lg.rectangle("fill", 20, 740, 950, 90, 10, 10)
		lg.setColor(1, 0.85, 0.2, alpha)
		lg.rectangle("line", 20, 740, 950, 90, 10, 10)
		lg.setColor(1, 1, 1, alpha)
		lg.printf(text, assets.small_font, 40, 752, 910, "center")
		lg.setColor(1, 1, 1)
	end
end

-- Bars of how many snakes in the deck cost 1, 2, ... 8+ venom
local function draw_curve()
	local counts, top, total = {}, 1, 0
	for i = 1, 8 do
		counts[i] = 0
	end
	for _, name in ipairs(collection.chosen()) do
		local cost = math.min(math.max(data.stats_by_name[name].cost, 1), 8)
		counts[cost] = counts[cost] + 1
		top, total = math.max(top, counts[cost]), total + data.stats_by_name[name].cost
	end
	local n = collection.deck_count()
	local x, y, w, h = 890, 762, 520, 100
	local step = (w - 28) / 8
	lg.setColor(0.07, 0.04, 0.14, 0.92)
	lg.rectangle("fill", x, y, w, h, 10, 10)
	for i = 1, 8 do
		local bar = counts[i] / top * 40
		local bx = x + 14 + (i - 1) * step
		lg.setColor(0.4, 0.85, 0.4)
		lg.rectangle("fill", bx + 8, y + 74 - bar, step - 16, bar)
		lg.setColor(1, 1, 1)
		lg.printf(i == 8 and "8+" or i, assets.card_text_font, bx, y + 76, step, "center")
		if counts[i] > 0 then
			lg.printf(counts[i], assets.card_text_font, bx, y + 54 - bar, step, "center")
		end
	end
	lg.printf("Cost curve" .. (n > 0 and string.format(" (avg %.1f)", total / n) or ""), assets.card_text_font, x, y + 4, w, "center")
end

-- The card (owned or not) under the given window position, if any
local function card_under(window_x, window_y)
	local rx, ry = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	local cw, ch = cell_size()
	local found
	if rx < GRID_X + GRID_W + CELL_GAP and ry >= GRID_Y and ry <= GRID_BOTTOM then
		each_collection_card(function(i, x, y)
			if rx >= x and rx < x + cw and ry >= y and ry < y + ch then
				found = assets.card_names[i]
			end
		end)
	end
	return found
end

-- Name of the owned snake under the given window position, if any (only owned cards can be clicked)
function render.collection_card_at(window_x, window_y)
	local name = card_under(window_x, window_y)
	return name and collection.has(name) and name or nil
end

-- Filter icons: tile colour, hover label and the little picture drawn on the tile
local ICON = 38
local ICON_INFO = {
	["kind:snake"] = { { 0.3, 0.7, 0.3 }, "Snakes" }, ["kind:brew"] = { { 0.6, 0.35, 0.85 }, "Brews" }, ["kind:spell"] = { { 0.35, 0.5, 0.95 }, "Spells" },
	["type:Land"] = { { 0.8, 0.65, 0.4 }, "Land snakes" }, ["type:Water"] = { { 0.25, 0.5, 0.9 }, "Water snakes" }, ["type:Tree"] = { { 0.25, 0.6, 0.3 }, "Tree snakes" },
	["type:Spirit"] = { { 0.55, 0.3, 0.8 }, "Spirit snakes" }, ["type:Rainbow"] = { { 0.9, 0.5, 0.6 }, "Rainbow snakes" },
	["own:owned"] = { { 0.3, 0.7, 0.35 }, "Owned" }, ["own:missing"] = { { 0.45, 0.45, 0.5 }, "Missing" },
}

-- Every icon with its position: the filter groups left to right, then the reset icon
local function filter_icons()
	local list, x = {}, 330
	for _, group in ipairs(collection.FILTER_GROUPS) do
		if group.id ~= "kind" then -- (the Snakes, Brews and Spells sections are picked on the landing page)
			for _, key in ipairs(group.keys) do
				table.insert(list, { group.id, key, x, 86 })
				x = x + ICON + 8
			end
			x = x + 14
		end
	end
	table.insert(list, { "reset", "reset", x, 86 })
	return list
end

function render.filter_icon_at(window_x, window_y)
	local rx, ry = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	for _, icon in ipairs(filter_icons()) do
		if rx >= icon[3] and rx <= icon[3] + ICON and ry >= icon[4] and ry <= icon[4] + ICON then
			return icon[1], icon[2]
		end
	end
end

local function draw_filter_icon(group, key, x, y, hovered)
	local id = group .. ":" .. key
	local on = group == "reset" and collection.filtering() or collection.filter_on(group, key)
	local info = ICON_INFO[id]
	local c = group == "tier" and RARITY_COLOUR[key] or info and info[1] or { 0.8, 0.3, 0.3 }
	local a = on and 1 or 0.3
	local s = ICON
	lg.setColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.95 * (on and 1 or 0.6))
	lg.rectangle("fill", x, y, s, s, 6, 6)
	lg.setColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5, hovered and 1 or 0.85 * a + 0.15)
	lg.setLineWidth(hovered and 3 or 2)
	lg.rectangle("line", x, y, s, s, 6, 6)
	lg.setLineWidth(1)
	lg.setColor(c[1], c[2], c[3], a)
	if id == "kind:snake" then
		lg.setLineWidth(4)
		lg.line(x + 7, y + 28, x + 14, y + 12, x + 22, y + 28, x + 30, y + 12)
		lg.setLineWidth(1)
		lg.circle("fill", x + 30, y + 11, 3)
	elseif id == "kind:brew" then
		lg.rectangle("fill", x + 15, y + 6, 8, 11)
		lg.circle("fill", x + 19, y + 24, 10)
		lg.setColor(1, 1, 1, 0.5 * a)
		lg.circle("fill", x + 15, y + 21, 2.5)
	elseif id == "kind:spell" then
		lg.polygon("fill", x + 19, y + 4, x + 23, y + 15, x + 34, y + 19, x + 23, y + 23, x + 19, y + 34, x + 15, y + 23, x + 4, y + 19, x + 15, y + 15)
	elseif id == "type:Land" then
		lg.polygon("fill", x + 4, y + 30, x + 16, y + 10, x + 24, y + 22, x + 30, y + 15, x + 35, y + 30)
	elseif id == "type:Water" then
		lg.setLineWidth(3)
		for row = 0, 2 do
			lg.line(x + 6, y + 11 + row * 9, x + 13, y + 7 + row * 9, x + 20, y + 11 + row * 9, x + 27, y + 7 + row * 9, x + 33, y + 11 + row * 9)
		end
		lg.setLineWidth(1)
	elseif id == "type:Tree" then
		lg.polygon("fill", x + 19, y + 4, x + 31, y + 24, x + 7, y + 24)
		lg.rectangle("fill", x + 16, y + 24, 6, 9)
	elseif id == "type:Spirit" then
		lg.circle("fill", x + 19, y + 15, 10)
		lg.rectangle("fill", x + 9, y + 15, 20, 15)
		lg.setColor(0, 0, 0, a)
		lg.circle("fill", x + 15, y + 15, 2)
		lg.circle("fill", x + 23, y + 15, 2)
	elseif id == "type:Rainbow" then
		lg.setLineWidth(3)
		local rainbow = { { 1, 0.3, 0.3 }, { 1, 0.85, 0.2 }, { 0.3, 0.8, 0.4 }, { 0.4, 0.5, 1 } }
		for i, col in ipairs(rainbow) do
			lg.setColor(col[1], col[2], col[3], a)
			lg.arc("line", "open", x + 19, y + 30, 22 - i * 4, math.pi, 2 * math.pi)
		end
		lg.setLineWidth(1)
	elseif group == "tier" then
		lg.printf(tostring(key), assets.small_font, x, y + 3, s, "center")
	elseif id == "own:owned" then
		lg.setLineWidth(5)
		lg.line(x + 8, y + 20, x + 16, y + 28, x + 31, y + 10)
		lg.setLineWidth(1)
	elseif id == "own:missing" then
		lg.printf("?", assets.small_font, x, y + 3, s, "center")
	else -- reset
		lg.setLineWidth(4)
		lg.line(x + 10, y + 10, x + 28, y + 28)
		lg.line(x + 28, y + 10, x + 10, y + 28)
		lg.setLineWidth(1)
	end
end

local function draw_filter_bar()
	local hovered_group, hovered_key = render.filter_icon_at(mouse.x, mouse.y)
	local label
	for _, icon in ipairs(filter_icons()) do
		local hovered = icon[1] == hovered_group and icon[2] == hovered_key
		draw_filter_icon(icon[1], icon[2], icon[3], icon[4], hovered)
		if hovered then
			label = { icon[1] == "tier" and ("Tier " .. icon[2] .. " " .. (require("Lore").tiers[icon[2]] or "")) or icon[1] == "reset" and "Show everything"
				or ICON_INFO[icon[1] .. ":" .. icon[2]][2], icon[3] }
		end
	end
	if label then
		local w = assets.card_text_font:getWidth(label[1]) + 16
		local lx = math.min(label[2], reference_window_width - w - 5)
		lg.setColor(0, 0, 0, 0.9)
		lg.rectangle("fill", lx, 86 + ICON + 4, w, 26, 5, 5)
		lg.setColor(1, 1, 1)
		lg.print(label[1], assets.card_text_font, lx + 8, 86 + ICON + 7)
	end
end

local pane_name -- the card the details pane shows: the hovered one, else the last one hovered

-- The right-hand pane: the hovered card's art and details
local function draw_info_pane()
	local px, py, pw, ph = 890, 155, 520, collection.deck_mode and 595 or 703
	local name = pane_name
	local st = name and data.stats_by_name[name]
	local tier = st and RARITY_COLOUR[st.rarity] or { 0.6, 0.6, 0.7 }
	lg.setColor(0.07, 0.04, 0.14, 0.92)
	lg.rectangle("fill", px, py, pw, ph, 12, 12)
	lg.setColor(tier[1], tier[2], tier[3], 0.8)
	lg.setLineWidth(3)
	lg.rectangle("line", px, py, pw, ph, 12, 12)
	lg.setLineWidth(1)
	if not st then
		lg.setColor(0.7, 0.75, 0.9)
		lg.printf("Hover over a card to see its details here", assets.small_font, px + 40, py + ph / 2 - 40, pw - 80, "center")
		return
	end
	local owned = collection.has(name)
	local snake = st.kind == "snake"
	local scale = 1.15
	lg.push()
	lg.translate(px + 18, py + 18)
	lg.scale(scale)
	lg.setColor(owned and { 1, 1, 1 } or { 0.25, 0.22, 0.32 })
	lg.draw(assets.card_by_name[name])
	if owned then
		require("CardText").draw(name, 0, 0)
	end
	lg.pop()

	local x, w = px + 18 + img_widths * scale + 18, pw - (18 + img_widths * scale + 18) - 18
	lg.setColor(1, 1, 1)
	local title = owned and name:gsub("_", " ") or "???"
	local _, lines = assets.font:getWrap(title, w)
	lg.printf(title, assets.font, x, py + 14, w)
	local y = py + 14 + #lines * assets.font:getHeight() + 6
	lg.setColor(tier)
	lg.printf("Tier " .. st.rarity .. " " .. (st.tier or "") .. "\n" .. (snake and ("Snake, " .. data.card_types[name]) or (st.kind == "brew" and "Brew" or "Spell")), assets.small_font, x, y, w)
	y = y + 70
	if snake then
		stat_chip("Cost", owned and st.cost or "?", x, y, 82, { 0.4, 0.85, 0.4 })
		stat_chip("Attack", owned and st.attack or "?", x + 94, y, 82, { 1, 0.4, 0.4 })
		stat_chip("Health", owned and st.defense or "?", x + 188, y, 82, { 0.45, 0.6, 1 })
	else
		stat_chip("Cost", owned and st.cost or "?", x, y, 82, { 0.4, 0.85, 0.4 })
		stat_chip("Use", st.kind == "brew" and "Drink" or "Cast", x + 94, y, 176, { 0.7, 0.5, 1 })
	end
	y = y + 100
	lg.setColor(1, 0.85, 0.2)
	if owned then
		local parts = {}
		for _, v in ipairs(snake and collection.variant_list(name) or { { "Basic", collection.count(name) } }) do
			table.insert(parts, (snake and v[1] .. " " or "") .. "x" .. v[2])
		end
		lg.printf("You own " .. collection.count(name) .. ":\n" .. table.concat(parts, ", "), assets.small_font, x, y, w)
	else
		lg.printf("Not collected yet. Find it in packs.", assets.small_font, x, y, w)
	end

	local below = py + 18 + img_heights * scale + 22
	if owned then
		below = info_section("Ability", st.ability or "None", px + 18, below, pw - 36, { 1, 0.85, 0.2 }, { 1, 1, 1 })
		info_section("Lore", st.lore or "", px + 18, below, pw - 36, { 0.6, 0.65, 0.85 }, { 0.8, 0.85, 1 })
	end
end

-- The collection's first page: one big tile per section
local SECTIONS = {
	{ key = "snake", title = "Snakes", sample = "Sand_Snake", colour = { 0.35, 0.7, 0.35 } },
	{ key = "brew", title = "Brews", sample = "Stoneskin_Tonic", colour = { 0.8, 0.5, 0.3 } },
	{ key = "spell", title = "Spells", sample = "Arcane_Insight", colour = { 0.45, 0.5, 0.95 } },
	{ key = "borders", title = "Borders", sample = "Dirt_Snake", colour = { 1, 0.8, 0.2 } },
}
local TILE_W, TILE_H, TILE_Y = 300, 480, 190

local function section_tile(i)
	return 75 + (i - 1) * 330, TILE_Y
end

function render.collection_tile_at(window_x, window_y)
	local rx, ry = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	for i, s in ipairs(SECTIONS) do
		local x, y = section_tile(i)
		if rx >= x and rx <= x + TILE_W and ry >= y and ry <= y + TILE_H then
			return s.key
		end
	end
end

local function draw_sections()
	local hovered = render.collection_tile_at(mouse.x, mouse.y)
	for i, s in ipairs(SECTIONS) do
		local x, y = section_tile(i)
		local c, lift = s.colour, hovered == s.key and -8 or 0
		local owned, total = 0, 0
		for _, name in ipairs(data.deck) do
			if data.stats_by_name[name].kind == s.key then
				total = total + 1
				owned = owned + (collection.has(name) and 1 or 0)
			end
		end
		lg.setColor(0.07, 0.04, 0.14, 0.92)
		lg.rectangle("fill", x, y + lift, TILE_W, TILE_H, 14, 14)
		lg.setColor(c[1], c[2], c[3])
		lg.setLineWidth(hovered == s.key and 6 or 3)
		lg.rectangle("line", x, y + lift, TILE_W, TILE_H, 14, 14)
		lg.setLineWidth(1)
		lg.printf(s.title, assets.font, x, y + lift + 14, TILE_W, "center")
		lg.push()
		lg.translate(x + (TILE_W - img_widths * 0.9) / 2, y + lift + 70)
		lg.scale(0.9)
		lg.setColor(1, 1, 1)
		lg.draw(assets.card_by_name[s.sample])
		require("CardText").draw(s.sample, 0, 0)
		if s.key == "borders" then
			borders.draw("Venom", 0, 0, img_widths, img_heights)
		end
		lg.pop()
		if s.key ~= "borders" then
			lg.setColor(c[1], c[2], c[3])
			lg.printf(owned .. "/" .. total, assets.font, x, y + lift + TILE_H - 62, TILE_W, "center")
		end
	end
end

function render.collection()
	background()
	if collection.landing() then
		draw_sections()
		buttons.collection["Collection Header"]:update_text("Collection " .. collection.owned_count() .. "/" .. #data.deck)
		buttons.collection["Collection Header"]:draw()
		buttons.collection["Back"]:draw()
		coach.start("coach_collection", {
			{ rect = { 75, TILE_Y, 1290, TILE_H }, text = "Pick a section" },
		})
		return
	end
	if not collection.deck_mode and not collection.sacrifice_mode then
		coach.start("coach_collection2", {
			{ rect = { 330, 84, 760, 42 }, text = "Filter" },
			{ rect = function() local c = buttons.collection["Sort"]; return { c.x, c.y, c.width, c.height } end, text = "Sort" },
			{ rect = { 20, 130, 860, 690 }, text = "Click a card for details" },
		})
	end

	local under = card_under(mouse.x, mouse.y) -- the pane shows any hovered card, owned or not
	pane_name = under or pane_name
	local sc = lg.getWidth() / reference_window_width
	-- a panel under the grid: green felt for the deck page, deep purple with a gold rim for the collection
	local felt = collection.deck_mode and { 0.04, 0.22, 0.1 } or { 0.1, 0.05, 0.2 }
	local rim = collection.deck_mode and { 0.35, 0.8, 0.4 } or { 0.82, 0.66, 0.25 }
	lg.setColor(felt[1], felt[2], felt[3], 0.75)
	lg.rectangle("fill", GRID_X - 15, GRID_Y - 8, GRID_W + 30, GRID_BOTTOM - GRID_Y + 16, 12, 12)
	lg.setColor(rim[1], rim[2], rim[3], 0.8)
	lg.setLineWidth(3)
	lg.rectangle("line", GRID_X - 15, GRID_Y - 8, GRID_W + 30, GRID_BOTTOM - GRID_Y + 16, 12, 12)
	lg.setLineWidth(1)
	for _, corner in ipairs({ { -15, -8 }, { GRID_W + 15, -8 }, { -15, GRID_BOTTOM - GRID_Y + 8 }, { GRID_W + 15, GRID_BOTTOM - GRID_Y + 8 } }) do
		lg.setColor(rim[1], rim[2], rim[3]) -- studs on the corners of the panel
		lg.circle("fill", GRID_X + corner[1], GRID_Y + corner[2], 6)
	end
	if not collection.deck_mode and not collection.sacrifice_mode then -- how much of the collection you have
		local have, total = collection.owned_count(), #data.deck
		lg.setColor(0, 0, 0, 0.55)
		lg.rectangle("fill", GRID_X - 15, 131, GRID_W + 30, 10, 5, 5)
		lg.setColor(0.95, 0.78, 0.25)
		lg.rectangle("fill", GRID_X - 15, 131, (GRID_W + 30) * have / total, 10, 5, 5)
		lg.setColor(1, 1, 1, 0.35)
		lg.rectangle("fill", GRID_X - 15, 132, (GRID_W + 30) * have / total, 3, 2, 2)
	end
	lg.setScissor(0, GRID_Y * sc, (GRID_X + GRID_W + CELL_GAP) * sc, (GRID_BOTTOM - GRID_Y) * sc)
	each_collection_card(function(i, gx, gy)
		lg.push()
		lg.translate(gx, gy)
		lg.scale(CARD_SCALE)
		local x, y = 0, 0
		local owned = collection.has(assets.card_names[i])
		local tier_colour = RARITY_COLOUR[data.stats_by_name[assets.card_names[i]].rarity]
		if assets.card_names[i] == under then -- the card under the mouse lifts a little
			lg.translate(img_widths / 2, img_heights / 2)
			lg.scale(1.06)
			lg.translate(-img_widths / 2, -img_heights / 2)
		end
		lg.setBlendMode("add") -- a soft glow in the card's tier colour (faint for cards you have not found)
		lg.setColor(tier_colour[1], tier_colour[2], tier_colour[3], owned and 0.22 or 0.06)
		lg.rectangle("fill", -9, -9, img_widths + 18, img_heights + 18, 18, 18)
		lg.setBlendMode("alpha")
		-- Snakes you haven't unlocked are drawn as dark silhouettes
		lg.setColor(owned and { 1, 1, 1 } or { 0.12, 0.1, 0.18 })
		lg.draw(assets.cards[i], x, y)
		if owned then
			require("CardText").draw(assets.card_names[i], x, y) -- (borders only show on a snake's own page, and in play)
		else
			lg.setColor(tier_colour[1], tier_colour[2], tier_colour[3], 0.45)
			lg.printf("?", assets.font, 0, img_heights / 2 - 60, img_widths / 3, "center", 0, 3, 3)
		end
		local name = assets.card_names[i]
		if owned then -- how many copies of the snake you own (duplicates and variants included)
			lg.setColor(0, 0, 0, 0.8)
			lg.rectangle("fill", x + 101, y + 154, 56, 34, 6, 6)
			lg.setColor(1, 1, 1)
			lg.printf("x" .. collection.count(name), assets.small_font, x + 101, y + 154, 56, "center")
		end
		if owned and collection.sacrifice_mode and collection.selected(name) > 0 then
			lg.setColor(0.8, 0.1, 0.1, 0.45)
			lg.rectangle("fill", x, y, img_widths, img_heights)
			lg.setColor(1, 1, 1)
			lg.printf("-" .. collection.selected(name), assets.font, x, y + img_heights / 2 - 25, img_widths, "center")
		end
		if owned and collection.deck_mode then
			local copies = collection.in_deck(name)
			if copies > 0 then -- a green badge counts the deck's copies of the snake
				lg.setColor(0.2, 0.75, 0.3)
				lg.circle("fill", x + img_widths - 26, y + 26, 18)
				lg.setColor(1, 1, 1)
				lg.printf(copies, assets.small_font, x + img_widths - 44, y + 8, 36, "center")
			else
				lg.setColor(0, 0, 0, 0.55)
				lg.rectangle("fill", x, y, img_widths, img_heights)
			end
		end
		if name == under then
			-- Hover: a pulsing glow and border kept inside the card so neighbours are untouched
			local pulse = 0.5 + 0.5 * math.sin(time * 6)
			lg.setBlendMode("add")
			lg.setColor(1, 1, 1, 0.1 + 0.1 * pulse)
			lg.draw(assets.cards[i], x, y)
			lg.setBlendMode("alpha")
			lg.setColor(0.95, 0.85, 0.25, 0.6 + 0.4 * pulse)
			lg.setLineWidth(5)
			lg.rectangle("line", x + 2, y + 2, img_widths - 4, img_heights - 4)
			lg.setLineWidth(1)
		end
		lg.pop()
	end)
	lg.setScissor()
	lg.setColor(1, 1, 1)
	draw_filter_bar()
	draw_info_pane()

	buttons.collection["Collection Header"]:update_text(collection.deck_mode and ("Your Deck " .. collection.deck_count() .. "/" .. collection.MAX_DECK)
		or collection.sacrifice_mode and ("Pick " .. #collection.sacrificing .. "/" .. collection.SACRIFICE)
		or ("Collection " .. collection.owned_count() .. "/" .. #data.deck))
	buttons.collection["Collection Header"]:draw()
	if collection.message and time - collection.message_t < 2 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 800, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(collection.message, assets.font, 370, 805, 700, "center")
	end
	buttons.collection["Sort"]:draw()
	if collection.deck_mode or collection.sacrifice_mode then
		buttons.collection["Sacrifice"]:update_text(collection.deck_mode and "Auto-fill" or "Cancel")
		buttons.collection["Sacrifice"]:draw()
	end
	if collection.deck_mode then
		draw_curve()
	end
	if collection.deck_mode then
		coach.start("coach_deck", {
			{ rect = { 20, 130, 860, 690 }, text = "Click to add or remove" },
			{ rect = function() local c = buttons.collection["Collection Header"]; return { c.x, c.y, c.width, c.height } end, text = "Deck size" },
			{ rect = function() local c = buttons.collection["Sacrifice"]; return { c.x, c.y, c.width, c.height } end, text = "Auto-fill: your best 3 snakes of each lane type" },
		})
	elseif collection.sacrifice_mode then
		coach.start("coach_imbue2", {
			{ rect = { 20, 130, 860, 690 }, text = "Pick 3 of the same snake" },
		})
	end
	if collection.sacrifice_mode then
		lg.setColor(0, 0, 0, 0.7)
		lg.rectangle("fill", 20, 725, 600, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf("Imbue: 3 copies of the same snake become 1 copy with a random border", assets.small_font, 25, 733, 590, "center")
		if collection.can_summon() then
			buttons.collection["Summon"]:update_text("Imbue")
			buttons.collection["Summon"]:draw()
		end
	end
	if not collection.sacrifice_mode then -- (the snake eyes you can spend on packs)
		lg.setColor(0, 0, 0, 0.7)
		lg.rectangle("fill", reference_window_width - 400, 14, 250, 40, 8, 8)
		lg.setColor(1, 0.85, 0.2)
		draw_eyes("", collection.eyes, reference_window_width - 400, 20, 238, "right")
	end
	buttons.collection["Back"]:draw()
end

-- The altar of the Snake God: the recipes you can perform now on the left, the chosen one's details on the right
local ALTAR_X, ALTAR_Y, ALTAR_W, ALTAR_BOTTOM, ROW_H = 30, 130, 590, 862, 82

-- The recipes you can perform, by reward tier (high to low) and name
local function altar_rows()
	local rows = {}
	for _, recipe in ipairs(collection.recipes()) do
		if collection.recipe_known(recipe) then
			table.insert(rows, recipe)
		end
	end
	table.sort(rows, function(a, b)
		local ca, cb = collection.can_sacrifice(a), collection.can_sacrifice(b)
		if ca ~= cb then
			return ca
		end
		local ra, rb = data.stats_by_name[a.get].rarity, data.stats_by_name[b.get].rarity
		if ra ~= rb then
			return ra > rb
		end
		return a.get < b.get
	end)
	return rows
end

local function altar_top(count)
	return math.max(math.min(scroll_offset_y * 5, 0), ALTAR_BOTTOM - ALTAR_Y - count * ROW_H) + ALTAR_Y
end

-- The reward of the recipe row under the given window position, if any
function render.altar_row_at(window_x, window_y)
	local rx, ry = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	if not collection.sacrifice_unlocked() or rx < ALTAR_X or rx > ALTAR_X + ALTAR_W or ry < ALTAR_Y or ry > ALTAR_BOTTOM then
		return nil
	end
	local rows = altar_rows()
	local row = rows[math.floor((ry - altar_top(#rows)) / ROW_H) + 1]
	return row and row.get
end

local function owns(name)
	return collection.can_sacrifice({ give = { name } })
end

function render.altar()
	background()
	lg.setColor(0, 0, 0, 0.8)
	lg.printf("Sacrifice", assets.font, 3, 13, reference_window_width, "center")
	lg.setColor(1, 0.85, 0.2)
	lg.printf("Sacrifice", assets.font, 0, 10, reference_window_width, "center")
	if not collection.sacrifice_unlocked() then
		lg.setColor(0, 0, 0, 0.75)
		lg.rectangle("fill", 320, 330, 800, 200, 14, 14)
		lg.setColor(1, 1, 1)
		lg.printf("The Snake God sleeps.\nBeat the 10th opponent to awaken it.", assets.small_font, 340, 380, 760, "center")
		buttons.universal["Back"]:draw()
		return
	end
	local list, by_target = collection.recipes()
	local rows = altar_rows()
	lg.setColor(0, 0, 0, 0.7)
	lg.rectangle("fill", 200, 68, 1040, 40, 8, 8)
	lg.setColor(0.9, 0.9, 1)
	lg.printf("It demands specific snakes and gives one specific snake in return.   Recipes you can perform: " .. #rows, assets.small_font, 200, 72, 1040, "center")
	if #rows == 0 then
		lg.setColor(1, 1, 1, 0.8)
		lg.printf("No recipes yet. A recipe appears here once you own every snake it asks for (one copy of each is enough).", assets.small_font, ALTAR_X + 20, 300, ALTAR_W - 40, "center")
	end
	if not collection.altar_target or not by_target[collection.altar_target] or not collection.recipe_known(by_target[collection.altar_target]) then
		collection.altar_target = rows[1] and rows[1].get
	end

	-- the list
	local sc = lg.getWidth() / reference_window_width
	lg.setScissor(0, ALTAR_Y * sc, (ALTAR_X + ALTAR_W + 10) * sc, (ALTAR_BOTTOM - ALTAR_Y) * sc)
	local top = altar_top(#rows)
	for i, recipe in ipairs(rows) do
		local y = top + (i - 1) * ROW_H
		local can, chosen = collection.can_sacrifice(recipe), recipe.get == collection.altar_target
		local st = data.stats_by_name[recipe.get]
		local tier = RARITY_COLOUR[st.rarity]
		lg.setColor(0.07, 0.04, 0.14, 0.9)
		lg.rectangle("fill", ALTAR_X, y, ALTAR_W, ROW_H - 6, 8, 8)
		if chosen then
			lg.setColor(1, 0.85, 0.2)
		elseif can then
			lg.setColor(0.35, 0.8, 0.4)
		else
			lg.setColor(0.4, 0.4, 0.5)
		end
		lg.setLineWidth(chosen and 4 or 2)
		lg.rectangle("line", ALTAR_X, y, ALTAR_W, ROW_H - 6, 8, 8)
		lg.setLineWidth(1)
		for k, name in ipairs(recipe.give) do
			lg.setColor(owns(name) and { 1, 1, 1 } or { 0.3, 0.27, 0.38 })
			lg.draw(assets.card_by_name[name], ALTAR_X + 10 + (k - 1) * 40, y + 3, 0, 0.22)
		end
		lg.setColor(1, 0.85, 0.2, can and 1 or 0.4)
		lg.printf(">", assets.font, ALTAR_X + 172, y + 12, 40, "center")
		lg.setColor(1, 1, 1)
		lg.draw(assets.card_by_name[recipe.get], ALTAR_X + 222, y + 3, 0, 0.22)
		lg.setColor(1, 1, 1, can and 1 or 0.6)
		lg.printf((recipe.get:gsub("_", " ")), assets.small_font, ALTAR_X + 270, y + 8, ALTAR_W - 280)
		lg.setColor(tier[1], tier[2], tier[3], can and 1 or 0.6)
		lg.print(st.tier or "", assets.card_text_font, ALTAR_X + 270, y + 44)
	end
	lg.setScissor()

	-- the details pane
	local px, py, pw, ph = 640, 125, 785, 737
	lg.setColor(0.07, 0.04, 0.14, 0.92)
	lg.rectangle("fill", px, py, pw, ph, 12, 12)
	lg.setColor(1, 0.85, 0.2, 0.7)
	lg.setLineWidth(3)
	lg.rectangle("line", px, py, pw, ph, 12, 12)
	lg.setLineWidth(1)
	local recipe = by_target[collection.altar_target or ""]
	if not recipe then
		lg.setColor(0.8, 0.85, 1)
		lg.printf("No recipes found yet.\nEach one appears once you own all the snakes it asks for.", assets.small_font, px + 40, py + ph / 2 - 40, pw - 80, "center")
		buttons.universal["Back"]:draw()
		return
	end
	local st = data.stats_by_name[recipe.get]
	local tier = RARITY_COLOUR[st.rarity]
	lg.setColor(1, 1, 1)
	lg.print((recipe.get:gsub("_", " ")), assets.font, px + 25, py + 12)
	lg.setColor(tier)
	lg.print("Tier " .. st.rarity .. " " .. (st.tier or "") .. "   |   Snake, " .. data.card_types[recipe.get], assets.small_font, px + 25, py + 70)

	lg.setColor(1, 0.85, 0.2)
	lg.print("The Snake God demands:", assets.small_font, px + 25, py + 115)
	local can = collection.can_sacrifice(recipe)
	for k, name in ipairs(recipe.give) do
		local x = px + 25 + (k - 1) * 98
		local have = owns(name)
		lg.setColor(have and { 1, 1, 1 } or { 0.3, 0.27, 0.38 })
		lg.draw(assets.card_by_name[name], x, py + 150, 0, 0.5)
		lg.setColor(have and { 0.8, 0.9, 1 } or { 1, 0.45, 0.45 })
		lg.printf((name:gsub("_", " ")), assets.card_text_font, x - 4, py + 314, 96, "center")
		lg.printf(have and ("you own " .. collection.count(name)) or "missing", assets.card_text_font, x - 4, py + 362, 96, "center")
	end
	lg.setColor(1, 0.85, 0.2, 0.5 + 0.5 * math.sin(time * 4))
	lg.printf(">", assets.font, px + 420, py + 250, 50, "center")
	lg.setColor(1, 0.85, 0.2)
	lg.print("You receive:", assets.small_font, px + 490, py + 115)
	-- a flame glow behind the reward
	lg.setBlendMode("add")
	for i = 1, 4 do
		lg.setColor(1, 0.45, 0.1, (0.05 + 0.03 * math.sin(time * 3)) * (5 - i))
		lg.rectangle("fill", px + 490 - i * 8, py + 150 - i * 8, 148 + i * 16, 288 + i * 16, 14, 14)
	end
	lg.setBlendMode("alpha")
	lg.push()
	lg.translate(px + 490, py + 150)
	lg.scale(0.9)
	lg.setColor(1, 1, 1)
	lg.draw(assets.card_by_name[recipe.get])
	require("CardText").draw(recipe.get, 0, 0)
	lg.pop()
	local y = py + 450
	y = info_section("Ability", st.ability or "None", px + 25, y, pw - 50, { 1, 0.85, 0.2 }, { 1, 1, 1 })
	if y < 770 then
		info_section("Lore", st.lore or "", px + 25, y, pw - 50, { 0.6, 0.65, 0.85 }, { 0.8, 0.85, 1 })
	end

	lg.setColor(1, 1, 1, can and 1 or 0.4)
	buttons.altar["Offer"]:update_text(can and "Offer them" or "Missing snakes")
	buttons.altar["Offer"]:draw()
	lg.setColor(1, 1, 1)
	if collection.message and time - collection.message_t < 2 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 60, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(collection.message, assets.small_font, 370, 72, 700, "center")
	end
	coach.start("coach_altar", {
		{ rect = { ALTAR_X, ALTAR_Y, ALTAR_W, 330 }, text = "Recipes" },
		{ rect = { 880, 790, 360, 60 }, text = "Offer the snakes" },
	})
	buttons.universal["Back"]:draw()
end

-- The compendium's Borders section: every border with its effect and how many of your snakes carry it
local BORDER_SAMPLE = { Brew = "Stoneskin_Tonic", Spell = "Arcane_Insight" }

local function border_tile(i)
	local tw, th, gap = 335, 170, 15
	local x0 = (reference_window_width - 4 * tw - 3 * gap) / 2
	return x0 + ((i - 1) % 4) * (tw + gap), 85 + math.floor((i - 1) / 4) * (th + 12), tw, th
end

-- Which border tile is at a screen point (nil if none)
function render.border_at(x, y)
	x, y = x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
	for i, name in ipairs(BORDER_PAGE) do
		local tx, ty, tw, th = border_tile(i)
		if x >= tx and x <= tx + tw and y >= ty and y <= ty + th then
			return name
		end
	end
end

-- The snakes you own with the chosen border
local function draw_border_holders(name)
	local c = borders.colour(name) or { 0.7, 0.7, 0.75 }
	lg.setColor(c[1], c[2], c[3])
	lg.printf(name .. " snakes", assets.font, 0, 70, reference_window_width, "center")
	local list = collection.border_holders(name)
	if #list == 0 then
		lg.setColor(0.85, 0.85, 0.95)
		lg.printf("You don't have any snakes with this border yet.", assets.font, 0, 400, reference_window_width, "center")
		return
	end
	local scale, per_row = 0.5, 8
	local cw, ch = img_widths * scale, img_heights * scale
	local x0 = (reference_window_width - per_row * (cw + 12) + 12) / 2
	for i, entry in ipairs(list) do
		local x, y = x0 + ((i - 1) % per_row) * (cw + 12), 140 + math.floor((i - 1) / per_row) * (ch + 12)
		lg.push()
		lg.translate(x, y)
		lg.scale(scale)
		lg.setColor(1, 1, 1)
		lg.draw(assets.card_by_name[entry[1]])
		require("CardText").draw(entry[1], 0, 0)
		borders.draw(name, 0, 0, img_widths, img_heights)
		lg.pop()
		lg.setColor(0, 0, 0, 0.8)
		lg.rectangle("fill", x + 4, y + 4, 40, 24, 5, 5)
		lg.setColor(1, 1, 1)
		lg.printf("x" .. entry[2], assets.small_font, x + 4, y + 4, 40, "center")
	end
end

function render.borders()
	background()
	lg.setColor(0, 0, 0, 0.8)
	lg.printf("Borders", assets.font, 3, 13, reference_window_width, "center")
	lg.setColor(1, 0.85, 0.2)
	lg.printf("Borders", assets.font, 0, 10, reference_window_width, "center")
	if border_view then
		draw_border_holders(border_view)
		buttons.borders["Back"]:draw()
		return
	end
	for i, name in ipairs(BORDER_PAGE) do
		local x, y, tw, th = border_tile(i)
		local c = borders.colour(name) or { 0.7, 0.7, 0.75 }
		lg.setColor(0.07, 0.04, 0.14, 0.92)
		lg.rectangle("fill", x, y, tw, th, 10, 10)
		lg.setColor(c[1], c[2], c[3], 0.8)
		lg.setLineWidth(2)
		lg.rectangle("line", x, y, tw, th, 10, 10)
		lg.setLineWidth(1)
		-- a sample card wearing the border
		local sample = BORDER_SAMPLE[name] or "Dirt_Snake"
		lg.push()
		lg.translate(x + 12, y + 12)
		lg.scale(0.45)
		lg.setColor(1, 1, 1)
		lg.draw(assets.card_by_name[sample])
		borders.draw(name, 0, 0, img_widths, img_heights)
		lg.pop()
		lg.setColor(c[1], c[2], c[3])
		lg.print(name, assets.small_font, x + 100, y + 10)
		local effect, rest = borders[name].text:match("^(.-): (.*)$")
		lg.setColor(1, 0.85, 0.2)
		lg.printf(effect or "Plain", assets.card_text_font, x + 100, y + 44, tw - 112)
		lg.setColor(0.9, 0.92, 1)
		lg.printf(rest or borders[name].text, assets.card_text_font, x + 100, y + 68, tw - 112)
		if name ~= "Basic" and name ~= "Brew" and name ~= "Spell" then
			lg.setColor(0.7, 0.75, 0.95)
			lg.printf("You have " .. collection.border_count(name), assets.card_text_font, x + 100, y + th - 30, tw - 112)
		end
	end
	lg.setColor(0.85, 0.85, 0.95)
	lg.printf("Click a border to see your snakes that have it. Snakes can be pulled from packs with a random border, or imbued with one at the collection.", assets.small_font, 0, 820, reference_window_width, "center")
	buttons.borders["Back"]:draw()
end

function render.achievements()
	background()
	local ach = require("Achievements")
	lg.setColor(1, 0.85, 0.2)
	lg.printf("Achievements  " .. ach.count() .. "/" .. #ach.list, assets.font, 0, 10, reference_window_width, "center")
	for i, a in ipairs(ach.list) do
		local x, y = 100 + ((i - 1) % 2) * 640, 100 + math.floor((i - 1) / 2) * 80
		local have, goal = ach.progress(a)
		local done = have >= goal
		lg.setColor(0.07, 0.04, 0.14, 0.92)
		lg.rectangle("fill", x, y, 600, 74, 10, 10)
		lg.setColor(done and 1 or 0.4, done and 0.85 or 0.4, done and 0.2 or 0.5)
		lg.setLineWidth(2)
		lg.rectangle("line", x, y, 600, 74, 10, 10)
		lg.setLineWidth(1)
		lg.print(a[2], assets.font, x + 18, y + 2)
		lg.setColor(0.85, 0.88, 1, done and 1 or 0.7)
		lg.print(a[3], assets.small_font, x + 18, y + 42)
		lg.printf(done and "Done" or have .. "/" .. goal, assets.small_font, x + 400, y + 42, 180, "right")
		lg.setColor(a[6] == 3 and 1 or 0.6, a[6] == 3 and 0.8 or 0.9, a[6] == 3 and 0.2 or 0.5, done and 0.6 or 1)
		lg.printf("Reward: " .. ach.PACK_NAMES[a[6]], assets.small_font, x + 300, y + 8, 280, "right")
	end
	buttons.achievements["Back"]:draw()
end

function render.lanes()
	background()
	lane_editor.draw()
	coach.start("coach_lanes", { -- first visit
		{ rect = { 110, 200, 1300, 280 }, text = "Four lanes. Each lane fits the two snake types shown" },
		{ rect = { 110, 250, 290, 100 }, text = "Click a type to change it. Any mix works" },
		{ rect = { 75, 695, 1290, 70 }, text = "Or pick a ready-made layout" },
		{ rect = { 300, 625, 840, 40 }, text = "Match your lanes to the snakes in your deck" },
	})
	buttons.lanes["Back"]:draw()
	for i = 1, #play.LANE_PRESETS do
		buttons.lanes["Preset " .. i]:draw()
	end
end

local function rnd(n)
	local v = math.sin(n * 12.9898) * 43758.5453
	return v - math.floor(v)
end

-- A foil pack, 260 x 380 around (0, 0): a dark body of overlapping scales, crimped top and bottom, a coiled snake with a
-- hood and eyes, and the name on a banner. The Elite pack is black and gold with a crown and sparkles. `part` draws just the
-- "top" or "bottom" half either side of a jagged tear (for the opening); `t` animates the shimmer.
local PACK_TEAR = -100
local function pack_art(pack, t, part)
	local c = pack.colour
	local elite = pack.floor ~= nil
	local gold = { 1, 0.82, 0.25 }
	local light = elite and { 1, 0.9, 0.5 } or { math.min(1, c[1] * 1.3 + 0.2), math.min(1, c[2] * 1.3 + 0.2), math.min(1, c[3] * 1.3 + 0.2) }
	local function tint(k, a) lg.setColor(c[1] * k, c[2] * k, c[3] * k, a or 1) end
	if part then
		local points = {}
		for i = 0, 14 do
			points[#points + 1], points[#points + 2] = 140 - i * 20, PACK_TEAR + (i % 2 == 0 and -9 or 9)
		end
		local edge = part == "top" and -210 or 210
		local poly = { 140, edge, -140, edge }
		for i = #points - 1, 1, -2 do -- the tear line, from the left edge back to the right
			poly[#poly + 1], poly[#poly + 2] = points[i], points[i + 1]
		end
		lg.stencil(function() lg.polygon("fill", poly) end, "replace", 1)
		lg.setStencilTest("greater", 0)
	end
	if elite then
		-- body and scales
		tint(elite and 0.16 or 0.38)
		lg.rectangle("fill", -130, -190, 260, 380, 16, 16)
		for row = 0, 19 do
			for col = 0, 6 do
				tint(elite and (0.28 + 0.1 * ((row + col) % 2)) or (0.55 + 0.1 * ((row + col) % 2)), 0.85)
				lg.arc("fill", -100 + col * 30 + (row % 2) * 15, -176 + row * 19, 17, 0, math.pi)
			end
		end
		-- the snake: a flared cobra hood with banded belly scales, a fanged head, and a body coiling down to a tapering tail
		local deep, mid = { 0.55, 0.38, 0.06 }, { 0.86, 0.64, 0.14 }
		local path = {}
		for k = 0, 44 do
			local u = k / 44
			path[k] = { 46 * math.sin(u * math.pi * 3.2) * (1 - 0.3 * u), -80 + u * 205, 17 * (1 - 0.72 * u) }
		end
		for pass = 1, 2 do
			for k = 44, 0, -1 do
				local p = path[k]
				if pass == 1 then
					lg.setColor(0, 0, 0, 0.85)
					lg.circle("fill", p[1], p[2], p[3] + 3)
				else
					local band = k % 8 < 4
					lg.setColor(band and gold[1] or mid[1], band and gold[2] or mid[2], band and gold[3] or mid[3])
					lg.circle("fill", p[1], p[2], p[3])
					lg.setColor(1, 0.97, 0.75, 0.45)
					lg.circle("fill", p[1] - p[3] * 0.3, p[2] - p[3] * 0.3, p[3] * 0.35)
				end
			end
		end
		-- the hood: wide at the shoulders, narrowing up to the head
		local hood = { -52, -74, -44, -106, -22, -132, 22, -132, 44, -106, 52, -74, 20, -62, -20, -62 }
		lg.setColor(0, 0, 0, 0.9)
		lg.setLineWidth(8)
		lg.polygon("line", hood)
		lg.setLineWidth(1)
		lg.setColor(mid[1], mid[2], mid[3])
		lg.polygon("fill", hood)
		for i = 0, 4 do -- belly scales: curved bands across the hood
			lg.setColor(i % 2 == 0 and gold[1] or deep[1], i % 2 == 0 and gold[2] or deep[2], i % 2 == 0 and gold[3] or deep[3])
			lg.arc("fill", "open", 0, -134 + i * 15, 38 + i * 3, math.pi * 0.12, math.pi * 0.88)
			lg.setColor(0, 0, 0, 0.5)
			lg.arc("line", "open", 0, -134 + i * 15, 38 + i * 3, math.pi * 0.12, math.pi * 0.88)
		end
		lg.setColor(0, 0, 0, 0.9) -- the head: a rounded wedge with a brow ridge
		lg.polygon("fill", -30, -128, -22, -150, 22, -150, 30, -128, 18, -98, -18, -98)
		lg.setColor(gold[1], gold[2], gold[3])
		lg.polygon("fill", -27, -128, -20, -146, 20, -146, 27, -128, 16, -102, -16, -102)
		lg.setColor(1, 0.97, 0.75, 0.5)
		lg.ellipse("fill", -8, -138, 9, 5)
		for side = -1, 1, 2 do
			lg.setColor(0, 0, 0)
			lg.polygon("fill", side * 7, -136, side * 24, -142, side * 24, -126, side * 10, -126)
			lg.setColor(0.95, 0.15, 0.15)
			lg.polygon("fill", side * 9, -134, side * 22, -139, side * 22, -128, side * 11, -128)
			lg.setColor(0, 0, 0)
			lg.rectangle("fill", side * 16 - 1, -140, 2, 12)
			lg.setColor(0.97, 0.96, 0.85) -- fangs
			lg.polygon("fill", side * 8 - 3, -104, side * 8 + 3, -104, side * 8, -90)
		end
		lg.setColor(0, 0, 0, 0.6)
		lg.circle("fill", -4, -118, 1.5)
		lg.circle("fill", 4, -118, 1.5)
		lg.setColor(0.9, 0.12, 0.2) -- forked tongue
		lg.polygon("fill", -1.5, -96, 1.5, -96, 1.5, -80, -1.5, -80)
		lg.polygon("fill", -1.5, -80, -8, -70, -5, -70, 0, -77, 5, -70, 8, -70, 1.5, -80)
		if elite then -- a crown
			lg.setColor(0, 0, 0, 0.9)
			lg.polygon("fill", -36, -146, -38, -176, -20, -160, 0, -184, 20, -160, 38, -176, 36, -146)
			lg.setColor(gold)
			lg.polygon("fill", -32, -148, -33, -170, -19, -157, 0, -178, 19, -157, 33, -170, 32, -148)
			lg.setColor(0.9, 0.2, 0.3)
			lg.circle("fill", 0, -156, 4)
		end
	elseif pack.kind == "snake" then
		-- Serpent pack: diamondback skin and an ouroboros (a snake eating its tail) round a slit eye
		tint(0.34)
		lg.rectangle("fill", -130, -190, 260, 380, 16, 16)
		for row = 0, 11 do
			for col = 0, 4 do
				local dx, dy = -90 + col * 45 + (row % 2) * 22, -165 + row * 32
				tint(0.5 + 0.12 * ((row + col) % 2), 0.9)
				lg.polygon("fill", dx, dy - 16, dx + 20, dy, dx, dy + 16, dx - 20, dy)
				tint(0.28, 0.9)
				lg.polygon("line", dx, dy - 16, dx + 20, dy, dx, dy + 16, dx - 20, dy)
			end
		end
		local ring = 0.34 * math.pi
		for pass = 1, 2 do
			for k = 0, 56 do
				local u = k / 56
				local ang = -math.pi / 2 + ring + u * (2 * math.pi - ring * 1.2)
				local px, py = 64 * math.cos(ang), -30 + 64 * math.sin(ang)
				local r = 8 + 7 * math.sin(u * math.pi)
				if pass == 1 then
					lg.setColor(0, 0, 0, 0.85)
					lg.circle("fill", px, py, r + 3)
				else
					if k % 6 < 3 then
						lg.setColor(light[1], light[2], light[3])
					else
						lg.setColor(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85)
					end
					lg.circle("fill", px, py, r)
				end
			end
		end
		lg.setColor(0, 0, 0, 0.85) -- the head, biting the tail
		lg.ellipse("fill", 14, -94, 22, 17)
		lg.setColor(light[1], light[2], light[3])
		lg.ellipse("fill", 14, -94, 19, 14)
		lg.setColor(1, 0.9, 0.2)
		lg.circle("fill", 8, -98, 4)
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", 7, -102, 2, 8)
		lg.setColor(0, 0, 0, 0.85) -- the slit eye in the middle
		lg.ellipse("fill", 0, -30, 40, 26)
		lg.setColor(0.95, 0.85, 0.2)
		lg.ellipse("fill", 0, -30, 35, 21)
		lg.setColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3)
		lg.ellipse("fill", 0, -30, 14, 19)
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", -3, -49, 6, 38)
		lg.setBlendMode("add")
		lg.setColor(1, 1, 1, 0.35)
		lg.circle("fill", -14, -40, 4)
		lg.setBlendMode("alpha")
	else
		-- Support pack: a night sky and a bubbling flask with a snake coiled round its neck
		tint(0.22)
		lg.rectangle("fill", -130, -190, 260, 380, 16, 16)
		for i = 1, 42 do
			local sx, sy = (rnd(i * 2.9) - 0.5) * 230, (rnd(i * 5.3) - 0.5) * 350
			local twinkle = 0.5 + 0.5 * math.sin(t * 2 + i)
			lg.setColor(1, 1, 0.85, 0.35 + 0.5 * twinkle * (i % 3 == 0 and 1 or 0.4))
			lg.rectangle("fill", sx, sy, i % 5 == 0 and 4 or 2, i % 5 == 0 and 4 or 2)
		end
		tint(0.6, 0.35)
		for r = 1, 3 do
			lg.setLineWidth(3)
			lg.arc("line", "open", 0, 40, 60 + r * 28, math.pi * 1.05, math.pi * 1.95)
		end
		lg.setLineWidth(1)
		-- the flask
		lg.setColor(0.04, 0.03, 0.1, 0.9)
		lg.circle("fill", 0, 10, 62)
		lg.rectangle("fill", -22, -76, 44, 40)
		lg.setColor(0.15, 0.18, 0.35)
		lg.circle("fill", 0, 10, 57)
		lg.rectangle("fill", -17, -72, 34, 40)
		local surface = 4 + 3 * math.sin(t * 3)
		local phi0 = math.acos(math.max(-1, math.min(1, (surface - 10) / 57)))
		local liquid = {}
		for k = 0, 16 do -- the part of the flask's round below the liquid's surface
			local phi = -phi0 + k / 16 * 2 * phi0
			liquid[#liquid + 1], liquid[#liquid + 2] = 57 * math.sin(phi), 10 + 57 * math.cos(phi)
		end
		lg.setColor(c[1] * 0.9, c[2] * 0.9, c[3] * 0.9)
		lg.polygon("fill", liquid)
		lg.setColor(light[1], light[2], light[3], 0.8)
		for i = 0, 6 do
			lg.circle("fill", -42 + i * 14, surface + 1.5 * math.sin(t * 4 + i), 7)
		end
		for i = 1, 5 do
			local rise = (t * 0.4 + rnd(i)) % 1
			lg.setColor(1, 1, 1, 0.7 * (1 - rise))
			lg.circle("line", (rnd(i * 4.1) - 0.5) * 44, 52 - rise * 44, 3 + 3 * rnd(i * 1.7))
		end
		lg.setColor(1, 1, 1, 0.3)
		lg.rectangle("fill", -42, -10, 8, 40, 4, 4)
		lg.setColor(0.65, 0.45, 0.25) -- cork
		lg.rectangle("fill", -14, -94, 28, 20, 4, 4)
		-- a snake coiled twice round the neck, head resting on the shoulder
		for pass = 1, 2 do
			for k = 0, 36 do
				local u = k / 36
				local ang = u * math.pi * 4
				local px, py = 24 * math.cos(ang), -62 + u * 26 + 6 * math.sin(ang)
				local r = 6.5 * (1 - 0.35 * u)
				if pass == 1 then
					lg.setColor(0, 0, 0, 0.85)
					lg.circle("fill", px, py, r + 2.5)
				else
					if k % 6 < 3 then
						lg.setColor(0.5, 0.92, 0.4)
					else
						lg.setColor(0.2, 0.62, 0.3)
					end
					lg.circle("fill", px, py, r)
				end
			end
		end
		lg.setColor(0, 0, 0, 0.85)
		lg.ellipse("fill", 38, -34, 19, 14)
		lg.setColor(0.5, 0.92, 0.4)
		lg.ellipse("fill", 38, -34, 16, 11)
		lg.setColor(1, 0.9, 0.2)
		lg.circle("fill", 43, -37, 3.5)
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", 42, -41, 2, 8)
		lg.setColor(0.9, 0.15, 0.2)
		lg.polygon("fill", 52, -33, 66, -36, 66, -30)
	end
	-- crimped top and bottom, and the frame
	for _, edge in ipairs({ -190, 168 }) do
		tint(elite and 0.5 or 0.75)
		lg.rectangle("fill", -130, edge, 260, 22, 8, 8)
		lg.setColor(0, 0, 0, 0.35)
		for x = -124, 124, 8 do
			lg.rectangle("fill", x, edge + 2, 2, 18)
		end
	end
	local rim = elite and gold or light
	lg.setColor(rim[1], rim[2], rim[3])
	lg.setLineWidth(elite and 7 or 5)
	lg.rectangle("line", -130, -190, 260, 380, 16, 16)
	if elite then
		lg.setLineWidth(2)
		lg.rectangle("line", -118, -178, 236, 356, 10, 10)
		for _, corner in ipairs({ { -130, -190 }, { 130, -190 }, { -130, 190 }, { 130, 190 } }) do
			lg.circle("fill", corner[1] * 0.94, corner[2] * 0.94, 7)
		end
	end
	lg.setLineWidth(1)
	-- name banner
	lg.setColor(0, 0, 0, 0.82)
	lg.rectangle("fill", -112, 118, 224, 44, 6, 6)
	lg.setColor(rim[1], rim[2], rim[3])
	lg.rectangle("line", -112, 118, 224, 44, 6, 6)
	lg.printf(pack.name, assets.small_font, -112, 124, 224, "center")
	-- a glint sweeping across, then sparkles for the Elite pack
	local sweep = ((t * 0.45) % 2.2) * 330 - 260
	lg.setBlendMode("add")
	lg.setColor(1, 1, 1, elite and 0.22 or 0.14)
	local function cl(x) return math.max(-130, math.min(130, x)) end
	lg.polygon("fill", cl(sweep), -190, cl(sweep + 46), -190, cl(sweep + 46 + 130), 190, cl(sweep + 130), 190)
	if elite then
		for i = 1, 7 do
			local life = (t * 0.7 + i * 0.37) % 1
			local sx, sy = (rnd(i * 3.3) - 0.5) * 220, (rnd(i * 7.1) - 0.5) * 340
			lg.setColor(1, 0.9, 0.4, math.sin(life * math.pi))
			local r = 3 + 7 * math.sin(life * math.pi)
			lg.rectangle("fill", sx - 1, sy - r, 2, r * 2)
			lg.rectangle("fill", sx - r, sy - 1, r * 2, 2)
		end
	end
	lg.setBlendMode("alpha")
	if part then
		lg.setStencilTest()
	end
	lg.setLineWidth(1)
end

function render.shop()
	background()
	lg.setColor(1, 1, 1)
	lg.printf("Pack Shop", assets.font, 0, 40, reference_window_width, "center")
	lg.setColor(0, 0, 0, 0.7)
	lg.rectangle("fill", reference_window_width / 2 - 200, 98, 400, 38, 8, 8)
	lg.setColor(1, 0.85, 0.2)
	draw_eyes("You have ", collection.eyes, 0, 102, reference_window_width, "center")
	local lore = require("Lore")
	for i, pack in ipairs(collection.PACKS) do
		local tiers = pack.kind == "snake" and lore.tiers or lore.support_tiers
		local x = 110 + (i - 1) * 420
		local c, price = pack.colour, collection.price(i)
		local weights, border_chance = collection.odds(pack)
		local elite = pack.floor ~= nil
		lg.setColor(0.05, 0.03, 0.1, 0.78)
		lg.rectangle("fill", x, 170, 380, 560, 14, 14)
		lg.setColor(c[1], c[2], c[3])
		lg.setLineWidth(elite and 6 or 4)
		lg.rectangle("line", x, 170, 380, 560, 14, 14)
		if elite then -- gold trim inside the frame
			lg.setLineWidth(2)
			lg.rectangle("line", x + 8, 178, 364, 544, 9, 9)
		end
		lg.setLineWidth(1)
		lg.push()
		lg.translate(x + 82, 312)
		lg.scale(0.37)
		pack_art(pack, time + i)
		lg.pop()
		lg.setColor(elite and { 1, 0.85, 0.3 } or { 1, 1, 1 })
		lg.printf(pack.name, assets.font, x, 184, 380, "center")
		if price == 0 and not (pack.daily and collection.pack_ready()) then
			lg.setColor(0.8, 1, 0.7)
			lg.printf("Reward pack (x" .. collection.tokens(i) .. ")", assets.small_font, x + 150, 262, 220, "left")
		elseif price == 0 then
			lg.setColor(0.8, 1, 0.7)
			lg.printf("Free today (one a day)", assets.small_font, x + 150, 262, 220, "left")
		else
			lg.setColor(1, 0.85, 0.2)
			draw_eyes("", price, x + 150, 262, 220, "left")
		end
		lg.setColor(0.8, 0.8, 0.8)
		lg.printf(pack.kind == "snake" and (pack.floor and "3, 4 and 5 star snakes only" or "Snakes") or "Brews and spells", assets.small_font, x + 150, 330, 220, "left")
		lg.setColor(1, 1, 1)
		lg.printf("Chance per card", assets.small_font, x, 386, 380, "center")
		local row = 0
		for r, weight in ipairs(weights) do
			if weight > 0 then
				local y = 418 + row * 34
				lg.push()
				lg.translate(x + 35, y + 2)
				lg.scale(1.2)
				for star = 1, r do -- one star per rarity level
					require("CardText").star((star - 1) * 18, 0)
				end
				lg.pop()
				lg.setColor(0.8, 0.8, 0.8)
				lg.print(tiers[r], assets.small_font, x + 35 + 5 * 21.6 + 10, y)
				lg.printf(weight .. "%", assets.small_font, x + 250, y, 90, "right")
				row = row + 1
			end
		end
		if border_chance > 0 then
			lg.setColor(1, 0.85, 0.2)
			lg.printf(math.floor(border_chance * 100 + 0.5) .. "% chance of a border", assets.small_font, x, 612, 380, "center")
		end
		local button = buttons.shop["Pack " .. i]
		button:update_text("Open")
		lg.setColor(1, 1, 1, collection.eyes < price and 0.45 or 1)
		button:draw()
	end
	lg.setColor(1, 1, 1)
	if collection.message and time - collection.message_t < 2 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 780, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(collection.message, assets.font, 370, 785, 700, "center")
	end
	lg.setColor(0.85, 0.85, 0.95)
	lg.printf("Earn snake eyes by beating opponents. Beat more of them for better odds.", assets.small_font, 0, 745, reference_window_width, "center")
	coach.start("coach_shop2", {
		{ rect = { 110, 170, 380, 560 }, text = "Spend snake eyes" },
		{ rect = { 110, 235, 380, 40 }, text = "One free pack a day" },
		{ rect = { 110, 170, 800, 560 }, text = "Pick one free pack: Serpent for snakes, or Support for brews and spells" },
	})
	buttons.shop["Back"]:draw()
end

-- Square sparks flying out from (x, y) that fall and fade; age in seconds
local function burst(x, y, age, count, colour, speed)
	if age < 0 or age > 1.4 then
		return
	end
	lg.setBlendMode("add")
	for k = 1, count do
		local angle, v = rnd(k * 1.7) * 6.283, speed * (0.3 + rnd(k * 3.1))
		local px, py = x + math.cos(angle) * v * age, y + math.sin(angle) * v * age + 260 * age * age
		lg.setColor(colour[1], colour[2], colour[3], 1 - age / 1.4)
		local size = 4 + math.floor(rnd(k * 5.3) * 6)
		lg.rectangle("fill", math.floor(px), math.floor(py), size, size)
	end
	lg.setBlendMode("alpha")
end

local REVEAL_START, REVEAL_GAP = 1.9, 1.0
local pack_fired = {} -- which sounds this opening has played

-- A sealed pack shakes and bursts open, then each snake is flipped over in turn (rarer snakes get a bigger show)
function render.pack()
	if pack_seen ~= pack_cards then
		pack_seen, pack_t = pack_cards, time
	end
	local t = time - pack_t
	background()
	local sfx = require("Sounds")
	local function once(key, name)
		if pack_fired[key] == nil then
			pack_fired[key] = true
			sfx.play(name)
		end
	end
	if pack_fired.seen ~= pack_cards then
		pack_fired = { seen = pack_cards }
	end
	once("start", collection.pack_kind == 0 and "summon" or "rumble")
	if t >= 1.5 then
		once("burst", "burst")
	end
	local pack = collection.PACKS[collection.pack_kind]
	local colour = pack and pack.colour or { 0.8, 0.2, 0.2 }
	local cx, cy = reference_window_width / 2, reference_window_height / 2
	lg.setColor(1, 1, 1)
	local title_alpha = math.min(1, math.max(0, t - REVEAL_START + 0.3))
	lg.setColor(1, 1, 1, title_alpha)
	local heading = #pack_cards == 0 and "You own every snake you can pull" or (pack and "Pack opened!" or "Summoned!")
	lg.setColor(0, 0, 0, title_alpha)
	lg.printf(heading, assets.font, 3, 63, reference_window_width, "center")
	lg.setColor(1, 1, 1, title_alpha)
	lg.printf(heading, assets.font, 0, 60, reference_window_width, "center")

	local rise = math.min(1, t / 0.4)
	rise = 1 - (1 - rise) ^ 3 -- the pack flies up into the middle
	local lift = (1 - rise) * 500
	local src = pack or { name = "Summon", colour = colour }
	if t < 1.5 then -- the sealed pack: shakes harder and glows brighter, light leaking out of the seam, until it tears open
		local k = math.max(0, (t - 0.4) / 1.1)
		local shake = k ^ 2 * 14
		local px, py = cx + math.sin(t * 60) * shake, cy + lift + math.cos(t * 47) * shake * 0.6
		lg.setBlendMode("add")
		for i = 1, 5 do
			lg.setColor(colour[1], colour[2], colour[3], (0.04 + 0.1 * k) * rise)
			lg.circle("fill", px, py, 150 + i * 28 + t * 40)
		end
		lg.setBlendMode("alpha")
		lg.push()
		lg.translate(px, py)
		lg.rotate(math.sin(t * 40) * shake * 0.004)
		lg.scale(0.7 + 0.3 * rise)
		pack_art(src, t)
		lg.setBlendMode("add") -- light along the seam
		lg.setColor(1, 0.95, 0.7, k * k)
		lg.rectangle("fill", -130, PACK_TEAR - 3 - 6 * k, 260, 6 + 12 * k)
		lg.setBlendMode("alpha")
		lg.pop()
	else
		local u = t - 1.5
		local flash = 1 - u / 0.5
		-- the top tears off and tumbles away, the bottom drops out of sight
		local fade = math.max(0, 1 - u / 0.9)
		if fade > 0 then
			lg.push()
			lg.translate(cx - u * 120, cy - 600 * u + 450 * u * u - 40)
			lg.rotate(-u * 2.2)
			lg.setColor(1, 1, 1, fade)
			pack_art(src, t, "top")
			lg.pop()
			lg.push()
			lg.translate(cx, cy + 700 * u * u)
			lg.rotate(u * 0.3)
			lg.setColor(1, 1, 1, fade)
			pack_art(src, t, "bottom")
			lg.pop()
		end
		lg.setBlendMode("add") -- rays of light from the pack
		for ray = 1, 9 do
			local angle = -math.pi / 2 + (ray - 5) * 0.16
			lg.setColor(colour[1], colour[2], colour[3], 0.16 * math.max(0, 1 - u / 1.2))
			lg.polygon("fill", cx, cy, cx + math.cos(angle - 0.05) * 900, cy + math.sin(angle - 0.05) * 900, cx + math.cos(angle + 0.05) * 900, cy + math.sin(angle + 0.05) * 900)
		end
		lg.setBlendMode("alpha")
		burst(cx, cy, u, 70, colour, 700)
		if pack and pack.floor then -- the Elite pack throws gold too
			burst(cx, cy, u, 50, { 1, 0.85, 0.3 }, 900)
		end
		if flash > 0 then
			lg.setColor(1, 1, 1, flash)
			lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
		end
	end

	local gap, scale = 40, 1.8
	local hovered_pull
	local n = #pack_cards
	local x0 = (reference_window_width - n * img_widths * scale - (n - 1) * gap) / 2
	for i, name in ipairs(pack_cards) do
		local age = t - (REVEAL_START + (i - 1) * REVEAL_GAP)
		if age > 0 then
			local st = data.stats_by_name[name]
			once("reveal" .. i, "reveal" .. st.rarity)
			local c = RARITY_COLOUR[st.rarity]
			local px = x0 + (i - 1) * (img_widths * scale + gap) + img_widths * scale / 2
			local py = 190 + img_heights * scale / 2
			-- rays behind the card, stronger for rarer snakes
			lg.setBlendMode("add")
			for ray = 1, 6 + st.rarity * 2 do
				local angle = ray / (6 + st.rarity * 2) * 6.283 + time * 0.4
				lg.setColor(c[1], c[2], c[3], math.min(1, age * 2) * (0.04 + 0.02 * st.rarity))
				lg.polygon("fill", px, py, px + math.cos(angle - 0.06) * 700, py + math.sin(angle - 0.06) * 700, px + math.cos(angle + 0.06) * 700, py + math.sin(angle + 0.06) * 700)
			end
			lg.setBlendMode("alpha")
			lg.setColor(c[1], c[2], c[3], math.max(0, 0.8 - age * 1.6)) -- a ring spreads out as it turns over
			lg.setLineWidth(5)
			lg.circle("line", px, py, 40 + age * 500)
			lg.setLineWidth(1)
			local flip = math.min(1, age / 0.5)
			local pop = 1 + 0.15 * math.max(0, 1 - age * 3)
			local face = flip >= 0.5
			lg.push()
			lg.translate(px, py)
			lg.scale(math.abs(math.cos(flip * math.pi)) * pop, pop)
			lg.translate(-img_widths * scale / 2, -img_heights * scale / 2)
			lg.scale(scale)
			if face then
				lg.setColor(1, 1, 1)
				lg.draw(assets.card_by_name[name])
				require("CardText").draw(name, 0, 0)
				borders.draw(collection.pack_borders and collection.pack_borders[i] or st.border, 0, 0, img_widths, img_heights, st.rarity)
			else
				lg.setColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5)
				lg.rectangle("fill", 0, 0, img_widths, img_heights, 8, 8)
				for row = 0, 15 do -- scales, and a slit eye in the middle
					for col = 0, 4 do
						lg.setColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7)
						lg.arc("fill", 12 + col * 34 + (row % 2) * 17, 10 + row * 20, 17, 0, math.pi)
					end
				end
				lg.setColor(c[1], c[2], c[3])
				lg.setLineWidth(4)
				lg.rectangle("line", 8, 8, img_widths - 16, img_heights - 16, 6, 6)
				lg.setLineWidth(1)
				lg.setColor(0, 0, 0, 0.8)
				lg.ellipse("fill", img_widths / 2, img_heights / 2, 44, 28)
				lg.setColor(1, 0.9, 0.2)
				lg.ellipse("fill", img_widths / 2, img_heights / 2, 38, 22)
				lg.setColor(0, 0, 0)
				lg.rectangle("fill", img_widths / 2 - 3, img_heights / 2 - 22, 6, 44)
			end
			lg.pop()
			if collection.pack_new[name] and face then
				lg.setColor(1, 0.85, 0.2, math.min(1, (age - 0.5) * 4))
				lg.printf("NEW!", assets.font, px - 100, 135, 200, "center")
			end
			local pulled_border = collection.pack_borders and collection.pack_borders[i]
			if face and pulled_border and pulled_border ~= st.border then -- a variant: its new border
				local bc = borders.colour(pulled_border)
				lg.setColor(bc[1], bc[2], bc[3], math.min(1, (age - 0.5) * 4))
				lg.printf(pulled_border .. " border!", assets.small_font, px - 140, py + img_heights * scale / 2 + 8, 280, "center")
			end
			burst(px, py, age - 0.4, 12 + st.rarity * 14, c, 250 + st.rarity * 120)
			local mx, my = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
			if face and math.abs(mx - px) < img_widths * scale / 2 and math.abs(my - py) < img_heights * scale / 2 then
				hovered_pull = { name, st, collection.pack_borders and collection.pack_borders[i] }
			end
		end
	end
	if hovered_pull then -- the same info popup as a snake on the field
		local mx, my = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
		card_popup({ card_path = hovered_pull[1] .. ".png", border = hovered_pull[3] }, mx + 24, my + 24)
	end
	lg.setColor(1, 1, 1)
	collection.pack_revealed = t > REVEAL_START + n * REVEAL_GAP
	if collection.pack_revealed then
		buttons.pack["Done"]:draw()
		local pack = collection.PACKS[collection.pack_kind]
		if pack then
			local price = collection.price(collection.pack_kind)
			local again = buttons.pack["Again"]
			again:update_text("")
			lg.setColor(1, 1, 1, collection.eyes >= price and 1 or 0.45)
			again:draw()
			lg.setColor(0.98, 0.94, 0.7, collection.eyes >= price and 1 or 0.45) -- the label, with the snake eye after the price
			draw_eyes("Open Another ", price, again.x, again.y + (again.height - assets.font:getHeight()) / 2, again.width, "center", assets.font)
			lg.setColor(1, 0.85, 0.2)
			draw_eyes("", collection.eyes, reference_window_width - 345, 20, 330, "right")
		end
	end
	if collection.message and time - collection.message_t < 2 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 730, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(collection.message, assets.font, 370, 735, 700, "center")
	end
end

-- Charmer cards: up to 5 across and as many rows as needed, in reference-window units
local CARD_W, CARD_H, CARD_GAP, PORTRAIT_H, PER_ROW = 170, 384, 12, 150, 5
local LOOKS_Y = PORTRAIT_H + 18 -- the strip of looks under the portrait, then the name and charm below it
local LOOKS_H = 54
local crops = {}

local function card_pos(i)
	local row, count = math.ceil(i / PER_ROW), math.min(PER_ROW, charmers.PICKABLE - (math.ceil(i / PER_ROW) - 1) * PER_ROW)
	local x0 = (reference_window_width - count * CARD_W - (count - 1) * CARD_GAP) / 2 -- each row is centred
	return x0 + ((i - 1) % PER_ROW) * (CARD_W + CARD_GAP), 85 + (row - 1) * (CARD_H + 20)
end

-- Returns the name of the charmer card under the given window position
function render.charmer_at(x, y)
	local rx, ry = x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
	for i = 1, charmers.PICKABLE do
		local cx, cy = card_pos(i)
		if rx > cx and rx < cx + CARD_W and ry > cy and ry < cy + CARD_H and charmers.is_unlocked(i) then
			return charmers.list[i].name
		end
	end
end

-- The four look slots in the strip under a charmer's portrait: { x, y, w, h, look number } each (a charmer with no extra
-- looks has just its one picture in the first slot, the rest stay empty)
local LOOK_SLOTS = 4
local function skin_boxes(i)
	local boxes = {}
	local x, y = card_pos(i)
	for n = 1, LOOK_SLOTS do
		boxes[n] = { x + 12 + (n - 1) * 38, y + LOOKS_Y, 34, 40, n }
	end
	return boxes
end

-- The charmer and look whose small picture is under the given window position
function render.skin_at(x, y)
	local rx, ry = x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
	for i = 1, charmers.PICKABLE do
		for _, b in ipairs(charmers.is_unlocked(i) and charmers.skin_count(charmers.list[i]) > 1 and skin_boxes(i) or {}) do
			if b[5] <= charmers.skin_count(charmers.list[i]) and rx > b[1] and rx < b[1] + b[3] and ry > b[2] and ry < b[2] + b[4] then
				return charmers.list[i].name, b[5]
			end
		end
	end
end

local skin_images = {}

-- Draws a charmer's portrait cropped to fill w x h
local LOWER_CROP = { ["Yuki Frostveil"] = 0.5, ["Ember Queen"] = 0.5, ["Warden Basalt"] = 0.5 } -- how far down the spare height the crop starts, so these portraits sit higher in the frame
local function portrait(name, x, y, w, h)
	local image = assets.avatars[name]
	local iw, ih = image:getDimensions()
	if not crops[name] then
		local cw, ch = math.min(iw, ih * w / h), math.min(ih, iw * h / w)
		crops[name] = lg.newQuad((iw - cw) / 2, (ih - ch) * (LOWER_CROP[name] or 0), cw, ch, iw, ih)
	end
	local _, _, cw = crops[name]:getViewport()
	lg.draw(image, crops[name], x, y, 0, w / cw)
end

function render.character_select()
	background()
	local x1, y1 = card_pos(1)
	local charm_known = collection.unlock_all or unlocked >= 4 -- charm powers are taught at level 4, so stay hidden until then
	local lesson = { { rect = { x1, y1, CARD_W, CARD_H }, text = "A charmer is your hero. Pick one to fight beside you." } }
	if charm_known then
		lesson[2] = { rect = { x1, y1 + PORTRAIT_H + LOOKS_H + 44, CARD_W, 110 }, text = "Each charmer has a charm: a power you can use for venom, then it needs time to recharge" }
	end
	lesson[#lesson + 1] = { rect = { x1, y1, PER_ROW * CARD_W + (PER_ROW - 1) * CARD_GAP, 2 * CARD_H + 20 }, text = "Click a card to choose. Some have small pictures to pick a different look" }
	coach.start("coach_charmers", lesson) -- first visit
	lg.setColor(1, 0.85, 0.3)
	lg.printf("Every " .. collection.WINS_PER_BONUS .. " wins with a charmer gives all your charmers +" .. collection.BONUS_HEALTH .. " health. Bonus now: +" .. collection.health_bonus() .. " health. (The number in brackets is wins to go.)", assets.small_font, 0, 800, reference_window_width, "center")
	lg.setColor(1, 1, 1)
	buttons.character_select["Charmers Header"]:draw()
	buttons.universal["Back"]:draw()
	local hovered = render.charmer_at(mouse.x, mouse.y)
	for i = 1, charmers.PICKABLE do
		local c = charmers.list[i]
		local x, y = card_pos(i)
		local selected = c.name == chosen_avatar
		lg.setColor(selected and green or (hovered == c.name and { 0.97, 0.9, 0.2 } or { 15 / 255, 140 / 255, 220 / 255 }))
		lg.rectangle("fill", x - 5, y - 5, CARD_W + 10, CARD_H + 10, 5, 5)
		lg.setColor(hovered == c.name and { 0.45, 0.25, 0.65 } or purple)
		lg.rectangle("fill", x, y, CARD_W, CARD_H, 5, 5)
		lg.setColor(1, 1, 1)
		portrait(c.name, x + 10, y + 10, CARD_W - 20, PORTRAIT_H)
		if selected then
			lg.setColor(green)
			lg.rectangle("fill", x + 10, y + 10, 90, 24)
			lg.setColor(1, 1, 1)
			lg.printf("Selected", assets.debug_font, x + 10, y + 12, 90, "center")
		end
		local looks = charmers.skin_count(c)
		for _, b in ipairs(charmers.is_unlocked(i) and skin_boxes(i) or {}) do -- the looks to choose from
			lg.setColor(0, 0, 0, 0.45)
			lg.rectangle("fill", b[1] - 3, b[2] - 3, b[3] + 6, b[4] + 6, 4, 4)
			if b[5] <= math.max(looks, 1) then
				local file = "assets/characters/" .. c.portrait:gsub("%..+$", "") .. (looks > 0 and "_" .. b[5] or "") .. ".png"
				skin_images[file] = skin_images[file] or lg.newImage(file)
				local image = skin_images[file]
				lg.setColor(1, 1, 1)
				lg.draw(image, b[1], b[2], 0, b[3] / image:getWidth(), b[4] / image:getHeight())
				if (charmers.skin[c.name] or 1) == b[5] then
					lg.setColor(green)
					lg.setLineWidth(3)
					lg.rectangle("line", b[1] - 3, b[2] - 3, b[3] + 6, b[4] + 6, 4, 4)
					lg.setLineWidth(1)
				end
			end
		end
		lg.setColor(1, 1, 1)
		lg.printf(c.name, assets.debug_font, x + 6, y + PORTRAIT_H + LOOKS_H + 24, CARD_W - 12, "center")
		if charmers.is_unlocked(i) then -- wins with this charmer, and how many more until the next health bonus
			local wins = collection.charmer_wins(c.name)
			lg.setColor(0, 0, 0, 0.75)
			lg.rectangle("fill", x + CARD_W - 86, y + PORTRAIT_H - 18, 76, 24, 4, 4)
			lg.setColor(1, 0.85, 0.3)
			lg.printf("Wins " .. wins .. " (" .. (collection.WINS_PER_BONUS - wins % collection.WINS_PER_BONUS) .. ")", assets.debug_font, x + CARD_W - 86, y + PORTRAIT_H - 15, 76, "center")
			lg.setColor(1, 1, 1)
		end
		if not charmers.is_unlocked(i) then
			lg.setColor(0, 0, 0, 0.72)
			lg.rectangle("fill", x, y, CARD_W, CARD_H, 5, 5)
			lg.setColor(1, 1, 1)
			lg.printf("Locked\nBeat " .. charmers.region_needed(i) .. " to unlock", assets.debug_font, x + 8, y + PORTRAIT_H / 2, CARD_W - 16, "center")
		elseif charm_known then
			lg.setColor(green)
			lg.printf(c.charm .. " (" .. c.cost .. " venom, cooldown " .. c.cooldown .. ")", assets.debug_font, x + 8, y + PORTRAIT_H + LOOKS_H + 48, CARD_W - 16, "center")
			lg.setColor(1, 1, 1)
			lg.printf(c.text, assets.debug_font, x + 8, y + PORTRAIT_H + LOOKS_H + 108, CARD_W - 16, "center")
		end
	end
end

function render.settings()
	background()
	buttons.universal["Back"]:draw()
	local p, blue = settings.panel, { 15 / 255, 140 / 255, 220 / 255 }
	lg.setColor(blue)
	lg.rectangle("fill", p.x - 5, p.y - 5, p.w + 10, p.h + 10, 8, 8)
	lg.setColor(0.1, 0.05, 0.2, 0.92)
	lg.rectangle("fill", p.x, p.y, p.w, p.h, 5, 5)

	local font, left, right = assets.font, p.x + 40, p.x + p.w - 40
	for _, item in ipairs(settings.items) do
		if item.heading then
			lg.setColor(green)
			lg.print(item.heading, assets.small_font, left, item.y + 4)
			lg.setLineWidth(2)
			lg.line(left, item.y + 34, right, item.y + 34)
		else
			lg.setColor(1, 1, 1)
			lg.print(item.label, font, left, item.y + (52 - font:getHeight()) / 2)
			if item.icon then
				local icon = audio and assets.icons.audio_enabled or assets.icons.audio_disabled
				lg.draw(icon, left + font:getWidth(item.label) + 20, item.y + 4, 0, 44 / icon:getHeight())
			end
			if item.slider then
				local x, y, w = settings.CX, settings.slider_y, settings.SW
				lg.setColor(blue)
				lg.rectangle("fill", x, y - 5, w, 10, 5, 5)
				lg.setColor(green)
				lg.rectangle("fill", x, y - 5, w * settings.volume, 10, 5, 5)
				lg.setColor(blue)
				lg.circle("fill", x + w * settings.volume, y, 22)
				lg.setColor(settings.dragging and green or purple)
				lg.circle("fill", x + w * settings.volume, y, 17)
				lg.setColor(1, 1, 1)
				lg.print(math.floor(settings.volume * 100 + 0.5) .. "%", font, x + w + 35, item.y + (52 - font:getHeight()) / 2)
			else
				buttons.settings[item.label]:update_text(item.text())
				buttons.settings[item.label]:draw()
			end
		end
	end

	if settings.confirm_reset then
		lg.setColor(0, 0, 0, 0.8)
		lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
		lg.setColor(1, 1, 1)
		lg.printf("Reset all progress?", font, 0, reference_window_height / 2 - 130, reference_window_width, "center")
		lg.printf("Levels, snakes and packs go back to a new game.", assets.small_font, 0, reference_window_height / 2 - 60, reference_window_width, "center")
		buttons.reset_confirm["Yes"]:draw()
		buttons.reset_confirm["No"]:draw()
	end
end

-- The level map is a long winding snake (tools/draw_levels.py draws it and writes LevelNodes.lua, where each level's
-- node sits). It is drawn at 7.5 reference units per art pixel and can be dragged around in every direction.
local map = require("LevelNodes")
local ART_SCALE, NODE_RADIUS = 4.5, 40
map_x, map_y = 0, 0 -- where the map's top left sits in the window (pan)

local function clamp_map()
	map_x = math.max(math.min(map_x, 0), reference_window_width - map.width * ART_SCALE)
	map_y = math.max(math.min(map_y, 0), reference_window_height - map.height * ART_SCALE)
end

-- Moves the map by a drag or a scroll (reference units)
function render.pan_map(dx, dy)
	map_x, map_y = map_x + dx, map_y + dy
	clamp_map()
end

-- Centres the map on a level
local function focus_level(i)
	local n = map.nodes[math.min(i, #map.nodes)]
	map_x, map_y = reference_window_width / 2 - n[1] * ART_SCALE, reference_window_height / 2 - n[2] * ART_SCALE
	clamp_map()
end

local function level_node(i)
	local n = map.nodes[i]
	return n[1] * ART_SCALE + map_x, n[2] * ART_SCALE + map_y
end

-- Returns the level whose node is under the given window position
function render.level_at(x, y)
	local rx, ry = x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
	for i = 1, #opponents do
		local nx, ny = level_node(i)
		if (rx - nx) ^ 2 + (ry - ny) ^ 2 <= NODE_RADIUS ^ 2 then
			return i
		end
	end
end

local level_start, last_level = 0, -1

-- The swirling background dissolves into the snake and its levels over about a second and a half
-- A row of small card thumbnails for a deck (list of names), wrapped at per_row; each thumbnail is remembered in thumb_hits
-- so hovering it can show the card (see thumb_popup)
-- With `foe_level`, only the cards that opponent has played against you show; the rest are face down
local thumb_hits = {}
local function deck_thumbs(deck, x, y, per_row, foe_level, scale)
	scale = scale or 0.26
	local w, h = 165 * scale, 320 * scale
	for i, name in ipairs(deck) do
		local col, row = (i - 1) % per_row, math.floor((i - 1) / per_row)
		local cx, cy = x + col * (w + 8), y + row * (h + 9)
		if foe_level and not collection.hint_seen("foe" .. foe_level .. "_" .. name) then
			lg.setColor(0.12, 0.09, 0.2)
			lg.rectangle("fill", cx, cy, w, h, 6, 6)
			lg.setColor(0.45, 0.4, 0.6)
			lg.rectangle("line", cx, cy, w, h, 6, 6)
			lg.printf("?", assets.font, cx, cy + h / 2 - 25, w, "center")
		else
			local rx, ry = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
			local hover = rx >= cx and rx <= cx + w and ry >= cy and ry <= cy + h
			if hover then
				lg.setColor(1, 0.9, 0.3, 0.9)
				lg.rectangle("fill", cx - 3, cy - 3, w + 6, h + 6, 7, 7)
			end
			lg.setColor(1, 1, 1)
			lg.draw(assets.card_by_name[name], cx, cy, 0, scale)
			thumb_hits[#thumb_hits + 1] = { cx, cy, w, h, name, hover }
		end
	end
end

-- The card under the mouse in the thumbnails drawn this frame, shown large with its stats and ability
local function thumb_popup()
	local hit
	for _, t in ipairs(thumb_hits) do
		hit = t[6] and t or hit
	end
	if not hit then
		return
	end
	local info = data.get_stats({ card_path = hit[5] .. ".png" })
	local snake = info.kind == "snake"
	local tier = RARITY_COLOUR[info.rarity]
	local pw, ph, scale = 600, 330, 0.9
	local x = hit[1] + hit[3] / 2 > reference_window_width / 2 and hit[1] - pw - 12 or hit[1] + hit[3] + 12
	local y = math.max(10, math.min(hit[2] - 40, reference_window_height - ph - 10))
	lg.setColor(0.07, 0.04, 0.14, 0.97)
	lg.rectangle("fill", x, y, pw, ph, 12, 12)
	lg.setColor(tier[1], tier[2], tier[3])
	lg.setLineWidth(4)
	lg.rectangle("line", x, y, pw, ph, 12, 12)
	lg.setLineWidth(1)
	lg.push()
	lg.translate(x + 20, y + 20)
	lg.scale(scale)
	lg.setColor(1, 1, 1)
	lg.draw(assets.card_by_name[hit[5]])
	require("CardText").draw(hit[5], 0, 0)
	lg.pop()
	local tx, tw = x + 190, pw - 210
	lg.setColor(1, 1, 1)
	lg.print((hit[5]:gsub("_", " ")), assets.font, tx, y + 18)
	lg.setColor(tier[1], tier[2], tier[3])
	lg.print((snake and data.get_type({ card_path = hit[5] .. ".png" }) or (info.kind == "brew" and "Brew" or "Spell")) .. "   |   Tier " .. info.rarity, assets.small_font, tx, y + 74)
	lg.setColor(0.5, 0.95, 0.4)
	lg.print("Cost " .. info.cost, assets.small_font, tx, y + 116)
	if snake then
		lg.setColor(1, 0.5, 0.45)
		lg.print("Attack " .. info.attack, assets.small_font, tx + 110, y + 116)
		lg.setColor(0.55, 0.7, 1)
		lg.print("Health " .. info.defense, assets.small_font, tx + 250, y + 116)
	end
	lg.setColor(1, 0.85, 0.2)
	lg.print("Ability", assets.small_font, tx, y + 166)
	lg.setColor(1, 1, 1)
	lg.printf(info.ability or "None", assets.small_font, tx, y + 198, tw)
end

local function charmer_info(charmer, x, y, who, level)
	lg.setColor(1, 0.85, 0.2)
	lg.printf(who .. ": " .. charmer.name, assets.small_font, x, y, 520, "left")
	lg.setColor(1, 1, 1)
	if play.charms_open(level) then
		lg.printf(charmer.charm .. " (" .. charmer.cost .. " venom, cooldown " .. charmer.cooldown .. "): " .. charmer.text, assets.small_font, x, y + 34, 520, "left")
	end
end

-- A rounded dark panel with a gold rim
local function panel(x, y, w, h, rim)
	lg.setColor(0.09, 0.05, 0.18, 0.94)
	lg.rectangle("fill", x, y, w, h, 14, 14)
	lg.setColor(rim or { 1, 0.85, 0.2 })
	lg.setLineWidth(3)
	lg.rectangle("line", x, y, w, h, 14, 14)
	lg.setLineWidth(1)
end

-- One side of the briefing: portrait, charmer and charm, then its deck
local function side_panel(x, who, charmer, level, rim)
	panel(x, 120, 640, 340, rim)
	lg.setColor(1, 1, 1)
	portrait(charmer.name, x + 16, 136, 84, 100)
	lg.setColor(rim)
	lg.print(who, assets.small_font, x + 116, 134)
	lg.setColor(1, 1, 1)
	lg.print(charmer.name, assets.font, x + 116, 160)
	if play.charms_open(level) then
		lg.setColor(0.6, 0.9, 0.4)
		lg.print(charmer.charm .. "  (" .. charmer.cost .. " venom, cooldown " .. charmer.cooldown .. ")", assets.debug_font, x + 116, 214)
		lg.setColor(0.85, 0.85, 0.95)
		lg.printf(charmer.text, assets.debug_font, x + 116, 238, 500)
	end
end

-- The screen shown when a level is clicked
function render.briefing(level)
	local opponent = opponents[level]
	thumb_hits = {}
	lg.setColor(0, 0, 0, 0.88)
	lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
	lg.setColor(1, 1, 1)
	lg.printf("Level " .. level .. ": " .. charmers.of("Opponent", level).name, assets.font, 0, 25, reference_window_width, "center")
	lg.setColor(1, 0.85, 0.2)
	draw_vials(reference_window_width - 250, 20)
	coach.start("coach_briefing", {
		{ rect = { reference_window_width / 2 - 250, 76, 520, 36 }, text = "Win a match to earn snake eyes. Spend them on packs." },
		{ rect = { 740, 120, 640, 340 }, text = "You see their charmer, but their deck stays hidden until they play the cards." },
		{ rect = { 740, 472, 640, 190 }, text = "Beat a level to unlock harder challenges here, worth bigger rewards." },
	})
	draw_eyes("Win: +", collection.payout(true, level), 0, 76, reference_window_width / 2 - 20, "right")
	draw_eyes("Lose: +", collection.payout(false, level), reference_window_width / 2 + 20, 76, 400, "left")

	local deck = collection.deck()
	local shown = { unpack(deck, 1, 20) } -- a deck is at most 20; before one is chosen every owned snake is in it
	side_panel(60, "YOU", charmers.by_name[chosen_avatar], level, { 0.45, 0.8, 0.3 })
	lg.setColor(1, 1, 1)
	lg.print("Your deck (" .. #deck .. ")" .. (#deck > 20 and ", first 20 shown" or ""), assets.small_font, 80, 268)
	deck_thumbs(shown, 80, 300, 10, nil, 0.23)
	side_panel(740, "OPPONENT", charmers.of("Opponent", level), level, { 0.9, 0.35, 0.35 })
	lg.setColor(1, 1, 1)
	lg.print("Their deck (" .. #opponent.deck .. ")", assets.small_font, 760, 268)
	deck_thumbs(opponent.deck, 760, 300, 10, level, 0.23)
	lg.setColor(0.7, 0.7, 0.8)
	lg.print("Cards show once they are played against you", assets.debug_font, 760, 432)

	panel(60, 472, 640, 190, { 1, 0.85, 0.2 })
	lg.setColor(1, 0.85, 0.2)
	lg.print("Win a snake", assets.font, 80, 484)
	lg.setColor(0.85, 0.85, 0.95)
	lg.printf("One of these, a third each, with a random border", assets.debug_font, 80, 526, 600)
	deck_thumbs(collection.level_rewards(level), 80, 556, 3, nil, 0.3)

	-- What the next fight is: the plain match, one of the level's challenges, or an endless rematch (beside the reward)
	local fight = play.next_fight(level)
	panel(740, 472, 640, 190, { 1, 0.85, 0.2 })
	local wins = collection.wins(level)
	lg.setColor(1, 0.85, 0.2)
	if not fight then
		lg.printf("The first fight", assets.font, 760, 484, 600, "left")
		lg.setColor(1, 1, 1)
		lg.printf("Beat them to unlock their challenges", assets.small_font, 760, 570, 600, "left")
	else
		local label = fight.endless and ("Endless rematch " .. fight.endless) or ("Challenge " .. fight.tier .. "/" .. #challenges[level])
		lg.printf(label, assets.font, 760, 484, 600, "left")
		lg.setColor(1, 1, 1)
		lg.printf((fight.endless and "" or fight.name .. "  ") .. "(x" .. string.format("%.4g", fight.mult) .. " reward)", assets.small_font, 760, 526, 600, "left")
		lg.setColor(0.85, 0.85, 0.95)
		lg.printf(fight.text, assets.small_font, 760, 576, 600, "left")
	end
	lg.setColor(0.7, 0.9, 1)
	lg.printf("Your wins against them: " .. wins, assets.small_font, 60, 690, 1320, "center")
	lg.setColor(1, 1, 1)
	buttons.level_choice["Play"]:draw()
	buttons.level_choice["Cancel"]:draw()
	thumb_popup()
end

-- What the opponent on a level node fights with, shown while the node is hovered
function render.level_tooltip(level)
	local opponent, charmer = opponents[level], charmers.of("Opponent", level)
	local nx, ny = level_node(level)
	local font = assets.small_font
	local w, pad, portrait_w = 480, 16, 96
	local text_x, text_w = pad + portrait_w + 16, w - portrait_w - 2 * pad - 16
	local charm = play.charms_open(level) and (charmer.charm .. " (" .. charmer.cost .. " venom, cooldown " .. charmer.cooldown .. "): " .. charmer.text)
	local _, charm_lines = font:getWrap(charm or "", w - 2 * pad)
	local h = pad * 2 + 120 + (charm and (#charm_lines * font:getHeight() + 28) or 0)
	-- beside the node, on whichever side has room, so the map around it stays visible
	local x = nx + NODE_RADIUS + 24
	if x + w > reference_window_width - 10 then
		x = nx - NODE_RADIUS - 24 - w
	end
	x = math.max(10, x)
	local y = math.max(10, math.min(ny - h / 2, reference_window_height - h - 10))
	lg.setColor(0.07, 0.04, 0.14, 0.96)
	lg.rectangle("fill", x, y, w, h, 12, 12)
	lg.setColor(1, 0.85, 0.2)
	lg.setLineWidth(3)
	lg.rectangle("line", x, y, w, h, 12, 12)
	lg.setLineWidth(1)
	lg.setColor(1, 1, 1)
	portrait(charmer.name, x + pad, y + pad, portrait_w, 120)
	lg.setColor(1, 1, 1)
	lg.printf(charmer.name, assets.font, x + text_x, y + pad - 2, text_w, "left")
	local chips = { { opponent.health .. " HP", { 1, 0.4, 0.4 } }, { #opponent.deck .. " cards", { 0.45, 0.6, 1 } } }
	local cx = x + text_x
	for _, chip in ipairs(chips) do
		local cw = font:getWidth(chip[1]) + 24
		lg.setColor(chip[2][1] * 0.25, chip[2][2] * 0.25, chip[2][3] * 0.25, 0.9)
		lg.rectangle("fill", cx, y + pad + 58, cw, 36, 8, 8)
		lg.setColor(chip[2])
		lg.rectangle("line", cx, y + pad + 58, cw, 36, 8, 8)
		lg.setColor(1, 1, 1)
		lg.print(chip[1], font, cx + 12, y + pad + 62)
		cx = cx + cw + 10
	end
	if charm then
		lg.setColor(0.5, 0.35, 0.8, 0.5)
		lg.rectangle("fill", x + pad, y + pad + 134, w - 2 * pad, #charm_lines * font:getHeight() + 14, 8, 8)
		lg.setColor(0.8, 0.92, 1)
		lg.printf(charm, font, x + pad + 8, y + pad + 140, w - 2 * pad - 16, "left")
	end
end

function render.level_select()
	if time - last_level > 0.25 then
		level_start = time
		focus_level(unlocked) -- open on the newest level
	end
	last_level = time
	local fade = math.min((time - level_start) / 1.4, 1)
	fade = fade * fade * (3 - 2 * fade)
	if fade < 1 then
		background()
	end

	lg.setColor(1, 1, 1, fade)
	lg.draw(assets.level_snake, map_x, map_y, 0, ART_SCALE / map.scale)

	local hovered = render.level_at(mouse.x, mouse.y)
	for i = 1, #opponents do
		local name = charmers.of("Opponent", i).name
		local x, y = level_node(i)
		local fill = not play.level_open(i) and { 0.3, 0.3, 0.3 } or (hovered == i and green or purple)
		if i == unlocked then -- the level you are up to pulses
			fill = { 0.45 + 0.35 * math.sin(time * 5), 0.8, 0.3 }
		end
		lg.setColor(fill[1], fill[2], fill[3], fade)
		lg.circle("fill", x, y, NODE_RADIUS)
		lg.setColor(0, 0, 0, fade)
		lg.setLineWidth(5)
		lg.circle("line", x, y, NODE_RADIUS)
		lg.setColor(1, 1, 1, fade)
		lg.printf(tostring(i), assets.font, x - NODE_RADIUS, y - 25, NODE_RADIUS * 2, "center")
		local right = x > reference_window_width / 2
		local tx = right and x - NODE_RADIUS - 415 or x + NODE_RADIUS + 15
		local reward = play.level_open(i) and ("+" .. collection.payout(true, i)) or nil
		-- a dark plate behind the label keeps it readable over the snake's green and tan
		local width = math.max(assets.font:getWidth(name), reward and assets.small_font:getWidth(reward) + 40 or 0) + 28
		local plate_x = right and tx + 400 - width + 14 or tx - 14
		lg.setColor(0.05, 0.02, 0.1, 0.72 * fade)
		local wins = collection.wins(i)
		width = math.max(width, wins > 0 and assets.small_font:getWidth("Wins: " .. wins) + 28 or 0)
		plate_x = right and tx + 400 - width + 14 or tx - 14
		lg.rectangle("fill", plate_x, y - 32, width, reward and (wins > 0 and 118 or 90) or 62, 10, 10)
		lg.setColor(1, 1, 1, fade)
		lg.printf(name, assets.font, tx, y - 25, 400, right and "right" or "left")
		if reward then
			lg.setColor(1, 0.85, 0.2, fade)
			draw_eyes(reward, "", tx, y + 22, 400, right and "right" or "left")
			if wins > 0 then
				lg.setColor(0.7, 0.9, 1, fade)
				lg.printf("Wins: " .. wins, assets.small_font, tx, y + 50, 400, right and "right" or "left")
			end
		end
	end
	lg.setColor(1, 1, 1)
	buttons.universal["Back"]:draw()
	if hovered and hovered >= 1 and play.level_open(hovered) and not level_choice then
		render.level_tooltip(hovered)
	end
	if level_choice then
		render.briefing(level_choice)
	else
		draw_vials(reference_window_width - 250, 20)
		if unlocked >= 2 then -- the first match is free; from the second on a vial pays for each fight
			coach.start("coach_vials", { { rect = { reference_window_width - 250, 20, 230, 44 }, text = "Each battle costs a venom vial. They refill over time." } })
		end
	end
	if collection.message and time - collection.message_t < 2 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 836, 700, 34, 8, 8)
		lg.setColor(1, 0.5, 0.4)
		lg.printf(collection.message, assets.small_font, 370, 838, 700, "center")
		lg.setColor(1, 1, 1)
	end
end


local HAND_SCALE = 0.8 -- the taller cards are drawn smaller in the hand to fit under the field

local function hand_x(i)
	local x_offset = img_widths * HAND_SCALE + 6
	local tray_x, tray_w = reference_window_width / 6 + 5, reference_window_width * 2 / 3 - 10 -- the hand tray (see Ui.lua)
	local total = (#player_hand - 1) * x_offset + img_widths * HAND_SCALE
	return tray_x + (tray_w - total) / 2 + x_offset * (i - 1), x_offset
end

local LANE_X, LANE_Y = { 20, 250, 490, 720 }, { 20, 280 } -- where each lane's cells sit inside the field image

-- Attack (sword) and defense (heart) sit in the bottom corners of the card's lane cell
local function draw_stats(sector)
	local card, lane = played_cards[sector], (sector - 1) % 4 + 1
	require("CardText").lane(play.shown_attack(card, sector), play.shown_hp(card), 245 + LANE_X[lane], 15 + LANE_Y[sector > 4 and 2 or 1])
end

-- A played card, drawn at 0.8 scale around its slot centre with any active effects applied
local ART_CENTRE = 120 -- the middle of the art area in a card image (rows 2-37 of its 5 pixel grid); snakes are drawn about this point
local SNAKE_SCALE = 0.95 -- cut-out snakes sit in the cell above the attack and defense badges

-- Snakes on the board are cut out of their card (no purple frame or corner numbers).
-- Every card is 33x64 art pixels; the shader keeps the art area, drops the card's background and frame colours
-- (they depend on the snake's lane type, see CardStyles.lua) and traces the silhouette in the border's colour.
-- Frozen snakes tint blue, poisoned ones tint green.
local snake_shader = lg.newShader([[
	uniform vec4 rim;
	uniform vec3 tint;
	uniform vec3 bgs[6];
	uniform int bg_count;
	uniform vec3 frame;
	const vec2 art = vec2(33.0, 64.0);

	vec4 snake(Image tex, vec2 uv) {
		vec2 px = uv * art;
		if (px.x < 2.0 || px.x > 31.0 || px.y < 2.0 || px.y > 62.0) return vec4(0.0);
		if (px.y < 9.0 && px.x < 10.0) return vec4(0.0);  // cost number and tier icon
		if (px.y >= 46.0) return vec4(0.0);               // the card below its art (the picture now reaches row 45)
		vec4 c = Texel(tex, uv);
		for (int i = 0; i < 6; i++) {
			if (i < bg_count && distance(c.rgb, bgs[i]) < 0.02) return vec4(0.0);  // card background
		}
		if (distance(c.rgb, frame) < 0.02) return vec4(0.0);                     // card frame
		return c;
	}

	vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
		vec2 at = uv;
		vec4 c = snake(tex, at);
		if (c.a > 0.0) return vec4(c.rgb * tint, c.a) * color;
		vec2 d = 1.0 / art;
		float edge = max(max(snake(tex, at + vec2(d.x, 0.0)).a, snake(tex, at - vec2(d.x, 0.0)).a),
		                 max(snake(tex, at + vec2(0.0, d.y)).a, snake(tex, at - vec2(0.0, d.y)).a));
		if (edge > 0.0 && rim.a > 0.0) return vec4(rim.rgb, rim.a * color.a);
		return vec4(0.0);
	}
]])

local CARD_ART_H = 240 -- the card without its text panel
local card_styles = require("CardStyles") -- the colours of each lane type's cards, cut out by the shader

-- The glow or particles on a snake that has drunk a brew (cx, cy = the snake's centre). Smoke fills the whole lane cell.
local function brew_aura(card, sector, cx, cy)
	local kind = card.brew
	if not kind then
		return
	end
	local t = time
	local function rising(count, speed, draw) -- calls draw(x, y, alpha, i) for particles drifting up the snake
		for i = 1, count do
			local phase = (t * speed + i / count) % 1
			draw(cx + math.sin(i * 12.9) * 55, cy + 75 - phase * 150, math.sin(phase * math.pi), i)
		end
	end
	local drank = card.brew_t and time - card.brew_t or 9
	if drank < 0.7 then -- a ring splashes out when the brew is first drunk
		lg.setColor(1, 1, 1, 0.8 * (1 - drank / 0.7))
		lg.setLineWidth(5)
		lg.circle("line", cx, cy, 20 + drank * 140)
		lg.setLineWidth(1)
	end
	if kind == "stone" then
		local pulse = 0.5 + 0.5 * math.sin(t * 2)
		lg.setColor(0.7, 0.72, 0.8, 0.12 + 0.08 * pulse)
		lg.ellipse("fill", cx, cy, 70, 82)
		lg.setColor(0.8, 0.82, 0.9, 0.5 + 0.3 * pulse)
		lg.setLineWidth(4)
		lg.ellipse("line", cx, cy, 70, 82)
		lg.setLineWidth(1)
	elseif kind == "regrow" then
		rising(6, 0.5, function(x, y, a)
			lg.setColor(0.4, 1, 0.5, a)
			lg.rectangle("fill", x - 3, y - 9, 6, 18)
			lg.rectangle("fill", x - 9, y - 3, 18, 6)
		end)
	elseif kind == "venom" then
		rising(8, 0.7, function(x, y, a, i)
			lg.setColor(0.75, 0.35, 0.95, a * 0.9)
			lg.circle("fill", x, y, 4 + i % 3 * 2)
			lg.setColor(1, 1, 1, a * 0.7)
			lg.circle("fill", x - 1, y - 1, 1.5)
		end)
	elseif kind == "rage" then
		for i = 1, 7 do
			local x = cx + (i - 4) * 18
			local h = 34 + 22 * math.sin(t * 9 + i * 2)
			lg.setColor(1, 0.35, 0.1, 0.7)
			lg.polygon("fill", x - 9, cy + 56, x, cy + 56 - h, x + 9, cy + 56)
			lg.setColor(1, 0.8, 0.2, 0.7)
			lg.polygon("fill", x - 5, cy + 56, x, cy + 56 - h * 0.6, x + 5, cy + 56)
		end
	elseif kind == "frost" then
		rising(7, -0.35, function(x, y, a)
			lg.setColor(0.8, 0.95, 1, a)
			lg.setLineWidth(2)
			for k = 0, 2 do
				local r = k * math.pi / 3 + t
				lg.line(x - 8 * math.cos(r), y - 8 * math.sin(r), x + 8 * math.cos(r), y + 8 * math.sin(r))
			end
			lg.setLineWidth(1)
		end)
	elseif kind == "phase" then
		local pulse = 0.5 + 0.5 * math.sin(t * 3)
		lg.setColor(0.9, 0.95, 1, 0.1 + 0.1 * pulse)
		lg.ellipse("fill", cx, cy, 72, 84)
		for i = 1, 3 do
			local a = t * 1.5 + i * 2.1
			lg.setColor(0.9, 0.95, 1, 0.55)
			lg.circle("fill", cx + math.cos(a) * 62, cy + math.sin(a) * 74, 7)
		end
	elseif kind == "smoke" then -- lane brew: drifting smoke over the whole cell the snake stands in
		local box = play.field_hitboxes[sector]
		for i = 1, 7 do
			local x = box[1] + 20 + (box[3] - 40) * ((i * 0.37 + t * 0.05) % 1)
			local y = box[2] + 30 + (box[4] - 80) * ((i * 0.61 + math.sin(t * 0.5 + i)) % 1)
			lg.setColor(0.45, 0.45, 0.5, 0.3)
			lg.circle("fill", x, y, 34 + i % 3 * 8)
		end
	end
	lg.setColor(1, 1, 1)
end

local function draw_slot(card, sector)
	local cx, cy = play.slot_centre(sector)
	local dx, dy, sx, sy, alpha, flash = effects.card(card)
	local stats = data.get_stats(card)
	local rim = borders.colour(stats.rarity == 5 and "Rainbow" or data.border_of(card))
	local pulse = 0.5 + 0.5 * math.sin(time * 4)
	card.card_object:setFilter("nearest", "nearest")
	local style = card_styles[data.get_type(card)]
	local bgs = {}
	for i = 1, 6 do
		local c = style.bgs[i] or style.bgs[1]
		bgs[i] = { c[1] / 255, c[2] / 255, c[3] / 255 }
	end
	snake_shader:send("bgs", unpack(bgs))
	snake_shader:send("bg_count", #style.bgs)
	snake_shader:send("frame", { style.frame[1] / 255, style.frame[2] / 255, style.frame[3] / 255 })
	snake_shader:send("rim", rim and { rim[1], rim[2], rim[3], 0.55 + 0.4 * pulse } or { 0, 0, 0, 0 })
	snake_shader:send("tint", (card.fx_at or 0) > time and { 1, 1, 1 } or card.frozen and { 0.6, 0.85, 1.2 } or (card.poison and { 0.7, 1.15, 0.6 } or { 1, 1, 1 }))
	lg.push()
	lg.translate(cx + dx, cy + dy)
	lg.scale(SNAKE_SCALE * sx, SNAKE_SCALE * sy)
	lg.setShader(snake_shader)
	lg.setColor(1, 1, 1, alpha)
	lg.draw(card.card_object, -img_widths / 2, -ART_CENTRE)
	if flash > 0 then
		lg.setBlendMode("add")
		lg.setColor(1, 1, 1, flash * 0.8)
		lg.draw(card.card_object, -img_widths / 2, -ART_CENTRE)
		lg.setBlendMode("alpha")
	end
	lg.setShader()
	lg.pop()
	brew_aura(card, sector, cx + dx, cy + dy)
end


-- A drop slot while a snake is held: a pulsing venom pool with scales, a glowing rim and bubbles rising from it
local function draw_venom_slot(x, y, w, h, seed)
	local pulse = 0.5 + 0.5 * math.sin(time * 4 + seed)
	lg.stencil(function() lg.rectangle("fill", x, y, w, h, 10, 10) end, "replace", 1)
	lg.setStencilTest("greater", 0)
	lg.setColor(0.1, 0.5, 0.15, 0.35 + 0.15 * pulse)
	lg.rectangle("fill", x, y, w, h)
	lg.setColor(0.5, 1, 0.2, 0.18 + 0.1 * pulse) -- a scale pattern, drifting slowly
	local sc, off = 22, (time * 6) % 22
	for row = -1, math.ceil(h / (sc * 0.5)) do
		for col = -1, math.ceil(w / sc) do
			local cx = x + col * sc + (row % 2) * sc / 2 + off
			lg.arc("line", "open", cx, y + row * sc * 0.5, sc / 2, 0, math.pi)
		end
	end
	for i = 1, 6 do -- bubbles
		local t = (time * 0.35 + i * 0.17 + seed * 0.3) % 1
		lg.setColor(0.7, 1, 0.4, (1 - t) * 0.8)
		lg.circle("fill", x + w * ((i * 0.37 + seed * 0.11) % 1), y + h * (1 - t), 3 + (i % 3) * 2)
	end
	lg.setStencilTest()
	for i = 3, 1, -1 do -- the glowing rim
		lg.setColor(0.45, 1, 0.2, (0.25 + 0.3 * pulse) / i)
		lg.setLineWidth(i * 2)
		lg.rectangle("line", x, y, w, h, 10, 10)
	end
	lg.setLineWidth(1)
end

local HOVER_DELAY = 0.5 -- seconds the mouse rests on a snake before its popup shows
local hover_target, hover_since = nil, 0

function render.playing()
	background()

	count = count + 1
	buttons.playing["Forfeit"]:draw()
	local tray = buttons.playing["Card Background"] -- the hand's tray: dark leather with a gold rim
	lg.setColor(0.1, 0.07, 0.06, 0.92)
	lg.rectangle("fill", tray.x, tray.y, tray.width, tray.height, 16, 16)
	lg.setColor(0.2, 0.14, 0.1, 0.9)
	lg.rectangle("fill", tray.x + 8, tray.y + 8, tray.width - 16, tray.height - 16, 12, 12)
	lg.setColor(0.85, 0.68, 0.28)
	lg.setLineWidth(4)
	lg.rectangle("line", tray.x + 2, tray.y + 2, tray.width - 4, tray.height - 4, 16, 16)
	lg.setLineWidth(1)
	lg.setColor(0.55, 0.4, 0.15)
	lg.rectangle("line", tray.x + 10, tray.y + 10, tray.width - 20, tray.height - 20, 10, 10)
	lg.setColor(1, 1, 1)
	buttons.playing["End Turn"]:draw()

	lg.setColor(1, 1, 1)
	lg.draw(assets.playing_field, 245, 15)
	-- The field image is the default arrangement; draw each lane's cells from the tiles for the lane types in use
	for lane = 1, 4 do
		for row = 1, 2 do
			lane_editor.draw_tile(play.lane_chips[lane][1], play.lane_chips[lane][2], row, 245 + LANE_X[lane], 15 + LANE_Y[row])
		end
	end

	-- Lane labels (tutorial only), and a green tint on the empty player slots the held card may go in
	for _, box in ipairs(play.field_hitboxes) do
		local lane = play.lane_types[(box[5] - 1) % 4 + 1]
		if tutorial.show_labels() then -- the type names are only spelled out while the tutorial explains lanes
			local label = {}
			for _, snake_type in ipairs({ "Land", "Water", "Tree", "Spirit" }) do
				if lane[snake_type] then
					table.insert(label, snake_type)
				end
			end
			lg.setColor(1, 1, 1, 0.9)
			lg.print(table.concat(label, " / "), assets.debug_font, box[1] + 10, box[2] + 6)
		end
		if held_card and box[5] > 4 and not played_cards[box[5]] and play.lane_accepts(held_card, box[5]) then
			draw_venom_slot(box[1] + 8, box[2] + 8, box[3] - 16, box[4] - 16, box[5])
		end
		lg.setColor(1, 1, 1)
	end

	-- Each side's charmer: portrait and name, plus the player's Charm button (covered by Info while a card is held)
	local charm_tip
	for side, spot in pairs({ Opponent = { 1215, 78 }, Player = { 1215, 548 } }) do
		local c = charmers.of(side, play.level)
		local mx, my = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
		if play.charms_open() and mx >= spot[1] and mx <= spot[1] + 215 and my >= spot[2] and my <= spot[2] + 72 then
			charm_tip = { side, c, spot }
		end
		local rim = c.colour or { 1, 0.85, 0.2 }
		lg.setColor(0.07, 0.04, 0.14, 0.88) -- a panel behind the charmer, their name and charm
		lg.rectangle("fill", spot[1] - 7, spot[2] - 7, 229, 86, 10, 10)
		lg.setColor(rim[1], rim[2], rim[3], 0.8)
		lg.setLineWidth(2)
		lg.rectangle("line", spot[1] - 7, spot[2] - 7, 229, 86, 10, 10)
		lg.setLineWidth(1)
		lg.setColor(1, 1, 1)
		portrait(c.name, spot[1], spot[2], 60, 72)
		local pulse = play.charm_pulse
		if pulse and pulse.side == side and time - pulse.t < 1.2 then -- using the charm sends rings out from the charmer, in its colour
			local age = time - pulse.t
			lg.setBlendMode("add")
			for ring = 0, 2 do
				local a = age - ring * 0.18
				if a > 0 then
					lg.setColor(pulse.colour[1], pulse.colour[2], pulse.colour[3], math.max(0, 0.9 - a / 0.9))
					lg.setLineWidth(6)
					lg.circle("line", spot[1] + 30, spot[2] + 36, 20 + a * 260)
				end
			end
			lg.setColor(pulse.colour[1], pulse.colour[2], pulse.colour[3], math.max(0, 0.6 - age))
			lg.rectangle("fill", spot[1] - 7, spot[2] - 7, 229, 86, 10, 10)
			lg.setLineWidth(1)
			lg.setBlendMode("alpha")
		end
		lg.printf(c.name, assets.debug_font, spot[1] + 68, spot[2], 145, "left")
		if play.charms_open() then
			lg.setColor(0.6, 0.9, 0.4)
			lg.printf(c.charm .. " (" .. c.cost .. ")", assets.debug_font, spot[1] + 68, spot[2] + 44, 145, "left")
		end
	end
	local charm = buttons.playing["Charm"]
	if play.charms_open() then
		charm:update_text(play.charm_cd.Player > 0 and ("Charm (" .. play.charm_cd.Player .. ")") or "Charm")
		charm:draw()
		if not play.charm_ready("Player") then
			lg.setColor(0, 0, 0, 0.55)
			lg.rectangle("fill", charm.x - 5, charm.y - 5, charm.width + 10, charm.height + 10, 5, 5)
		end
	end
	lg.setColor(1, 1, 1)

	-- Positions are in reference-window units; love.draw scales everything
	local y_pos = tray.y + (tray.height - img_heights * HAND_SCALE) / 2 -- the same space above and below the cards
	card_hitboxes = {} -- only the cards in the hand now (leftover boxes of played cards would be picked up as ghosts)
	for i, card in ipairs(player_hand) do
		local x, x_offset = hand_x(i)
		local draw_x, draw_y = x, y_pos
		local glide = card.glide_t and (time - card.glide_t) / 0.15
		if glide and glide < 1 then
			local ease = 1 - (1 - glide) ^ 3
			draw_x, draw_y = card.glide_x + (x - card.glide_x) * ease, card.glide_y + (y_pos - card.glide_y) * ease
		end
		card:draw(draw_x, draw_y, 0, HAND_SCALE)
		card_hitboxes[card] = { x, y_pos, i ~= #player_hand and x_offset or img_widths * HAND_SCALE, img_heights * HAND_SCALE }
	end

	for sector, card in pairs(played_cards) do
		draw_slot(card, sector)
	end
	for _, ghost in ipairs(effects.ghosts()) do
		draw_slot(ghost.card, ghost.sector)
	end

	lg.setColor(1, 1, 1)

	local venom_scale = 2
	lg.scale(venom_scale)
	lg.draw(assets.venom[venom.Opponent + 1], (245 - venom_scale * 36) / 2, 15 / 2)
	lg.draw(assets.venom[venom.Player + 1], (245 - venom_scale * 36) / 2, (555 - venom_scale * 36) / 2)
	lg.scale(1 / venom_scale)

	for sector = 1, 8 do
		if played_cards[sector] then
			draw_stats(sector)
		end
	end

	-- A golden glow with sparks circling it marks your snakes whose activated ability you can afford right now
	local pulse = 0.5 + 0.5 * math.sin(time * 5)
	for sector = 5, 8 do
		if played_cards[sector] and turn == "Player" and tutorial.allows("ability") and abilities.ready(played_cards[sector], "Player") then
			local box = play.field_hitboxes[sector]
			lg.setBlendMode("add")
			lg.setColor(1, 0.8, 0.2, 0.12 + 0.14 * pulse)
			lg.rectangle("fill", box[1], box[2], box[3], box[4], 12, 12)
			lg.setBlendMode("alpha")
			lg.setColor(1, 0.9, 0.3, 0.55 + 0.45 * pulse)
			lg.setLineWidth(4)
			lg.rectangle("line", box[1] + 2, box[2] + 2, box[3] - 4, box[4] - 4, 12, 12)
			lg.setLineWidth(1)
			for k = 0, 3 do -- sparks running round the edge
				local u = (time * 0.5 + k / 4) % 1 * 2 * (box[3] + box[4])
				local sx, sy
				if u < box[3] then sx, sy = box[1] + u, box[2]
				elseif u < box[3] + box[4] then sx, sy = box[1] + box[3], box[2] + u - box[3]
				elseif u < 2 * box[3] + box[4] then sx, sy = box[1] + box[3] - (u - box[3] - box[4]), box[2] + box[4]
				else sx, sy = box[1], box[2] + box[4] - (u - 2 * box[3] - box[4]) end
				lg.setColor(1, 1, 0.8)
				lg.rectangle("fill", sx - 3, sy - 3, 6, 6)
			end
		end
	end

	-- The first time one of your snakes suffers a bad effect, explain it
	for sector, card in pairs(played_cards) do
		local box = sector > 4 and play.field_hitboxes[sector]
		if box and card.poison then
			coach.start("fx_poison", { { rect = box, text = "Poisoned! It loses 1 health at the start of each of your turns, for 2 turns. An Antidote cures it." } })
		elseif box and card.frozen then
			coach.start("fx_frozen", { { rect = box, text = "Frozen! It skips its next attack, then it thaws." } })
		end
	end

	-- Hovering a snake (on the field or in the hand) explains it once the mouse has rested on it for half a second
	if not held_card and not (field_press and field_press.drag) then
		local target, draw
		for sector, card in pairs(played_cards) do
			if play.is_hitbox(mouse.x, mouse.y, play.field_hitboxes[sector]) then
				local status = {}
				if card.poison then
					table.insert(status, "Poisoned: loses 1 health at the start of its turn (" .. card.poison .. " left)")
				end
				if card.frozen then
					table.insert(status, "Frozen: skips its next attack")
				end
				if card.shield then
					table.insert(status, "Shield " .. card.shield .. ": soaks up that much damage")
				end
				local mx, my = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
				local px = mx > 720 and mx - POPUP_W - 24 or mx + 24 -- flips to the left over the right half of the field
				target, draw = card, function() card_popup(card, px, my - 130, card.hp and play.shown_hp(card), status) end
			end
		end
		for card, box in pairs(card_hitboxes) do -- snakes in the hand too
			if play.is_hitbox(mouse.x, mouse.y, box) then
				local mx = mouse.x * reference_window_width / lg.getWidth()
				target, draw = card, function() card_popup(card, mx - POPUP_W / 2, 250) end
			end
		end
		if target ~= hover_target then
			hover_target, hover_since = target, time
		end
		if draw and time - hover_since >= HOVER_DELAY then
			draw()
		end
	end

	-- (the turn log, if switched on, sits on the left of the field)
	if settings.turn_log then
		lg.setColor(0, 0, 0, 0.6)
		lg.rectangle("fill", 5, 95, 235, 185, 6, 6)
		lg.setColor(1, 1, 1)
		for i, line in ipairs(play.log) do
			while LOG_FONT:getWidth(line) > 225 do
				line = line:sub(1, -3)
			end
			lg.print(line, LOG_FONT, 10, 98 + (i - 1) * 20)
		end
	end

	-- Health bars and turn indicator on the right of the field
	for side, y in pairs(play.bar_y) do
		local shake, flash = effects.bar(side)
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", 1210 + shake, y, 210, 40)
		lg.setColor(0.8, 0.1, 0.1)
		lg.rectangle("fill", 1215 + shake, y + 5, 200 * math.max(0, play.shown_health(side)) / max_health[side], 30)
		lg.setColor(1, 1, 1, flash * 0.7)
		lg.rectangle("fill", 1210 + shake, y, 210, 40)
		lg.setColor(1, 1, 1)
		lg.printf(math.max(0, play.shown_health(side)) .. " HP", assets.debug_font, 1215 + shake, y + 8, 200, "center")
	end
	effects.draw()
	if play.flash and time - play.flash.t < 0.5 then -- a screen-wide flash when a spell is cast
		local col = play.flash.colour
		lg.setColor(col[1], col[2], col[3], 0.4 * (1 - (time - play.flash.t) / 0.5))
		lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
	end
	lg.setColor(1, 1, 1)

	local held_spell = held_card and data.get_stats(held_card).kind == "spell" and require("Brews").by_name[held_card.card_path:sub(1, -5)]
	if held_spell then -- dragging a spell: what it would hit glows
		local slots, bars = require("Brews").targets(held_spell, "Player")
		local col, pulse = held_spell.colour, 0.5 + 0.5 * math.sin(time * 8)
		local function glow(x, y, w, h)
			lg.setBlendMode("add")
			lg.setColor(col[1], col[2], col[3], 0.2 + 0.2 * pulse)
			lg.rectangle("fill", x, y, w, h, 12, 12)
			lg.setBlendMode("alpha")
			lg.setColor(col[1], col[2], col[3], 0.7 + 0.3 * pulse)
			lg.setLineWidth(5)
			lg.rectangle("line", x, y, w, h, 12, 12)
			lg.setLineWidth(1)
		end
		for _, slot in ipairs(slots) do
			local box = play.field_hitboxes[slot]
			glow(box[1] + 2, box[2] + 2, box[3] - 4, box[4] - 4)
		end
		for _, side in ipairs(bars) do
			glow(1210, play.bar_y[side], 210, 40)
		end
		lg.setColor(1, 1, 1)
	end
	if held_card then
		local hx = mouse.x * reference_window_width / lg.getWidth() - img_widths / 2
		local hy = mouse.y * reference_window_height / lg.getHeight() - img_heights / 2
		held_card:draw(hx, hy, 0)
		-- a readout above the card: its numbers, and why it can't be played yet
		local st = data.get_stats(held_card)
		local short = venom.Player < st.cost
		lg.setColor(0, 0, 0, 0.8)
		local ry = math.max(hy - 44, 0)
		lg.rectangle("fill", hx - 10, ry, img_widths + 20, 38, 6, 6)
		lg.setColor(1, short and 0.4 or 1, short and 0.4 or 1)
		lg.printf(short and ("Need " .. st.cost .. " venom") or (st.kind ~= "snake" and ("Cost " .. st.cost .. (st.kind == "brew" and "  drop on your snake" or "  drop on the field")) or ("Cost " .. st.cost .. "  Atk " .. st.attack .. "  Health " .. st.defense)), assets.small_font, hx - 10, ry + 2, img_widths + 20, "center")
		lg.setColor(1, 1, 1)
	end

	if not tutorial.allows("end_turn") then -- locked controls are dimmed like an unaffordable Charm
		local end_turn = buttons.playing["End Turn"]
		lg.setColor(0, 0, 0, 0.55)
		lg.rectangle("fill", end_turn.x - 5, end_turn.y - 5, end_turn.width + 10, end_turn.height + 10, 5, 5)
		lg.setColor(1, 1, 1)
	end
	tutorial.draw()
	tutorial.draw_pointers()
	if tutorial.needs_next() then
		buttons.playing["Tutorial Next"]:draw()
	end

	if confirm_forfeit then
		lg.setColor(0, 0, 0, 0.7)
		lg.rectangle("fill", 0, 0, reference_window_width, reference_window_height)
		lg.setColor(1, 1, 1)
		lg.printf("Forfeit this match?", assets.font, 0, reference_window_height / 2 - 100, reference_window_width, "center")
		buttons.playing["Yes"]:draw()
		buttons.playing["No"]:draw()
	end
	if field_press and field_press.drag and love.mouse.isDown(1) then -- dragging one of your snakes off the field
		local mx, my = mouse.x * reference_window_width / lg.getWidth(), mouse.y * reference_window_height / lg.getHeight()
		local over = play.is_hitbox(mouse.x, mouse.y, { tray.x, tray.y, tray.width, tray.height })
		lg.setColor(0, 0, 0, 0.8)
		lg.rectangle("fill", mx + 18, my + 10, 300, 34, 6, 6)
		lg.setColor(over and 1 or 0.8, over and 0.85 or 0.8, over and 0.3 or 0.9)
		lg.printf(over and "Let go to retreat it (it is lost)" or "Drop on your hand to retreat", assets.debug_font, mx + 26, my + 18, 290, "left")
		lg.setColor(1, 1, 1)
	end

	if charm_tip then -- hovering a charmer shows its charm
		local side, c, spot = charm_tip[1], charm_tip[2], charm_tip[3]
		local w = 440
		local _, lines = assets.small_font:getWrap(c.text, w - 40)
		local h = 130 + #lines * assets.small_font:getHeight()
		local x, y = spot[1] - w - 14, math.max(10, math.min(spot[2] - 20, reference_window_height - h - 10))
		lg.setColor(0.07, 0.04, 0.14, 0.97)
		lg.rectangle("fill", x, y, w, h, 12, 12)
		lg.setColor(1, 0.85, 0.2)
		lg.setLineWidth(3)
		lg.rectangle("line", x, y, w, h, 12, 12)
		lg.setLineWidth(1)
		lg.setColor(1, 1, 1)
		lg.print(c.name, assets.font, x + 20, y + 12)
		lg.setColor(0.6, 0.9, 0.4)
		lg.print(c.charm .. "  (" .. c.cost .. " venom, cooldown " .. c.cooldown .. ")", assets.small_font, x + 20, y + 56)
		lg.setColor(0.9, 0.9, 1)
		lg.printf(c.text, assets.small_font, x + 20, y + 88, w - 40)
		lg.setColor(0.7, 0.85, 1)
		local state = play.charm_cd[side] > 0 and ("Recharging: " .. play.charm_cd[side] .. " more turn" .. (play.charm_cd[side] > 1 and "s" or "")) or "Ready to use"
		lg.print(state, assets.debug_font, x + 20, y + h - 28)
		lg.setColor(1, 1, 1)
	end
end

function render.ended()
	background()
	local won = winner == "Player"
	local top = won and 55 or 230 -- a defeat has no reward snakes, so its panel is short and centred
	lg.setColor(0, 0, 0, 0.55)
	lg.rectangle("fill", 200, top, reference_window_width - 400, won and 690 or 400, 16, 16)
	lg.setColor(1, 1, 1)
	lg.printf(won and (play.versus and "Victory!" or "Level " .. play.level .. " Complete!") or "Defeat", assets.font, 0, top + 15, reference_window_width / 3, "center", 0, 3, 3)
	if won then
		local message = play.versus and (require("Versus").status == "The other player left" and "The other player left" or "") or level_unlocked and ("Level " .. level_unlocked .. " unlocked!") or (play.level == #opponents and "You beat every opponent!" or "")
		lg.printf(message, assets.font, 0, 230, reference_window_width, "center")
		if charmer_unlocked then
			lg.setColor(0.4, 1, 0.5)
			lg.printf("New charmer unlocked: " .. charmer_unlocked .. "!", assets.font, 0, 275, reference_window_width, "center")
		end
	end
	lg.setColor(1, 0.85, 0.2)
	draw_eyes("+", collection.last_reward or 0, 0, won and 330 or top + 150, reference_window_width, "center", assets.font)
	lg.setColor(1, 1, 1)
	local drops = won and { collection.last_snake, collection.last_bonus } or {}
	if #drops > 0 then -- one of the level's reward snakes, and on a first win of level 3 or 10 a bonus snake, each with a random border
		local scale, gap = 0.8, 420
		for i, drop in ipairs(drops) do
			local cx = reference_window_width / 2 + (i - 1 - (#drops - 1) / 2) * gap
			lg.setColor(1, 1, 1)
			lg.printf((i == 2 and "Bonus snake: " or "New snake: ") .. drop.name:gsub("_", " ") .. " (" .. drop.border .. ")", assets.small_font, cx - gap / 2, 395, gap, "center")
			lg.push()
			lg.translate(cx - img_widths * scale / 2, 435)
			lg.scale(scale)
			lg.draw(assets.card_by_name[drop.name])
			borders.draw(drop.border, 0, 0, img_widths, img_heights, data.stats_by_name[drop.name].rarity)
			lg.pop()
		end
	elseif won and play.challenge then
		lg.printf((play.challenge.endless and "Endless: " or "Challenge: ") .. play.challenge.name .. " (x" .. play.challenge.mult .. " reward)", assets.small_font, 0, 420, reference_window_width, "center")
	end
	local continue = buttons.ended["Continue"]
	continue.home_y = continue.home_y or continue.y
	continue.y = won and continue.home_y or top + 300
	continue:draw()
end

-- Host or join a two-player match
function render.versus()
	local versus = require("Versus")
	coach.start("coach_versus", {
		{ rect = { 160, 150, 520, 520 }, text = "Host: share this address" },
		{ rect = { 760, 150, 520, 520 }, text = "Join: type theirs" },
	})
	background()
	buttons.versus["Back"]:draw()
	lg.setColor(1, 1, 1)
	lg.printf("Versus", assets.font, 0, 20, reference_window_width, "center")
	lg.printf("Battle a friend with your own deck and charmer", assets.small_font, 0, 80, reference_window_width, "center")
	for i, title in ipairs({ "Host a match", "Join a match" }) do
		local x = i == 1 and 160 or 760
		lg.setColor(0.07, 0.04, 0.14, 0.92)
		lg.rectangle("fill", x, 150, 520, 520, 14, 14)
		lg.setColor(1, 0.85, 0.2)
		lg.rectangle("line", x, 150, 520, 520, 14, 14)
		lg.printf(title, assets.font, x, 165, 520, "center")
		lg.setColor(1, 1, 1)
	end
	lg.printf("Your friend joins with this address. If you are not on the same network, forward port 47625 (UDP) to this computer.", assets.small_font, 190, 250, 460, "left")
	lg.setColor(0.7, 1, 0.5)
	lg.printf(versus.local_ip(), assets.font, 160, 410, 520, "center")
	lg.setColor(1, 1, 1)
	lg.printf("Type the host's address, then Join.", assets.small_font, 790, 250, 460, "left")
	lg.setColor(0, 0, 0, 0.6)
	lg.rectangle("fill", 800, 400, 440, 60, 8, 8)
	lg.setColor(1, 1, 1)
	local caret = (versus.mode ~= "join" and math.floor(time * 2) % 2 == 0) and "|" or ""
	lg.printf(versus.ip .. caret, assets.font, 810, 405, 420, "left")
	buttons.versus["Host"]:draw()
	buttons.versus["Join"]:draw()
	lg.setColor(1, 0.85, 0.2)
	lg.printf(versus.status, assets.small_font, 0, 700, reference_window_width, "center")
	lg.setColor(1, 1, 1)
end

-- A snake that was just played is shown close up with its stats and ability (a click skips it)
-- The info page for a card: art on the left, then name and tier, stat boxes, border, ability, lore and (from the collection) your copies
function render.info()
	background()
	if not info_card then
		buttons.info["Back"]:draw()
		return
	end
	local info = data.get_stats(info_card)
	local snake = info.kind == "snake"
	local name = info_card.card_path:sub(1, -5)
	local tier = RARITY_COLOUR[info.rarity]
	local pulse = 0.5 + 0.5 * math.sin(time * 2.5)

	-- the card, on a glow in its tier colour
	local cx, cy, scale = 60, 70, 2.3
	lg.setBlendMode("add")
	for i = 1, 4 do
		lg.setColor(tier[1], tier[2], tier[3], (0.05 + 0.03 * pulse) * (5 - i))
		lg.rectangle("fill", cx - i * 10, cy - i * 10, img_widths * scale + i * 20, img_heights * scale + i * 20, 16, 16)
	end
	lg.setBlendMode("alpha")
	lg.push()
	info_card:draw(cx, cy, 0, scale)
	lg.pop()

	-- the text panel
	local px, pw = 500, 900
	lg.setColor(0.07, 0.04, 0.14, 0.92)
	lg.rectangle("fill", px, 40, pw, 792, 14, 14)
	lg.setColor(tier[1], tier[2], tier[3], 0.7 + 0.3 * pulse)
	lg.setLineWidth(4)
	lg.rectangle("line", px, 40, pw, 792, 14, 14)
	lg.setLineWidth(1)

	local x, w = px + 35, pw - 70
	lg.setColor(1, 1, 1)
	lg.print((name:gsub("_", " ")), assets.font, x, 58)
	lg.setColor(tier)
	local kind = snake and ("Snake, " .. data.get_type(info_card)) or (info.kind == "brew" and "Brew" or "Spell")
	lg.print("Tier " .. info.rarity .. (info.tier and (" " .. info.tier) or "") .. "   |   " .. kind, assets.small_font, x, 122)

	-- stat boxes
	local y = 172
	stat_chip("Cost", info.cost, x, y, 150, { 0.4, 0.85, 0.4 })
	if snake then
		stat_chip("Attack", info.attack, x + 170, y, 150, { 1, 0.4, 0.4 })
		stat_chip("Health", info.defense, x + 340, y, 150, { 0.45, 0.6, 1 })
	else
		stat_chip("Use", info.kind == "brew" and "Drink" or "Cast", x + 170, y, 320, { 0.7, 0.5, 1 })
		lg.setColor(0.8, 0.85, 1)
		lg.printf(info.kind == "brew" and "Drop it on one of your snakes" or ((require("Brews").by_name[name] or {}).target == "enemy" and "Drop it on an enemy snake" or "Drop it anywhere on the field"), assets.small_font, x + 510, y + 22, w - 510)
	end
	y = y + 112

	if snake then
		local border = data.border_of(info_card)
		local colour = borders.colour(border) or { 0.7, 0.7, 0.7 }
		lg.setColor(colour[1] * 0.2, colour[2] * 0.2, colour[3] * 0.2, 0.9)
		local _, lines = assets.small_font:getWrap(borders.describe(border), w - 30)
		local h = 20 + #lines * assets.small_font:getHeight()
		lg.rectangle("fill", x, y, w, h, 8, 8)
		lg.setColor(colour[1], colour[2], colour[3])
		lg.rectangle("fill", x, y, 8, h, 4, 4)
		lg.printf(borders.describe(border), assets.small_font, x + 22, y + 10, w - 30)
		y = y + h + 22
	end

	y = info_section("Ability", info.ability or "None", x, y, w, { 1, 0.85, 0.2 }, { 1, 1, 1 })
	y = info_section("Lore", info.lore or "", x, y, w, { 0.6, 0.65, 0.85 }, { 0.8, 0.85, 1 })

	-- From the collection: every variant of the snake you have, with its border and how many copies
	if info_return == "collection" and y < 690 and collection.count(name) > 0 then
		lg.setColor(1, 0.85, 0.2)
		lg.print("Your copies (" .. collection.count(name) .. ")", assets.small_font, x, 690)
		local variants = snake and collection.variant_list(name) or { { "Basic", collection.count(name) } }
		for i, v in ipairs(variants) do
			local vx, thumb = x + (i - 1) * 70, 0.33
			lg.push()
			lg.translate(vx, 724)
			lg.scale(thumb)
			lg.setColor(1, 1, 1)
			lg.draw(assets.card_by_name[name])
			if snake then
				borders.draw(v[1], 0, 0, img_widths, img_heights, info.rarity)
			end
			lg.pop()
			lg.setColor(0, 0, 0, 0.8)
			lg.rectangle("fill", vx, 724, 34, 24, 5, 5)
			lg.setColor(1, 1, 1)
			lg.printf("x" .. v[2], assets.card_text_font, vx, 725, 34, "center")
		end
	end
	buttons.info["Back"]:draw()
end

return render
