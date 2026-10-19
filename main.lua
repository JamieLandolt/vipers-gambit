local love = require("love")
local lg = love.graphics
local la = love.audio
local assets = require("Assets")
local build_ui = require("Ui")
local play = require("Play")
local challenges = require("Challenges")
local hub = require("Hub")
local render = require("Render")
local collection = require("Collection")
local charmers = require("Charmers")
local tutorial = require("Tutorial")
local lane_editor = require("LaneEditor")
local settings = require("Settings")
local coach = require("Coach")
local effects = require("Effects")
local achievements = require("Achievements")
local versus = require("Versus")

reference_window_width = 1440
reference_window_height = 872
time = 0

-- Shared state (global because Button, Avatar, Play and Render read it)
mouse = {}
chosen_avatar = "Raja Kaal"
chosen_opponent = "Ice King"
scroll_offset_y = 0
count = 0
held_since, held_at = 0, { 0, 0 } -- when and where the held snake was picked up (a quick click opens its info)
mouse_over_info_background = false
characters = {} -- (Avatar.lua checks it)
played_cards = {}
card_hitboxes = {} -- x, y, width, height
player_hand = {}
opponent_hand = {}
held_card = nil
held_index = nil -- where the held snake sat in the hand
info_card = nil
info_return = "playing" -- screen the info page's Back button returns to
level_unlocked = nil -- level opened by the last win
confirm_forfeit = false -- the forfeit confirmation is showing
pack_cards = {} -- names pulled from the most recent pack
-- Set by play.new_game: turn, health, max_health, max_venom, venom, winner
audio = true
unlocked = 1 -- highest level the player can pick, saved in save.txt
animation_time = 0 -- how long it has been playing
animation_length = 0.1 -- how long it lasts
animation = false
animation_next_screen = nil
buttons = {
	menu = {},
	settings = {},
	level_select = {},
	character_select = {},
	collection = {},
	lanes = {},
	playing = {},
	paused = {},
	pack = {},
	shop = {},
	altar = {},
	borders = {},
	achievements = {},
	ended = {},
	info = {},
	universal = {},
	reset_confirm = {},
	hub_popup = {},
	gameplay = {},
	play_menu = {},
	level_choice = {},
	sac_tutorial = {},
	versus = {},
}
sac_tutorial = nil -- step (1-3) of the Sacrifice tutorial while it is showing
achievements_return = "settings" -- where the achievements page's Back goes: the settings, or the menu when opened from there
shop_return = "menu" -- where Back goes from the pack shop: the menu, or the collection when opened from there
level_choice = nil -- the beaten level whose Play/Challenge dialog is open
game = {
	state = {
		menu = true,
		gameplay = false,
		play_menu = false,
		settings = false,
		level_select = false,
		character_select = false,
		collection = false,
		lanes = false,
		playing = false,
		paused = false,
		pack = false,
		shop = false,
		altar = false,
		borders = false,
		achievements = false,
		ended = false,
		info = false,
		versus = false,
	},
}

local debug_text = "Debug Text"
local w, h = 1440, 900

function resize(num, type)
	-- type 1: x, type2: y
	if type == 1 then
		return num * lg.getWidth() / reference_window_width
	elseif type == 2 then
		return num * lg.getHeight() / reference_window_height
	else
		error("Unrecognised Type: (" .. tostring(type) .. ") passed to function: resize")
	end
end

function play_sound(sound)
	if audio then
		la.play(sound)
	end
end

function debugger(text)
	debug_text = text
end

function update_animation_screen(screen)
	animation_next_screen = screen
end

function update_game_state(state)
	for state_name in pairs(game.state) do
		game.state[state_name] = false
	end
	animation = false
	game.state[state] = true
	if state == "menu" then
		hub.return_to = nil
	end
end

function contains(table, val)
	for _, v in ipairs(table) do
		if v == val then
			return true
		end
	end
	return false
end

local function get_game_state()
	for state, val in pairs(game.state) do
		if val then
			return state
		end
	end
end

local function handle_animations(dt)
	mouse.x, mouse.y = love.mouse.getPosition()

	if animation then
		animation_time = animation_time + dt
		if animation_time > animation_length * 3 then
			if animation_next_screen then
				update_game_state(animation_next_screen)
				update_animation_screen(nil)
			end
			animation = false
		end
	else
		animation_time = 0
	end

	if game.state["info"] then
		mouse_over_info_background = buttons.info["Info Background"]:hover()
	end
end

function love.load()
	math.randomseed(os.time())
	mouse.x, mouse.y = love.mouse.getPosition()

	img_widths = assets.cards[1]:getWidth()
	img_heights = assets.cards[1]:getHeight()
	hover_sound = la.newSource("assets/audio/hover.mp3", "static")

	love.window.setMode(reference_window_width, reference_window_height, { resizable = true, vsync = 0 })
	collection.load()
	collection.load_vials()
	require("Achievements").load()
	play.load_lanes()
	charmers.load()
	build_ui()
	settings.load() -- after build_ui, which lays out for the reference window size
end

function love.update(dt)
	time = time + dt

	-- Keep the window at the reference aspect ratio
	local aspect_ratio = 1440 / 872
	if not settings.fullscreen and math.abs(w / h - aspect_ratio) > 0.008 then
		h = w / aspect_ratio
		love.window.setMode(w, h, { resizable = true })
	end

	w = lg.getWidth()
	h = lg.getHeight()

	handle_animations(dt)
	if map_press and love.mouse.isDown(1) and game.state["level_select"] and not level_choice then -- dragging the level map
		local mx, my = love.mouse.getPosition()
		local dx, dy = (mx - map_press.x) * reference_window_width / w, (my - map_press.y) * reference_window_height / h
		map_press.x, map_press.y, map_press.moved = mx, my, map_press.moved + math.abs(dx) + math.abs(dy)
		render.pan_map(dx, dy)
	end
	settings.update()
	versus.update()
	if game.state["playing"] then
		tutorial.update()
		play.update_ending()
		if settings.infinite_venom and venom and not play.versus then -- testing: the player's venom vials never run out
			venom.Player = play.MAX_VENOM
		end
		if confirm_forfeit or play.ending then
			return
		elseif turn == "Player" then
			-- Checks where to place a card if one has been let go since last update
			play.place_card()
		elseif not play.versus then
			play.opponent_turn(dt)
		end
	end
end

function love.mousepressed(x, y, button)
	if button ~= 1 then
		return
	end

	if coach.active() then -- a mini tutorial is showing: a click moves it on
		coach.click()
		return
	end

	if game.state["settings"] then
		if settings.confirm_reset then
			for _, name in ipairs({ "Yes", "No" }) do
				buttons.reset_confirm[name]:checkPressed(x, y)
			end
			return
		end
		if settings.press(x, y) then
			return
		end
	end

	-- While the forfeit confirmation is up, only Yes and No respond
	if game.state["playing"] and confirm_forfeit then
		for _, name in ipairs({ "Yes", "No" }) do
			buttons.playing[name]:checkPressed(x, y)
		end
		return
	end

	if game.state["level_select"] and level_choice then -- only the choice dialog responds while it is open
		for _, name in ipairs({ "Play", "Cancel" }) do
			buttons.level_choice[name]:checkPressed(x, y)
		end
		return
	end

	if game.state["collection"] and sac_tutorial then -- only Next responds during the Sacrifice tutorial
		buttons.sac_tutorial["Next"]:checkPressed(x, y)
		return
	end

	if game.state["menu"] then
		local spot = hub.spotlight()
		if #spot > 0 then -- something new is highlighted: clicking it opens it, clicking elsewhere just dismisses the note
			local hit = hub.at(x, y)
			if hit and contains(spot, hit) then
				hub.click(hit)
			else
				hub.dismiss(spot)
			end
			return
		end
		local item = hub.at(x, y)
		if item then
			hub.click(item)
			return
		end
	end

	-- Check if button on screen is clicked
	local pressed = false
	local hidden = game.state["playing"] and { [buttons.playing["Yes"]] = true, [buttons.playing["No"]] = true } or {} -- the forfeit buttons only exist while it is asked
	for _, b in pairs(buttons[get_game_state()]) do
		if not hidden[b] and b:checkPressed(x, y) then
			pressed = true
		end
	end

	-- Check universal buttons only if a screen button wasn't pressed
	if not pressed then
		for _, b in pairs(buttons.universal) do
			b:checkPressed(x, y)
		end
	end

	for _, screen in ipairs({ "gameplay", "play_menu" }) do
		if game.state[screen] and not pressed then
			local item = hub.screen_at(screen, x, y)
			if item then
				hub.screen_click(screen, item)
			end
		end
	end

	if game.state["collection"] and not pressed and collection.landing() then
		local key = render.collection_tile_at(x, y)
		if key == "borders" then
			animation, animation_time = true, 0
			update_animation_screen("borders")
		elseif key then
			collection.open_section(key)
		end
		if key then
			play_sound(hover_sound)
		end
	end

	if game.state["collection"] and not pressed and not collection.landing() then
		local group, key = render.filter_icon_at(x, y)
		local name = not group and render.collection_card_at(x, y)
		if group then
			if group == "reset" then
				collection.clear_filters()
			else
				collection.toggle_filter(group, key)
			end
			play_sound(hover_sound)
		elseif name and collection.deck_mode then
			-- Editing the deck: a click adds or removes the snake (the message says why it didn't work)
			collection.message, collection.message_t = collection.toggle_deck(name), time
			play_sound(hover_sound)
		elseif name and collection.sacrifice_mode then
			collection.message, collection.message_t = collection.pick_sacrifice(name), time
			play_sound(hover_sound)
		elseif name then
			info_card, info_return = require("Card")(name .. ".png", img_widths, img_heights), "collection"
			play_sound(hover_sound)
			animation, animation_time = true, 0
			update_animation_screen("info")
		end
	end

	if game.state["borders"] and not pressed and not border_view then
		border_view = render.border_at(x, y)
		if border_view then
			play_sound(hover_sound)
		end
	end

	if game.state["altar"] and not pressed then
		local target = render.altar_row_at(x, y)
		if target then
			collection.altar_target = target
			play_sound(hover_sound)
		end
	end

	if game.state["character_select"] then
		local skin_name, look = render.skin_at(x, y)
		local name = skin_name or render.charmer_at(x, y)
		if name then
			chosen_avatar = name
			if skin_name then -- a small picture of one of the charmer's looks: pick the charmer and that look
				charmers.set_skin(skin_name, look)
			else
				charmers.save()
			end
			play_sound(hover_sound)
		end
	end

	if game.state["lanes"] and not pressed then
		lane_editor.press(x, y)
	end

	if game.state["level_select"] and not pressed then
		map_press = { x = x, y = y, moved = 0 } -- a click opens the level, a drag pans the map (see love.mousereleased)
	end

	-- Check if card is clicked with no card in hand
	if game.state["playing"] and turn == "Player" and not play.ending then
		-- Clicking one of your snakes on the field uses its activated ability
		for slot = 5, 8 do
			if played_cards[slot] and tutorial.allows("ability") and play.is_hitbox(x, y, play.field_hitboxes[slot]) then
				play.activate(slot)
			end
		end
		for card, hitbox in pairs(card_hitboxes) do
			if play.is_hitbox(x, y, hitbox) then
				local found
				for i, c in pairs(player_hand) do
					if c == card then
						table.remove(player_hand, i)
						held_index, found = i, true -- so it goes back to the same place if it isn't played
						break
					end
				end
				if found then
					card_hitboxes[card] = nil
					held_card = card
					held_since, held_at = time, { mouse.x, mouse.y }
				end
			end
		end
	end
end

function love.textinput(text)
	if game.state["versus"] then
		versus.textinput(text)
	end
end

function love.keypressed(key)
	if game.state["versus"] and key == "backspace" then
		versus.backspace()
	end
end

function love.mousereleased(x, y, button)
	if button == 1 and map_press then
		local press = map_press
		map_press = nil
		if press.moved < 10 and game.state["level_select"] and not level_choice then
			local level = render.level_at(x, y)
			if level and play.level_open(level) then
				level_choice = level -- the briefing: reward, challenge, charmers and decks
			end
		end
	end
	if button == 1 and game.state["lanes"] then
		lane_editor.release(x, y)
	end
end

function love.wheelmoved(x, y)
	if game.state["level_select"] and not level_choice then -- the level map scrolls in every direction
		render.pan_map(x * 40, y * 40)
		return
	end
	if scroll_offset_y + y < 0 then
		scroll_offset_y = scroll_offset_y + y * 2
	else
		scroll_offset_y = 0
	end
end

function love.draw()
	lg.scale(lg.getWidth() / reference_window_width, lg.getHeight() / reference_window_height)

	local shake_x, shake_y = 0, 0
	if game.state["playing"] then
		shake_x, shake_y = effects.screen_offset()
	end
	lg.translate(shake_x, shake_y)
	render[get_game_state()]()
	lg.translate(-shake_x, -shake_y)
	coach.draw()

	local toast = achievements.current()
	if toast then -- an achievement banner slides down from the top
		local slide = math.min((time - toast.t) * 4, 1)
		local y = -80 + 95 * slide
		lg.setColor(0.07, 0.04, 0.14, 0.95)
		lg.rectangle("fill", 470, y, 500, 84, 10, 10)
		lg.setColor(1, 0.85, 0.2)
		lg.rectangle("line", 470, y, 500, 84, 10, 10)
		lg.printf("Achievement: " .. toast.a[2], assets.font, 470, y + 2, 500, "center")
		lg.setColor(0.85, 0.88, 1)
		lg.printf(toast.a[3] .. "  (+ " .. achievements.PACK_NAMES[toast.a[6]] .. ")", assets.small_font, 470, y + 48, 500, "center")
		lg.setColor(1, 1, 1)
	end

	if settings.debug then
		lg.setColor(1, 0, 0)
		lg.printf(tostring(debug_text), assets.debug_font, 10, 70, reference_window_width)
		lg.setColor(1, 1, 1)
	end
	lg.scale(reference_window_width / lg.getWidth(), reference_window_height / lg.getHeight())
end
