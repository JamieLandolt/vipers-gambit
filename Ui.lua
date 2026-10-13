local love = require("love")
local lg = love.graphics
local button = require("Button")
local assets = require("Assets")
local play = require("Play")
local collection = require("Collection")
local tutorial = require("Tutorial")
local title = require("Title")
local hub = require("Hub")
local challenges = require("Challenges")
local settings = require("Settings")

local font = assets.font
local button_width, button_height = 200, 60

-- The collection screen's toolbar buttons use the smaller font
local function small(text, func, params, x, y, w, h)
	return button(text, func, params, x, y, w, h, assets.small_font, debugger)
end

-- Shared defaults: font and debugger
local function b(text, func, params, x, y, w, h, ...)
	return button(text, func, params, x, y, w, h, font, debugger, ...)
end

-- If adding a new button, remember to draw it, may need to add game state too
return function()
	local w, h = lg.getWidth(), lg.getHeight()
	local back_width = button_width * 5 / 8

	local hand = {
		x = reference_window_width / 6 + 5,
		width = reference_window_width * 2 / 3 - 10,
		height = reference_window_height / 3,
	}
	hand.y = reference_window_height - hand.height - 10

	local info_width = reference_window_width * 5 / 6
	local info_height = reference_window_height * 5 / 6
	info_background_y = reference_window_height / 12

	-- The main menu is the Hub (icons around a temple); only its Deck & Lanes popup uses buttons
	buttons.hub_popup["Deck"] = b("Deck", function()
		hub.popup = false
		collection.deck_mode = true
		collection.start_deck_edit()
		update_animation_screen("collection")
	end, nil, w / 2 - button_width - 20, h / 2 - 40, button_width, button_height)
	buttons.hub_popup["Lanes"] = b("Lanes", function()
		hub.popup = false
		update_animation_screen("lanes")
	end, nil, w / 2 + 20, h / 2 - 40, button_width, button_height)
	buttons.hub_popup["Cancel"] = b("Cancel", function() hub.popup = false end, nil, w / 2 - button_width / 2, h / 2 + 50, button_width, button_height)

	buttons.collection["Collection Header"] = b("Collection", nil, nil, w / 2 - 170, 5, 340, button_height)
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

	buttons.collection["Open Pack"] = b("Packs", function()
		shop_return = "collection"
		update_animation_screen("shop")
	end, nil, w - 140, 5, 135, button_height)
	buttons.collection["Sacrifice"] = small("Imbue", function()
		if collection.deck_mode then -- in deck editing this button is Auto-fill
			collection.auto_deck()
			return
		end
		if not collection.sacrifice_unlocked() then
			collection.message, collection.message_t = "Beat the second opponent to unlock Imbue", time
			return
		end
		collection.sacrifice_mode = not collection.sacrifice_mode
		collection.sacrificing = {}
		collection.deck_mode = false
	end, nil, 215, 70, 190, 44)
	buttons.sac_tutorial["Next"] = b("Next", function() sac_tutorial = sac_tutorial < 3 and sac_tutorial + 1 or nil end, nil, w / 2 - button_width / 2, h / 2 + 150, button_width, button_height)
	buttons.collection["Summon"] = b("Summon", function()
		if collection.can_summon() then
			pack_cards = collection.summon()
			buttons.pack["Done"].func_params = "collection"
			update_animation_screen("pack")
		end
	end, nil, 20, 790, button_width, button_height)
	-- The altar: back to the main screen, and offer the chosen recipe's snakes
	buttons.altar["Offer"] = b("Offer", function()
		local _, by_target = collection.recipes()
		local recipe = by_target[collection.altar_target or ""]
		local names = recipe and collection.sacrifice_recipe(recipe)
		if names then
			pack_cards = names
			buttons.pack["Done"].func_params = "altar"
			update_animation_screen("pack")
		else
			collection.message, collection.message_t = "You don't have everything the Snake God asks for", time
		end
	end, nil, 880, 790, 360, button_height)
	buttons.shop["Back"] = b("Back", function() update_animation_screen(shop_return) end, nil, 5, 5, back_width, button_height)
	for i = 1, #collection.PACKS do
		buttons.shop["Pack " .. i] = b("Open", function()
			local names, message = collection.open_pack(i)
			if names then
				pack_cards = names
				buttons.pack["Done"].func_params = "shop"
				update_animation_screen("pack")
			else
				collection.message, collection.message_t = message, time
			end
		end, nil, 110 + (i - 1) * 420 + 65, 650, 250, button_height)
	end
	-- Buy the same pack again from the pack screen (replays the opening)
	buttons.pack["Again"] = b("Open Another", function()
		local pack = collection.PACKS[collection.pack_kind]
		if not pack or not collection.pack_revealed then
			return -- only after a bought pack has been fully shown
		end
		local names, message = collection.open_pack(collection.pack_kind)
		if names then
			pack_cards = names
		else
			collection.message, collection.message_t = message, time
		end
	end, nil, w / 2 - button_width, 800, button_width * 2, button_height)
	buttons.collection["Sort"] = small("Sort: " .. collection.sort_name(), function()
		collection.next_sort()
		buttons.collection["Sort"]:update_text("Sort: " .. collection.sort_name())
	end, nil, w - 220, 70, 200, 44)
	buttons.collection["Edit Deck"] = small("Edit Deck", function()
		collection.deck_mode = not collection.deck_mode
		collection.sacrifice_mode, collection.sacrificing = false, {}
		if collection.deck_mode then
			collection.start_deck_edit()
		end
	end, nil, 15, 70, 190, 44)
	buttons.pack["Done"] = b("Done", update_animation_screen, "shop", 5, 5, back_width, button_height)

	-- Beaten levels ask first: the plain match or that level's challenge
	buttons.level_choice["Play"] = b("Play", function()
		local level = level_choice
		level_choice = nil
		play.begin(level)
	end, nil, w / 2 - button_width * 1.5 - 20, h - 100, button_width, button_height)
	buttons.level_choice["Challenge"] = b("Challenge", function()
		local level = level_choice
		if play.challenge_open(level) then
			level_choice = nil
			play.begin(level, challenges[level])
		end
	end, nil, w / 2 - button_width / 2, h - 100, button_width, button_height)
	buttons.level_choice["Cancel"] = b("Cancel", function() level_choice = nil end, nil, w / 2 + button_width / 2 + 20, h - 100, button_width, button_height)
	buttons.lanes["Back"] = b("Back", update_animation_screen, "menu", 5, 5, back_width, button_height)
	buttons.lanes["Reset"] = b("Reset", function() play.reset_lanes() end, nil, w / 2 - button_width / 2, h - 110, button_width, button_height)

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
	buttons.playing["Tutorial Next"] = b("Next", function()
		tutorial.advance()
	end, nil, 20, 410, 200, 50)
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
		if turn == "Player" and tutorial.allows("end_turn") then
			play.end_turn()
		end
	end
	buttons.playing["End Turn"] = b("End Turn", end_player_turn, nil, 1215, 255, button_width, button_height)

	buttons.ended["Continue"] = b("Continue", update_animation_screen, "level_select", w / 2 - button_width / 2, h / 2 + 100, button_width, button_height)

	buttons.info["Back"] = b("Back", function()
		update_animation_screen(info_return)
	end, nil, 5, 5, back_width, button_height)
	buttons.info["Info Background"] = b(
		"",
		function() end,
		nil,
		reference_window_width * 0.7 / 6 + 5,
		info_background_y,
		info_width,
		info_height
	)
	buttons.info["Info Background"].top_text = true
end
