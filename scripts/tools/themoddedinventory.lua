local skin_queue = {}
local unlocked_skins = {}
--Add a new table for skins that are only unlocked in this world
local unlocked_skins_sessions = {}

local TheModdedInventory = Class(function(self)
    self.conditions = {}
	self.isopeningmodgift = false
    self.session_id = TheNet:GetSessionIdentifier()
    unlocked_skins_sessions[self.session_id] = {}

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
    return unlocked_skins[skin_id] ~= nil or (unlocked_skins_sessions[self.session_id] ~= nil and unlocked_skins_sessions[self.session_id][skin_id] ~= nil)
end

local function MakeClientOwned(self, skin_id)
    local condition = self.conditions[skin_id]
    if condition.session_specific then
        unlocked_skins_sessions[self.session_id][skin_id] = true
    else
        unlocked_skins[skin_id] = true
    end
    SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, true)
    -- Add a post_fn which gives the ability to unlock other gifts at the same time
    -- or for other things
    if condition.post_fn ~= nil then
        condition.post_fn()
    end
end

function TheModdedInventory:UnlockSkin(skin_id)
    local condition = self.conditions[skin_id]
    if condition then
        if condition.no_gift then
            MakeClientOwned(self, skin_id)
        else
            -- Should only be added if a world specific skin hasn't been unlocked
            local should_add_to_queue = condition.session_specific and not
                (unlocked_skins_sessions[self.session_id] ~= nil and unlocked_skins_sessions[self.session_id][skin_id]) or not unlocked_skins[skin_id]
            if should_add_to_queue then --Let's not take a step backwards if the gift's been opened
                skin_queue[skin_id] = true
                SendModRPCToServer(GetModRPC("ModdedSkins", "RefreshModGiftCount"))
            end
        end
    end
	self:Save()
end

function TheModdedInventory:OpenGift(skin_id)
    if skin_queue[skin_id] then
        skin_queue[skin_id] = nil

        MakeClientOwned(self, skin_id)

		self.isopeningmodgift = false
		self:Save()
        return true
    end
end

function TheModdedInventory:LockSkin(skin_id) --TODO only send rpc is skin is in skin queue, no need to send the rpc if its only in the unlocked_skins
    skin_queue[skin_id] = nil
    local condition = self.conditions[skin_id]
    if condition.session_specific then
        unlocked_skins_sessions[self.session_id][skin_id] = nil
    else
        unlocked_skins[skin_id] = nil
    end
	SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, false)
	SendModRPCToServer(GetModRPC("ModdedSkins", "RefreshModGiftCount"))
	self:Save()
end

function TheModdedInventory:SetClientOwnedSkins()
    for skin_id, unlocked in pairs(unlocked_skins) do
        -- Check if skins have the session_specific condition and only mark them as owned
        -- if they are owned in unlocked_skins_sessions[self.session_id]
        if CLIENT_MOD_RPC["ModdedSkins"] and not (self.conditions[skin_id] and self.conditions[skin_id].session_specific) then
            SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, unlocked)
        end
    end
    for skin_id, unlocked in pairs(unlocked_skins_sessions[self.session_id]) do
        if CLIENT_MOD_RPC["ModdedSkins"] then
            SendModRPCToServer(GetModRPC("ModdedSkins", "SetClientOwned"), skin_id, unlocked)
        end
    end
end

function TheModdedInventory:Save()
    local str = json.encode({skin_queue = skin_queue, unlocked_skins = unlocked_skins, unlocked_skins_sessions = unlocked_skins_sessions})
    TheSim:SetPersistentString("moddedskins", str, false)
end

function TheModdedInventory:Load()
    TheSim:GetPersistentString("moddedskins", function(load_success, data) 
        if load_success and data ~= nil then
            local status, invdata = pcall( function() return json.decode(data) end )
            if status and invdata then
                skin_queue = invdata.skin_queue or {}
                unlocked_skins = invdata.unlocked_skins or {}
                unlocked_skins_sessions = invdata.unlocked_skins_sessions or {}
                unlocked_skins_sessions[self.session_id] = unlocked_skins_sessions[self.session_id] or {}
            else
                print("Failed to load TheModdedInventory!", status, invdata)
            end
        end
    end)
end

return TheModdedInventory()