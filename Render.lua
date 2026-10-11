local love = require("love")
local lg = love.graphics
local assets = require("Assets")
local data = require("CardData")
local play = require("Play")
local opponents = require("Opponents")
local shader = require("Shader")

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

function render.menu()
	scroll_offset_y = 0
	background()
	for _, name in ipairs({ "Button Background", "Play Game", "Collection", "Character", "Settings" }) do
		buttons.menu[name]:draw()
	end
end

function render.collection()
	local offset_x = 69
	local offset_y = math.min(scroll_offset_y * 5, 0)
	background()

	for _, image in pairs(assets.cards) do
		if offset_x + resize(img_widths, 1) > reference_window_width then
			offset_x = 69
			offset_y = offset_y + img_heights
		end
		lg.draw(image, offset_x, offset_y + 70)
		offset_x = offset_x + img_widths
	end

	buttons.collection["Collection Header"]:draw()
	buttons.universal["Back"]:draw()
end

function render.character_select()
	background()
	buttons.universal["Back"]:draw()
end

function render.settings()
	background()
	buttons.universal["Back"]:draw()
	buttons.settings["Toggle Audio"]:draw()
	buttons.settings[audio and "Audio Enabled" or "Audio Disabled"]:draw()
end

-- The level snake is 192x540 art pixels drawn at 7.5 reference units each; its centre line
-- must match centre_x() in tools/draw_levels.py. Levels sit evenly along it, level 1 at the tail.
local ART_SCALE, HEAD_Y, NODE_RADIUS = 7.5, 480, 40

local function level_offset_y()
	return math.max(math.min(scroll_offset_y * 5, 0), reference_window_height - 540 * ART_SCALE)
end

local function level_node(i)
	local y = 40 + (i - 1) * (HEAD_Y - 80) / (#opponents - 1)
	local u = (y + 10) / (HEAD_Y + 10)
	local env = math.max(math.min((1 - u) / 0.1, 1), 0)
	return (96 + 52 * math.sin(2 * math.pi * 3 * u) * env) * ART_SCALE, y * ART_SCALE + level_offset_y()
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

function render.level_select()
	lg.setColor(1, 1, 1)
	lg.draw(assets.level_snake, 0, level_offset_y(), 0, ART_SCALE / 10)

	local hovered = render.level_at(mouse.x, mouse.y)
	for i, opponent in ipairs(opponents) do
		local x, y = level_node(i)
		lg.setColor(i > unlocked and { 0.3, 0.3, 0.3 } or (hovered == i and green or purple))
		lg.circle("fill", x, y, NODE_RADIUS)
		lg.setColor(0, 0, 0)
		lg.setLineWidth(5)
		lg.circle("line", x, y, NODE_RADIUS)
		lg.setColor(1, 1, 1)
		lg.printf(tostring(i), assets.font, x - NODE_RADIUS, y - 25, NODE_RADIUS * 2, "center")
		local right = x > reference_window_width / 2
		lg.printf(opponent.name, assets.font, right and x - NODE_RADIUS - 415 or x + NODE_RADIUS + 15, y - 25, 400, right and "right" or "left")
	end
	buttons.universal["Back"]:draw()
end

local function hand_x(i)
	local x_pos = reference_window_width * 1.1 / 6 + 5
	local x_offset = reference_window_width * 0.44 / 6
	return x_pos + x_offset * (i - 1) + (-450 / 8 * #player_hand + 450), x_offset
end

local function draw_stats(sector, offset)
	local background_scale, digit_scale = 1.9, 1.5
	local attack_x, defense_x, y = 285, 385, 468
	local slot = (sector - 5) * 230 + offset
	local stats = data.get_stats(played_cards[sector])

	lg.scale(background_scale)
	lg.draw(assets.backgrounds[1], (defense_x + slot) / background_scale, y / background_scale)
	lg.draw(assets.backgrounds[2], (attack_x + slot) / background_scale, y / background_scale)
	lg.scale(1 / background_scale)

	lg.scale(digit_scale)
	for _, digits in ipairs({ { assets.defenses, played_cards[sector].hp or stats.defense, defense_x }, { assets.attacks, stats.attack, attack_x } }) do
		local sprites, value, x = digits[1], digits[2], digits[3] + 5 + slot
		lg.draw(sprites[math.floor(value / 10) + 1], (x - 10) / digit_scale, (y + 5) / digit_scale)
		lg.draw(sprites[value % 10 + 1], (x + 11) / digit_scale, (y + 5) / digit_scale)
	end
	lg.scale(1 / digit_scale)
end

function render.playing()
	background()

	count = count + 1
	buttons.universal["Back"]:draw()
	buttons.playing["Card Background"]:draw()
	buttons.playing["End Turn"]:draw()

	lg.setColor(1, 1, 1)
	lg.draw(assets.playing_field, 245, 15)

	if held_card then
		buttons.playing["Info"]:draw()
	end

	-- Positions are in reference-window units; love.draw scales everything
	local y_pos = reference_window_height * 16.6 / 24 - 5
	for i, card in ipairs(player_hand) do
		local x, x_offset = hand_x(i)
		card:draw(x, y_pos, 0)
		card_hitboxes[card] = { x, y_pos, i ~= #player_hand and x_offset or 165, img_heights }
	end

	for sector, card in pairs(played_cards) do
		local box = play.field_hitboxes[sector]
		card:draw(box[1] + 54, box[2] + 34, 0, 0.8)
	end

	lg.setColor(1, 1, 1)

	local venom_scale = 2
	lg.scale(venom_scale)
	lg.draw(assets.venom[venom.Opponent + 1], (245 - venom_scale * 36) / 2, 15 / 2)
	lg.draw(assets.venom[venom.Player + 1], (245 - venom_scale * 36) / 2, (555 - venom_scale * 36) / 2)
	lg.scale(1 / venom_scale)

	-- Offset accounts for the thicker middle bar in the playing field; it carries over between sectors
	local offset = 0
	for sector = 1, 8 do
		if played_cards[sector] then
			if sector == 7 or sector == 2 then
				offset = 15
			elseif sector == 8 or sector == 4 then
				offset = 20
			end
			draw_stats(sector, offset)
		end
	end

	-- Health bars and turn indicator on the right of the field
	for side, y in pairs({ Opponent = 30, Player = 500 }) do
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", 1210, y, 210, 40)
		lg.setColor(0.8, 0.1, 0.1)
		lg.rectangle("fill", 1215, y + 5, 200 * health[side] / 20, 30)
		lg.setColor(1, 1, 1)
		lg.printf(health[side] .. " HP", assets.debug_font, 1215, y + 8, 200, "center")
	end
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
end

function render.ended()
	background()
	lg.setColor(1, 1, 1)
	lg.printf(winner == "Player" and "Victory!" or "Defeat", assets.font, 0, 250, reference_window_width / 3, "center", 0, 3, 3)
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
		{ "Tier: ", info.border, 2.7 },
		{ "Attack: ", info.attack, 3.7 },
		{ "Rarity: ", info.rarity, 4.7 },
		{ "Ability: ", info.ability, 5.7 },
		{ "Lore: ", info.lore, 6.7 },
	}
	for _, row in ipairs(rows) do
		lg.print(
			row[1] .. tostring(row[2]),
			assets.font,
			reference_window_width / 2,
			info_background_y + reference_window_height * row[3] / 10
		)
	end
end

return render
