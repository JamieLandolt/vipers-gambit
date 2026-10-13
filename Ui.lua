local love = require("love")
local lg = love.graphics
local button = require("Button")
local assets = require("Assets")
local play = require("Play")
local collection = require("Collection")
local title = require("Title")
local settings = require("Settings")

local font = assets.font
local button_width, button_height = 200, 60

-- Shared defaults: font and debugger
local function b(text, func, params, x, y, w, h, ...)
	return button(text, func, params, x, y, w, h, font, debugger, ...)
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
		{ "Play Game", "level_select", -150 },
		{ "Collection", "collection", -50 },
		{ "Charmers", "character_select", 50 },
		{ "Settings", "settings", 150 },
	}
	for _, m in ipairs(menu) do
		buttons.menu[m[1]] =
			b(m[1], update_animation_screen, m[2], w / 2 - button_width / 2, h / 2 + m[3] + title.MENU_DROP, button_width, button_height)
	end
	buttons.menu["Button Background"] =
		b("", nil, nil, w / 2 - bg_width / 2, h / 2 - bg_height / 2 + resize(30, 2) + title.MENU_DROP, bg_width, bg_height)

	buttons.collection["Collection Header"] = b("Collection", nil, nil, w / 2 - button_width / 2, 5, button_width, button_height)
	buttons.universal["Back"] = b("Back", update_animation_screen, "menu", 5, 5, back_width, button_height)

	for _, item in ipairs(settings.items) do
		if item.click then
			buttons.settings[item.label] =
				b(item.text(), function() settings.click(item) end, nil, settings.CX, item.y + 5, settings.CW, settings.CH)
		end
	end
	-- Reset confirmation; kept apart from buttons.settings so they only respond while it is showing
	buttons.reset_confirm["Yes"] = b("Yes", settings.reset_progress, nil, w / 2 - button_width - 20, h / 2, button_width, button_height)
	buttons.reset_confirm["No"] = b("No", function() settings.confirm_reset = false end, nil, w / 2 + 20, h / 2, button_width, button_height)

	buttons.collection["Open Pack"] = b("Open Pack", function()
		if collection.pack_ready() then
			pack_cards = collection.open_pack()
			update_animation_screen("pack")
		end
	end, nil, w - button_width * 1.4 - 5, 5, button_width * 1.4, button_height)
	buttons.collection["Sort"] = b("Sort: " .. collection.sort_name(), function()
		collection.next_sort()
		buttons.collection["Sort"]:update_text("Sort: " .. collection.sort_name())
	end, nil, 850, 5, button_width * 1.3, button_height)
	buttons.pack["Done"] = b("Done", update_animation_screen, "collection", 5, 5, back_width, button_height)

	buttons.level_select["Select Opponent"] = b("Select Opponent", nil, nil, 5, 5, back_width, button_height)

	buttons.character_select["Charmers Header"] = b("Charmers", nil, nil, w / 2 - button_width / 2, 5, button_width, button_height)

	-- Replaces Back during a match; asks for confirmation before conceding
	buttons.playing["Forfeit"] = b("Forfeit", function() confirm_forfeit = true end, nil, 5, 5, button_width * 0.8, button_height)
	buttons.playing["Yes"] = b("Yes", function()
		confirm_forfeit, winner = false, "Opponent"
		update_game_state("ended")
	end, nil, w / 2 - button_width - 20, h / 2, button_width, button_height)
	buttons.playing["No"] = b("No", function() confirm_forfeit = false end, nil, w / 2 + 20, h / 2, button_width, button_height)
	buttons.playing["Charm"] = b("Charm", function() play.use_charm("Player") end, nil, 1210, 640, 210, button_height)
	buttons.playing["Card Background"] = b("", function() end, nil, hand.x, hand.y, hand.width, hand.height)
	buttons.playing["Info"] = b(
		"Info",
		function() end,
		nil,
		reference_window_width * 5.05 / 6 + 5,
		reference_window_height * 2 / 3 - 10,
		reference_window_width * 0.9 / 6 - 10,
		reference_window_height / 3,
		true -- The balatro button effect
	)
	local function end_player_turn()
		if turn == "Player" then
			play.end_turn()
		end
	end
	buttons.playing["End Turn"] = b("End Turn", end_player_turn, nil, 1215, 255, button_width, button_height)

	buttons.ended["Continue"] = b("Continue", update_animation_screen, "level_select", w / 2 - button_width / 2, h / 2 + 100, button_width, button_height)

	buttons.info["Back"] = b("Back", function()
		update_animation_screen(info_return)
	end, nil, 5, 5, back_width, button_height)
	buttons.info["Info Background"] = b(
		"Card Stats:",
		function() end,
		nil,
		reference_window_width * 0.7 / 6 + 5,
		info_background_y,
		info_width,
		info_height
	)
	buttons.info["Info Background"].top_text = true
end
