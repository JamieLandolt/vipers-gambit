local love = require("love")
local lg = love.graphics

local function numbered(prefix, suffix, first, last)
	local images = {}
	for i = first, last do
		images[#images + 1] = lg.newImage("assets/Sprites/" .. prefix .. i .. suffix .. ".png")
	end
	return images
end

local assets = {
	font = lg.newFont("assets/Jersey15-Regular.ttf", 50),
	small_font = lg.newFont("assets/Jersey15-Regular.ttf", 28),
	card_name_font = lg.newFont("assets/Jersey15-Regular.ttf", 24),
	card_text_font = lg.newFont("assets/Jersey15-Regular.ttf", 17),
	debug_font = lg.newFont("assets/Jersey15-Regular.ttf", 20),
	venom = numbered("Venom_", "", 0, 10),
	background = lg.newImage("assets/backgrounds/SnakeBackground.png"),
	level_snake = lg.newImage("assets/backgrounds/LevelSnake.png"),
	lane_tiles = lg.newImage("assets/Sprites/Lane_Tiles.png"),
	playing_field = lg.newImage("assets/Sprites/Playing_field.png"),
	avatars = {},
	icons = {
		audio_enabled = lg.newImage("assets/icons/audio_enabled.png"),
		audio_disabled = lg.newImage("assets/icons/audio_disabled.png"),
	},
	cards = {},
	card_names = {}, -- same order as cards
	card_by_name = {},
}

for _, c in ipairs(require("Charmers").list) do
	assets.avatars[c.name] = lg.newImage(require("Charmers").file(c))
end

-- Each campaign opponent has its own portrait
for _, o in ipairs(require("Opponents")) do
	assets.avatars[o.name] = assets.avatars[o.name] or lg.newImage("assets/" .. o.portrait)
end

for _, file in ipairs(love.filesystem.getDirectoryItems("assets/Snake_Cards")) do
	if file:match("%.png$") then
		local image, name = lg.newImage("assets/Snake_Cards/" .. file), file:sub(1, -5)
		table.insert(assets.cards, image)
		table.insert(assets.card_names, name)
		assets.card_by_name[name] = image
	end
end

return assets
