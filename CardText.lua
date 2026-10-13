local love = require("love")
local lg = love.graphics

-- The name and ability written in the text panel of a card, in card-image units (165 x 320, panel from y = 190)
local cardtext = {}

local MAX_LINES = 3

function cardtext.draw(name, x, y)
	local assets = require("Assets")
	local ability = require("CardData").stats_by_name[name].ability
	lg.setColor(0, 0, 0, 0.45)
	lg.rectangle("fill", x + 11, y + 192, 143, 82, 4, 4)
	lg.setColor(1, 1, 1)
	local title = name:gsub("_", " ")
	local shrink = math.min(1, 139 / assets.card_name_font:getWidth(title)) -- long names are drawn smaller to stay on one line
	lg.print(title, assets.card_name_font, x + 82.5, y + 193 + (1 - shrink) * 12, 0, shrink, shrink, assets.card_name_font:getWidth(title) / 2, 0)
	local _, lines = assets.card_text_font:getWrap(ability, 139)
	if #lines > MAX_LINES then
		lines = { lines[1], lines[2], lines[3] .. "..." }
	end
	lg.setColor(0.9, 0.95, 1)
	for i = 1, math.min(#lines, MAX_LINES) do
		lg.printf(lines[i], assets.card_text_font, x + 13, y + 219 + (i - 1) * 17, 139, "center")
	end
	lg.setColor(1, 1, 1)
end

return cardtext
