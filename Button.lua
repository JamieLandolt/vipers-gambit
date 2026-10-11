local love = require("love")
local la = love.audio
local lg = love.graphics

-- Buttons with bound functions show the hover effect
function Button(
	text,
	func,
	func_params,
	x,
	y,
	width,
	height,
	font,
	text_offset_x,
	text_offset_y,
	debugger,
	colour_variation,
	icon,
	icon_scale,
	icon_offset_x,
	icon_offset_y
)
	local function colour_scaling(val)
		if colour_variation then
			return val + (25 * (math.sin(3 * time) + 1) / 255)
		else
			return val
		end
	end

	return {
		edge_buttons = { "Play", "Back", "Switch Background", "Hand" },
		icon = icon,
		icon_scale = icon_scale,
		icon_offset_x = icon_offset_x,
		icon_offset_y = icon_offset_y,
		font = font,
		text = text or "No Text",
		func = func,
		func_params = func_params,
		text_offset_x = text_offset_x,
		text_offset_y = text_offset_y,
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
			if
				mouse.x * (reference_window_width / lg.getWidth()) > self.x
				and mouse.x * (reference_window_width / lg.getWidth()) < self.x + self.width
				and mouse.y * (reference_window_height / lg.getHeight()) > self.y
				and mouse.y * (reference_window_height / lg.getHeight()) < self.y + self.height
				and self.func
			then
				return true
			end
			return false
		end,

		draw = function(self, scale)
			local blue = { 15 / 255, 140 / 255, 220 / 255 }
			local green = { colour_scaling(116 / 255), colour_scaling(182 / 255), colour_scaling(82 / 255) }
			local purple = { colour_scaling(101 / 255), colour_scaling(52 / 255), colour_scaling(150 / 255) }

			local g1, g2, g3 = green[1], green[2], green[3]
			local b1, b2, b3 = blue[1], blue[2], blue[3]
			local p1, p2, p3 = purple[1], purple[2], purple[3]
			-- Outer rectangle
			love.graphics.setColor(b1, b2, b3)
			if self:hover() then
				if contains(self.edge_buttons, self.text) then
					if animation_length < animation_time * 1 and animation_time < animation_length * 2 then
						love.graphics.rectangle(
							"fill",
							self.x,
							self.y,
							self.width,
							self.height,
							self.border_radius,
							self.border_radius
						)
					else
						love.graphics.rectangle(
							"fill",
							self.x - 5,
							self.y - 5,
							self.width + 10,
							self.height + 10,
							self.border_radius,
							self.border_radius
						)
					end
				else
					if animation_length < animation_time * 1 and animation_time < animation_length * 2 then
						love.graphics.rectangle(
							"fill",
							self.x - 5,
							self.y - 5,
							self.width + 10,
							self.height + 10,
							self.border_radius,
							self.border_radius
						)
					else
						love.graphics.rectangle(
							"fill",
							self.x - 13,
							self.y - 13,
							self.width + 26,
							self.height + 26,
							self.border_radius,
							self.border_radius
						)
					end
				end
			else
				love.graphics.rectangle(
					"fill",
					self.x - 5,
					self.y - 5,
					self.width + 10,
					self.height + 10,
					self.border_radius,
					self.border_radius
				)
			end

			-- Inner rectangle

			if self:hover() then
				love.graphics.setColor(g1, g2, g3)
				if contains(self.edge_buttons, self.text) then
					if animation_length < animation_time * 1 and animation_time < animation_length * 2 then
						love.graphics.rectangle(
							"fill",
							self.x + 5,
							self.y + 5,
							self.width - 10,
							self.height - 10,
							self.border_radius,
							self.border_radius
						)
					else
						love.graphics.rectangle(
							"fill",
							self.x,
							self.y,
							self.width,
							self.height,
							self.border_radius,
							self.border_radius
						)
					end
				else
					if animation_length < animation_time * 1 and animation_time < animation_length * 2 then
						love.graphics.rectangle(
							"fill",
							self.x,
							self.y,
							self.width,
							self.height,
							self.border_radius,
							self.border_radius
						)
					else
						love.graphics.rectangle(
							"fill",
							self.x - 5,
							self.y - 5,
							self.width + 10,
							self.height + 10,
							self.border_radius,
							self.border_radius
						)
					end
				end
			else
				love.graphics.setColor(p1, p2, p3)
				love.graphics.rectangle(
					"fill",
					self.x,
					self.y,
					self.width,
					self.height,
					self.border_radius,
					self.border_radius
				)
			end
			if self.icon then
				love.graphics.scale(self.icon_scale)
				love.graphics.draw(
					self.icon,
					self.x * 1 / self.icon_scale + self.text_offset_x + self.icon_offset_x,
					self.y * 1 / self.icon_scale + self.icon_offset_y
				)
				love.graphics.scale(1 / self.icon_scale)
			end
			if self.text then
				if self:hover() then
					love.graphics.setColor(p1, p2, p3)
				else
					love.graphics.setColor(g1, g2, g3)
				end
				love.graphics.print(self.text, self.font, self.x + self.text_offset_x, self.y + self.text_offset_y)
			end
		end,

		checkPressed = function(self, mouse_x, mouse_y)
			if
				mouse_x * (reference_window_width / lg.getWidth()) > self.x
				and mouse_x * (reference_window_width / lg.getWidth()) < self.x + self.width
				and mouse_y * (reference_window_height / lg.getHeight()) > self.y
				and mouse_y * (reference_window_height / lg.getHeight()) < self.y + self.height
				and self.func
			then
				play_sound(hover_sound)
				animation = true
				animation_time = 0

				if self.func_params then
					self.func(self.func_params)
					return true
				else
					self.func()
					return true
				end
			end
			return false
		end,
	}
end

return Button
