local love = require("love")
local title = require("Title")
local play = require("Play")
local collection = require("Collection")

-- User settings, saved as key=value lines in settings.txt. The settings screen is built from
-- settings.items (Ui.lua makes the buttons, Render.lua draws the rows).
local settings = { volume = 1, mute = false, fullscreen = false, debug = false, speed = 2, confirm_reset = false, dragging = false, turn_log = false, reduce_motion = false, infinite_venom = false, zoom_snakes = true }

local SPEEDS = { { "Slow", 1.2 }, { "Normal", 0.7 }, { "Fast", 0.3 } } -- seconds between opponent actions
local ROW, HEADING = 48, 40
-- Controls sit in a column on the right: x, width, height (slider uses the same x and a narrower width)
settings.panel = { x = 230, y = 70, w = 980, h = 780 }
settings.CX, settings.CW, settings.CH, settings.SW = 780, 300, 42, 240

local big_window = false

-- "Fullscreen" is a borderless window as big as the desktop; the game is drawn stretched to fill it (see love.draw),
-- so there are no gaps at the top and bottom
local function set_big_window(big)
	big_window = big
	if big then
		local dw, dh = love.window.getDesktopDimensions()
		love.window.setMode(dw, dh, { borderless = true, vsync = 0 })
	else
		love.window.setMode(reference_window_width, reference_window_height, { resizable = true, vsync = 0 })
	end
end

function settings.apply()
	love.audio.setVolume(settings.volume)
	audio = not settings.mute
	reduce_motion = settings.reduce_motion
	play.ai_delay = SPEEDS[settings.speed][2]
	play.zoom_snakes = settings.zoom_snakes
	if settings.fullscreen ~= big_window then
		set_big_window(settings.fullscreen)
	end
end

function settings.save()
	local lines = {
		"volume=" .. string.format("%.2f", settings.volume),
		"mute=" .. (settings.mute and 1 or 0),
		"fullscreen=" .. (settings.fullscreen and 1 or 0),
		"debug=" .. (settings.debug and 1 or 0),
		"turn_log=" .. (settings.turn_log and 1 or 0),
		"reduce_motion=" .. (settings.reduce_motion and 1 or 0),
		"infinite_venom=" .. (settings.infinite_venom and 1 or 0),
		"zoom_snakes=" .. (settings.zoom_snakes and 1 or 0),
		"speed=" .. settings.speed,
		"title=" .. title.styles[title.style].name,
	}
	love.filesystem.write("settings.txt", table.concat(lines, "\n"))
end

function settings.load()
	local t = {}
	for k, v in (love.filesystem.read("settings.txt") or ""):gmatch("(%w+)=([^\n]+)") do
		t[k] = v
	end
	settings.volume = math.min(math.max(tonumber(t.volume) or 1, 0), 1)
	settings.mute, settings.fullscreen, settings.debug = t.mute == "1", t.fullscreen == "1", t.debug == "1"
	settings.turn_log, settings.reduce_motion, settings.infinite_venom = t.turn_log == "1", t.reduce_motion == "1", t.infinite_venom == "1"
	settings.zoom_snakes = t.zoom_snakes ~= "0"
	settings.speed = SPEEDS[tonumber(t.speed)] and tonumber(t.speed) or 2
	for i, style in ipairs(title.styles) do
		if style.name == t.title then
			title.style = i
		end
	end
	settings.apply()
end

local function flag(label, key)
	return {
		label = label,
		text = function() return settings[key] and "On" or "Off" end,
		click = function() settings[key] = not settings[key] end,
	}
end

local mute = flag("Mute", "mute")
mute.icon = true

-- Rows top to bottom: a heading, or a label with a slider or a button (text() shows its state, click() changes it)
settings.items = {
	{ heading = "Sound" },
	{ label = "Master volume", slider = true },
	mute,
	{ heading = "Display" },
	flag("Fullscreen", "fullscreen"),
	flag("Debug text", "debug"),
	flag("Reduce motion", "reduce_motion"),
	{
		label = "Title style",
		text = function() return title.styles[title.style].name end,
		click = title.next_style,
	},
	{ heading = "Gameplay" },
	{
		label = "Opponent speed",
		text = function() return SPEEDS[settings.speed][1] end,
		click = function() settings.speed = settings.speed % #SPEEDS + 1 end,
	},
	flag("Turn log", "turn_log"),
	flag("Infinite venom (testing)", "infinite_venom"),
	{ heading = "Data" },
	{
		label = "Unlock all",
		text = function() return collection.unlock_all and "On" or "Off" end,
		click = collection.toggle_unlock_all,
	},
	{
		label = "Achievements",
		text = function() return require("Achievements").count() .. "/" .. #require("Achievements").list end,
		click = function() achievements_return = "settings"; update_animation_screen("achievements") end,
	},
	{ label = "Progress", text = function() return "Reset" end, click = function() settings.confirm_reset = true end },
}

local y = settings.panel.y + 20
for _, item in ipairs(settings.items) do
	item.y = y
	y = y + (item.heading and HEADING or ROW)
	if item.slider then
		settings.slider_y = item.y + ROW / 2
	end
end

function settings.click(item)
	item.click()
	settings.apply()
	settings.save()
end

function settings.reset_progress()
	collection.reset()
	settings.confirm_reset = false
end

local function set_volume_from(screen_x)
	local rx = screen_x * reference_window_width / love.graphics.getWidth()
	settings.volume = math.floor(math.min(math.max((rx - settings.CX) / settings.SW, 0), 1) * 100 + 0.5) / 100
	love.audio.setVolume(settings.volume)
end

-- Starts a slider drag if the click (window pixels) is on the slider row; returns true if so
function settings.press(x, y)
	local rx, ry = x * reference_window_width / love.graphics.getWidth(), y * reference_window_height / love.graphics.getHeight()
	if rx >= settings.CX - 20 and rx <= settings.CX + settings.SW + 20 and math.abs(ry - settings.slider_y) <= ROW / 2 then
		settings.dragging = true
		set_volume_from(x)
		return true
	end
	return false
end

function settings.update()
	if not settings.dragging then
		return
	end
	if love.mouse.isDown(1) then
		set_volume_from(love.mouse.getX())
	else
		settings.dragging = false
		settings.save()
		play_sound(hover_sound)
	end
end

return settings
