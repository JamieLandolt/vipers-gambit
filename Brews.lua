-- Brews and spells: two more kinds of card that share the deck, collection, packs and sacrificing with the snakes.
--   Brew:  drag it onto one of your snakes to make it drink; the effect lasts as long as the snake lives
--          (card.brew holds the effect id) and shows as an aura on the snake (or its lane) -- see Render.brew_aura.
--   Spell: drag it anywhere onto the field; it takes effect at once and the card is spent.
-- Stats (cost, tier) come from this list; tools/draw_brews.py draws the card art for it.
local brews = {}

local function foe(side)
	return side == "Player" and "Opponent" or "Player"
end

-- Occupied slots of a side as a list of { slot, card }
local function snakes(side)
	local found = {}
	for slot = side == "Player" and 5 or 1, side == "Player" and 8 or 4 do
		if played_cards[slot] then
			table.insert(found, { slot, played_cards[slot] })
		end
	end
	return found
end

local function defense(card)
	return require("CardData").get_stats(card).defense
end

local function heal(play, slot, card, amount)
	local hp = card.hp or defense(card)
	if hp < defense(card) then
		card.hp = math.min(hp + amount, defense(card))
		play.float(slot, "+" .. (card.hp - hp) .. " hp")
		return true
	end
end
brews.heal = heal

local function attack(card)
	return require("CardData").get_stats(card).attack + (card.bonus or 0)
end

-- The enemy snake with the most attack, or with the fewest hit points (as { slot, card })
local function strongest(side)
	local best
	for _, s in ipairs(snakes(foe(side))) do
		if not best or attack(s[2]) > attack(best[2]) then
			best = s
		end
	end
	return best
end

local function weakest(side)
	local best
	for _, s in ipairs(snakes(foe(side))) do
		if not best or (s[2].hp or defense(s[2])) < (best[2].hp or defense(best[2])) then
			best = s
		end
	end
	return best
end

local function stat(play, slot, card, atk, hp)
	card.bonus = (card.bonus or 0) + atk
	card.hp = math.max((card.hp or defense(card)) + hp, 1)
	play.float(slot, (atk ~= 0 and "+" .. atk .. " atk " or "") .. (hp ~= 0 and (hp > 0 and "+" or "") .. hp .. " hp" or ""))
end

local function every(side, fn) -- fn(slot, card) for each of a side's snakes; true if there were any
	local list = snakes(side)
	for _, s in ipairs(list) do
		fn(s[1], s[2])
	end
	return #list > 0
end

local function opposite(slot)
	return played_cards[slot > 4 and slot - 4 or slot + 4]
end

brews.list = {
	-- Brews (effect = the id kept on the snake)
	{ name = "Stoneskin_Tonic", kind = "brew", effect = "stone", cost = 1, rarity = 1, colour = { 0.6, 0.62, 0.7 },
		text = "Drink: the snake takes 2 less damage from every hit", lore = "Tastes of gravel, but nothing bites through it." },
	{ name = "Regrowth_Brew", kind = "brew", effect = "regrow", cost = 2, rarity = 1, colour = { 0.4, 0.9, 0.5 },
		text = "Drink: the snake heals 2 at the start of your turn", lore = "A green broth that knits the skin back together." },
	{ name = "Venom_Elixir", kind = "brew", effect = "venom", cost = 2, rarity = 2, colour = { 0.7, 0.3, 0.9 },
		text = "Drink: the snake's hits poison what they hurt", lore = "Brewed from three kinds of fang and a grudge." },
	{ name = "Smoke_Draught", kind = "brew", effect = "smoke", cost = 2, rarity = 2, colour = { 0.5, 0.5, 0.55 },
		text = "Drink: the lane fills with smoke, the enemy snake ahead has 2 less attack", lore = "Nobody strikes well when they cannot see." },
	{ name = "Rage_Draught", kind = "brew", effect = "rage", cost = 3, rarity = 2, colour = { 1, 0.35, 0.2 },
		text = "Drink: the snake gains 3 attack for good", lore = "Bright red and still boiling in the bottle." },
	{ name = "Frostbrew", kind = "brew", effect = "frost", cost = 3, rarity = 3, colour = { 0.5, 0.85, 1 },
		text = "Drink: the snake's hits freeze what they hurt", lore = "Served ice cold, as revenge should be." },
	{ name = "Ghost_Tonic", kind = "brew", effect = "phase", cost = 3, rarity = 3, colour = { 0.85, 0.9, 1 },
		text = "Drink: the snake dodges the first hit it takes each turn", lore = "One sip and you are only partly here." },

	{ name = "Iron_Tonic", kind = "brew", effect = "iron", cost = 1, rarity = 1, colour = { 0.55, 0.6, 0.75 }, text = "Drink: the snake gains a 4 point shield",
		lore = "Swallow it and your scales ring like a bell.", drink = function(play, slot, card) card.shield = (card.shield or 0) + 4; play.float(slot, "+4 shield") end },
	{ name = "Bitter_Tea", kind = "brew", effect = "tea", cost = 1, rarity = 1, colour = { 0.6, 0.45, 0.25 }, text = "Drink: the snake gains 2 attack for good",
		lore = "So bitter it makes you want to bite someone.", drink = function(play, slot, card) stat(play, slot, card, 2, 0) end },
	{ name = "Hearty_Broth", kind = "brew", effect = "broth", cost = 1, rarity = 1, colour = { 0.95, 0.6, 0.3 }, text = "Drink: the snake gains 5 health",
		lore = "Thick, salty and exactly what a snake needs.", drink = function(play, slot, card) stat(play, slot, card, 0, 5) end },
	{ name = "Honey_Mead", kind = "brew", effect = "mead", cost = 1, rarity = 1, colour = { 1, 0.8, 0.3 }, text = "Drink: the snake heals 6",
		lore = "Sweet enough to close a wound.", drink = function(play, slot, card) heal(play, slot, card, 6) end },
	{ name = "Antidote", kind = "brew", effect = "antidote", cost = 1, rarity = 1, colour = { 0.7, 1, 0.9 }, text = "Drink: the snake is cured of poison and freezing, and heals 3",
		lore = "Tastes like the cure for everything, because it is.", drink = function(play, slot, card)
			card.poison, card.frozen = nil, nil
			heal(play, slot, card, 3)
		end },
	{ name = "Swift_Tonic", kind = "brew", effect = "swift", cost = 1, rarity = 1, colour = { 1, 0.95, 0.5 }, text = "Drink: the snake's ability is ready to use again",
		lore = "A jolt that sets the fangs twitching.", drink = function(_, _, card) card.used = nil end },
	{ name = "Thorn_Tonic", kind = "brew", effect = "thorn", cost = 2, rarity = 2, colour = { 0.8, 0.25, 0.3 }, text = "Drink: attackers take 2 damage",
		lore = "Prickly going down, prickly coming back.", drink = function() end },
	{ name = "Leech_Brew", kind = "brew", effect = "leech", cost = 2, rarity = 2, colour = { 0.8, 0.15, 0.45 }, text = "Drink: the snake heals 3 each time it hits a snake",
		lore = "Brewed with a leech still in it.", drink = function() end },
	{ name = "Sunrise_Elixir", kind = "brew", effect = "sunrise", cost = 2, rarity = 2, colour = { 1, 0.7, 0.3 }, text = "Drink: the snake heals fully",
		lore = "Bottled from the first light of a very good day.", drink = function(play, slot, card) heal(play, slot, card, 99) end },
	{ name = "Berserk_Brew", kind = "brew", effect = "berserk", cost = 2, rarity = 2, colour = { 0.75, 0.1, 0.15 }, text = "Drink: the snake gains 4 attack and loses 3 health",
		lore = "It does not stay in the bottle, or in your head.", drink = function(play, slot, card) stat(play, slot, card, 4, -3) end },
	{ name = "Shell_Brew", kind = "brew", effect = "shell", cost = 2, rarity = 2, colour = { 0.85, 0.7, 0.5 }, text = "Drink: the snake gains a 7 point shield",
		lore = "Crunchy, and then very hard to crack.", drink = function(play, slot, card) card.shield = (card.shield or 0) + 7; play.float(slot, "+7 shield") end },
	{ name = "Vigour_Brew", kind = "brew", effect = "vigour", cost = 2, rarity = 2, colour = { 0.5, 0.9, 0.4 }, text = "Drink: the snake gains 2 attack and 3 health",
		lore = "A little of everything, and all of it green.", drink = function(play, slot, card) stat(play, slot, card, 2, 3) end },
	{ name = "Gold_Draught", kind = "brew", effect = "gold", cost = 3, rarity = 3, colour = { 1, 0.85, 0.2 }, text = "Drink: you gain 1 venom at the start of each of your turns while the snake lives",
		lore = "Liquid gold, and it pays for itself.", drink = function() end },
	{ name = "Fire_Draught", kind = "brew", effect = "fire", cost = 3, rarity = 3, colour = { 1, 0.5, 0.1 }, text = "Drink: damage beyond a kill hits the owner's health 1.5x",
		lore = "It burns on the way down and on the way out.", drink = function() end },
	{ name = "Giant_Brew", kind = "brew", effect = "giant", cost = 3, rarity = 3, colour = { 0.35, 0.65, 0.3 }, text = "Drink: the snake gains 4 attack and 4 health",
		lore = "Grown in a pot far too small for it.", drink = function(play, slot, card) stat(play, slot, card, 4, 4) end },
	{ name = "Warding_Brew", kind = "brew", effect = "ward", cost = 3, rarity = 3, colour = { 1, 0.95, 0.7 }, text = "Drink: the snake gains a 3 point shield at the start of each of your turns",
		lore = "Each sip wraps you in a fresh circle of light.", drink = function() end },
	{ name = "Siphon_Brew", kind = "brew", effect = "siphon", cost = 3, rarity = 3, colour = { 0.85, 0.15, 0.3 }, text = "Drink: at the start of each of your turns the snake drains 2 health from the snake opposite",
		lore = "It drinks you back.", drink = function() end },
	{ name = "Blight_Brew", kind = "brew", effect = "blight", cost = 3, rarity = 3, colour = { 0.7, 0.85, 0.2 }, text = "Drink: at the start of each of your turns the snake opposite is poisoned",
		lore = "Where it spills, nothing grows.", drink = function() end },
	{ name = "Numbing_Brew", kind = "brew", effect = "numb", cost = 4, rarity = 4, colour = { 0.7, 0.85, 1 }, text = "Drink: at the start of each of your turns the snake opposite is frozen",
		lore = "You will not feel a thing. Neither will they, for a while.", drink = function() end },
	{ name = "Adamant_Draught", kind = "brew", effect = "adamant", cost = 4, rarity = 4, colour = { 0.5, 0.55, 0.85 }, text = "Drink: the snake takes 4 less damage from every hit",
		lore = "Stronger than stone and twice as smug.", drink = function() end },
	{ name = "Titan_Tonic", kind = "brew", effect = "titan", cost = 4, rarity = 4, colour = { 0.55, 0.3, 0.8 }, text = "Drink: the snake gains 6 attack and 6 health",
		lore = "Drink it and the room gets smaller.", drink = function(play, slot, card) stat(play, slot, card, 6, 6) end },
	{ name = "Phoenix_Elixir", kind = "brew", effect = "phoenix", cost = 4, rarity = 4, colour = { 1, 0.6, 0.2 }, text = "Drink: the snake heals 4 at the start of each of your turns",
		lore = "Rises from its own ashes, every morning.", drink = function() end },
	{ name = "Dragon_Blood", kind = "brew", effect = "dragon", cost = 4, rarity = 4, colour = { 0.8, 0.1, 0.1 }, text = "Drink: the snake gains 1 attack at the start of each of your turns",
		lore = "Thick, dark and not entirely willing.", drink = function() end },
	-- Spells (cast = what happens at once; return false to do nothing and cost nothing)
	{ name = "Arcane_Insight", kind = "spell", cost = 1, rarity = 1, colour = { 0.5, 0.6, 1 },
		text = "Cast: draw 2 snakes into your hand", lore = "The cards seem to arrange themselves.",
		cast = function(play, side)
			for _ = 1, 2 do
				play.draw_extra(side)
			end
			return true
		end },
	{ name = "Venom_Well", kind = "spell", cost = 1, rarity = 1, colour = { 0.7, 0.3, 0.9 },
		text = "Cast: gain 4 venom", lore = "A pool that never quite empties.",
		cast = function(play, side)
			if venom[side] >= play.MAX_VENOM - 1 then
				return false
			end
			venom[side] = math.min(venom[side] + 4, play.MAX_VENOM)
			play.float_bar(side, "+4 venom")
			return true
		end },
	{ name = "Healing_Rain", kind = "spell", cost = 2, rarity = 2, colour = { 0.4, 0.9, 0.7 },
		text = "Cast: all your snakes heal 4", lore = "It rains once a year in the desert, and everyone remembers.",
		cast = function(play, side)
			local healed = false
			for _, s in ipairs(snakes(side)) do
				healed = heal(play, s[1], s[2], 4) or healed
			end
			return healed
		end },
	{ name = "Guardian_Ward", kind = "spell", cost = 2, rarity = 2, colour = { 1, 0.85, 0.3 },
		text = "Cast: all your snakes gain a 3 point shield", lore = "A circle of gold that the first blow cannot cross.",
		cast = function(play, side)
			local list = snakes(side)
			for _, s in ipairs(list) do
				s[2].shield = (s[2].shield or 0) + 3
				play.float(s[1], "+3 shield")
			end
			return #list > 0
		end },
	{ name = "Frost_Nova", kind = "spell", cost = 3, rarity = 3, colour = { 0.5, 0.85, 1 },
		text = "Cast: freeze every enemy snake for a turn", lore = "The air cracks, and so does everything in it.",
		cast = function(play, side)
			local list = snakes(foe(side))
			for _, s in ipairs(list) do
				s[2].frozen = true
				play.float(s[1], "frozen")
			end
			return #list > 0
		end },
	{ name = "Lightning_Storm", kind = "spell", cost = 4, rarity = 3, colour = { 1, 0.95, 0.4 },
		text = "Cast: 3 damage to every enemy snake", lore = "Snakes are not fond of thunder.",
		cast = function(play, side)
			local list = snakes(foe(side))
			for _, s in ipairs(list) do
				play.wound(s[1], 3)
			end
			return #list > 0
		end },
	{ name = "Meteor_Strike", kind = "spell", cost = 5, rarity = 4, colour = { 1, 0.5, 0.2 },
		text = "Cast: 10 damage to the enemy charmer", lore = "A star with a grudge against one particular Charmer.",
		cast = function(play, side)
			play.hurt(foe(side), 10)
			return true
		end },
	{ name = "Spark", kind = "spell", cost = 1, rarity = 1, colour = { 1, 0.95, 0.5 }, text = "Cast: 8 damage to the enemy charmer", lore = "Small, bright and rude.",
		cast = function(play, side) play.hurt(foe(side), 8); return true end },
	{ name = "Mend", kind = "spell", cost = 1, rarity = 1, colour = { 0.5, 0.95, 0.6 }, text = "Cast: your most hurt snake heals 6", lore = "A stitch in time.",
		cast = function(play, side)
			local best, gap = nil, 0
			for _, s in ipairs(snakes(side)) do
				local missing = defense(s[2]) - (s[2].hp or defense(s[2]))
				if missing > gap then
					best, gap = s, missing
				end
			end
			return best and heal(play, best[1], best[2], 6)
		end },
	{ name = "Sharpen", kind = "spell", cost = 1, rarity = 1, colour = { 0.8, 0.85, 0.95 }, text = "Cast: all your snakes gain 1 attack for good", lore = "Fangs, not blades, but the stone does not mind.",
		cast = function(play, side) return every(side, function(slot, c) stat(play, slot, c, 1, 0) end) end },
	{ name = "Candle_Whisper", kind = "spell", cost = 1, rarity = 1, colour = { 1, 0.85, 0.5 }, text = "Cast: draw 1 snake and gain 1 venom", lore = "The flame leans in to tell you something.",
		cast = function(play, side)
			play.draw_extra(side)
			venom[side] = math.min(venom[side] + 1, play.MAX_VENOM)
			return true
		end },
	{ name = "Mist_Veil", kind = "spell", cost = 1, rarity = 1, colour = { 0.75, 0.85, 0.95 }, text = "Cast: all your snakes gain a 2 point shield", lore = "A cool fog that softens the first blow.",
		cast = function(play, side) return every(side, function(slot, c) c.shield = (c.shield or 0) + 2; play.float(slot, "+2 shield") end) end },
	{ name = "Poison_Dart", kind = "spell", cost = 1, rarity = 1, colour = { 0.5, 0.9, 0.2 }, text = "Cast: poison the enemy snake with the most attack", lore = "Thrown by someone who would rather not be bitten.",
		cast = function(play, side)
			local s = strongest(side)
			if s then
				s[2].poison = 2
				play.float(s[1], "poison")
			end
			return s ~= nil
		end },
	{ name = "Cold_Snap", kind = "spell", cost = 2, rarity = 2, colour = { 0.6, 0.9, 1 }, text = "Cast: freeze the enemy snake with the most attack for a turn", lore = "The air goes still and a little blue.",
		cast = function(play, side)
			local s = strongest(side)
			if s then
				s[2].frozen = true
				play.float(s[1], "frozen")
			end
			return s ~= nil
		end },
	{ name = "Fireball", kind = "spell", cost = 2, rarity = 2, colour = { 1, 0.5, 0.15 }, text = "Cast: 5 damage to the enemy snake with the most attack", lore = "It has a name and a target.",
		cast = function(play, side)
			local s = strongest(side)
			if s then
				play.wound(s[1], 5)
			end
			return s ~= nil
		end },
	{ name = "Execute", kind = "spell", cost = 2, rarity = 2, colour = { 0.8, 0.8, 0.85 }, text = "Cast: destroy the enemy snake with the least health if it has 5 or less", lore = "A kindness, in the end.",
		cast = function(play, side)
			local s = weakest(side)
			if s and (s[2].hp or defense(s[2])) <= 5 then
				play.wound(s[1], s[2].hp or defense(s[2]))
				return true
			end
			return false
		end },
	{ name = "Drain_Life", kind = "spell", cost = 2, rarity = 2, colour = { 0.8, 0.1, 0.3 }, text = "Cast: 4 damage to the enemy charmer, and you heal 4", lore = "What is theirs becomes yours.",
		cast = function(play, side)
			play.hurt(foe(side), 4)
			health[side] = math.min(health[side] + 4, max_health[side])
			play.float_bar(side, "+4 health")
			return true
		end },
	{ name = "Dispel", kind = "spell", cost = 2, rarity = 2, colour = { 0.75, 0.6, 1 }, text = "Cast: enemy snakes lose their brews and shields", lore = "Everything that was glowing stops.",
		cast = function(play, side)
			local any = false
			for _, s in ipairs(snakes(foe(side))) do
				if s[2].brew or (s[2].shield or 0) > 0 then
					s[2].brew, s[2].shield, any = nil, nil, true
					play.float(s[1], "dispelled")
				end
			end
			return any
		end },
	{ name = "Blood_Pact", kind = "spell", cost = 2, rarity = 2, colour = { 0.7, 0.1, 0.2 }, text = "Cast: lose 3 health and gain 5 venom", lore = "Signed in a hand that is no longer quite yours.",
		cast = function(play, side)
			if health[side] <= 3 or venom[side] >= play.MAX_VENOM - 2 then
				return false
			end
			play.hurt(side, 3)
			venom[side] = math.min(venom[side] + 5, play.MAX_VENOM)
			play.float_bar(side, "+5 venom")
			return true
		end },
	{ name = "Encore", kind = "spell", cost = 2, rarity = 3, colour = { 1, 0.7, 0.9 }, text = "Cast: your charmer's ability is ready to use again", lore = "The crowd demands it.",
		cast = function(play, side)
			if not play.charm_used[side] and play.charm_cd[side] == 0 then
				return false
			end
			play.charm_used[side], play.charm_cd[side] = false, 0
			play.float_bar(side, "charm ready")
			return true
		end },
	{ name = "Battle_Cry", kind = "spell", cost = 3, rarity = 3, colour = { 1, 0.4, 0.3 }, text = "Cast: all your snakes gain 2 attack for good", lore = "A hiss that goes down the whole line.",
		cast = function(play, side) return every(side, function(slot, c) stat(play, slot, c, 2, 0) end) end },
	{ name = "Mass_Heal", kind = "spell", cost = 3, rarity = 3, colour = { 0.4, 1, 0.6 }, text = "Cast: all your snakes heal 8", lore = "The temple bells ring and the scars fade.",
		cast = function(play, side)
			local healed = false
			for _, s in ipairs(snakes(side)) do
				healed = heal(play, s[1], s[2], 8) or healed
			end
			return healed
		end },
	{ name = "Iron_Wall", kind = "spell", cost = 3, rarity = 3, colour = { 0.65, 0.7, 0.8 }, text = "Cast: all your snakes gain a 6 point shield", lore = "Built in a breath, and it will hold.",
		cast = function(play, side) return every(side, function(slot, c) c.shield = (c.shield or 0) + 6; play.float(slot, "+6 shield") end) end },
	{ name = "Plague", kind = "spell", cost = 3, rarity = 3, colour = { 0.6, 0.8, 0.2 }, text = "Cast: poison every enemy snake", lore = "It started with one cough.",
		cast = function(play, side) return every(foe(side), function(slot, c) c.poison = 2; play.float(slot, "poison") end) end },
	{ name = "Starfall", kind = "spell", cost = 3, rarity = 3, colour = { 0.7, 0.8, 1 }, text = "Cast: 6 damage to the enemy charmer", lore = "Wish carefully.",
		cast = function(play, side) play.hurt(foe(side), 6); return true end },
	{ name = "Scholars_Gift", kind = "spell", cost = 3, rarity = 3, colour = { 0.5, 0.6, 1 }, text = "Cast: draw 4 snakes into your hand", lore = "A whole library, folded into one page.",
		cast = function(play, side)
			for _ = 1, 4 do
				play.draw_extra(side)
			end
			return true
		end },
	{ name = "Blizzard", kind = "spell", cost = 4, rarity = 4, colour = { 0.8, 0.95, 1 }, text = "Cast: 2 damage to every enemy snake and freeze them for a turn", lore = "Nothing outside is moving.",
		cast = function(play, side)
			return every(foe(side), function(slot, c)
				c.frozen = true
				play.wound(slot, 2)
			end)
		end },
	{ name = "Earthquake", kind = "spell", cost = 5, rarity = 4, colour = { 0.7, 0.5, 0.3 }, text = "Cast: 6 damage to every enemy snake", lore = "The ground has opinions about snakes.",
		cast = function(play, side)
			local list = snakes(foe(side))
			for _, s in ipairs(list) do
				play.wound(s[1], 6)
			end
			return #list > 0
		end },
	{ name = "Renewal", kind = "spell", cost = 4, rarity = 4, colour = { 1, 0.9, 0.5 }, text = "Cast: all your snakes heal fully and you heal 5", lore = "The sun comes up inside the temple.",
		cast = function(play, side)
			every(side, function(slot, c) heal(play, slot, c, 99) end)
			health[side] = math.min(health[side] + 5, max_health[side])
			play.float_bar(side, "+5 health")
			return true
		end },
	{ name = "Time_Warp", kind = "spell", cost = 4, rarity = 4, colour = { 0.6, 0.5, 1 }, text = "Cast: all your snakes' abilities are ready again, and draw 2 snakes", lore = "Yesterday, but with better timing.",
		cast = function(play, side)
			every(side, function(_, c) c.used = nil end)
			for _ = 1, 2 do
				play.draw_extra(side)
			end
			return true
		end },
}

brews.by_name = {}
for _, card in ipairs(brews.list) do
	brews.by_name[card.name] = card
end

-- Does the snake (in `slot`) have this brew active?
function brews.has(card, effect)
	return card and card.brew == effect
end

-- The snake in `slot` drinks the brew; returns false if it can't
function brews.drink(play, def, slot)
	local card = played_cards[slot]
	if not card then
		return false
	end
	card.brew = def.effect
	if def.effect == "rage" then
		card.bonus = (card.bonus or 0) + 3
	end
	card.brew_t = time
	play.float(slot, "drank " .. def.name:gsub("_", " "))
	if def.drink then
		def.drink(play, slot, card)
	end
	return true
end

-- Start of a snake's owner's turn
function brews.turn(play, card, slot)
	local effect, side, foe_card = card.brew, slot > 4 and "Player" or "Opponent", opposite(slot)
	if effect == "regrow" then
		heal(play, slot, card, 2)
	elseif effect == "phoenix" then
		heal(play, slot, card, 4)
	elseif effect == "phase" then
		card.phased = nil
	elseif effect == "dragon" then
		stat(play, slot, card, 1, 0)
	elseif effect == "ward" then
		card.shield = (card.shield or 0) + 3
		play.float(slot, "+3 shield")
	elseif effect == "gold" then
		venom[side] = math.min(venom[side] + 1, play.MAX_VENOM)
		play.float(slot, "+1 venom")
	elseif foe_card and effect == "numb" then
		foe_card.frozen = true
		play.float(slot > 4 and slot - 4 or slot + 4, "frozen")
	elseif foe_card and effect == "blight" then
		foe_card.poison = 2
		play.float(slot > 4 and slot - 4 or slot + 4, "poison")
	elseif foe_card and effect == "siphon" then
		play.wound(slot > 4 and slot - 4 or slot + 4, 2)
		heal(play, slot, card, 2)
	end
end

return brews
