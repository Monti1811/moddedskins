local env = env
local AddClassPostConstruct = AddClassPostConstruct
local AddComponentPostInit = AddComponentPostInit
local AddPrefabPostInit = AddPrefabPostInit
local AddPlayerPostInit = AddPlayerPostInit
local AddStategraphPostInit = AddStategraphPostInit
local AddSimPostInit = AddSimPostInit

_G.setfenv(1, _G)

local function GetUpValue(func, varname)
	local i = 1
	local n, v = debug.getupvalue(func, 1)
	while v ~= nil do
		if n == varname then
			return v
		end
		i = i + 1
		n, v = debug.getupvalue(func, i)
	end
end

local function ReplaceUpValue(func, varname, newvalue)
	local i = 1
	local n, v = debug.getupvalue(func, 1)
	while v ~= nil do
		if n == varname then
			debug.setupvalue(func, i, newvalue)
			return
		end
		i = i + 1
		n, v = debug.getupvalue(func, i)
	end
end

local Builder = require("components/builder")
local _EvaluateTechTrees = Builder.EvaluateTechTrees

function Builder:EvaluateTechTrees(...)
    _EvaluateTechTrees(self, ...)
 
    if self.inst.components.moddedgiftreceiver ~= nil then
        self.inst.components.moddedgiftreceiver:SetGiftMachine(
            self.current_prototyper ~= nil and
            self.current_prototyper:HasTag("moddedgiftmachine") and
            CanEntitySeeTarget(self.inst, self.current_prototyper) and
            self.inst.components.inventory.isopen and
            self.current_prototyper or
            nil)
    end
end

-- Fox: Applying skins doesn't work for modded items
-- So... we just run system very similar to Klei's, but from the lua side!
local ApplyModdedSkin = env.ApplyModdedSkin

local _SpawnPrefab = SpawnPrefab
function SpawnPrefab(name, skin, ...)
	local ent = _SpawnPrefab(name, skin, ...)

	if ent and skin and env.IsModdedSkin(skin) then
		name = name:gsub("_placer", "")

		ApplyModdedSkin(ent, name, skin)
	end

	return ent
end

-- Fox: Same story here: the game saves skins on the engine side and applies them through global fns, so we just save them in onsave
env.AddGlobalClassPostConstruct("entityscript", "EntityScript", function(self)
	local _GetPersistData, _SetPersistData = self.GetPersistData, self.SetPersistData
	function self:GetPersistData(...)
		local val = {_GetPersistData(self, ...)}

		if self.moddedskinname then
			if not val[1] then
				val[1] = {}
			end
			val[1].moddedskinname = self.moddedskinname
		end

		return unpack(val)
	end

	function self:SetPersistData(data, ...)
		_SetPersistData(self, data, ...)
		if data and data.moddedskinname then
			ApplyModdedSkin(self, self.prefab, data.moddedskinname)
		end
	end
end)

--Hornet: Gotta get GetSkinBuild to return the modded skin build!
MODDEDSKIN_BUILDS = {} --e.g. [self.AnimState] = netvar

local _AddAnimState = Entity.AddAnimState
local _GetSkinBuild = AnimState.GetSkinBuild
local _Remove = EntityScript.Remove

function Entity:AddAnimState(...)
	local guid = self:GetGUID()
	local inst = Ents[guid]
	local hasanimstate = inst.AnimState
	local animstate = _AddAnimState(self, ...)

	if inst and not hasanimstate then
		MODDEDSKIN_BUILDS[animstate] = net_string(guid, "moddedskins.build")
	end
	
	return animstate
end

function AnimState:GetSkinBuild(...)
	return (MODDEDSKIN_BUILDS[self]:value() ~= "" and MODDEDSKIN_BUILDS[self]:value()) or _GetSkinBuild(self, ...)
end

function EntityScript:Remove(...)
    if self.AnimState then
        MODDEDSKIN_BUILDS[self.AnimState] = nil
    end
    return _Remove(self, ...)
end

--Adding nessacary gift stuff for Prestihatitator and Shadow Manipulator
local magic_stations = {"researchlab3", "researchlab4"}
local giftsound = "science" --temporary, we need custom sounds for presthatitator and manipulator gift opening(well we dont NEED,
-- but the little details matter :) )

local function isgifting(inst)
    for k, v in pairs(inst.components.prototyper.doers) do
        if k.components.moddedgiftreceiver ~= nil and
            k.components.moddedgiftreceiver:HasGift() and
            k.components.moddedgiftreceiver.giftmachine == inst then
            return true
        end
    end
end

local function doneact(inst)
    inst._activetask = nil
    if not inst:HasTag("burnt") then
        if inst.components.prototyper.on then
            inst.components.prototyper.onturnon(inst)
        else
            inst.components.prototyper.onturnoff(inst)
        end
    end
end

local function ongiftopened(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("gift")

        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_"..giftsound.."_gift_recieve")
        if inst._activetask ~= nil then
            inst._activetask:Cancel()
        end
        inst._activetask = inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 2 * FRAMES, doneact)
    end
end

local function refreshonstate(inst)
    if not inst:HasTag("burnt") and inst.components.prototyper.on then
        inst.components.prototyper.onturnon(inst)
    end
end

for k, v in pairs(magic_stations) do
    AddPrefabPostInit(v, function(inst)
        inst:AddTag("moddedgiftmachine")
		
		inst.AnimState:AddOverrideBuild(v.."_gift")

        if not TheWorld.ismastersim then
            return
        end
		
		local _onturnon = inst.components.prototyper.onturnon
		inst.components.prototyper.onturnon = function(inst, ...)
			_onturnon(inst, ...)

			--Gift proximity loop animation
			if inst._activetask == nil and not inst:HasTag("burnt") then
				if isgifting(inst) then
					if inst.AnimState:IsCurrentAnimation("proximity_gift_loop") or
						inst.AnimState:IsCurrentAnimation("place") then
						inst.AnimState:PushAnimation("proximity_gift_loop", true)
					else
						inst.AnimState:PlayAnimation("proximity_gift_loop", true)
					end
					if not inst.SoundEmitter:PlayingSound("loop") then
						inst.SoundEmitter:KillSound("idlesound")
						inst.SoundEmitter:PlaySound("dontstarve/common/research_machine_gift_active_LP", "loop")
					end
				end
			end
		end
		
		local _onturnoff = inst.components.prototyper.onturnoff
		inst.components.prototyper.onturnoff = function(inst, ...)
			_onturnoff(inst, ...)

			inst.SoundEmitter:KillSound("loop")
		end
		
		inst:AddComponent("wardrobe")
        inst.components.wardrobe:SetCanUseAction(false) --also means NO wardrobe tag!
        inst.components.wardrobe:SetCanBeShared(true)
        inst.components.wardrobe:SetRange(TUNING.RESEARCH_MACHINE_DIST + .1)
        
        inst:ListenForEvent("ms_addgiftreceiver", refreshonstate)
        inst:ListenForEvent("ms_removegiftreceiver", refreshonstate)
        inst:ListenForEvent("ms_giftopened", ongiftopened)
    end)
end

--Player classified stuff for modded gifts

local function OnModdedGiftsDirty(inst)
    if inst._parent ~= nil and inst._parent.HUD ~= nil then
        inst._parent:PushEvent("moddedgiftreceiverupdate", {
            numitems = inst.hasmoddedgift:value() and 1 or 0,
            active = inst.hasmoddedgiftmachine:value(),
        })
    end
end

AddPrefabPostInit("player_classified", function(inst)
	--ModdedGiftReceiver Variables
	inst.hasmoddedgift = net_bool(inst.GUID, "moddedgiftreceiver.hasmoddedgift", "moddedgiftsdirty")
    inst.hasmoddedgiftmachine = net_bool(inst.GUID, "moddedgiftreceiver.hasmoddedgiftmachine", "moddedgiftsdirty")
	
	inst:DoTaskInTime(0, function()
		inst:ListenForEvent("moddedgiftsdirty", OnModdedGiftsDirty)
		OnModdedGiftsDirty(inst)
	end)
end)

--Add ModdedGiftReceiver to players
AddPlayerPostInit(function(inst)
	if not TheWorld.ismastersim then
		return
	end
	
	if not GetGameModeProperty("hide_received_gifts") then --TODO, Hornet: make this compatible with that one mod that allows gifts in forge and gorge(?) -- Fox: That's my mod!
		inst:AddComponent("moddedgiftreceiver")
	end
end)

AddStategraphPostInit("wilson", function(sg)
	local opengift = sg.states["opengift"]
	if opengift ~= nil then
		local _onenter = opengift.onenter
		opengift.onenter = function(inst, ...)
			inst.AnimState:ClearOverrideSymbol("giftbox")
			inst.AnimState:ClearOverrideSymbol("tear_fx")
			inst.AnimState:AddOverrideBuild("player_receive_gift")

			if inst.components.moddedgiftreceiver ~= nil then
				if inst.components.moddedgiftreceiver.openingmodgift then
					inst.AnimState:OverrideSymbol("giftbox", "player_receive_moddedgift", "giftbox")
					inst.AnimState:OverrideSymbol("tear_fx", "player_receive_moddedgift", "tear_fx")
					
					env.SendModRPCToClient(env.GetClientModRPC("ModdedSkins", "IsOpeningModGift"), inst.userid, true)
					
					inst.components.moddedgiftreceiver.openingmodgift = false
				end
                inst.components.moddedgiftreceiver:OnStartOpenGift()
            end
			
			if _onenter ~= nil then
				_onenter(inst, ...)
			end
		end

		local _doneopengift = opengift.events["ms_doneopengift"] ~= nil and opengift.events["ms_doneopengift"].fn
		
		if _doneopengift ~= nil then
			opengift.events["ms_doneopengift"].fn = function(inst, data)
				if data.wardrobe == nil then data.wardrobe = inst.components.moddedgiftreceiver.giftmachine end
				_doneopengift(inst, data)
			end
		end
	end
end)

--Fix for players loading in

--Is this code even still needed?....
local Skinner = require("components/skinner")
local _Skinner_OnLoad = Skinner.OnLoad

function Skinner:OnLoad(data, ...)
	_Skinner_OnLoad(self, data, ...)
	
	if not table.contains(DST_CHARACTERLIST, self.inst.prefab) and data.skin_name ~= nil then
		self:SetSkinName(data.skin_name)
	end
end

--Allowing to adjust scale and offset for clean sweeper effect (I LOVE LOCAL VARIABLES)
RESKIN_FX_INFO = {} --e.g. eyeball_turret = {offset = 2, scale = 1.6}

AddSimPostInit(function()
	if Prefabs["reskin_tool"] == nil then return end
	
	local _spellCB = GetUpValue(Prefabs["reskin_tool"].fn, "spellCB")
	if _spellCB == nil then return end
	
	local _reskin_fx_info = GetUpValue(_spellCB, "reskin_fx_info")
	for pref, data in pairs(RESKIN_FX_INFO) do
		_reskin_fx_info[pref] = data
	end
end)