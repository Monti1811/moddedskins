local skin_queue = {}
local unlocked_skins = {}

local TheModdedInventory = Class(function(self)
    self.conditions = {}
	self.isopeningmodgift = false

    self:Load()
end)

function TheModdedInventory:GetQueueCount()
	local c = 0
    for k,v in pairs(skin_queue) do
        c = c + 1
    end
    return c
end

function TheModdedInventory:GetNextInQueue()
    for k,v in pairs(skin_queue) do
        return k
    end
end

function TheModdedInventory:CheckOwnership(skin_id)
    return unlocked_skins[skin_id] ~= nil
end

function TheModdedInventory:UnlockSkin(skin_id)
    local condition = self.conditions[skin_id]
    if condition then
        if condition.no_gift then
            unlocked_skins[skin_id] = true
			SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, true)
        elseif not unlocked_skins[skin_id] then --Let's not take a step backwards if the gift's been opened
            skin_queue[skin_id] = true
			SendModRPCToServer(GetModRPC("ModdedSkins", "RefreshModGiftCount"))
        end
    end
	self:Save()
end

function TheModdedInventory:OpenGift(skin_id)
    if skin_queue[skin_id] then
        skin_queue[skin_id] = nil
        unlocked_skins[skin_id] = true
		SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, true)

		self.isopeningmodgift = false
		self:Save()
        return true
    end
end

function TheModdedInventory:LockSkin(skin_id) --TODO only send rpc is skin is in skin queue, no need to send the rpc if its only in the unlocked_skins
    skin_queue[skin_id] = nil
    unlocked_skins[skin_id] = nil
	SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, false)
	SendModRPCToServer(GetModRPC("ModdedSkins", "RefreshModGiftCount"))
	self:Save()
end

function TheModdedInventory:SetClientOwnedSkins()
	for skin_id, unlocked in pairs(unlocked_skins) do
		if CLIENT_MOD_RPC["ModdedSkins"] then
			SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, unlocked)
		end
	end
end

function TheModdedInventory:Save()
    local str = json.encode({skin_queue = skin_queue, unlocked_skins = unlocked_skins})
    TheSim:SetPersistentString("moddedskins", str, false)
end

function TheModdedInventory:Load()
    TheSim:GetPersistentString("moddedskins", function(load_success, data) 
        if load_success and data ~= nil then
            local status, invdata = pcall( function() return json.decode(data) end )
            if status and invdata then
                skin_queue = invdata.skin_queue or {}
                unlocked_skins = invdata.unlocked_skins or {}
            else
                print("Faild to load TheModdedInventory!", status, invdata)
            end
        end
    end)
end

return TheModdedInventory()