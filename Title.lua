local love = require("love")
local lg = love.graphics

local title = {}

title.MENU_DROP = 90

local PX, TOP, STAGGER, DROP_TIME = 13, 110, 0.1, 0.7
local TEXT = "VIPER'S GAMBIT"

local GLYPHS = {
	V = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
	I = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
	P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
	E = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
	R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
	["'"] = { "11", "11", "10" },
	S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
	G = { "01110", "10001", "10000", "10111", "10001", "10001", "01110" },
	A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
	M = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" },
	B = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
	T = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
}

local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }
local DROP = { { 0.4, 0.4 } }

-- fill gives a letter cell's colour; snake is the S; eyes sit on a cell, tongues flick out of a
-- cell in a direction (col, row, dx, dy). The last style is the default.
title.styles = {
	{
		name = "Classic",
		fill = function(_, r)
			local s = r > 4 and 0.82 or 1
			return 0.95 * s, 0.95 * s, 0.8 * s
		end,
		snake = { 0.45, 0.71, 0.32 },
		shadow = { 0.1, 0.08, 0.24, 0.8 },
		offsets = DROP,
		eye = { 1, 0.84, 0.25 },
		tongue = { 0.86, 0.16, 0.24 },
		eyes = { P = { 2, 1 }, G = { 2, 2 }, S = { 3, 0 } },
		tongues = { V = { 2, 7, 0, 1 }, T = { 2, 7, 0, 1 }, S = { 5, 0, 1, 0 } },
	},
	{
		name = "Venom",
		fill = function(c, r)
			local s = (c + r) % 2 == 0 and 1 or 0.78
			return 0.42 * s, 0.82 * s, 0.25 * s
		end,
		snake = { 0.9, 0.7, 0.25 },
		shadow = { 0.02, 0.05, 0.02, 1 },
		offsets = SIDES,
		eye = { 1, 0.95, 0.2 },
		tongue = { 0.95, 0.1, 0.2 },
		eyes = { P = { 2, 1 }, G = { 2, 2 }, S = { 3, 0 }, A = { 2, 4 }, M = { 2, 1 }, R = { 2, 1 }, E = { 2, 1 }, B = { 2, 1 } },
		tongues = { V = { 2, 7, 0, 1 }, T = { 2, 7, 0, 1 }, S = { 5, 0, 1, 0 }, I = { 2, 7, 0, 1 } },
	},
	{
		name = "Neon",
		gap = 3,
		fill = function(_, _, u)
			return 0.75 - 0.5 * u, 0.3 + 0.6 * u, 0.95
		end,
		snake = { 0.6, 1, 0.3 },
		shadow = { 1, 0.2, 0.8, 0.22 },
		offsets = SIDES,
		eye = { 0.6, 1, 0.3 },
		tongue = { 1, 0.3, 0.75 },
		eyes = { P = { 2, 1 }, G = { 2, 2 }, S = { 3, 0 } },
		tongues = { V = { 2, 7, 0, 1 }, T = { 2, 7, 0, 1 }, S = { 5, 0, 1, 0 } },
	},
	{
		name = "Gold",
		fill = function(_, r)
			local k = (r - 1) / 6
			return 1, 0.92 - 0.45 * k, 0.45 - 0.35 * k
		end,
		snake = { 0.25, 0.65, 0.3 },
		shadow = { 0.35, 0.05, 0.08, 1 },
		offsets = { { 0.5, 0.5 }, { 0.25, 0.25 } },
		eye = { 0.3, 0.9, 0.35 },
		tongue = { 0.85, 0.1, 0.1 },
		eyes = { P = { 2, 1 }, G = { 2, 2 }, M = { 2, 1 }, S = { 3, 0 } },
		tongues = { V = { 2, 7, 0, 1 }, E = { 2, 7, 0, 1 }, T = { 2, 7, 0, 1 }, S = { 5, 0, 1, 0 } },
	},
	{
		name = "Frost",
		fill = function(_, r)
			local k = (r - 1) / 6
			return 0.95 - 0.5 * k, 0.98 - 0.25 * k, 1
		end,
		snake = { 0.85, 0.95, 1 },
		shadow = { 0.05, 0.12, 0.4, 1 },
		offsets = { { 0.4, 0.4 }, { 0.2, 0.6 } },
		eye = { 0.95, 0.15, 0.2 },
		tongue = { 1, 0.55, 0.8 },
		eyes = { P = { 2, 1 }, G = { 2, 2 }, S = { 3, 0 }, B = { 2, 1 } },
		tongues = { V = { 2, 7, 0, 1 }, T = { 2, 7, 0, 1 }, S = { 5, 0, 1, 0 }, I = { 2, 7, 0, 1 } },
	},
	{
		name = "Viper",
		fill = function(_, r)
			local s = r > 4 and 0.8 or 1
			return 0.5 * s, 0.85 * s, 0.28 * s
		end,
		snake = { 0.1, 0.42, 0.22 },
		shadow = { 0.04, 0.12, 0.08, 1 },
		offsets = { { 0.4, 0.4 }, { 0.2, 0.2 } },
		eye = { 1, 0.84, 0.25 },
		tongue = { 0.9, 0.12, 0.22 },
		eyes = { P = { 2, 1 }, G = { 2, 2 }, S = { 3, 0 } },
		tongues = { V = { 2, 7, 0, 1 }, T = { 2, 7, 0, 1 }, S = { 5, 0, 1, 0 } },
	},
}
title.style = #title.styles

function title.next_style()
	title.style = title.style % #title.styles + 1
	return title.styles[title.style].name
end

local function cell(c, r, x, y, inset)
	inset = inset or 0
	lg.rectangle("fill", x + c * PX + inset, y + r * PX + inset, PX - inset * 2, PX - inset * 2)
end

local function eye(style, c, r, x, y)
	lg.setColor(style.eye)
	cell(c, r, x, y)
	lg.setColor(0.05, 0.03, 0.1)
	lg.rectangle("fill", x + c * PX + PX * 0.375, y + r * PX, PX * 0.25, PX)
end

local function tongue(style, c, r, dx, dy, x, y, length)
	lg.setColor(style.tongue)
	for k = 0, length - 1 do
		cell(c + dx * k, r + dy * k, x, y)
	end
	local fc, fr = c + dx * length, r + dy * length
	cell(fc - dy, fr + dx, x, y)
	cell(fc + dy, fr - dx, x, y)
end

local function letter(style, ch, rows, x, y, alpha, t, index)
	local gap = style.gap or 0
	local u = index / #TEXT
	for pass = 0, #style.offsets do
		for r, row in ipairs(rows) do
			for c = 1, #row do
				if row:sub(c, c) == "1" then
					if pass < #style.offsets then
						local o = style.offsets[pass + 1]
						local sh = style.shadow
						lg.setColor(sh[1], sh[2], sh[3], (sh[4] or 1) * alpha)
						cell(c - 1 + o[1], r - 1 + o[2], x, y, gap)
					else
						if ch == "S" then
							local s = (c + r) % 2 == 0 and 1 or 0.8
							lg.setColor(style.snake[1] * s, style.snake[2] * s, style.snake[3] * s, alpha)
						else
							local cr, cg, cb = style.fill(c, r, u)
							lg.setColor(cr, cg, cb, alpha)
						end
						cell(c - 1, r - 1, x, y, gap)
					end
				end
			end
		end
	end
	if style.eyes[ch] then
		eye(style, style.eyes[ch][1], style.eyes[ch][2], x, y)
	end
	if style.tongues[ch] then
		local tg = style.tongues[ch]
		tongue(style, tg[1], tg[2], tg[3], tg[4], x, y, math.sin(t * 7 + index) > 0 and 2 or 1)
	end
end

local function ease_out_back(p)
	return 1 + 2.7 * (p - 1) ^ 3 + 1.7 * (p - 1) ^ 2
end

function title.draw(t)
	local total = 0
	for ch in TEXT:gmatch(".") do
		total = total + (ch == " " and 4 or #GLYPHS[ch][1] + 1) * PX
	end
	local x = (reference_window_width - total) / 2
	for i = 1, #TEXT do
		local ch = TEXT:sub(i, i)
		if ch == " " then
			x = x + 4 * PX
		else
			local rows = GLYPHS[ch]
			local p = math.max(0, math.min(1, (t - (i - 1) * STAGGER) / DROP_TIME))
			if p > 0 then
				letter(title.styles[title.style], ch, rows, x, TOP - (1 - ease_out_back(p)) * 220, math.min(1, p * 4), t, i)
			end
			x = x + (#rows[1] + 1) * PX
		end
	end
	lg.setColor(1, 1, 1)
end

return title
