local love = require("love")
local lg = love.graphics

local BLUE = { 15 / 255, 140 / 255, 220 / 255 }

-- Buttons with bound functions show the hover effect. Text and icon are centred in the button;
-- set top_text on a button to put its text at the top instead (for panels).
function Button(text, func, func_params, x, y, width, height, font, debugger, colour_variation, icon, icon_scale)
	local function colour_scaling(val)
		if colour_variation then
			return val + (25 * (math.sin(3 * time) + 1) / 255)
		end
		return val
	end

	-- Is the window position (in screen pixels) over the button?
	local function over(self, screen_x, screen_y)
		local rx, ry = screen_x * reference_window_width / lg.getWidth(), screen_y * reference_window_height / lg.getHeight()
		return rx > self.x and rx < self.x + self.width and ry > self.y and ry < self.y + self.height and self.func ~= nil
	end

	return {
		edge_buttons = { "Play", "Back", "Switch Background", "Hand" },
		icon = icon,
		icon_scale = icon_scale,
		font = font,
		text = text or "No Text",
		func = func,
		func_params = func_params,
		x = x,
		y = y,
		width = width,
		height = height,
		border_radius = 5,
		debugger = debugger,

		update_text = function(self, new_text)
			self.text = new_text
		end,

		hover = function(self)
			return over(self, mouse.x, mouse.y)
		end,

		draw = function(self)
			local green = { colour_scaling(116 / 255), colour_scaling(182 / 255), colour_scaling(82 / 255) }
			local purple = { colour_scaling(101 / 255), colour_scaling(52 / 255), colour_scaling(150 / 255) }
			local hovered = self:hover()

			-- Border grows outwards by `outer`, the fill by `-inset` (an inset > 0 shrinks it).
			-- Hovering pops the button during the click animation's middle third.
			local outer, inset = 5, 0
			if hovered then
				local mid_animation = animation_length < animation_time and animation_time < animation_length * 2
				if contains(self.edge_buttons, self.text) then
					outer, inset = mid_animation and 0 or 5, mid_animation and 5 or 0
				else
					outer, inset = mid_animation and 5 or 13, mid_animation and 0 or -5
				end
			end
			local r = self.border_radius
			lg.setColor(BLUE)
			lg.rectangle("fill", self.x - outer, self.y - outer, self.width + outer * 2, self.height + outer * 2, r, r)
			lg.setColor(hovered and green or purple)
			lg.rectangle("fill", self.x + inset, self.y + inset, self.width - inset * 2, self.height - inset * 2, r, r)

			lg.setColor(1, 1, 1)
			if self.icon then
				local scale = self.icon_scale
				local icon_x = self.x + (self.width - self.icon:getWidth() * scale) / 2
				local icon_y = self.y + (self.height - self.icon:getHeight() * scale) / 2
				lg.draw(self.icon, math.floor(icon_x), math.floor(icon_y), 0, scale)
			end

			if self.text ~= "" then
				local text_x = self.x + (self.width - self.font:getWidth(self.text)) / 2
				local text_y = self.top_text and self.y + 10 or self.y + (self.height - self.font:getHeight()) / 2
				lg.setColor(hovered and purple or green)
				lg.print(self.text, self.font, math.floor(text_x), math.floor(text_y))
			end
		end,

		checkPressed = function(self, mouse_x, mouse_y)
			if not over(self, mouse_x, mouse_y) then
				return false
			end
			play_sound(hover_sound)
			animation = true
			animation_time = 0
			if self.func_params then
				self.func(self.func_params)
			else
				self.func()
			end
			return true
		end,
	}
end

return Button
