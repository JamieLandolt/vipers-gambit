local love = require "love"
local lg = love.graphics
local borders = require("Borders")
local data = require("CardData")

function Card(card_path, card_width, card_height)
    return {
        card_object = lg.newImage("assets/Snake_Cards/" .. card_path),
        card_height = card_height,
        card_width = card_width,
        card_path = card_path,
        draw = function(self, x, y, rot, scale)
            scale = scale or 1
            lg.scale(scale)
            lg.rotate(rot)
            lg.setColor(1, 1, 1)
            lg.draw(self.card_object, x/scale, y/scale)
            borders.draw(data.get_stats(self).border, x/scale, y/scale, self.card_object:getWidth(), self.card_object:getHeight(), data.get_stats(self).rarity)
            lg.setColor(163/255, 15/255, 32/255)
            lg.scale(1/scale)
            lg.rotate(-rot)
        end
    }
end

return Card