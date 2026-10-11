local love = require("love")
local lg = love.graphics
local scandir = require("scandir")

local function numbered(prefix, suffix, first, last)
	local images = {}
	for i = first, last do
		images[#images + 1] = lg.newImage("assets/Sprites/" .. prefix .. i .. suffix .. ".png")
	end
	return images
end

local assets = {
	font = lg.newFont("assets/Jersey15-Regular.ttf", 50),
	debug_font = lg.newFont("assets/Jersey15-Regular.ttf", 20),
	backgrounds = {
		lg.newImage("assets/Sprites/DefenseBackground.png"),
		lg.newImage("assets/Sprites/AttackBackground.png"),
	},
	defenses = numbered("", "Defense", 0, 9),
	attacks = numbered("", "Attack", 0, 9),
	venom = numbered("Venom_", "", 0, 10),
	background = lg.newImage("assets/backgrounds/SnakeBackground.png"),
	level_snake = lg.newImage("assets/backgrounds/LevelSnake.png"),
	playing_field = lg.newImage("assets/Sprites/Playing_field.png"),
	avatars = {},
	icons = {
		audio_enabled = lg.newImage("assets/icons/audio_enabled.png"),
		audio_disabled = lg.newImage("assets/icons/audio_disabled.png"),
	},
	cards = {},
}

for _, name in ipairs({ "gabe", "jamie", "alem", "josh", "michael", "darcy" }) do
	assets.avatars[name] = lg.newImage("assets/characters/" .. name .. ".jpg")
end

-- scandir lists ".", ".." and ".DS_Store" first
for i, file in pairs(scandir("/Users/jameslandolt/IdeaProjects/SnakeGame/assets/Snake_Cards")) do
	if i > 3 then
		assets.cards[i - 3] = lg.newImage("assets/Snake_Cards/" .. file)
	end
end

return assets
