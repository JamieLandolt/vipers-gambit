local love = require("love")
local lg = love.graphics

-- Buttons are snakeskin: dark green scales inside a gold rim, drawn by this shader over a 1x1 image
local pixel = lg.newImage(love.image.newImageData(1, 1))
local scales = lg.newShader([[
	uniform vec2 size;
	uniform float rim;
	uniform float radius;
	uniform vec3 body;
	uniform vec3 rim_colour;
	float box(vec2 p, vec2 half_size, float r) {
		vec2 q = abs(p) - half_size + r;
		return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	}
	vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
		vec2 p = uv * size;
		float d = box(p - size / 2.0, size / 2.0, radius);
		if (d > 0.0) return vec4(0.0);
		if (d > -rim) return vec4(rim_colour, 1.0);
		float row = floor(p.y / 7.0);
		vec2 f = vec2(fract(p.x / 14.0 + 0.5 * mod(row, 2.0)), fract(p.y / 7.0));
		float edge = smoothstep(0.38, 0.5, length(vec2(f.x - 0.5, (f.y - 1.0) * 0.8)));
		float shine = 0.12 * (1.0 - smoothstep(0.0, 0.6, length(vec2(f.x - 0.5, f.y - 0.35))));
		return vec4(body * (0.72 + 0.28 * (1.0 - edge)) + shine, 1.0);
	}
]])
local SKIN, SKIN_HOVER = { 0.13, 0.36, 0.2 }, { 0.22, 0.55, 0.25 }
local GOLD, LIME = { 0.82, 0.66, 0.25 }, { 0.62, 0.9, 0.25 }
local CREAM = { 0.98, 0.94, 0.7 }

-- Buttons with bound functions show the hover effect. Text and icon are centred in the button;
-- set top_text on a button to put its text at the top instead (for panels).
function Button(text, func, func_params, x, y, width, height, font, debugger, colour_variation, icon, icon_scale)
	-- Is the window position (in screen pixels) over the button?
	local function over(self, screen_x, screen_y)
		local rx, ry = screen_x * reference_window_width / lg.getWidth(), screen_y * reference_window_height / lg.getHeight()
		return rx > self.x and rx < self.x + self.width and ry > self.y and ry < self.y + self.height and self.func ~= nil
	end

	return {
		edge_buttons = { "Back", "Switch Background", "Hand" },
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
			local body = hovered and SKIN_HOVER or SKIN
			local rim = hovered and LIME or GOLD
			if colour_variation then
				local pulse = (math.sin(3 * time) + 1) / 2
				body = { body[1] + 0.1 * pulse, body[2] + 0.1 * pulse, body[3] + 0.05 * pulse }
			end
			scales:send("size", { self.width + outer * 2, self.height + outer * 2 })
			scales:send("rim", outer + inset)
			scales:send("radius", 12)
			scales:send("body", body)
			scales:send("rim_colour", rim)
			lg.setShader(scales)
			lg.setColor(1, 1, 1)
			lg.draw(pixel, self.x - outer, self.y - outer, 0, self.width + outer * 2, self.height + outer * 2)
			lg.setShader()

			lg.setColor(1, 1, 1)
			if self.icon then
				local scale = self.icon_scale
				local icon_x = self.x + (self.width - self.icon:getWidth() * scale) / 2
				local icon_y = self.y + (self.height - self.icon:getHeight() * scale) / 2
				lg.draw(self.icon, math.floor(icon_x), math.floor(icon_y), 0, scale)
			end

			if self.text == "Back" then -- every back button is a left arrow
				local cx, cy = self.x + self.width / 2, self.y + self.height / 2
				local arrow = { cx - 20, cy, cx - 4, cy - 15, cx - 4, cy - 6, cx + 20, cy - 6, cx + 20, cy + 6, cx - 4, cy + 6, cx - 4, cy + 15 }
				lg.setColor(0, 0, 0, 0.5)
				lg.translate(2, 3)
				lg.polygon("fill", arrow)
				lg.translate(-2, -3)
				lg.setColor(hovered and { 1, 1, 1 } or CREAM)
				lg.polygon("fill", arrow)
			elseif self.text ~= "" then
				local text_x = self.x + (self.width - self.font:getWidth(self.text)) / 2
				local text_y = self.top_text and self.y + 10 or self.y + (self.height - self.font:getHeight()) / 2
				lg.setColor(0, 0, 0, 0.5)
				lg.print(self.text, self.font, math.floor(text_x) + 2, math.floor(text_y) + 3)
				lg.setColor(hovered and { 1, 1, 1 } or CREAM)
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
