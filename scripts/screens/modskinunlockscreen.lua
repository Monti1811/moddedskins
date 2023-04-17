local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"

local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"

local buttons = {
	text=STRINGS.UI.LOBBYSCREEN.CANCEL,
	cb = function()
		TheFrontEnd:PopScreen()
	end
}

local ModSkinUnlockScreen = Class(Screen, function(self, item_key)
	Screen._ctor(self, "ModSkinUnlockScreen")
	
	self.root = self:AddChild(TEMPLATES.ScreenRoot("GameOptions"))
	
	local black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    black.image:SetVRegPoint(ANCHOR_MIDDLE)
    black.image:SetHRegPoint(ANCHOR_MIDDLE)
    black.image:SetVAnchor(ANCHOR_MIDDLE)
    black.image:SetHAnchor(ANCHOR_MIDDLE)
    black.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    black.image:SetTint(0,0,0,.5)
    black:SetOnClick(function() TheFrontEnd:PopScreen() end)
    black:SetHelpTextMessage("")
	black:MoveToBack()

	local bodytext = STRINGS.MODSKINUNLOCK_REQUIREMENT[item_key] or STRINGS.MODSKINUNLOCK_REQUIREMENT["MISSING"]
	self.unlockrequirement = self.root:AddChild(TEMPLATES.CurlyWindow(611, 130, STRINGS.UI.MODLOCKED, buttons, nil, bodytext))
	self.unlockrequirement:MoveToFront()
	self.unlockrequirement.body:SetRegionSize(611, 300)
	self.unlockrequirement.body:EnableWordWrap(true)
end)

return ModSkinUnlockScreen