--First, we gotta add our new rarities!
--NOTE: THIS IS IMPORTANT!
--Klei prefers to have modded skins stand out from official stuff
--This is so that users can tell the difference between official and modded skins

--Hornet: #40E0D0 was the skin color klei reserved for us, but... it's kinda bright lol. I'm only desaturating a tiny bit though, not too much.
--SKIN_RARITY_COLORS["ModMade"]    = {  64/255, 224/255, 208/255, 1 } --#40E0D0
--SKIN_RARITY_COLORS["ModLocked"]  = { 213/255,   0/255, 108/255, 1 } --#D5006C

SKIN_RARITY_COLORS["ModMade"]    = {  72/255, 208/255, 208/255, 1 } --#48D0D0
SKIN_RARITY_COLORS["ModLocked"]  = { 186/255,   7/255, 98/255, 1 } --#BA0762

MODSKINANNOUNCEMENT_COLOR = {64/255, 219/255, 234/255, 1}

local modded_order = {ModMade = 31, ModLocked = 32}
local _oldCompareRarities = CompareRarities
CompareRarities = function(a, b)
	local rarity1 = GetRarityForItem(a)
	local rarity2 = GetRarityForItem(b)
	
	if modded_order[rarity1] or modded_order[rarity2] then
		local rarity1_sort = modded_order[rarity1] and modded_order[rarity1] or 1
		local rarity2_sort = modded_order[rarity2] and modded_order[rarity2] or 1
		
		return rarity1_sort < rarity2_sort
	end
	return _oldCompareRarities(a, b)
end

function RegisterNoneSkin(skin_id, base_prefab) --used in ms_skinloader.lua and tools/autononeskin.lua
	if not PREFAB_SKINS[base_prefab] then PREFAB_SKINS[base_prefab] = {} end
	if not PREFAB_SKINS_IDS[base_prefab] then PREFAB_SKINS_IDS[base_prefab] = {} end
	if not PREFAB_SKINS_IDS[base_prefab][skin_id] then
		local key = #PREFAB_SKINS[base_prefab]+1
		PREFAB_SKINS[base_prefab][key] = skin_id
		PREFAB_SKINS_IDS[base_prefab][skin_id] = key
	end
end

--Deprecated and from the original API! There are mods that STILL try to use these functions by checking for the ModMade rarity and if it exists, haha. So here's a fix to that edge-case
--Please don't use these if you're delving into the code and looking at stuff

function MakeModCharacterSkinnable()
	--Fuck you, does nothing.
end

function AddModCharacterSkin(prefab, skin, skins, assets, tags, options)
	local skin_assets = {}
	for _,anim in pairs(assets) do
		table.insert(skin_assets, Asset("ANIM", "anim/"..anim..".zip"))
	end
		
	return CreatePrefabSkin(prefab.."_"..skin, {
		base_prefab = prefab,
		build_name_override = skins["normal_skin"],
		skins = skins,
		assets = skin_assets,
		tags = tags or {},
		rarity = "ModMade",
	})
end

function AddModItemSkin()
	--Fuck you, does nothing and takes up unnecessary ram
	return Prefab("nothing", function() end)
end