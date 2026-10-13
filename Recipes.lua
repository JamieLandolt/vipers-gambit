-- Sacrifice recipes: the Snake God demands specific snakes and gives one specific snake in return.
-- Every snake of tier 2 or higher has exactly one recipe. It asks for snakes of the tier below (2 for tier 2, 3 for tiers 3 and 4,
-- 4 for the Mythics), preferring the target's own lane type, and picks them with a fixed hash so the list never changes.
-- `exclude` lists snakes that can't be offered (the starters and the royal line).
return function(data, exclude)
	local function hash(s)
		local h = 5381
		for i = 1, #s do
			h = (h * 33 + s:byte(i)) % 2147483647
		end
		return h
	end
	local COUNT = { [2] = 2, [3] = 3, [4] = 3, [5] = 4 }

	local by_rarity = {}
	for _, name in ipairs(data.deck) do
		local st = data.stats_by_name[name]
		if st.kind == "snake" and not contains(exclude, name) then
			by_rarity[st.rarity] = by_rarity[st.rarity] or {}
			table.insert(by_rarity[st.rarity], name)
		end
	end

	local list, by_target = {}, {}
	for _, target in ipairs(data.deck) do
		local st = data.stats_by_name[target]
		if st.kind == "snake" and st.rarity >= 2 then
			local home = data.card_types[target]
			local pool = {}
			for _, name in ipairs(by_rarity[st.rarity - 1] or {}) do
				if name ~= target then
					table.insert(pool, name)
				end
			end
			local function kin(name)
				local kind = data.card_types[name]
				return kind == home or kind == "Rainbow" or home == "Rainbow"
			end
			table.sort(pool, function(a, b)
				if kin(a) ~= kin(b) then
					return kin(a)
				end
				local ha, hb = hash(target .. a), hash(target .. b)
				return ha ~= hb and ha < hb or (ha == hb and a < b)
			end)
			local give = {}
			for i = 1, math.min(COUNT[st.rarity], #pool) do
				give[i] = pool[i]
			end
			table.sort(give)
			local recipe = { give = give, get = target }
			table.insert(list, recipe)
			by_target[target] = recipe
		end
	end
	return list, by_target
end
