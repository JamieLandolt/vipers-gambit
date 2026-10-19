local love = require("love")

-- Little synthesised sound effects (no audio files needed); sources are cloned so they can overlap
local sounds = {}
local RATE = 22050

-- Notes are { start_freq, end_freq, seconds, volume, noise_mix }, played one after another
local function make(notes)
	local total = 0
	for _, n in ipairs(notes) do
		total = total + math.floor(n[3] * RATE)
	end
	local data, i = love.sound.newSoundData(total, RATE, 16, 1), 0
	for _, n in ipairs(notes) do
		local len, phase = math.floor(n[3] * RATE), 0
		for s = 0, len - 1 do
			local p = s / len
			phase = phase + (n[1] + (n[2] - n[1]) * p) / RATE
			local tone = math.sin(phase * 6.2832)
			data:setSample(i, (tone * (1 - (n[5] or 0)) + (math.random() * 2 - 1) * (n[5] or 0)) * n[4] * (1 - p) ^ 1.5)
			i = i + 1
		end
	end
	return love.audio.newSource(data)
end

local builders = {
	hit = function() return make({ { 220, 70, 0.12, 0.5, 0.5 } }) end,
	kill = function() return make({ { 300, 60, 0.3, 0.55, 0.6 } }) end,
	spell = function() return make({ { 400, 1200, 0.35, 0.35, 0.05 } }) end,
	brew = function() return make({ { 300, 500, 0.08, 0.3 }, { 450, 700, 0.08, 0.3 }, { 350, 600, 0.1, 0.3 } }) end,
	achievement = function() return make({ { 523, 523, 0.1, 0.4 }, { 659, 659, 0.1, 0.4 }, { 784, 784, 0.1, 0.4 }, { 1047, 1047, 0.3, 0.4 } }) end,
	rumble = function() return make({ { 50, 110, 1.4, 0.5, 0.35 } }) end,
	burst = function() return make({ { 500, 80, 0.5, 0.6, 0.7 } }) end,
	summon = function() return make({ { 200, 900, 0.9, 0.45, 0.05 } }) end,
	hint = function() return make({ { 660, 660, 0.08, 0.3 }, { 880, 880, 0.12, 0.3 } }) end,
	heal = function() return make({ { 523, 523, 0.07, 0.3 }, { 659, 659, 0.07, 0.3 }, { 880, 880, 0.2, 0.3 } }) end, -- a soft rising chime
	buff = function() return make({ { 300, 700, 0.1, 0.35, 0.05 }, { 700, 1100, 0.18, 0.3 } }) end, -- a sharp power-up
	shield = function() return make({ { 900, 650, 0.1, 0.3, 0.15 }, { 1300, 900, 0.18, 0.25, 0.1 } }) end, -- a metal ring
	block = function() return make({ { 1300, 350, 0.1, 0.5, 0.45 }, { 900, 300, 0.2, 0.4, 0.2 } }) end, -- a hard clang
	poison = function() return make({ { 420, 160, 0.22, 0.35, 0.12 }, { 300, 120, 0.2, 0.3, 0.2 } }) end, -- a wet bubbling drop
	freeze = function() return make({ { 1500, 2300, 0.1, 0.22 }, { 1900, 1200, 0.25, 0.22, 0.05 } }) end, -- glassy crackle
}
for rarity = 1, 5 do -- a rising arpeggio, one note longer for each rarity
	builders["reveal" .. rarity] = function()
		local notes = {}
		for k = 1, rarity do
			notes[k] = { 392 * 2 ^ ((k - 1) * 4 / 12), 392 * 2 ^ ((k - 1) * 4 / 12), 0.12 + (k == rarity and 0.2 or 0), 0.4 }
		end
		return make(notes)
	end
end

function sounds.play(name)
	if not audio then
		return
	end
	sounds[name .. "_src"] = sounds[name .. "_src"] or builders[name]()
	love.audio.play(sounds[name .. "_src"]:clone())
end

return sounds
