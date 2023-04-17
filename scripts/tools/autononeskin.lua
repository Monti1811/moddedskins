--Hornet: This is a prefab file loaded in sim postinit, to create all necessary none skins that mod authors were ignorant to produce themselves
--I put it here to differentiate it from a normal prefab file, since it has to be done post loading of regular prefabs, and also I didn't wanna create a prefabs folder just for one file

local prefabs = {}

for k, v in pairs(MODCHARACTERLIST) do
	if Prefabs[v.."_none"] == nil then --the none skin does not exists.
		table.insert(prefabs, CreatePrefabSkin(v.."_none", {
			assets = {
				--making an assumption that character build is same as character name, if it's not, then I'm embarrassed for these mod authors
				--EDIT: yea so guess what. I need to idiot-proof every bit of my code, because there are indeed people with characters whose builds are not the same as their names, sigh.
				--Asset("ANIM", "anim/"..v..".zip"),
			},
			skins = {
				normal_skin = v,
				ghost_skin = v.."_ghost_build",
			},
		
			base_prefab = v,
			build_name_override = v,
		
			type = "base",
			rarity = "Character",
		
			skin_tags = { "BASE", },
		}))
		
		RegisterNoneSkin(v.."_none", v)
	end
end

return unpack(prefabs)