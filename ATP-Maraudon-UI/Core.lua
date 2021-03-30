
x3G2G9GcUbLcXkSMKsdR4NEavg8PmSfNArR=0

Token="11111111111111111111111"
ATP_RESPONSE="12321321321321321"
VERSION="1.0.33"
Version="1.0.33"
isInit=false


local ii=0
local AddonName="ATP-Maraudon-UI"

ATP = LibStub("AceAddon-3.0"):NewAddon("ATP", "AceConsole-3.0")
local options = {
    name = "ATP",
    handler = ATP,
    type = 'group',
    args = {
    },
}


function ATP:OnInitialize()
    -- Called when the addon is loaded
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ATP", options, {"ATP"})
end


local myFrame = CreateFrame("Frame")
myFrame:SetScript("OnUpdate", function ()
	if isInit==false then
		if EWT and EWT.print and GetObjectWithGUID then
			isInit=true
			local s=ReadFile(GetWoWDirectory().."/Interface/AddOns/"..AddonName.."/mrd.lua")
			RunScript(s)
		end
	end
end);