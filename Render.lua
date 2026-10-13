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
local shader = require("Shader")
local title = require("Title")
local charmers = require("Charmers")
local tutorial = require("Tutorial")
local lane_editor = require("LaneEditor")
local settings = require("Settings")

local render = {}

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
	local slide = math.max(0, math.min(1, (t - 0.3) / 1.5))
	local offset = -(1 - slide * slide * (3 - 2 * slide)) * title.MENU_DROP
	for _, name in ipairs({ "Button Background", "Play Game", "Collection", "Charmers", "Settings" }) do
		-- Move the button itself (not just the drawing) so its hitbox follows it while it slides
		local button = buttons.menu[name]
		button.rest_y = button.rest_y or button.y
		button.y = button.rest_y + offset
		button:draw()
	end
end

-- Calls fn(index, x, y) for each card in the collection grid, in the current sort order
local function each_collection_card(fn)
	local per_row = math.floor((reference_window_width - 69) / img_widths)
	local rows = math.ceil(#assets.card_names / per_row)
	local x, y = 69, math.max(math.min(scroll_offset_y * 5, 0), reference_window_height - 140 - rows * img_heights) + 70
	for _, i in ipairs(collection.order(assets.card_names)) do
		if x + img_widths > reference_window_width then
			x, y = 69, y + img_heights
		end
		fn(i, x, y)
		x = x + img_widths
	end
end

-- Name of the owned snake under the given window position, if any
function render.collection_card_at(window_x, window_y)
	local rx, ry = window_x * reference_window_width / lg.getWidth(), window_y * reference_window_height / lg.getHeight()
	local found
	each_collection_card(function(i, x, y)
		if collection.has(assets.card_names[i]) and rx >= x and rx < x + img_widths and ry >= y and ry < y + img_heights then
			found = assets.card_names[i]
		end
	end)
	return found
end

function render.collection()
	background()

	local hovered = render.collection_card_at(mouse.x, mouse.y)
	each_collection_card(function(i, x, y)
		local owned = collection.has(assets.card_names[i])
		-- Snakes you haven't unlocked are drawn as dark silhouettes
		lg.setColor(owned and { 1, 1, 1 } or { 0.12, 0.1, 0.18 })
		lg.draw(assets.cards[i], x, y)
		if owned then
			borders.draw(data.stats_by_name[assets.card_names[i]].border, x, y, img_widths, img_heights, data.stats_by_name[assets.card_names[i]].rarity)
		end
		if owned and collection.deck_mode then
			if collection.in_deck(assets.card_names[i]) then -- a green tick marks the deck's snakes
				lg.setColor(0.2, 0.75, 0.3)
				lg.circle("fill", x + img_widths - 26, y + 26, 18)
				lg.setColor(1, 1, 1)
				lg.setLineWidth(5)
				lg.line(x + img_widths - 36, y + 26, x + img_widths - 29, y + 34, x + img_widths - 16, y + 18)
				lg.setLineWidth(1)
			else
				lg.setColor(0, 0, 0, 0.55)
				lg.rectangle("fill", x, y, img_widths, img_heights)
			end
		end
		if assets.card_names[i] == hovered then
			-- Hover: a pulsing glow and border kept inside the card so neighbours are untouched
			local pulse = 0.5 + 0.5 * math.sin(time * 6)
			lg.setBlendMode("add")
			lg.setColor(1, 1, 1, 0.1 + 0.1 * pulse)
			lg.draw(assets.cards[i], x, y)
			lg.setBlendMode("alpha")
			lg.setColor(0.95, 0.85, 0.25, 0.6 + 0.4 * pulse)
			lg.setLineWidth(4)
			lg.rectangle("line", x + 2, y + 2, img_widths - 4, img_heights - 4)
			lg.setLineWidth(1)
		end
	end)
	lg.setColor(1, 1, 1)

	buttons.collection["Collection Header"]:update_text(collection.deck_mode and ("Deck " .. collection.deck_count() .. "/" .. collection.MAX_DECK) or "Collection")
	buttons.collection["Collection Header"]:draw()
	buttons.collection["Edit Deck"]:update_text(collection.deck_mode and "Done" or "Edit Deck")
	buttons.collection["Edit Deck"]:draw()
	if collection.message and time - collection.message_t < 2 then
		lg.setColor(0, 0, 0, 0.85)
		lg.rectangle("fill", 370, 800, 700, 56, 8, 8)
		lg.setColor(1, 1, 1)
		lg.printf(collection.message, assets.font, 370, 805, 700, "center")
	end
	buttons.collection["Sort"]:draw()
	buttons.collection["Open Pack"]:update_text(collection.pack_ready() and "Open Pack" or "Pack: tomorrow")
	buttons.collection["Open Pack"]:draw()
	buttons.universal["Back"]:draw()
end

function render.lanes()
	background()
	lane_editor.draw()
	buttons.lanes["Back"]:draw()
	buttons.lanes["Reset"]:draw()
end

function render.pack()
	background()
	lg.setColor(1, 1, 1)
	lg.printf(#pack_cards > 0 and "New snakes!" or "You own every snake you can pull", assets.font, 0, 80, reference_window_width, "center")
	local gap = 40
	local x = (reference_window_width - #pack_cards * (img_widths * 2) - (#pack_cards - 1) * gap) / 2
	for _, name in ipairs(pack_cards) do
		lg.push()
		lg.translate(x, 200)
		lg.scale(2)
		lg.draw(assets.card_by_name[name])
		borders.draw(data.stats_by_name[name].border, 0, 0, img_widths, img_heights, data.stats_by_name[name].rarity)
		lg.pop()
		x = x + img_widths * 2 + gap
	end
	buttons.pack["Done"]:draw()
end

-- Charmer cards: 6 across, 2 down, in reference-window units
local CARD_W, CARD_H, CARD_GAP, PORTRAIT_H = 215, 372, 17, 200
local crops = {}

local function card_pos(i)
	local x0 = (reference_window_width - 6 * CARD_W - 5 * CARD_GAP) / 2
	return x0 + (i - 1) % 6 * (CARD_W + CARD_GAP), 88 + math.floor((i - 1) / 6) * (CARD_H + CARD_GAP)
end

-- Returns the name of the charmer card under the given window position
function render.charmer_at(x, y)
	local rx, ry = x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
	for i, c in ipairs(charmers.list) do
		local cx, cy = card_pos(i)
		if rx > cx and rx < cx + CARD_W and ry > cy and ry < cy + CARD_H then
			return c.name
		end
	end
end

-- Draws a charmer's portrait cropped to fill w x h
local function portrait(name, x, y, w, h)
	local image = assets.avatars[name]
	local iw, ih = image:getDimensions()
	if not crops[name] then
		local cw, ch = math.min(iw, ih * w / h), math.min(ih, iw * h / w)
		crops[name] = lg.newQuad((iw - cw) / 2, 0, cw, ch, iw, ih)
	end
	local _, _, cw = crops[name]:getViewport()
	lg.draw(image, crops[name], x, y, 0, w / cw)
end

function render.character_select()
	background()
	buttons.character_select["Charmers Header"]:draw()
	buttons.universal["Back"]:draw()
	local hovered = render.charmer_at(mouse.x, mouse.y)
	for i, c in ipairs(charmers.list) do
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
			lg.rectangle("fill", x + 10, y + 10, 100, 26)
			lg.setColor(1, 1, 1)
			lg.printf("Selected", assets.debug_font, x + 10, y + 12, 100, "center")
		end
		lg.printf(c.name, assets.small_font, x + 10, y + PORTRAIT_H + 14, CARD_W - 20, "center")
		lg.setColor(green)
		lg.printf(c.charm .. " (" .. c.cost .. " venom)", assets.debug_font, x + 10, y + PORTRAIT_H + 48, CARD_W - 20, "center")
		lg.setColor(1, 1, 1)
		lg.printf(c.text, assets.debug_font, x + 12, y + PORTRAIT_H + 74, CARD_W - 24, "center")
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
			lg.print(item.heading, assets.small_font, left, item.y + 8)
			lg.setLineWidth(2)
			lg.line(left, item.y + 40, right, item.y + 40)
		else
			lg.setColor(1, 1, 1)
			lg.print(item.label, font, left, item.y + (62 - font:getHeight()) / 2)
			if item.icon then
				local icon = audio and assets.icons.audio_enabled or assets.icons.audio_disabled
				lg.draw(icon, left + font:getWidth(item.label) + 20, item.y + 9, 0, 44 / icon:getHeight())
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
				lg.print(math.floor(settings.volume * 100 + 0.5) .. "%", font, x + w + 35, item.y + (62 - font:getHeight()) / 2)
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

-- The level snake is 192x540 art pixels drawn at 7.5 reference units each; its centre line
-- must match centre_x() in tools/draw_levels.py. Levels sit evenly along it, level 1 at the tail.
local ART_SCALE, HEAD_Y, NODE_RADIUS = 7.5, 480, 40

local function level_offset_y()
	return math.max(math.min(scroll_offset_y * 5, 0), reference_window_height - 540 * ART_SCALE)
end

local function level_node(i)
	local y = i == 0 and 12 or 40 + (i - 1) * (HEAD_Y - 80) / (#opponents - 1) -- 0 is the tutorial, at the tail
	local u = (y + 10) / (HEAD_Y + 10)
	local env = math.max(math.min((1 - u) / 0.1, 1), 0)
	return (96 + 52 * math.sin(2 * math.pi * 3 * u) * env) * ART_SCALE, y * ART_SCALE + level_offset_y()
end

-- Returns the level whose node is under the given window position
function render.level_at(x, y)
	local rx, ry = x * reference_window_width / lg.getWidth(), y * reference_window_height / lg.getHeight()
	for i = 0, #opponents do
		local nx, ny = level_node(i)
		if (rx - nx) ^ 2 + (ry - ny) ^ 2 <= NODE_RADIUS ^ 2 then
			return i
		end
	end
end

local level_start, last_level = 0, -1

-- The swirling background dissolves into the snake and its levels over about a second and a half
function render.level_select()
	if time - last_level > 0.25 then
		level_start = time
	end
	last_level = time
	local fade = math.min((time - level_start) / 1.4, 1)
	fade = fade * fade * (3 - 2 * fade)
	if fade < 1 then
		background()
	end

	lg.setColor(1, 1, 1, fade)
	lg.draw(assets.level_snake, 0, level_offset_y(), 0, ART_SCALE / 10)

	local hovered = render.level_at(mouse.x, mouse.y)
	for i = 0, #opponents do
		local name = i == 0 and "Tutorial" or opponents[i].name
		local x, y = level_node(i)
		local fill = i > unlocked and { 0.3, 0.3, 0.3 } or (hovered == i and green or purple)
		if i == 0 and not tutorial.done then -- the new-player hint: this node pulses until it has been beaten
			fill = { 0.45 + 0.35 * math.sin(time * 5), 0.8, 0.3 }
		end
		lg.setColor(fill[1], fill[2], fill[3], fade)
		lg.circle("fill", x, y, NODE_RADIUS)
		lg.setColor(0, 0, 0, fade)
		lg.setLineWidth(5)
		lg.circle("line", x, y, NODE_RADIUS)
		lg.setColor(1, 1, 1, fade)
		lg.printf(i == 0 and "?" or tostring(i), assets.font, x - NODE_RADIUS, y - 25, NODE_RADIUS * 2, "center")
		local right = x > reference_window_width / 2
		lg.printf(name, assets.font, right and x - NODE_RADIUS - 415 or x + NODE_RADIUS + 15, y - 25, 400, right and "right" or "left")
	end
	lg.setColor(1, 1, 1)
	buttons.level_select["Deck"]:draw()
	buttons.level_select["Lanes"]:draw()
	buttons.universal["Back"]:draw()
end

local function hand_x(i)
	local x_pos = reference_window_width * 1.1 / 6 + 5
	local x_offset = reference_window_width * 0.44 / 6
	return x_pos + x_offset * (i - 1) + (-450 / 8 * #player_hand + 450), x_offset
end

-- Attack and defense badges sit along the bottom of the card's own field sector
local function draw_stats(sector)
	local box = play.field_hitboxes[sector]
	local background_scale, digit_scale = 1.9, 1.5
	local attack_x, defense_x, y = box[1] + 40, box[1] + 140, box[2] + 183
	local stats = data.get_stats(played_cards[sector])

	lg.scale(background_scale)
	lg.draw(assets.backgrounds[1], defense_x / background_scale, y / background_scale)
	lg.draw(assets.backgrounds[2], attack_x / background_scale, y / background_scale)
	lg.scale(1 / background_scale)

	lg.scale(digit_scale)
	for _, digits in ipairs({ { assets.defenses, played_cards[sector].hp or stats.defense, defense_x }, { assets.attacks, abilities.attack(played_cards[sector], sector), attack_x } }) do
		local sprites, value, x = digits[1], digits[2], digits[3] + 5
		lg.draw(sprites[math.floor(value / 10) + 1], (x - 10) / digit_scale, (y + 5) / digit_scale)
		lg.draw(sprites[value % 10 + 1], (x + 11) / digit_scale, (y + 5) / digit_scale)
	end
	lg.scale(1 / digit_scale)
end

-- A played card, drawn at 0.8 scale around its slot centre with any active effects applied
local SNAKE_SCALE = 1.0 -- cut-out snakes are drawn a little larger than whole cards were

-- Snakes on the board are cut out of their card (no purple frame or corner numbers) and sway gently.
-- Every card is 33x48 art pixels; the shader keeps the middle, drops the card's background and frame colours,
-- shifts each row sideways by whole art pixels (a wave that grows towards the tail) and traces the silhouette
-- in the border's colour. Frozen snakes stop moving and tint blue, poisoned ones tint green.
local snake_shader = lg.newShader([[
	uniform float time;
	uniform float seed;
	uniform float sway;
	uniform vec4 rim;
	uniform vec3 tint;
	const vec2 art = vec2(33.0, 48.0);

	vec4 snake(Image tex, vec2 uv) {
		vec2 px = uv * art;
		if (px.x < 2.0 || px.x > 31.0 || px.y < 2.0 || px.y > 46.0) return vec4(0.0);
		if (px.y < 9.0 && px.x < 10.0) return vec4(0.0);  // cost number and tier icon
		if (px.y >= 38.0) return vec4(0.0);               // attack, defense and rarity bars
		vec4 c = Texel(tex, uv);
		if (distance(c.rgb, vec3(118.0, 66.0, 138.0) / 255.0) < 0.02) return vec4(0.0);  // card background
		if (distance(c.rgb, vec3(63.0, 63.0, 116.0) / 255.0) < 0.02) return vec4(0.0);   // card frame
		return c;
	}

	vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
		float row = uv.y * art.y;
		float shift = floor(sin(time * 2.4 + row * 0.35 + seed) * (0.5 + 1.5 * uv.y) * sway + 0.5);
		vec2 at = uv - vec2(shift / art.x, 0.0);
		vec4 c = snake(tex, at);
		if (c.a > 0.0) return vec4(c.rgb * tint, c.a) * color;
		vec2 d = 1.0 / art;
		float edge = max(max(snake(tex, at + vec2(d.x, 0.0)).a, snake(tex, at - vec2(d.x, 0.0)).a),
		                 max(snake(tex, at + vec2(0.0, d.y)).a, snake(tex, at - vec2(0.0, d.y)).a));
		if (edge > 0.0 && rim.a > 0.0) return vec4(rim.rgb, rim.a * color.a);
		return vec4(0.0);
	}
]])

local function draw_slot(card, sector)
	local cx, cy = play.slot_centre(sector)
	local dx, dy, sx, sy, alpha, flash = effects.card(card)
	local stats = data.get_stats(card)
	local rim = borders.colour(stats.rarity == 5 and "Rainbow" or stats.border)
	local pulse = 0.5 + 0.5 * math.sin(time * 4)
	card.card_object:setFilter("nearest", "nearest")
	snake_shader:send("time", time)
	snake_shader:send("seed", sector * 1.7)
	snake_shader:send("sway", card.frozen and 0 or 1)
	snake_shader:send("rim", rim and { rim[1], rim[2], rim[3], 0.55 + 0.4 * pulse } or { 0, 0, 0, 0 })
	snake_shader:send("tint", card.frozen and { 0.6, 0.85, 1.2 } or (card.poison and { 0.7, 1.15, 0.6 } or { 1, 1, 1 }))
	lg.push()
	lg.translate(cx + dx, cy + dy)
	lg.scale(SNAKE_SCALE * sx, SNAKE_SCALE * sy)
	lg.setShader(snake_shader)
	lg.setColor(1, 1, 1, alpha)
	lg.draw(card.card_object, -img_widths / 2, -img_heights / 2)
	if flash > 0 then
		lg.setBlendMode("add")
		lg.setColor(1, 1, 1, flash * 0.8)
		lg.draw(card.card_object, -img_widths / 2, -img_heights / 2)
		lg.setBlendMode("alpha")
	end
	lg.setShader()
	lg.pop()
end

local LANE_X, LANE_Y = { 20, 250, 490, 720 }, { 20, 280 } -- where each lane's cells sit inside the field image

function render.playing()
	background()

	count = count + 1
	buttons.playing["Forfeit"]:draw()
	buttons.playing["Card Background"]:draw()
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
			lg.setColor(0.45, 0.8, 0.3, 0.25)
			lg.rectangle("fill", box[1] + 8, box[2] + 8, box[3] - 16, box[4] - 16)
		end
		lg.setColor(1, 1, 1)
	end

	-- Each side's charmer: portrait and name, plus the player's Charm button (covered by Info while a card is held)
	for side, spot in pairs({ Opponent = { 1215, 78 }, Player = { 1215, 548 } }) do
		local c = charmers.of(side, play.level)
		lg.setColor(1, 1, 1)
		portrait(c.name, spot[1], spot[2], 60, 72)
		lg.printf(c.name, assets.debug_font, spot[1] + 68, spot[2], 145, "left")
		lg.setColor(0.6, 0.9, 0.4)
		lg.printf(c.charm .. " (" .. c.cost .. ")", assets.debug_font, spot[1] + 68, spot[2] + 44, 145, "left")
	end
	local charm = buttons.playing["Charm"]
	charm:update_text(play.charm_used.Player and "Charm used" or "Charm")
	charm:draw()
	if not play.charm_ready("Player") then
		lg.setColor(0, 0, 0, 0.55)
		lg.rectangle("fill", charm.x - 5, charm.y - 5, charm.width + 10, charm.height + 10, 5, 5)
	end
	lg.setColor(1, 1, 1)

	if held_card then
		buttons.playing["Info"]:draw()
	end

	-- Positions are in reference-window units; love.draw scales everything
	local y_pos = reference_window_height * 16.6 / 24 - 5
	for i, card in ipairs(player_hand) do
		local x, x_offset = hand_x(i)
		local draw_x, draw_y = x, y_pos
		local glide = card.glide_t and (time - card.glide_t) / 0.15
		if glide and glide < 1 then
			local ease = 1 - (1 - glide) ^ 3
			draw_x, draw_y = card.glide_x + (x - card.glide_x) * ease, card.glide_y + (y_pos - card.glide_y) * ease
		end
		card:draw(draw_x, draw_y, 0)
		card_hitboxes[card] = { x, y_pos, i ~= #player_hand and x_offset or 165, img_heights }
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

	-- A pulsing ! marks your snakes whose activated ability you can afford right now
	local pulse = 0.5 + 0.5 * math.sin(time * 6)
	for sector = 5, 8 do
		if played_cards[sector] and turn == "Player" and tutorial.allows("ability") and abilities.ready(played_cards[sector], "Player") then
			local box = play.field_hitboxes[sector]
			lg.setColor(1, 0.9, 0.2, 0.6 + 0.4 * pulse)
			lg.circle("fill", box[1] + box[3] - 28, box[2] + 28, 16)
			lg.setColor(0, 0, 0)
			lg.printf("!", assets.font, box[1] + box[3] - 44, box[2] + 8, 32, "center")
		end
	end

	-- Hovering a snake on the field explains it
	if not held_card then
		for sector, card in pairs(played_cards) do
			if play.is_hitbox(mouse.x, mouse.y, play.field_hitboxes[sector]) then
				local stats = data.get_stats(card)
				local status = {}
				for _, flag in ipairs({ "poison", "frozen", "shield" }) do
					if card[flag] then
						table.insert(status, flag == "shield" and ("shield " .. card.shield) or flag)
					end
				end
				lg.setColor(0, 0, 0, 0.85)
				lg.rectangle("fill", 1200, 325, 235, 170)
				lg.setColor(1, 1, 1)
				lg.printf(
					card.card_path:sub(1, -5):gsub("_", " ") .. "\n" .. stats.ability .. "\n" .. borders.describe(stats.border)
						.. (#status > 0 and ("\n" .. table.concat(status, ", ")) or ""),
					assets.debug_font, 1208, 330, 220
				)
			end
		end
	end

	-- Health bars and turn indicator on the right of the field
	for side, y in pairs(play.bar_y) do
		local shake, flash = effects.bar(side)
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", 1210 + shake, y, 210, 40)
		lg.setColor(0.8, 0.1, 0.1)
		lg.rectangle("fill", 1215 + shake, y + 5, 200 * health[side] / max_health[side], 30)
		lg.setColor(1, 1, 1, flash * 0.7)
		lg.rectangle("fill", 1210 + shake, y, 210, 40)
		lg.setColor(1, 1, 1)
		lg.printf(health[side] .. " HP", assets.debug_font, 1215 + shake, y + 8, 200, "center")
	end
	effects.draw()
	lg.setColor(1, 1, 1)
	lg.printf(turn == "Player" and "Your Turn" or "Opponent's Turn", assets.font, 1200, 190, 230, "center")
	lg.setColor(1, 1, 1)

	if held_card then
		held_card:draw(
			mouse.x * reference_window_width / lg.getWidth() - img_widths / 2,
			mouse.y * reference_window_height / lg.getHeight() - img_heights / 2,
			0
		)
	end

	if not tutorial.allows("end_turn") then -- locked controls are dimmed like an unaffordable Charm
		local end_turn = buttons.playing["End Turn"]
		lg.setColor(0, 0, 0, 0.55)
		lg.rectangle("fill", end_turn.x - 5, end_turn.y - 5, end_turn.width + 10, end_turn.height + 10, 5, 5)
		lg.setColor(1, 1, 1)
	end
	tutorial.draw()
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
end

function render.ended()
	background()
	lg.setColor(1, 1, 1)
	local won = winner == "Player"
	lg.printf(won and (play.level == 0 and "Tutorial Complete!" or "Level " .. play.level .. " Complete!") or "Defeat", assets.font, 0, 220, reference_window_width / 3, "center", 0, 3, 3)
	if won then
		local message = level_unlocked and ("Level " .. level_unlocked .. " unlocked!") or (play.level == #opponents and "You beat every opponent!" or "")
		lg.printf(message, assets.font, 0, 400, reference_window_width, "center")
	end
	buttons.ended["Continue"]:draw()
end

function render.info()
	background()
	buttons.info["Back"]:draw()
	buttons.info["Info Background"]:draw()

	if not info_card then
		return
	end
	info_card:draw(reference_window_width * 0.8 / 6 + 5, reference_window_height * 1 / 6, 0, 2.65)

	lg.setColor(mouse_over_info_background and purple or green)
	local info = data.get_stats(info_card)
	local rows = {
		{ "Cost: ", info.cost, 0.7 },
		{ "Defense: ", info.defense, 1.7 },
		{ "Type: ", data.get_type(info_card), 2.7 },
		{ "Attack: ", info.attack, 3.7 },
		{ "Tier: ", info.rarity .. (info.tier and " " .. info.tier or ""), 4.7 },
	}
	for _, row in ipairs(rows) do
		lg.print(
			row[1] .. tostring(row[2]),
			assets.font,
			reference_window_width / 2,
			info_background_y + reference_window_height * row[3] / 10
		)
	end
	-- Longer text wraps in the smaller font
	local text_width = reference_window_width * 0.37
	for _, block in ipairs({
		{ "Ability: " .. info.ability, 5.3 },
		{ borders.describe(info.border), 6.4 },
		{ info.lore, 7.5 },
	}) do
		lg.printf(block[1], assets.small_font, reference_window_width / 2, info_background_y + reference_window_height * block[2] / 10, text_width)
	end
end

return render
