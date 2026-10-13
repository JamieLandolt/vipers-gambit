local love = require("love")
local title = require("Title")
local play = require("Play")
local collection = require("Collection")

-- User settings, saved as key=value lines in settings.txt. The settings screen is built from
-- settings.items (Ui.lua makes the buttons, Render.lua draws the rows).
local settings = { volume = 1, mute = false, fullscreen = false, debug = false, speed = 2, confirm_reset = false, dragging = false }

local SPEEDS = { { "Slow", 1.2 }, { "Normal", 0.7 }, { "Fast", 0.3 } } -- seconds between opponent actions
local ROW, HEADING = 62, 46
-- Controls sit in a column on the right: x, width, height (slider uses the same x and a narrower width)
settings.panel = { x = 230, y = 90, w = 980, h = 720 }
settings.CX, settings.CW, settings.CH, settings.SW = 780, 300, 52, 240

local big_window = false

-- "Fullscreen" is the largest borderless window with the reference aspect ratio that fits the
-- desktop, so the 1440x872 scaling and the aspect lock keep working
local function set_big_window(big)
	big_window = big
	if big then
		local dw, dh = love.window.getDesktopDimensions()
		local w = math.floor(math.min(dw, dh * reference_window_width / reference_window_height))
		love.window.setMode(w, math.floor(w * reference_window_height / reference_window_width), { borderless = true, vsync = 0 })
	else
		love.window.setMode(reference_window_width, reference_window_height, { resizable = true, vsync = 0 })
	end
end

function settings.apply()
	love.audio.setVolume(settings.volume)
	audio = not settings.mute
	play.ai_delay = SPEEDS[settings.speed][2]
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
	{ heading = "Data" },
	{
		label = "Unlock all",
		text = function() return collection.unlock_all and "On" or "Off" end,
		click = collection.toggle_unlock_all,
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
