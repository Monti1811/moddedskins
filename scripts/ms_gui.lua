local env = env
local AddClassPostConstruct = AddClassPostConstruct
local AddSimPostInit = AddSimPostInit

_G.setfenv(1, _G)

require("misc_items")

local Menu = require "widgets/menu"
local TEMPLATES = require "widgets/redux/templates"
local PlayerHud = require "screens/playerhud"
local GiftItemPopUp = require "screens/giftitempopup"

local AccountItemFrame = require("widgets/redux/accountitemframe")
local LoadoutSelect = require("widgets/redux/loadoutselect")
local ItemImage = require("widgets/itemimage")
local Menu = require "widgets/menu"
local ModSkinUnlockScreen = require("screens/modskinunlockscreen")
local ItemExplorer = require("widgets/redux/itemexplorer")
local GiftItemToast = require "widgets/giftitemtoast"
local ModdedGiftItemToast = require "widgets/moddedgiftitemtoast"
local Image = require("widgets/image")
local ChatLine = require("widgets/redux/chatline")

local COMMERCE_WIDTH = 130
local COMMERCE_HEIGHT = 45

local official_on_tex = "button_officialskins_off.tex" --NOT A TYPO! These are backwards on purpose!
local official_off_tex = "button_officialskins_on.tex" --Strings display these as "hide? on/off"
local modded_on_tex = "button_moddedskins_off.tex"
local modded_off_tex = "button_moddedskins_on.tex"

--

local _LoadSavedSkins = LoadoutSelect._LoadSavedSkins

local _SetTexture = Image.SetTexture

local SetRarity = AccountItemFrame._SetRarity
local SetEventIcon = AccountItemFrame._SetEventIcon
local _SetActivityState = AccountItemFrame.SetActivityState

local _SetItem = ItemImage.SetItem

local __GetActionInfoText = ItemExplorer._GetActionInfoText
local __UpdateItemSelectedInfo = ItemExplorer._UpdateItemSelectedInfo

local _OpenItemManagerScreen = PlayerHud.OpenItemManagerScreen

local _ToggleHUDFocus = GiftItemToast.ToggleHUDFocus
local _ToggleCrafting = GiftItemToast.ToggleCrafting
local _ToggleController = GiftItemToast.ToggleController

local _SetChatData = ChatLine.SetChatData

--


function LoadoutSelect:_LoadSavedSkins(...)
	if not table.contains(DST_CHARACTERLIST, self.currentcharacter) and self.currentcharacter ~= "random" and self.currentcharacter ~= "scarecrow" then
		self.have_base_option = true
	end
	return _LoadSavedSkins(self, ...)
end

Image.SetTexture = function(self, atlas, tex, default_tex) --Prepare for the DUMBEST hack ever before seen.
	if default_tex == nil and atlas == "images/button_icons.xml"
	and (tex == official_on_tex
	or tex == official_off_tex
	or tex == modded_on_tex
	or tex == modded_off_tex) then
		atlas = "images/ms_buttons.xml"
	end
	_SetTexture(self, atlas, tex, default_tex)
end

AddClassPostConstruct("widgets/redux/filterbar", function(self)
	local officialfilterID = "officialFilter"
	local moddedfilterID = "moddedFilter"
	
	----------
	local official_filter = function(skin_id)
		if IsDefaultSkin(skin_id) then return true end
        return env.IsModdedSkin(skin_id)
	end
	self.official_filter = self.picker.header:AddChild( self:AddFilter(STRINGS.UI.WARDROBESCREEN.OFFICIAL_FILTER_FMT,
		official_on_tex, official_off_tex, officialfilterID, official_filter) )
	----------
	local modded_filter = function(skin_id)
		if IsDefaultSkin(skin_id) then return true end
        return not env.IsModdedSkin(skin_id)
	end
	self.modded_filter = self.picker.header:AddChild( self:AddFilter(STRINGS.UI.WARDROBESCREEN.MODDED_FILTER_FMT,
		modded_on_tex, modded_off_tex, moddedfilterID, modded_filter) )
	----------
	
	--SCREAMING
	local __UpdatePositions = self._UpdatePositions
	self._UpdatePositions = function(self)
		__UpdatePositions(self)
		if self.hasmigrated then return end

		if self.search_box then
			self.hasmigrated = true
			if not self.thin_mode then
				self.picker.header:Nudge(Vector3(-145,0,0))
				self.picker.progress:Nudge(Vector3(145,0,0))
				--
				self.official_filter:Nudge(Vector3(70,-65,0))
				self.modded_filter:Nudge(Vector3(0,-120,0))
			else
				self.picker.header:Nudge(Vector3(-121,0,0))
				self.picker.progress:Nudge(Vector3(130,0,0))
				--search_box only needs to be nudged in clothing menu
				self.search_box:Nudge(Vector3(-20,0,0))
				--
				self.official_filter:Nudge(Vector3(46,-65,0))
				self.modded_filter:Nudge(Vector3(-12,-120,0))
			end
		elseif self.picker.primary_item_type == "loading" then
			self.hasmigrated = true

			self.picker.header:Nudge(Vector3(-145,0,0))
			self.picker.progress:Nudge(Vector3(145,0,0))

			self.inst:DoTaskInTime(0, function() --Hornet: We need a taskintime specifically for the loading panel because.... yea game dum
				self.official_filter:Nudge(Vector3(140,-630,0))
				self.modded_filter:Nudge(Vector3(140,-630,0))
			end)
		end
	end
end)

function AccountItemFrame:_SetRarity(rarity)
	if rarity == "ModMade" or rarity == "ModLocked" then
		self:GetAnimState():OverrideSymbol("SWAP_frameBG", "modded_frame_BG", GetFrameSymbolForRarity(rarity))
	else
		SetRarity(self, rarity)
	end
end

function AccountItemFrame:_SetEventIcon(item_key)
	local rarity = GetRarityForItem(item_key)
	if rarity == "ModMade" or rarity == "ModLocked" then
		self.is_displaying_mod = true
		self:GetAnimState():OverrideSymbol("DLC", "modded_event_icon", "event_modded")
		self:GetAnimState():Show("DLC")
	else
		self.is_displaying_mod = false
		self:GetAnimState():ClearOverrideSymbol("DLC")
		self:GetAnimState():Hide("DLC")
	end
	SetEventIcon(self, item_key)
end

function AccountItemFrame:SetActivityState(is_active, is_owned, is_unlockable, is_dlc_owned)
	is_unlockable = self.is_displaying_mod and true or is_unlockable
	_SetActivityState(self, is_active, is_owned, is_unlockable, is_dlc_owned)
	if self.is_displaying_mod then self:GetAnimState():Show("DLC") end
end

function ItemImage:SetItem(...)
	_SetItem(self, ...)
	if self.rarity == "ModMade" or self.rarity == "ModLocked" then
		self.frame:GetAnimState():OverrideSymbol("SWAP_frameBG", "modded_frame_BG", GetFrameSymbolForRarity(self.rarity))
	end
end

function ItemExplorer:_GetActionInfoText(item_data)
	local text = __GetActionInfoText(self, item_data)
	if env.IsModdedSkin(item_data.item_key) then
		local mod = KnownModIndex:GetModFancyName(env.GetSkinSourceMod(item_data.item_key))
		if mod ~= nil then --There are certain mods that don't actually load their prefab skins as prefabs and only run CreatePrefabSkin but not returning the resulted prefab which means we can't register our skin source...
			text = text.."\n"..STRINGS.UI.BARTERSCREEN.COMMERCE_INFO_ISMODDED.." ("..mod..")"
		end
	end
	return text
end

-- Fox: we prob just use the same bg with TEMPLATES btn, but WHATEVA for now
-- Maybe it looks even beter this way
-- I put in a TEMPLATE, was easier
local function MimBtn(atlas, icon, str, onclick)
	local btn = TEMPLATES.IconButton(atlas, icon..".tex", str)
	btn:SetOnClick(onclick)
	btn:ForceImageSize(82, 55)
	btn:SetScale(0.8)
	return btn
end

local function BuildMsMenuForItem(self, itemkey)
	local folder = env.GetSkinSourceMod(itemkey)
	if folder == nil then return end
	local isworkshop = folder:find("workshop-") ~= nil
	local rarity = GetRarityForItem(itemkey)
	self.ms_btns = self.footer:AddChild(Menu(nil, -64, true))
	self.ms_btns:MoveToBack()
	self.ms_btns:SetPosition(205, -23)
	if isworkshop then
		self.ms_btns:AddCustomItem(MimBtn("images/button_icons.xml", "more_info", STRINGS.UI.WARDROBESCREEN.MODLINK_MOREINFO, function() --Linking to the original Workshop mod that added this skin
			VisitURL("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. folder:sub(10))
		end))
	end
	if rarity == "ModLocked" and not TheInventory:CheckOwnership(itemkey) then
		self.ms_btns:AddCustomItem(MimBtn("images/ms_buttons.xml", "button_modlocked", STRINGS.UI.MODLOCKED, function()
			TheFrontEnd:PushScreen(ModSkinUnlockScreen(itemkey))
		end))
	end
end

function ItemExplorer:_UpdateItemSelectedInfo(item, ...)
	if self.ms_btns then
		self.ms_btns:Kill()
		self.ms_btns = nil
	end
	if item and env.IsModdedSkin(item) then
		BuildMsMenuForItem(self, item)
	end
	return __UpdateItemSelectedInfo(self, item, ...)
end

--Modded Skins Gift Popup

function PlayerHud:OpenItemManagerScreen(...)
	if TheModdedInventory.isopeningmodgift then --We're opening a mod gift
		TheCamera:PopScreenHOffset(self)
		self:ClearRecentGifts()
		
		if self.giftitempopup ~= nil and self.giftitempopup.inst:IsValid() then
			TheFrontEnd:PopScreen(self.giftitempopup)
		end
		local item = TheModdedInventory:GetNextInQueue() or nil
		if item ~= nil then
			TheModdedInventory:OpenGift(item)
			env.SendModRPCToServer(env.GetModRPC("ModdedSkins", "RefreshModGiftCount"))
			
			self.giftitempopup = GiftItemPopUp(self.owner, { item }, { "0" })
			self.giftitempopup.spawn_portal:GetAnimState():SetBuild("moddedskingift_popup")
			self:OpenScreenUnderPause(self.giftitempopup)
			return true
		else
			return false
		end
	end
	
	return _OpenItemManagerScreen(self, ...)
end

AddClassPostConstruct("widgets/controls", function(self)
	self.moddeditem_notification = self.topleft_root:AddChild(ModdedGiftItemToast(self.owner))
    self.moddeditem_notification:SetPosition(220, 150, 0)
	
	self.item_notification._mod_notification = self.moddeditem_notification
end)

--Hornet: little hack to get ToggleHUDFocus, ToggleCrafting and ToggleController functions called for moddeditem_notification
function GiftItemToast:ToggleHUDFocus(focus, ...)
	if _ToggleHUDFocus ~= nil then
		_ToggleHUDFocus(self, focus, ...)
	end
	
	if self._mod_notification ~= nil then
		self._mod_notification:ToggleHUDFocus(focus)
	end
end

function GiftItemToast:ToggleCrafting(focus, ...)
	if _ToggleCrafting ~= nil then
		_ToggleCrafting(self, focus, ...)
	end
	
	if self._mod_notification ~= nil then
		self._mod_notification:ToggleCrafting(focus)
	end
end

function GiftItemToast:ToggleController(focus, ...)
	if _ToggleController ~= nil then
		_ToggleController(self, focus, ...)
	end
	
	if self._mod_notification ~= nil then
		self._mod_notification:ToggleController(focus)
	end
end

function ChatLine:SetChatData(type, alpha, message, m_colour, sender, s_colour, icondata, ...)
	if _SetChatData ~= nil then
		_SetChatData(self, type, alpha, message, m_colour, sender, s_colour, icondata, ...)
	end
	
	if alpha > 0 then
        self.root:Show()
		
		local skin_name = message
        if self.type == ChatTypes.SkinAnnouncement then
			if env.IsModdedSkin(skin_name) then
				local r,g,b,a = unpack(MODSKINANNOUNCEMENT_COLOR)
				self.skin_btn:SetTextColour(r,g,b,a)
				self.skin_btn:SetTextFocusColour(r,g,b,a)
				self.skin_btn:SetText(string.format(STRINGS.UI.NOTIFICATION.NEW_MODSKIN_ANNOUNCEMENT, sender))
				
			else
				self.skin_btn:SetTextColour(1,1,1,1)
				self.skin_btn:SetTextFocusColour(1, 1, 1, 1)
			end

			self:UpdateSkinAnnouncementPosition()
		end
	end
end

--Fixing a klei bug with SetCustomizationItemState
--original line was is_active or nil, and if is_active is false... welll it'll default to nil...
local _SetCustomizationItemState = Profile.SetCustomizationItemState
function Profile:SetCustomizationItemState(customization_type, item_key, is_active)
	_SetCustomizationItemState(self, customization_type, item_key, is_active)

	if customization_type == "loading" then --we only care to fix vignette state data, i dont wanna run self:Save() twice
		self.persistdata.customization_items[customization_type][item_key] = is_active

		self:Save()
	end
end

--[[Modded Skin Inventory Icon Fix]]
local _RegisterInventoryItemAtlas = RegisterInventoryItemAtlas
function RegisterInventoryItemAtlas(atlas, imagename)
	_RegisterInventoryItemAtlas(atlas, imagename)

	if string.sub(imagename, 1, 3) == "ms_" then --ModdedSkins aren't initalized so we can't use IsModdedSkin...
		RegisterInventoryItemAtlas(atlas, hash(imagename))
	end
end

--[[
Some mod authors don't create default skins for their characters even though it should be done....
We fix that
]]--

AddSimPostInit(function()
	LoadPrefabFile("tools/autononeskin")
end)


--[[SetSkinsOnAnim hook]]

--[[
Hornet: The extra build override thing is really mainly for Leonardo Coxington's Playable Pets, as large mobs like Dragonfly can exceed the texture limit in a anim zip
easily when recompiling requiring build overrides to be added on.

I have NO idea in which other scenario you'd need to use the extra build overrides feature but it's here if you need it.
]]
local _SetSkinsOnAnim = SetSkinsOnAnim

function SetSkinsOnAnim(anim_state, prefab, base_skin, clothing_names, skintype, default_build, ...)
	for build, list in pairs(BASE_BUILD_OVERRIDES) do
		for i, buildoverride in pairs(list) do
			anim_state:ClearOverrideBuild(buildoverride)
		end
	end

	_SetSkinsOnAnim(anim_state, prefab, base_skin, clothing_names, skintype, default_build, ...)

	if BASE_BUILD_OVERRIDES[base_skin] ~= nil then
		for i, buildoverride in pairs(BASE_BUILD_OVERRIDES[base_skin]) do
			anim_state:AddOverrideBuild(buildoverride)
		end
	end
end