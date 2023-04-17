local MSENV = env
local AddModRPCHandler = AddModRPCHandler
local AddClientModRPCHandler = AddClientModRPCHandler
local SendModRPCToClient = SendModRPCToClient
local GetClientModRPC = GetClientModRPC

_G.setfenv(1, _G)

local ExtraClothingInfo = { --Hornet: client data is hardcoded in the engine so we have to do this for our extra clothing slots
	--e.g. [userid] = {glasses = "glasses_basic"}
}

local _GetClientTableForUser = NetworkProxy.GetClientTableForUser
local _GetClientTable = NetworkProxy.GetClientTable

NetworkProxy.GetClientTableForUser = function(self, userid, ...)
	local data = _GetClientTableForUser(self, userid, ...)

	if data ~= nil then
		data.glasses_skin = ExtraClothingInfo[userid] ~= nil and ExtraClothingInfo[userid].glasses
	end

	return data
end

NetworkProxy.GetClientTable = function(self, ...)
	local data = _GetClientTable(self, ...)

	for k, v in pairs(data or {}) do
		if v.userid ~= nil then
			data[k].glasses_skin = ExtraClothingInfo[v.userid] ~= nil and ExtraClothingInfo[v.userid].glasses
		end
	end

	return data
end

AddModRPCHandler("ModdedSkins", "RefreshModGiftCount", function(player)
	local moddedgiftreceiver = player.components.moddedgiftreceiver
	if moddedgiftreceiver ~= nil then
		moddedgiftreceiver:RefreshGiftCount()
	end
end)

AddModRPCHandler("ModdedSkins", "GiveGiftCountToServer", function(player, giftcount)
	local moddedgiftreceiver = player.components.moddedgiftreceiver
	if moddedgiftreceiver ~= nil then
		moddedgiftreceiver.newgiftcount = giftcount
		player:PushEvent("receivedmoddedgiftcount")
	end
end)

AddClientModRPCHandler("ModdedSkins", "GetClientGiftCount", function()
	SendModRPCToServer(GetModRPC("ModdedSkins", "GiveGiftCountToServer"), TheModdedInventory:GetQueueCount())
end)

AddClientModRPCHandler("ModdedSkins", "IsOpeningModGift", function(isopening)
	TheModdedInventory.isopeningmodgift = isopening
end)

AddModRPCHandler("ModdedSkins", "SetSkinInfo", function(player, base, glasses)
	local skinner = player.components.skinner
	if skinner ~= nil then
		skinner.skin_name = base
		skinner.clothing.glasses = glasses
	end
end)

AddModRPCHandler("ModdedSkins", "OpenModdedGift", function(player)
	local moddedgiftreceiver = player.components.moddedgiftreceiver
	if moddedgiftreceiver ~= nil then
		moddedgiftreceiver:OpenNextGift()
	end
end)

AddClientModRPCHandler("ModdedSkins", "UnlockModdedSkin", function(skin_id)
	if TheModdedInventory ~= nil then
		TheModdedInventory:UnlockSkin(skin_id)
    end
end)

--Our own version of Network:SetPlayerSkin but for our custom slots
AddClientModRPCHandler("ModdedSkins", "SetPlayerSkin", function(userid, glasses)
	if userid == nil then return end
	if ExtraClothingInfo[userid] == nil then ExtraClothingInfo[userid] = {} end

	ExtraClothingInfo[userid].glasses = glasses
	
	--Hornet: For updating the lobby used in Forge/Gorge (rpc's take a bit so yknow)
	local scrn = TheFrontEnd ~= nil and TheFrontEnd:GetActiveScreen()
	if scrn and scrn.panel and scrn.panel.waiting_for_players then
		scrn.panel.waiting_for_players:Refresh(true)
	end
end)

AddModRPCHandler("ModdedSkins", "SetPlayerSkinServer", function(userid, glasses)
	if userid == nil then return end
	--Pass to the server, then pass to everyone!

	SendModRPCToClient(GetClientModRPC("ModdedSkins", "SetPlayerSkin"), nil, userid, glasses or "")
end)

AddClientModRPCHandler("ModdedSkins", "LockModdedSkin", function(skin_id)
	if TheModdedInventory ~= nil then
		TheModdedInventory:LockSkin(skin_id)
    end
end)

AddModRPCHandler("ModdedSkins", "SetClientOwned", function(userid, skinid, owned)
	if ClientOwnedSkins[userid] == nil then ClientOwnedSkins[userid] = {} end

	ClientOwnedSkins[userid][skinid] = owned
end)

MarkUserIDRPC("ModdedSkins", "SetClientOwned")
MarkUserIDRPC("ModdedSkins", "SetPlayerSkinServer")

TheModdedInventory:SetClientOwnedSkins()