name = "[API] Modded Skins"
version = "2.12.05"
description = [[Modded Skins API helps other mods add their own custom skins for their characters and custom items, and more!]]
author = "Hornet, Willow, Cunning Fox, & Erik"
forumthread = ""
api_version = 10
icon_atlas = "images/modicon.xml"
icon = "modicon.tex"

folder_name = folder_name or "workshop-"
if not folder_name:find("workshop-") then
	name = name .. " - GitLab Ver."
end

dont_starve_compatible = false
reign_of_giants_compatible = false
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false

forge_compatible = true
gorge_compatible = true

priority = 2147483647 --First mod to load, adds functionality for skins to the modding environment
server_filter_tags = {
	"api",
	"skins",
	"moddedskins",
}

--[[
configuration_options =
{
	{
		name = "glassesslot",				
		label = "Glasses Slot",			
		hover = "Choose to enable or disable the glasses skin slot,
		options = {
			{
				description = "Disabled", 
				data = false
			}, 
			{
				description = "Enabled", 
				data = true
			}
		},
		default = true
	},
]]