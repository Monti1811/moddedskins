local function OnUpdateGiftItems(inst)
    inst.components.moddedgiftreceiver:RefreshGiftCount()
end

local function OnInit(inst, delay)
    if delay > 0 then
        inst:DoTaskInTime(0, OnInit, delay - 1)
    else
        OnUpdateGiftItems(inst)
    end
end

local function ongiftcount(self, giftcount)
    if self.inst.player_classified ~= nil then
        self.inst.player_classified.hasmoddedgift:set(giftcount > 0)
    end
end

local function ongiftmachine(self, giftmachine)
    if self.inst.player_classified ~= nil then
        self.inst.player_classified.hasmoddedgiftmachine:set(giftmachine ~= nil)
    end
end

local function OnReceiveGiftCount(inst)
	local self = inst.components.moddedgiftreceiver
	if self.newgiftcount ~= nil then
		local giftcount = self.newgiftcount
		if giftcount ~= self.giftcount then
			local old = self.giftcount
			self.giftcount = giftcount
			if self.giftmachine ~= nil then
				if giftcount > 0 then
					if old <= 0 then
						self.giftmachine:PushEvent("ms_addgiftreceiver", self.inst)
					end
				elseif old > 0 then
					self.giftmachine:PushEvent("ms_removegiftreceiver", self.inst)
				end
			end
		end
		
		self.newgiftcount = nil
	end
	self.inst:RemoveEventCallback("receivedmoddedgiftcount", OnReceiveGiftCount)
end

local ModdedGiftReceiver = Class(function(self, inst) --Hornet: easier to just make a new component imo
    self.inst = inst

    self.giftcount = 0
    self.giftmachine = nil

    self.onclosepopup = function(doer, data)
        if data.popup == POPUPS.GIFTITEM then
            self.should_open_wardrobe = data.args[1]
            --self:OnStopOpenGift(data.args[1])
        end
    end
    inst:ListenForEvent("ms_closepopup", self.onclosepopup)
    --Delay init because a couple frames to wait for userid set
    inst:DoTaskInTime(0, OnInit, 1)
end,
nil,
{
    giftcount = ongiftcount,
    giftmachine = ongiftmachine,
})

function ModdedGiftReceiver:OnRemoveFromEntity()
    inst:RemoveEventCallback("ms_closepopup", self.onclosepopup)
    inst:RemoveEventCallback("ms_updategiftitems", OnUpdateGiftItems)
end

function ModdedGiftReceiver:HasGift()
    return self.giftcount > 0
end

function ModdedGiftReceiver:RefreshGiftCount()
	SendModRPCToClient(GetClientModRPC("ModdedSkins", "GetClientGiftCount"), self.inst.userid)
	self.inst:ListenForEvent("receivedmoddedgiftcount", OnReceiveGiftCount)
end

function ModdedGiftReceiver:SetGiftMachine(inst)
    if self.giftmachine ~= inst then
        local old = self.giftmachine
        self.giftmachine = inst
        if self.giftcount > 0 then
            if old ~= nil then
                old:PushEvent("ms_removegiftreceiver", self.inst)
            end
            if inst ~= nil then
                inst:PushEvent("ms_addgiftreceiver", self.inst)
            end
        end
        if inst == nil then
            self:OnStopOpenGift()
        end
    end
end

function ModdedGiftReceiver:OpenNextGift()
    if self.giftcount > 0 and self.giftmachine ~= nil then
        self.inst:PushEvent("ms_opengift")
		self.openingmodgift = true
    end
end

function ModdedGiftReceiver:OnStartOpenGift()
    if self.giftmachine ~= nil then
        self.giftmachine:PushEvent("ms_giftopened")
    end
end

function ModdedGiftReceiver:OnStopOpenGift(usewardrobe)
    self.inst:PushEvent("ms_doneopengift", usewardrobe and { wardrobe = self.giftmachine } or nil)
end

return ModdedGiftReceiver