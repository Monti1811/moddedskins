--Hornet: The code for implementing the glasses slot and etc is in it's own file because HOLY sh*t it's a lot of hooks.
--This thing's stability is balanced on a piece of graphite pulled out from a pencil. Any UI update and this thing will most likely break LOL.
--Atleast the rest of the mod will still work though!

--[[
TODO's

Unique offset for each character as their face x, y positions vary a lot(We gotta wait on Klei for this one)

The Player Avatar pop up, how... do we fit a glasses slot on there

Improve these overrides and make them into actual hooks, if a UI update happens, please check these over!!!:
Wardrobe.onclosepopup
]]

local env = env

local AddComponentPostInit = AddComponentPostInit
local AddClassPostConstruct = AddClassPostConstruct

_G.setfenv(1, _G)

--TODO, Hornet: Put in it's own util file ig, but I only need this here for now so.
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

CLOTHING.glasses_default1 =
{
    type = "glasses",
    skin_tags = {},
    is_default = true,
    release_group = 999,
}

CLOTHING_SYMBOLS["swap_face"] = true

require("components/skinner")

--Player Profile Saving
local PlayerProfile = require("playerprofile")
local _SetSkinsForCharacter = PlayerProfile.SetSkinsForCharacter
local _GetSkinsForCharacter = PlayerProfile.GetSkinsForCharacter

--Hornet: So we need to save our glasses and whatever other slots seperately because if you disable the mod and set outfit,
--the glasses are deleted, which makes it super annoying for when you re-enable MS and now you have to re-set your glasses.
--This way, our glasses are never touched by the vanilla game so they'll be there when you re-enable MS

function PlayerProfile:SetSkinsForCharacter(character, skinList, ...)
    if not self.persistdata.extra_character_skins then
		self.persistdata.extra_character_skins = {}
	end

	if not self.persistdata.extra_character_skins[character] then
		self.persistdata.extra_character_skins[character] = {}
	end

    if skinList ~= nil then
        local extraSlots = shallowcopy(skinList)
        self.persistdata.extra_character_skins[character] = { glasses = extraSlots.glasses }
    end

    _SetSkinsForCharacter(self, character, skinList, ...)
end

function PlayerProfile:GetSkinsForCharacter(character, ...)
    if not self.persistdata.extra_character_skins then
		self.persistdata.extra_character_skins = {}
	end

	if not self.persistdata.extra_character_skins[character] then
		self.persistdata.extra_character_skins[character] = {}
	end

    local skins = _GetSkinsForCharacter(self, character, ...)

    return MergeMaps(skins, self.persistdata.extra_character_skins[character])
end

--Global Hooks and Fn's

local _clothing_order = GetUpValue(SetSkinsOnAnim, "clothing_order")
table.insert(_clothing_order, 1, "glasses")

local _GetSkinsDataFromClientTableData = GetSkinsDataFromClientTableData
function GetSkinsDataFromClientTableData(data, ...)
	local ret = {_GetSkinsDataFromClientTableData(data, ...)}
	
	if ret[2] ~= nil then --ret[2] == clothing
		ret[2].glasses = data.glasses_skin or ""
	end
	
	return unpack(ret)
end

--Component Hooks and Fn's
local Skinner = require("components/skinner")
local Wardrobe = require("components/wardrobe")
local PlayerAvatarData = require("components/playeravatardata")

local _AddClothingData = PlayerAvatarData.AddClothingData

function PlayerAvatarData:AddClothingData(save, ...)
    _AddClothingData(self, save, ...)

    if self.skins ~= nil and self.skins.glasses_skin == nil then
        self.skins.glasses_skin = net_string(self.inst.GUID, "playeravatardata.glasses_skin")
    end
end
--
local _SetSkinMode = Skinner.SetSkinMode
local _GetClothing = Skinner.GetClothing

function Skinner:SetSkinMode(...)
    _SetSkinMode(self, ...)
    env.SendModRPCToClient(env.GetClientModRPC("ModdedSkins", "SetPlayerSkin"), nil, self.inst.userid, self.clothing["glasses"] or "")
end

function Skinner:GetClothing(...)
    local clothing = _GetClothing(self, ...)
    --
    clothing.glasses = self.clothing.glasses
    --
	return clothing
end
--
local _ApplySkins = Wardrobe.ApplySkins
local _ApplyTargetSkins = Wardrobe.ApplyTargetSkins

local _DoDoerChanging = GetUpValue(Wardrobe.ActivateChanging, "DoDoerChanging")

local newdiffdata = {} 
local _DoDoerChangingEnv = setmetatable({
    next = function(t, ...)
        t.glasses = newdiffdata.skins.glasses ~= nil and newdiffdata.skins.glasses ~= newdiffdata.old.glasses and newdiffdata.skins.glasses or nil
        newdiffdata = nil
        return next(t, ...)
    end
}, 
{__index = _G, __newindex = _G})

local function DoDoerChanging(self, doer, skins, ...)
    local old = doer.components.skinner:GetClothing()
    newdiffdata = {old = old, skins = skins}
    return _DoDoerChanging(self, doer, skins, ...)
end

setfenv(_DoDoerChanging, _DoDoerChangingEnv)
ReplaceUpValue(Wardrobe.ActivateChanging, "DoDoerChanging", DoDoerChanging)

--TODO, Bad!!! Overriding stinky!
AddComponentPostInit("wardrobe", function(self)
    self.onclosepopup = function(doer, data)
        if data.popup == POPUPS.WARDROBE then
            local skins = {
                base = data.args[1],
                body = data.args[2],
                hand = data.args[3],
                legs = data.args[4],
                feet = data.args[5],
                glasses = data.args[6],
            }
            self.onclosewardrobe(doer, skins)
        end
    end
end)

function Wardrobe:ApplySkins(doer, diff, ...)
	_ApplySkins(self, doer, diff, ...)
    --
	if doer.components.skinner ~= nil and diff.glasses ~= nil then
        doer.components.skinner:ClearClothing("glasses")
        if CLOTHING[diff.glasses] ~= nil then
            doer.components.skinner:SetClothing(diff.glasses)
        end
	end
end

function Wardrobe:ApplyTargetSkins(target, doer, skins, ...)
    _ApplyTargetSkins(self, target, doer, skins, ...)
    --
    if target.components.skinner ~= nil then
        target.components.skinner:SetClothing(skins.glasses)
    end
end

--gui fns
local ClothingExplorerPanel = require("widgets/redux/clothingexplorerpanel")
local TEMPLATES = require "widgets/redux/templates"
local GridWardrobePopupScreen = require("screens/redux/wardrobepopupgridloadout")
local GridScarecrowPopupScreen = require("screens/redux/scarecrowpopupgridloadout")
local SkinPresetsPopup = require("screens/redux/skinpresetspopup")
local WardrobeScreen = require("screens/redux/wardrobescreen")
local PlayerStatusScreen = require("screens/playerstatusscreen")
local LoadoutSelect = require("widgets/redux/loadoutselect")
local SkinsPuppet = require("widgets/skinspuppet")
local AccountItemFrame = require("widgets/redux/accountitemframe")
local PlayerBadge = require("widgets/playerbadge")
local ScarecrowClothingPopupScreen = require("screens/scarecrowclothingpopup")
local PlayerAvatarPopup = require("widgets/playeravatarpopup")
local DressUpPanel = require("widgets/dressuppanel")
local DressupAvatarPopup = require("widgets/dressupavatarpopup")
local Image = require "widgets/image"

--Scarecrow support... it uses the old UI... grr...
local _Layout = DressupAvatarPopup.Layout
local _UpdateData = DressupAvatarPopup.UpdateData
local _UpdateSkinWidgetForSlot = DressupAvatarPopup.UpdateSkinWidgetForSlot

function DressupAvatarPopup:Layout(data, ...)
    local widget_height = 75
    local body_offset = 95
    local line_offset = body_offset + 37
    local line_scale = 0.55
    local line_x_offset = 2
    --
    _Layout(self, data, ...)
    --
    self.frame:SetScale(.5, 1.2)
    self.frame_bg:SetScale(.29, .585)

    self.frame:Nudge(Vector3(0, -50, 0))
    self.frame_bg:Nudge(Vector3(0, 5, 0))

    self.glasses_image = self.proot:AddChild(self:CreateSkinWidgetForSlot())
    self.glasses_image:SetPosition(0, body_offset)
    self:UpdateSkinWidgetForSlot(self.glasses_image, "glasses", data.glasses_skin or "none")

    self.body_image:SetPosition(0, body_offset - widget_height)
    self.hand_image:SetPosition(0, body_offset - 2 * widget_height)
    self.legs_image:SetPosition(0, body_offset - 3 * widget_height)
    self.feet_image:SetPosition(0, body_offset - 4 * widget_height)
    --
    self.horizontal_line5 = self.proot:AddChild(Image("images/ui.xml", "line_horizontal_6.tex"))
    self.horizontal_line5:SetScale(line_scale, .25)
    self.horizontal_line5:SetPosition(line_x_offset, line_offset - 4 * widget_height)

    self.horizontal_line1:SetPosition(line_x_offset, line_offset)
    self.horizontal_line2:SetPosition(line_x_offset, line_offset - widget_height)
    self.horizontal_line3:SetPosition(line_x_offset, line_offset - 2 * widget_height)
    self.horizontal_line4:SetPosition(line_x_offset, line_offset - 3 * widget_height)

    if self.close_button ~= nil then
        self.close_button:Nudge(Vector3(0, -70, 0))
    end
end

function DressupAvatarPopup:UpdateData(data, ...)
    _UpdateData(self, data, ...)
    --
    if self.glasses_image ~= nil then
        self:UpdateSkinWidgetForSlot(self.glasses_image, "glasses", data.glasses_skin or "none")
    end
end

function DressupAvatarPopup:UpdateSkinWidgetForSlot(image_group, slot, skin_name)
    _UpdateSkinWidgetForSlot(self, image_group, slot, skin_name)
    --
    local skin_build = GetBuildForItem(skin_name)
    if (skin_build == nil or skin_build == "none") and slot == "glasses" then
        image_group._image:GetAnimState():OverrideSkinSymbol("SWAP_ICON", "glasses_default1", "SWAP_ICON")
    end
end
--

AddClassPostConstruct("screens/scarecrowclothingpopup", function(self)
    self.menu:Nudge(Vector3(0, -30, 0))
end)

function ScarecrowClothingPopupScreen:Close(apply_skins) --TODO, Hornet: Replacing for now
	local skins = self.dressup:GetSkinsForGameStart()

    local data = {}
    if apply_skins and (TheInventory:HasSupportForOfflineSkins() or TheNet:IsOnlineMode()) then
		data = skins
    end

    POPUPS.WARDROBE:Close(self.doer, data.base, data.body, data.hand, data.legs, data.feet, data.glasses)

    self.dressup:OnClose()
    TheFrontEnd:PopScreen(self)
end
--
local _GetSkinOptionsForSlot = DressUpPanel.GetSkinOptionsForSlot
local _DoFocusHookups = DressUpPanel.DoFocusHookups
local _GetClothingOptions = DressUpPanel.GetClothingOptions
local _SetPuppetSkins = DressUpPanel.SetPuppetSkins
local _SetDefaultSkinsForBase = DressUpPanel.SetDefaultSkinsForBase
local _GetSkinsForGameStart = DressUpPanel.GetSkinsForGameStart

AddClassPostConstruct("widgets/dressuppanel", function(self)
    local body_offset = -20
    local vert_scale = .66
    local option_height = 75
    local spinner_offset = -10
    local arrow_scale = .3
    local title_height = 190

    if TheNet:IsOnlineMode() then
        self.bg_group:SetScale(.6, .76) --orig .6, .6
        self.bg_group:Nudge(Vector3(0, -30, 0))

        self.dressup_bg:SetScale(-.66, -.84) --orig -.66, -.82

        self.puppet:SetPosition(10, title_height - 40)
        self.shadow:SetPosition(8, title_height - 45)

        self.glasses_spinner = self.spinners:AddChild(self:MakeSpinner("glasses"))
		self.glasses_spinner:SetPosition(0, body_offset + option_height + spinner_offset)
		self.glasses_spinner.spinner:SetArrowScale(arrow_scale)

        self.upper_horizontal_line:SetPosition(10, body_offset+2*option_height, 0)
        self.mid_horizontal_line1:SetPosition(10, body_offset+option_height, 0)
        self.mid_horizontal_line2:SetPosition(10, body_offset, 0)
        self.mid_horizontal_line3:SetPosition(10, body_offset-option_height, 0)
        self.mid_horizontal_line4:SetPosition(10, body_offset-2*option_height, 0)
        self.lower_horizontal_line:SetPosition(10, body_offset-3*option_height, 0)

        self.mid_horizontal_line5 = self.outline:AddChild(Image("images/ui.xml", "line_horizontal_5.tex"))
	    self.mid_horizontal_line5:SetScale(.19, .4)
	    self.mid_horizontal_line5:SetPosition(10, body_offset-4*option_height, 0)

        self.base_spinner:SetPosition(0, body_offset + spinner_offset)
        self.body_spinner:SetPosition(0, body_offset-option_height + spinner_offset)
        self.hand_spinner:SetPosition(0, body_offset-2*option_height + spinner_offset)
        self.legs_spinner:SetPosition(0, body_offset-3*option_height + spinner_offset)
        self.feet_spinner:SetPosition(0, body_offset-4*option_height + spinner_offset)

        self.left_vertical_line:SetScale(.45, vert_scale)
        self.right_vertical_line:SetScale(.45, vert_scale)

        self.left_vertical_line:Nudge(Vector3(0, -20, 0))
        self.right_vertical_line:Nudge(Vector3(0, -20, 0))

        table.insert(self.all_spinners, self.glasses_spinner)
    end
end)

function DressUpPanel:GetSkinOptionsForSlot(slot, ...)
    local skin_options = _GetSkinOptionsForSlot(self, slot, ...)

    if slot == "glasses" and skin_options[1].build == self.currentcharacter then
        skin_options[1].build = "glasses_default1"
    end

    return skin_options
end

function DressUpPanel:DoFocusHookups(...)
    if self.glasses_spinner and self.base_spinner then
        self.glasses_spinner:SetFocusChangeDir(MOVE_DOWN, self.base_spinner)
        self.base_spinner:SetFocusChangeDir(MOVE_UP, self.glasses_spinner)
    end
    --
    _DoFocusHookups(self, ...)
end

function DressUpPanel:GetClothingOptions(...)
    _GetClothingOptions(self, ...)
    --
    self.clothing_options["glasses"] = self.profile:GetClothingOptionsForType("glasses")
end

function DressUpPanel:SetPuppetSkins(skip_change_emote, ...)
    local glasses
    if self.glasses_spinner.GetItem() ~= "" then
		glasses = self.glasses_spinner.GetItem()
	end

    local _SetSkins = self.puppet.SetSkins
    function self.puppet:SetSkins(character, base, clothing, skipemote, ...)
        clothing["glasses"] = glasses
        _SetSkins(self, character, base, clothing, skipemote, ...)
    end
    --
    _SetPuppetSkins(self, skip_change_emote, ...)
    --
    self.puppet.SetSkins = _SetSkins
end

function DressUpPanel:SetDefaultSkinsForBase(skip_change_emote, ...)
    local _, random_base = self.base_spinner.GetItem()

	if random_base then
		self.glasses_spinner.spinner:SetSelectedIndex(1)
    else
        local skins = self.profile:GetSkinsForCharacter(self.currentcharacter)

		self.glasses_spinner.spinner:SetSelectedIndex(self.glasses_spinner:GetIndexForSkin(skins.glasses))
    end
    --
    _SetDefaultSkinsForBase(self, skip_change_emote, ...)
end

function DressUpPanel:GetSkinsForGameStart(...)
    local skins = _GetSkinsForGameStart(self, ...)

    if self.dressup_frame then
        local glasses = self.glasses_spinner.GetItem()

        if not IsValidClothing( skins.glasses ) then skins.glasses = "" end

        skins.glasses = glasses
		self.profile:SetSkinsForCharacter(self.currentcharacter, skins)
    end

    return skins
end
--
local _PlayerBadge_Set = PlayerBadge.Set

function PlayerBadge:SetGlasses(glasses)
    self:Set(self.prefabname, self.colour, self.ishost, self.userflags, self.base_skin, glasses)
end

--Hornet: Glasses are the first actual clothing item that show up on the head, so they need to show up for playerbadges unlike the other clothing!
function PlayerBadge:Set(prefab, colour, ishost, userflags, base_skin, glasses_skin, ...) --TODO, Hornet: Update if the parameters for this ever are.
    self.colour = colour

    _PlayerBadge_Set(self, prefab, colour, ishost, userflags, base_skin, glasses_skin, ...)

    local dirty = false
    --Hornet: Set() is being called twice, once in vanilla, once here, and so glasses_skin will be nil in the first call, so make sure that glasses_skin isnt nil
    if self.glasses_skin ~= glasses_skin and not (glasses_skin == nil) then
        self.glasses_skin = glasses_skin
        dirty = true
    end

    if dirty then
        if not self:UseAvatarImage() then
            local _, _, skin_mode, _, _ = GetPlayerBadgeData( prefab, self:IsGhost(), self:IsCharacterState1(), self:IsCharacterState2(), self:IsCharacterState3() )

            local skindata = GetSkinData(base_skin or self.prefabname.."_none")
            local base_build = self.prefabname
            if skindata.skins ~= nil then
                base_build = skindata.skins[skin_mode]
            end
            SetSkinsOnAnim( self.head_animstate, self.prefabname, base_build, {glasses = self.glasses_skin}, nil, skin_mode)
        end
    end
end

--
local _PlayerStatusScreen_OnUpdate = PlayerStatusScreen.OnUpdate

function PlayerStatusScreen:OnUpdate(dt, ...)
    _PlayerStatusScreen_OnUpdate(self, dt, ...)

    if TheFrontEnd:GetFadeLevel() > 0 then return end
    if self.time_to_refresh > dt then return end

    if self.scroll_list ~= nil then
        local ClientObjs = TheNet:GetClientTable() or {}

        for _,playerListing in ipairs(self.player_widgets) do
            for _,client in ipairs(ClientObjs) do
                if playerListing.userid == client.userid and playerListing.ishost == (client.performance ~= nil) then
                    local client_table = TheNet:GetClientTableForUser(client.userid)
	                if client_table ~= nil then
		                local _, clothing, _, _, _= GetSkinsDataFromClientTableData(client_table)
                        playerListing.characterBadge:SetGlasses(clothing.glasses)
                    end
                end
            end
        end
    end
end
--
local SkinPresetsPopup_constructor = SkinPresetsPopup._ctor
SkinPresetsPopup._ctor = function(self, ...)
	local _ScrollingGrid = TEMPLATES.ScrollingGrid
    function TEMPLATES.ScrollingGrid(items, opts, ...)
        opts.widget_width = opts.widget_width + 30
        local _item_ctor_fn = opts.item_ctor_fn
        opts.item_ctor_fn = function(context, i, ...)
            local item = _item_ctor_fn(context, i, ...)

            item.glasses_icon = item.root:AddChild( AccountItemFrame() )
            item.glasses_icon:SetStyle_Normal()
            item.glasses_icon:SetScale(0.4)

            if not table.contains(DST_CHARACTERLIST, self.character) then
				print(self.character)
				item.base_icon = item.root:AddChild( AccountItemFrame() )
	            item.base_icon:SetStyle_Normal()
	            item.base_icon:SetScale(0.4)

            	item.root:SetPosition(20,0)
			end

            local x_start = -145

            item.glasses_icon:SetPosition(x_start + -1 * 50,0)
            item.base_icon:SetPosition(x_start + 0 * 50,0)
            item.body_icon:SetPosition(x_start + 1 * 50,0)
            item.hand_icon:SetPosition(x_start + 2 * 50,0)
            item.legs_icon:SetPosition(x_start + 3 * 50,0)
            item.feet_icon:SetPosition(x_start + 4 * 50,0)

            item.row_label:SetPosition(-230,-1)

            return item
        end

        local _apply_fn = opts.apply_fn
        opts.apply_fn = function(context, item, data, index, ...)
            _apply_fn(context, item, data, index, ...)

            if data then
                if not table.contains(DST_CHARACTERLIST, self.character) then
                    if data.base then
                        item.base_icon:SetItem(data.base)
                    else
                        item.base_icon:SetItem(self.character.."_none")
                    end
                end

                if data.glasses then
                    item.glasses_icon:SetItem(data.glasses)
                else
                    item.glasses_icon:SetItem("glasses_default1" )
                end
            end
        end

        return _ScrollingGrid(items, opts, ...)
    end
    --
	SkinPresetsPopup_constructor(self, ...)
    --
    TEMPLATES.ScrollingGrid = _ScrollingGrid
end
--
AddClassPostConstruct("screens/redux/wardrobepopupgridloadout", function(self)
    local client_table = TheNet:GetClientTableForUser(ThePlayer.userid)
	if client_table ~= nil then
		local base_skin, clothing, _, _, _= GetSkinsDataFromClientTableData(client_table)

		self.initial_skins = { base = base_skin, body = clothing.body, feet = clothing.feet, hand = clothing.hand, legs = clothing.legs, glasses = clothing.glasses }
	else
		self.initial_skins = {}
	end

    self.profile:SetSkinsForCharacter(self.owner_player.prefab, self.initial_skins)
    self.loadout:_LoadSavedSkins()
end)

AddClassPostConstruct("screens/redux/scarecrowpopupgridloadout", function(self)
    local client_table = self.owner_scarecrow.components.playeravatardata and self.owner_scarecrow.components.playeravatardata:GetData() or nil
	if client_table ~= nil then
		local base_skin, clothing, _, _, _= GetSkinsDataFromClientTableData(client_table)

		self.initial_skins = { base = base_skin, body = clothing.body, feet = clothing.feet, hand = clothing.hand, legs = clothing.legs, glasses = clothing.glasses }
	else
		self.initial_skins = {}
	end

    self.profile:SetSkinsForCharacter(self.owner_scarecrow.prefab, self.initial_skins)
    self.loadout:_LoadSavedSkins()
end)

local glassesclosedata

local _Close = POPUPS.WARDROBE.Close

local _GridWardrobePopupScreen_Close = GridWardrobePopupScreen.Close
local _GridScarecrowPopupScreen_Close = GridScarecrowPopupScreen.Close

function POPUPS.WARDROBE:Close(inst, ...)
    local data = {...}
    table.insert(data, glassesclosedata)
    glassesclosedata = nil
    return _Close(self, inst, unpack(data))
end

local function CommonPopupClose(self)
    local skins = self.loadout.selected_skins
    if TheInventory:HasSupportForOfflineSkins() or TheNet:IsOnlineMode() then
		glassesclosedata = skins.glasses
    end
    if not IsValidClothing( glassesclosedata ) or not TheInventory:CheckOwnership(glassesclosedata) then glassesclosedata = "" end
end

function GridWardrobePopupScreen:Close(...)
    CommonPopupClose(self)
    return _GridWardrobePopupScreen_Close(self, ...)
end

function GridScarecrowPopupScreen:Close(...)
    CommonPopupClose(self)
    return _GridScarecrowPopupScreen_Close(self, ...)
end
--
local _SetSkins = SkinsPuppet.SetSkins
local _DoIdleEmote = SkinsPuppet.DoIdleEmote

local change_delay_time = .5
local _change_emotes = GetUpValue(SkinsPuppet.DoChangeEmote, "change_emotes")
local noglasses_emotes = deepcopy(_change_emotes)

_change_emotes.glasses = { "emote_glasses" }

function SkinsPuppet:SetSkins(prefabname, base_item, clothing_names, skip_change_emote, skinmode, monkey_curse, ...)
    if not skip_change_emote then
        if self.play_non_idle_emotes and (self.queued_change_slot == "" or self.time_to_change_emote < change_delay_time ) then
			--Hornet: Only run this animation if we actually equipped glasses!
			if self.last_skins.glasses ~= clothing_names.glasses and (clothing_names.glasses ~= nil or self.animstate:BuildHasSymbol("swap_face")) then
				self.queued_change_slot = "glasses"
            end
        end
    end

    _SetSkins(self, prefabname, base_item, clothing_names, skip_change_emote, skinmode, monkey_curse, ...)

    self.last_skins.glasses = clothing_names.glasses
end

function SkinsPuppet:DoIdleEmote(...)
	local _add_change_emote_for_idle = self.add_change_emote_for_idle

	--Only characters with glasses can do the animation!
	if self.add_change_emote_for_idle and (self.last_skins.glasses == nil or not self.animstate:BuildHasSymbol("swap_face"))then
		--Hornet: WE Don't want to do the 80% chance roll again if we already did it.
		self.add_change_emote_for_idle = false
		local r = math.random()
		if r > 0.8 then
			self.queued_change_slot = GetRandomKey(noglasses_emotes)
			self:DoChangeEmote()
			return
		end
	end
	
	local ret = {_DoIdleEmote(self, ...)}
	
	self.add_change_emote_for_idle = _add_change_emote_for_idle
	
	return unpack(ret)
end

local LobbyScreen = require("screens/redux/lobbyscreen")

local _ToNextPanel = LobbyScreen.ToNextPanel

function LobbyScreen:ToNextPanel(dir, ...)
	local ret = {_ToNextPanel(self, dir, ...)}

	if self.panel ~= nil and self.panel.name == "LoadoutPanel" then --OOF!
		local owner = self
		local _OnNextButton = self.panel.OnNextButton
		function self.panel:OnNextButton(...) --Hornet: Yikes!
			local ret = {_OnNextButton(self, ...)}
			
			local skins = owner.currentskins or {}
			if GetGameModeProperty("lobbywaitforallplayers") and owner.lobbycharacter ~= "random" then
				env.SendModRPCToServer(env.GetModRPC("ModdedSkins", "SetPlayerSkinServer"), skins.glasses or "")
			end

			return unpack(ret)
		end
	end

	return unpack(ret)
end

AddClassPostConstruct("screens/redux/lobbyscreen", function(self)
	local _cb = self.cb
	if _cb ~= nil then
		self.cb = function(char, skin_base, clothing_body, clothing_hand, clothing_legs, clothing_feet, ...)
            --Hornet: People in bad times are lead to bad places. Forgive me, o' lord.
            local skins = self.currentskins or {}

            local _Fade = FrontEnd.Fade
            function FrontEnd:Fade(in_or_out, time_to_take, fn, fade_delay_time, delayovercb, fadeType, ...)
                local _fn = fn
                fn = function(...)
                    _fn(...)
                    env.SendModRPCToServer(env.GetModRPC("ModdedSkins", "SetSkinInfo"), skin_base, skins.glasses)
                end
                _Fade(self, in_or_out, time_to_take, fn, fade_delay_time, delayovercb, fadeType, ...)
            end
            --
			_cb(char, skin_base, clothing_body, clothing_hand, clothing_legs, clothing_feet, ...)
            --
            FrontEnd.Fade = _Fade
		end
	end
end)
--
local __MakeMenu = WardrobeScreen._MakeMenu
local __UpdateMenu = WardrobeScreen._UpdateMenu
local _ApplySkinPresets = WardrobeScreen.ApplySkinPresets

AddClassPostConstruct("screens/redux/wardrobescreen", function(self)
	local reader = function(item_key)
        return table.contains(self.selected_skins, item_key)
    end
    local writer_builder = function(item_type)
        return function(item_data)
            self:_SelectSkin(item_type, item_data.item_key, item_data.is_active, item_data.is_owned)
        end
    end

	if self.subscreener ~= nil then
		self.subscreener.sub_screens.glasses = self.root:AddChild(ClothingExplorerPanel(self, self.user_profile, "glasses", reader, writer_builder("glasses")))

		self:_LoadSavedSkins()
		self.subscreener:OnMenuButtonSelected("base")
	else
		print("Modded Skins Warning: The subscreener in wardrobescreen doesn't exist?!?!?")
	end
end)

function WardrobeScreen:_MakeMenu(subscreener, ...)
	local menu = __MakeMenu(self, subscreener, ...)

	self.button_glasses = subscreener:WardrobeButton(STRINGS.UI.WARDROBESCREEN.GLASSES, "glasses", STRINGS.UI.WARDROBESCREEN.TOOLTIP_GLASSES, self.tooltip)

	menu:AddCustomItem(self.button_glasses)

	self.tooltip:Nudge(Vector3(0, -65, 0))
	menu:Nudge(Vector3(0, -65, 0))

	return menu
end

function WardrobeScreen:_UpdateMenu(skins, ...)
    if self.button_glasses then
        if skins["glasses"] then
            self.button_glasses:SetItem(skins["glasses"])
        else
            self.button_glasses:SetItem("glasses_default1")
        end
    end
	__UpdateMenu(self, skins, ...)
end

function WardrobeScreen:ApplySkinPresets(skins, ...)
    if skins.glasses == nil then
        skins.glasses = "glasses_default1"
    end
	_ApplySkinPresets(self, skins, ...)
end

--
local _LoadoutMakeMenu = LoadoutSelect._MakeMenu
local _LoadoutApplySkinPresets = LoadoutSelect.ApplySkinPresets
local _Loadout_UpdateMenu = LoadoutSelect._UpdateMenu

AddClassPostConstruct("widgets/redux/loadoutselect", function(self)
	local reader = function(item_key)
        return table.contains(self.selected_skins, item_key)
    end
    local writer_builder = function(item_type)
        return function(item_data)
            self:_SelectSkin(item_type, item_data.item_key, item_data.is_active, item_data.is_owned)
        end
    end

	if self.subscreener ~= nil then
		local filter_options = {}
        filter_options.ignore_hero = not self.have_base_option

		self.subscreener.sub_screens.glasses = self.loadout_root:AddChild(ClothingExplorerPanel(self, self.user_profile, "glasses", reader, writer_builder("glasses"), filter_options))
		self.subscreener.sub_screens.glasses:SetScale(0.85)
		self.subscreener.sub_screens.glasses:SetPosition(130, -10)

		if self.currentcharacter == "scarecrow" then
			self.subscreener.menu:SetPosition(375, 315)
		else
			self.subscreener.menu:SetPosition(315, 315)
		end
		
		if self.presetsbutton ~= nil then
			self.presetsbutton:Nudge(Vector3(-60, 0, 0))
		end

		if self.itemskinsbutton ~= nil then
			self.itemskinsbutton:Nudge(Vector3(-60, 0, 0))
		end
	end
end)

function LoadoutSelect:_MakeMenu(subscreener, ...)
	local menu = _LoadoutMakeMenu(self, subscreener, ...)

	--Hornet: I. LOVE. UI. MODDING!!!!!!!!!!!!
    --Frankly this is kinda useless as a 'hook', we're replacing everything anyways lol.
    --But i'm committed!
	self.button_glasses = subscreener:WardrobeButtonMinimal("glasses")
	self.button_body = subscreener:WardrobeButtonMinimal("body")
    self.button_hand = subscreener:WardrobeButtonMinimal("hand")
    self.button_legs = subscreener:WardrobeButtonMinimal("legs")
    self.button_feet = subscreener:WardrobeButtonMinimal("feet")

	local menu_items = nil
    if self.have_base_option then
		self.button_base = subscreener:WardrobeButtonMinimal("base")
        menu_items =
        {
            {widget = self.button_glasses },
            {widget = self.button_base },
            {widget = self.button_body },
            {widget = self.button_hand },
            {widget = self.button_legs },
            {widget = self.button_feet },
        }
    else
        menu_items =
        {
            {widget = self.button_glasses },
            {widget = self.button_body },
            {widget = self.button_hand },
            {widget = self.button_legs },
            {widget = self.button_feet },
        }
    end

	menu:Clear()

	for k,v in ipairs(menu_items) do
		menu:AddCustomItem(v.widget)
	end

	self:_UpdateMenu(self.selected_skins)

	return menu
end

function LoadoutSelect:ApplySkinPresets(skins, ...)
    if skins.glasses == nil then
        skins.glasses = "glasses_default1"
    end
	_LoadoutApplySkinPresets(self, skins, ...)
end

function LoadoutSelect:_UpdateMenu(skins, ...)
    if self.button_glasses then
        if skins["glasses"] then
            self.button_glasses:SetItem(skins["glasses"])
        else
            self.button_glasses:SetItem("glasses_default1")
        end
    end
	_Loadout_UpdateMenu(self, skins, ...)
end