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
	rumble = function() return make({ { 50, 110, 1.4, 0.5, 0.35 } }) end,
	burst = function() return make({ { 500, 80, 0.5, 0.6, 0.7 } }) end,
	summon = function() return make({ { 200, 900, 0.9, 0.45, 0.05 } }) end,
	hint = function() return make({ { 660, 660, 0.08, 0.3 }, { 880, 880, 0.12, 0.3 } }) end,
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
