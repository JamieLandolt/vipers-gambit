local love = require("love")
local lg = love.graphics

-- The name written in the text panel of a card, in card-image units (165 x 320, panel from y = 190).
-- Abilities are not printed on the card: they are on the info page and the hover tooltip.
local cardtext = {}

function cardtext.draw(name, x, y)
	local assets = require("Assets")
	lg.setColor(0, 0, 0, 0.45)
	lg.rectangle("fill", x + 11, y + 192, 143, 30, 4, 4)
	lg.setColor(1, 1, 1)
	local title = name:gsub("_", " ")
	local shrink = math.min(1, 139 / assets.card_name_font:getWidth(title)) -- long names are drawn smaller to stay on one line
	lg.print(title, assets.card_name_font, x + 82.5, y + 195 + (1 - shrink) * 12, 0, shrink, shrink, assets.card_name_font:getWidth(title) / 2, 0)
	lg.setColor(1, 1, 1)
end

return cardtext
