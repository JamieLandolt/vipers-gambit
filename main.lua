local love = require("love")
local lg = love.graphics
local la = love.audio
local assets = require("Assets")
local build_ui = require("Ui")
local play = require("Play")
local render = require("Render")

reference_window_width = 1440
reference_window_height = 872
time = 0

-- Shared state (global because Button, Avatar, Play and Render read it)
mouse = {}
chosen_avatar = "Jamie"
chosen_opponent = "Ice King"
scroll_offset_y = 0
count = 0
mouse_over_info = false
mouse_over_info_background = false
characters = { "Alem", "Gabe", "Jamie", "Darcy", "Josh", "Michael" }
played_cards = {}
card_hitboxes = {} -- x, y, width, height
player_hand = {}
opponent_hand = {}
held_card = nil
info_card = nil
-- Set by play.new_game: turn, health, max_health, max_venom, venom, winner
audio = true
unlocked = 1 -- highest level the player can pick, saved in progress.txt
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
	playing = {},
	paused = {},
	ended = {},
	info = {},
	universal = {},
}
game = {
	state = {
		menu = true,
		settings = false,
		level_select = false,
		character_select = false,
		collection = false,
		playing = false,
		paused = false,
		ended = false,
		info = false,
	},
}

local debug_text = "Debug Text"
local debugger_enabled = true
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

function toggle_audio()
	audio = not audio
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

	if game.state["playing"] then
		mouse_over_info = buttons.playing["Info"]:hover()
	end
end

function love.load()
	math.randomseed(os.time())
	mouse.x, mouse.y = love.mouse.getPosition()

	img_widths = assets.cards[1]:getWidth()
	img_heights = assets.cards[1]:getHeight()
	hover_sound = la.newSource("assets/audio/hover.mp3", "static")

	love.window.setMode(reference_window_width, reference_window_height, { resizable = true, vsync = 0 })
	unlocked = tonumber(love.filesystem.read("progress.txt") or "") or 1
	build_ui()
end

function love.update(dt)
	time = time + dt

	-- Keep the window at the reference aspect ratio
	local aspect_ratio = 1440 / 872
	if math.abs(w / h - aspect_ratio) > 0.008 then
		h = w / aspect_ratio
		love.window.setMode(w, h, { resizable = true })
	end

	w = lg.getWidth()
	h = lg.getHeight()

	handle_animations(dt)
	if game.state["playing"] then
		if turn == "Player" then
			-- Checks where to place a card if one has been let go since last update
			play.place_card()
		else
			play.opponent_turn(dt)
		end
	end
end

function love.mousepressed(x, y, button)
	if button ~= 1 then
		return
	end

	-- Check if button on screen is clicked
	local pressed = false
	for _, b in pairs(buttons[get_game_state()]) do
		if b:checkPressed(x, y) then
			pressed = true
		end
	end

	-- Check universal buttons only if a screen button wasn't pressed
	if not pressed then
		for _, b in pairs(buttons.universal) do
			b:checkPressed(x, y)
		end
	end

	if game.state["level_select"] then
		local level = render.level_at(x, y)
		if level and level <= unlocked then
			play.new_game(level)
			animation, animation_time = true, 0
			update_animation_screen("playing")
		end
	end

	-- Check if card is clicked with no card in hand
	if game.state["playing"] and turn == "Player" then
		for card, hitbox in pairs(card_hitboxes) do
			if play.is_hitbox(x, y, hitbox) then
				for i, c in pairs(player_hand) do
					if c == card then
						table.remove(player_hand, i)
					end
				end
				card_hitboxes[card] = nil
				held_card = card
			end
		end
	end
end

function love.wheelmoved(_, y)
	if scroll_offset_y + y < 0 then
		scroll_offset_y = scroll_offset_y + y * 2
	else
		scroll_offset_y = 0
	end
end

function love.draw()
	lg.scale(lg.getWidth() / reference_window_width)

	render[get_game_state()]()

	if debugger_enabled then
		lg.setColor(1, 0, 0)
		lg.printf(tostring(debug_text), assets.debug_font, 10, 70, reference_window_width)
		lg.setColor(1, 1, 1)
	end
	lg.scale(reference_window_width / lg.getWidth())
end
