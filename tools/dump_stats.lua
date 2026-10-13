-- Prints every snake's final stats (after the health scale and attack floor in CardData.lua) as JSON for tools/redraw_stats.py
package.path = "./?.lua;" .. package.path
package.preload["love"] = function() return { graphics = {}, mouse = {}, filesystem = { write = function() end, getInfo = function() end } } end
package.preload["Effects"] = function() return { add = function() end, clear = function() end } end
local data = require("CardData")
local out = {}
for _, name in ipairs(data.deck) do
	local s = data.stats_by_name[name]
	out[#out + 1] = ('"%s":[%d,%d,%d,%d,"%s"]'):format(name, s.cost, s.attack, s.defense, s.rarity, s.kind)
end
print("{" .. table.concat(out, ",") .. "}")
