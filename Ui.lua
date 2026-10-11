local love = require("love")
local lg = love.graphics
local button = require("Button")
local avatar = require("Avatar")
local assets = require("Assets")
local play = require("Play")

local font = assets.font
local button_width, button_height = 200, 60

-- Shared defaults: font, text y-offset and debugger
local function b(text, func, params, x, y, w, h, text_offset_x, ...)
	return button(text, func, params, x, y, w, h, font, text_offset_x, 4, debugger, ...)
end

-- If adding a new button, remember to draw it, may need to add game state too
return function()
	local w, h = lg.getWidth(), lg.getHeight()
	local back_width = button_width * 5 / 8
	local bg_width, bg_height = resize(240, 1), resize(425, 2)

	local hand = {
		x = reference_window_width / 6 + 5,
		width = reference_window_width * 2 / 3 - 10,
		height = reference_window_height / 3,
	}
	hand.y = reference_window_height - hand.height - 10

	local info_width = reference_window_width * 5 / 6
	local info_height = reference_window_height * 5 / 6
	info_background_y = reference_window_height / 12

	local menu = {
		{ "Play Game", "level_select", -150, 9 },
		{ "Collection", "collection", -50, 11 },
		{ "Character", "character_select", 50, 6 },
		{ "Settings", "settings", 150, 19 },
	}
	for _, m in ipairs(menu) do
		buttons.menu[m[1]] =
			b(m[1], update_animation_screen, m[2], w / 2 - button_width / 2, h / 2 + m[3], button_width, button_height, m[4])
	end
	buttons.menu["Button Background"] =
		b("", nil, nil, w / 2 - bg_width / 2, h / 2 - bg_height / 2 + resize(30, 2), bg_width, bg_height, 19, nil, nil, nil, nil, true)

	buttons.collection["Collection Header"] = b("Collection", nil, nil, w / 2 - button_width / 2, 5, button_width, button_height, 14)
	buttons.universal["Back"] = b("Back", update_animation_screen, "menu", 5, 5, back_width, button_height, 19)

	buttons.settings["Toggle Audio"] =
		b("Toggle Audio", toggle_audio, nil, w / 2 - button_width / 4, h / 2 - 100, button_width * 1.315, button_height, 19)
	for name, icon in pairs({ ["Audio Enabled"] = assets.icons.audio_enabled, ["Audio Disabled"] = assets.icons.audio_disabled }) do
		buttons.settings[name] =
			b("", nil, nil, w / 2 - button_width * 3 / 4, h / 2 - 100, button_width * 0.3, button_height, 19, false, icon, 1 / 4, -6, 16)
	end

	buttons.level_select["Select Opponent"] = b("Select Opponent", nil, nil, 5, 5, back_width, button_height, 19)

	local text_offsets = { Gabe = 95, Jamie = 85, Michael = 75, Josh = 95, Alem = 95, Darcy = 85 }
	for name, offset in pairs(text_offsets) do
		buttons.character_select[name] =
			avatar(name, name, update_game_state, "menu", offset, 20, font, 355, 500, assets.avatars[name:lower()], 0.7, debugger)
	end

	buttons.playing["Card Background"] = b("", function() end, nil, hand.x, hand.y, hand.width, hand.height, 19)
	buttons.playing["Info"] = b(
		"Info",
		function() end,
		nil,
		reference_window_width * 5.05 / 6 + 5,
		reference_window_height * 2 / 3 - 10,
		reference_window_width * 0.9 / 6 - 10,
		reference_window_height / 3,
		19,
		true -- The balatro button effect
	)
	local function end_player_turn()
		if turn == "Player" then
			play.end_turn()
		end
	end
	buttons.playing["End Turn"] = b("End Turn", end_player_turn, nil, 1215, 255, button_width, button_height, 19, false)

	buttons.info["Back"] = b("Back", update_animation_screen, "playing", 5, 5, back_width, button_height, 19)
	buttons.info["Info Background"] = b(
		"Card Stats:",
		function() end,
		nil,
		reference_window_width * 0.7 / 6 + 5,
		info_background_y,
		info_width,
		info_height,
		19
	)
end
