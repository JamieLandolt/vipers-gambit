-- Flavour text for each snake (see LORE_DRAFT.md for the world it comes from) and the name of each tier.
-- New snakes bring their own lore in NewCards.lua; a snake listed here overrides it.
local lore = {
	tiers = { "Hatchling", "Fanged", "Ancient", "Royal", "Mythic" },

	-- Land: the Dustwild
	Snake = "The plain, original snake, the one every Charmer starts with.",
	Big_Snake = "Grew too large for its burrow and has been blocking the road since.",
	Baby_Snake = "Hatched yesterday and bites anything that moves.",
	Well_Fed_Snake = "Sleeps after meals, so it never needs to attack.",
	Cannibal_Snake = "Eats other snakes; the Court bans it from banquets.",
	Cobra = "The Court's guard animal, hood flared to show the way out.",
	King_Cobra = "Rules the Dustwild dens and expects bows.",
	Albino_Cobra = "Bleached by moonlight; considered a bad omen at court.",
	Horned_Viper = "Its horns are a warning; nobody has ignored them twice.",
	Grey_Snake = "Blends into the dust so well it is rarely counted.",
	Dirt_Snake = "Hides under a handful of soil and waits.",
	Sand_Snake = "Moves like a ripple through the dunes.",

	-- Water: the Drowned Reaches
	Anaconda = "Rules the deepest river and swallows what disagrees.",
	Extra_Long_Python = "Measured once, then the tape ran out.",
	Frost_Cobra = "A royal cobra frozen mid-hiss in a glacier, now thawed and cross.",
	Sea_Snake = "The reef's quiet guard; its venom is stronger than it looks.",
	Toxic_Snake = "Bred in poisoned ponds; touching it is a mistake.",
	Mud_Snake = "Hard to hold and harder to see.",
	Ball_Python = "Curls up in a ball and waits for the danger to go away.",
	Garter_Snake = "Harmless, friendly, and the first lesson in every Gambit.",
	Copperhead = "Strikes from leaf litter and vanishes.",

	-- Tree: the Canopy
	Boa_Constrictor = "The Canopy's strongest squeeze; trees creak around it.",
	Tree_Boa = "Hangs from branches and drops without warning.",
	Vine_Snake = "Looks like a vine until it moves.",
	Grass_Snake = "Always found, never caught.",
	Worm_Snake = "Tiny and shy, often mistaken for dinner.",
	Black_Mamba = "Fastest of the Canopy; its bite is a short story.",
	Kingsnake = "Eats other snakes and wears the stripes of a diplomat.",
	Corn_Snake = "Farmers' friend and the Charmer's favourite first pet.",
	Brown_Snake = "Seen everywhere, remembered nowhere.",

	-- Spirit: the Hollow
	Zombie_Snake = "Died, got up again, and has been angry since.",
	Skeleton_Snake = "Only bones now, which makes it very hard to squeeze.",
	Ghost_Snake = "Passes through walls, locked doors, and defences.",
	Shadow_Snake = "A snake-shaped gap in the light.",
	Lava_Snake = "Swims in magma and leaves molten tracks.",
	Blood_Cobra = "The Court's executioner; its hood is the colour of its work.",
	Pale_Snake = "What a snake becomes when everything has already happened.",

	-- Wildborn: fits any lane
	Coral_Snake = "Red, yellow, black: a warning wrapped in a rhyme.",
	Rattlesnake = "Announces itself and still wins.",
	Gaboon_Viper = "Fangs longer than a thumb and a temper to match.",
	Golden_Snake = "Said to be a gift from the First Serpent; the Golden Heir's pride.",
	-- Mythic: the five legendaries
	Jormungandr = "The sea serpent that circles the Drowned Reaches; when it exhales, whole fleets freeze.",
	Quetzalcoatl = "The feathered serpent of the Canopy who brought the first rain and the first dawn.",
	Apophis = "The Hollow's night-eater; each dusk it swallows the sun, and each dawn the sun barely escapes.",
	Ouroboros = "A Wildborn that devours its own tail and is reborn in every colour of light.",
	Nagaraja = "The golden serpent king of the Dustwild, whose seven hoods shelter the mountain of the sun.",
}

return lore
