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
		play.float(slot, "+" .. amount .. " hp")
		return true
	end
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
	return true
end

-- Start of a snake's owner's turn
function brews.turn(play, card, slot)
	if card.brew == "regrow" then
		heal(play, slot, card, 2)
	elseif card.brew == "phase" then
		card.phased = nil
	end
end

return brews
