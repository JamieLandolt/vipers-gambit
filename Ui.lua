local love = require("love")
local lg = love.graphics
local button = require("Button")
local assets = require("Assets")
local play = require("Play")
local collection = require("Collection")
local tutorial = require("Tutorial")
local title = require("Title")
local hub = require("Hub")
local settings = require("Settings")
local versus = require("Versus")

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

	-- The main menu is the Hub (icons around a temple); its Play and Gameplay popups use these buttons
	local left, right = w / 2 - button_width - 20, w / 2 + 20
	local function row(n) return h / 2 - 190 + (n - 1) * 80 end
	local function locked(name)
		local need = hub.locked(name)
		if need then
			hub.note, hub.note_t = need, time
		end
		return need
	end
	buttons.hub_popup["Campaign"] = b("Campaign", function()
		update_animation_screen("level_select")
	end, nil, left, h / 2 - 40, button_width, button_height)
	buttons.hub_popup["Versus"] = b("Versus", function()
		if locked("Versus") then
			return
		end
		update_animation_screen("versus")
	end, nil, right, h / 2 - 40, button_width, button_height)
	buttons.hub_popup["Charmers"] = b("Charmers", function()
		if locked("Charmers") then
			return
		end
		update_animation_screen("character_select")
	end, nil, left, row(1), button_width, button_height)
	buttons.hub_popup["Collection"] = b("Collection", function()
		if locked("Collection") then
			return
		end
		collection.deck_mode, collection.sacrifice_mode, collection.sacrificing = false, false, {}
		collection.section, collection.return_to = nil, nil
		collection.clear_filters()
		update_animation_screen("collection")
	end, nil, right, row(1), button_width, button_height)
	buttons.hub_popup["Deck"] = b("Deck", function()
		if locked("Deck") then
			return
		end
		collection.deck_mode, collection.section = true, nil
		collection.clear_filters()
		collection.start_deck_edit()
		update_animation_screen("collection")
	end, nil, left, row(2), button_width, button_height)
	buttons.hub_popup["Lanes"] = b("Lanes", function()
		if locked("Lanes") then
			return
		end
		update_animation_screen("lanes")
	end, nil, right, row(2), button_width, button_height)
	buttons.hub_popup["Imbue"] = b("Imbue", function()
		if locked("Imbue") then
			return
		end
		collection.sacrifice_mode, collection.sacrificing, collection.deck_mode = true, {}, false
		collection.return_to = hub.home()
		collection.open_section("snake")
		update_animation_screen("collection")
	end, nil, left, row(3), button_width, button_height)
	buttons.hub_popup["Sacrifice"] = b("Sacrifice", function()
		if locked("Sacrifice") then
			return
		end
		update_animation_screen("altar")
	end, nil, right, row(3), button_width, button_height)
	buttons.play_menu["Back"] = b("Back", function() update_animation_screen("menu") end, nil, 5, 5, back_width, button_height)
	buttons.gameplay["Back"] = b("Back", function() update_animation_screen("menu") end, nil, 5, 5, back_width, button_height)

	buttons.collection["Collection Header"] = b("Collection", nil, nil, w / 2 - 170, 5, 340, button_height)
	buttons.universal["Back"] = b("Back", function() update_animation_screen(game.state["level_select"] and "menu" or hub.home()) end, nil, 5, 5, back_width, button_height)

	for _, item in ipairs(settings.items) do
		if item.click then
			buttons.settings[item.label] =
				b(item.text(), function() settings.click(item) end, nil, settings.CX, item.y + 5, settings.CW, settings.CH)
		end
	end
	-- Reset confirmation; kept apart from buttons.settings so they only respond while it is showing
	buttons.reset_confirm["Yes"] = b("Yes", settings.reset_progress, nil, w / 2 - button_width - 20, h / 2, button_width, button_height)
	buttons.reset_confirm["No"] = b("No", function() settings.confirm_reset = false end, nil, w / 2 + 20, h / 2, button_width, button_height)

	-- Leaves a section page, imbue mode or deck editing: back to the section list, the altar it came from, or the menu
	local function collection_back()
		if collection.sacrifice_mode and collection.return_to then
			local to = collection.return_to
			collection.sacrifice_mode, collection.sacrificing, collection.return_to, collection.section = false, {}, nil, nil
			update_animation_screen(to)
		elseif collection.section and not collection.deck_mode then
			collection.section = nil
			collection.clear_filters()
		else
			update_animation_screen(hub.home())
		end
	end
	buttons.collection["Back"] = b("Back", collection_back, nil, 5, 5, back_width, button_height)
	buttons.collection["Sacrifice"] = small("Imbue", function() -- (Auto-fill in deck editing, Cancel while imbuing; imbuing starts at the altar)
		if collection.deck_mode then
			collection.auto_deck()
		elseif collection.sacrifice_mode then
			collection_back()
		end
	end, nil, 215, 84, 190, 44)
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
	buttons.borders["Back"] = b("Back", function()
		if border_view then
			border_view = nil
		else
			update_animation_screen("collection")
		end
	end, nil, 5, 5, back_width, button_height)
	buttons.achievements["Back"] = b("Back", function() update_animation_screen(achievements_return) end, nil, 5, 5, back_width, button_height)
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
	end, nil, w - 220, 84, 200, 44)
	buttons.pack["Done"] = b("Back", update_animation_screen, "shop", 5, 5, back_width, button_height)

	-- The briefing before a match: Play starts the level's next fight (the plain match, then its challenges, then endless rematches)
	buttons.level_choice["Play"] = b("Play", function()
		if play.begin(level_choice) then
			level_choice = nil
		end
	end, nil, w / 2 - button_width - 20, h - 100, button_width, button_height)
	buttons.level_choice["Cancel"] = b("Cancel", function() level_choice = nil end, nil, w / 2 + 20, h - 100, button_width, button_height)
	buttons.lanes["Back"] = b("Back", function() update_animation_screen(hub.home()) end, nil, 5, 5, back_width, button_height)
	for i, preset in ipairs(play.LANE_PRESETS) do -- a row of ready-made layouts under the lanes
		buttons.lanes["Preset " .. i] = small(preset.name, function() play.apply_lane_preset(i) end, nil, 75 + (i - 1) * 215, 700, 200, button_height)
	end

	buttons.level_select["Select Opponent"] = b("Select Opponent", nil, nil, 5, 5, back_width, button_height)

	buttons.character_select["Charmers Header"] = b("Charmers", nil, nil, w / 2 - button_width / 2, 5, button_width, button_height)

	-- Replaces Back during a match; asks for confirmation before conceding
	buttons.playing["Forfeit"] = b("Forfeit", function() confirm_forfeit = true end, nil, 5, 5, button_width * 0.8, button_height)
	buttons.playing["Yes"] = b("Yes", function()
		confirm_forfeit = false
		play.forfeited = true -- giving up earns nothing: no reward, no progress
		if play.versus == "host" then
			health.Player = 0
			play.check_end()
		elseif play.versus == "guest" then
			versus.send({ k = "forfeit" })
			versus.finish("Opponent")
		else
			winner, collection.last_reward = "Opponent", 0
			tutorial.active = false
			update_game_state("ended")
		end
	end, nil, w / 2 - button_width - 20, h / 2, button_width, button_height)
	buttons.playing["No"] = b("No", function() confirm_forfeit = false end, nil, w / 2 + 20, h / 2, button_width, button_height)
	buttons.playing["Charm"] = b("Charm", function() play.use_charm("Player") end, nil, 1210, 640, 210, button_height)
	buttons.playing["Tutorial Next"] = b("Next", function()
		tutorial.advance()
	end, nil, 20, 410, 200, 50)
	buttons.playing["Card Background"] = b("", function() end, nil, hand.x, hand.y, hand.width, hand.height)
	local function end_player_turn()
		if turn == "Player" and not play.ending and tutorial.allows("end_turn") then
			play.end_turn()
		end
	end
	buttons.playing["End Turn"] = b("End Turn", end_player_turn, nil, 1215, 255, button_width, button_height)

	buttons.ended["Continue"] = b("Continue", function()
		if play.versus then
			versus.leave()
			update_animation_screen("menu")
		else
			update_animation_screen("level_select")
		end
	end, nil, w / 2 - button_width / 2, h - button_height - 40, button_width, button_height)

	buttons.versus["Back"] = b("Back", function()
		versus.leave()
		update_animation_screen("menu")
	end, nil, 5, 5, back_width, button_height)
	buttons.versus["Host"] = b("Host", versus.host, nil, 160 + 80, 560, 360, button_height)
	buttons.versus["Join"] = b("Join", function() versus.join(versus.ip) end, nil, 760 + 80, 560, 360, button_height)

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
