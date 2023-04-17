_G = GLOBAL
require = _G.require

--If enabled by MiM, we do not want to change anything when on a server.

-- Hornet: So there's a weird bug where sometimes skins enabled by MiM DO show up on a server, but sometimes it doesnt?
-- I assume GetServerGameMode isn't consistent and can sometimes give us a result we do not want
print("Is MiM enabled?: ", is_mim_enabled, " What is the server game mode?: ", _G.TheNet:GetServerGameMode()) 
if is_mim_enabled and _G.TheNet:GetServerGameMode() ~= "" then return end

Assets = {
	Asset("ANIM", "anim/modded_event_icon.zip"),
	Asset("ANIM", "anim/modded_frame_BG.zip"),
	Asset("ANIM", "anim/moddedskingift_popup.zip"),
	Asset("ANIM", "anim/tab_moddedgift.zip"),
	Asset("ANIM", "anim/player_receive_moddedgift.zip"),
	Asset("ANIM", "anim/researchlab3_gift.zip"),
	Asset("ANIM", "anim/researchlab4_gift.zip"),

	--
	Asset("ATLAS", "images/ms_buttons.xml"),
	Asset("IMAGE", "images/ms_buttons.tex"),
	
	--
	Asset("ANIM", "anim/glasses_default1.zip"),

	Asset("DYNAMIC_ANIM", "anim/dynamic/ms_glasses_catshade.zip"),
	Asset("PKGREF", "anim/dynamic/ms_glasses_catshade.dyn"),
	Asset("DYNAMIC_ANIM", "anim/dynamic/ms_glasses_heartstruck.zip"),
	Asset("PKGREF", "anim/dynamic/ms_glasses_heartstruck.dyn"),
	Asset("DYNAMIC_ANIM", "anim/dynamic/ms_glasses_pointedshade.zip"),
	Asset("PKGREF", "anim/dynamic/ms_glasses_pointedshade.dyn"),
	Asset("DYNAMIC_ANIM", "anim/dynamic/ms_glasses_shades.zip"),
	Asset("PKGREF", "anim/dynamic/ms_glasses_shades.dyn"),

	Asset("ANIM", "anim/player_emote_glasses.zip"),
}

-- Fox: Debug tools
if not MODROOT:find("workshop-") then
	_G.CHEATS_ENABLED = true
end

-- Hornet: Stinky hack, mod debug print crashes for us since we're in the global environment in our modimports so... let's just disable it temporarily!
-- P.S. I had NO idea anyone actually used mod debug print haha, never seemed all that useful imo
local _IsModInitPrintEnabled = _G.KnownModIndex.IsModInitPrintEnabled
function _G.KnownModIndex:IsModInitPrintEnabled(...)
	local enabled = _IsModInitPrintEnabled(self, ...)
	if enabled then 
		print([[MODDED SKINS WARNING:
			Mod Debug Print was detected to be enabled!
			Unfortunately we have to disable this as MS is in the global environment and thus would have crashed the game, Sorry!]])
	end
	return false 
end

require("ms_strings")
require("ms_skinutil")

modimport("scripts/ms_skinloader")
modimport("scripts/ms_customslots")
modimport("scripts/ms_gui")

-- GUI should be changes for both server/client, Postinits are server only
if is_mim_enabled then return end

modimport("scripts/ms_postinits")
modimport("scripts/ms_rpc")