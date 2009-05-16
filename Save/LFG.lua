


--local addon = LibStub("AceAddon-3.0"):NewAddon("LFG", "AceConsole-3.0", "AceTimer-3.0", "AceHook-3.0")

--@debug@ 
--addon.Version = "LFG (|cff8080ff".."DEBUG".."|r)"
--@end-debug@

--[===[@non-debug@
--addon.Version  = "LFG (|cff8080ff".."@project-revision@".."|r)"
--@end-non-debug@]===]


local LFGSources = {
    chat,
    blizzlfg
}

local PlayerInfoServices = {
    who,
    inspect,
    historical,
    notes
}

    




local Providers = setmetatable({}, { __index=addon })

lfg = { db = {} }
   
-- LFG Data Record (keyed by charname:lower())
--[[

    charname = {
        chat = {},
        spamfilter = {},
        who = {},
        inspect = {},
        historical = {},
        notes = {}
    }
]]


--[[ The strings

GetLFGTypes() 
    "None", "Dungeon", "Raid", "Quest (Group)", "Zone", "Heroic Dungeon"

LFG_TYPE_QUEST
LFG_TYPE_RAID
LFG_TYPE_ZONE
LFG_TYPE_BATTLEGROUND
LFG_TYPE_DUNGEON
LFG_TYPE_HEROIC_DUNGEON


Caverns of Time - The Culling of Stratholme  Gun'Drak Gundrak The Oculus TheOculus 
Ulduar: Halls of Lightning HallsofLightning 
Ulduar: Halls of Stone HallsofStone Utgarde Pinnacle UtgardePinnacle 

•AcceptLFGMatch - Accepts a proposed LFG matchdeprecated
•CanSendLFGQuery - Returns whether or not the player can submit a LFG/LFM request for the given type and index
•CancelPendingLFG - Removes the player from all open LookingForGroup queues.
•ClearLFGAutojoin - Clears the Autojoin functionality in the LFG tool
•ClearLFMAutofill - Stops the LFM interface from auto-adding members to your group
•ClearLookingForGroup - Clears the player from any LFG/LFM listings or requests
•ClearLookingForMore - Clears all active LFM requests, removing the player from the LFG queue
•DeclineLFGMatch - This function is deprecateddeprecated
•GetLFGPartyResults - Returns information about a member of a party in the LFG results
•GetLFGResults - Returns information about a specific line of a LFM/LFG query
•GetLFGStatusText - Returns information on your current Looking For Group status.
•GetLFGTypeEntries - Returns the valid entries of a specific type in the LFG system
•GetLFGTypes - Returns the type of possible LFG queries
•GetLookingForGroup - Retrieves information about the players LFG status.
•GetNumLFGResults - Returns the number of results from a LFG query
•IsInLFGQueue - Returns whether or not the player is currently in the LFG queue
•LFGQuery - Sends a looking for group request, optionally filtered by class
•SetLFGAutojoin - Enables auto-join in the LFG system
•SetLFGComment - Adds a comment to your listing in the LFG system
•SetLFGType - Sets a filter for the LFG system in a specific slot
•SetLFMAutofill - Turns on the auto-fill option in the Looking For More interface
•SetLFMType - Sets the type of the current LFM request
•SetLookingForGroup - Sets one of the three looking for group slots
•SetLookingForMore - Start looking for more members for the given activity type and index
•SortLFG - Sets the sort type for a Looking for Group query

]]


lfg.frame = CreateFrame("Frame")
lfg.frame.lfg = lfg
lfg.frame:SetScript("OnEvent", function(frame, event, ...) local f=frame.lfg if f[event] then f[event](f, ...) end end )
lfg.frame:Show()
lfg.frame:RegisterEvent("VARIABLES_LOADED")

lfg.frame:RegisterEvent("UPDATE_INSTANCE_INFO")

lfg.svc={}

local function getSvcOnEvent(svc) 
    return function(frame, event, ...) 
        local f=svc 
        if f[event] then f[event](f, ...) end
    end 
end

function lfg.svc.chat:WTFfunction(base)
    local svc = {}
    svc.frame = CreateFrame("Frame")
    
    local f = svc.frame    
    f:SetScript("OnEvent", getSvcOnEvent(svc))
    f:Show()
    
    svc.data = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("lfg.svc.chat.data", {
    	type = "lfg.svc.chat.msg",
        -- message
        -- sender
        -- channelName
    })
    -- Init

    svc.frame:RegisterEvent("CHAT_MSG_CHANNEL")
        
    function svc:CHAT_MSG_CHANNEL(message, sender, language, channelString, target, flags, _, channelNumber, channelName, _, counter)
        Prat.PrintLiteral(message, sender, language, channelString, target, flags, _, channelNumber, channelName, _, counter)
        self.data = { message, sender, channel:lower()}
        self.data.sender = sender:lower()
        self.data.channelName = channelName
    end
-- ChatServicae: 
--    spamfilter,
--    keywordfilter,
--[[
•message - The message thats received (string) 
•sender - The sender's username. (string) 
•language - The language the message is in. (string) 
•channelString - The full name of the channel, including number. (string) 
•target - The username of the target of the action. Not used by all events. (string) 
•flags - The various chat flags. Like, DND or AFK. (string) 
•unknown - This variable has an unkown purpose, although it may be some sort of internal channel id. That however is not confirmed. (number) 
•channelNumber - The numeric ID of the channel. (number) 
•channelName - The full name of the channel, does not include the number. (string) 
•unknown - This variable has an unkown purpose although it always seems to be 0. (number) 
•counter - This 
]]

end

function lfg:VARIABLES_LOADED()
    self.frame:UnregisterAllEvents()
    self.frame:RegisterEvent("VARIABLES_LOADED")
end

function lfg:UPDATE_INSTANCE_INFO()
   local instanceName, instanceID, instanceReset
   lfg.savedinstances = {}

    local t = lfg.savedinstances

    for i=1,GetNumSavedInstances() do
        instanceName, instanceID, instanceReset  = GetSavedInstanceInfo(i) 

        t[instanceName] = instanceID
    end
end

local lfgLDB = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("lfg-dev", {
	type = "launcher",
	text = "lfg-dev",
	icon = [[Interface\ICONS\INV_Misc_Eye_02]],
})

local icon = LibStub("LibDBIcon-1.0", true)

icon:Register("lfg-dev", lfgLDB, lfg.db)

function lfgLDB.OnClick(self, button)
	if button == "RightButton" then
            lfg.index = lfg.index == #lfg.types and 2 or lfg.index + 1
            print("right-click")
	else
		if IsShiftKeyDown() then
			print("shift-click")
		elseif IsAltKeyDown() then
			print("alt-click")
		else
			print("click")
		end
	end
end

lfg.index = 2

local function addTypeLine(tooltip, name, token, ...)
    if name == nil or token == nil then
        return
    end

    
    if lfg.savedinstances[name] then
        tooltip:AddLine(("    |cffff0000SAVED|r %s"):format(name, token))
    elseif lfg.current[name] then
        tooltip:AddLine("    |cff00ff00LFG|r "..name)
    else
        tooltip:AddLine("    "..name)
    end
    return addTypeLine(tooltip, ...)
end

local function getLFG(typeid, name)
    local t = lfg.types[typeid]
    local n = { GetLFGTypeEntries(typeid) }
    if n then return n[name*2-1] end
end

function lfgLDB.OnTooltipShow(tooltip)
    local t = lfg.types or { GetLFGTypes() }
    lfg.types = t

-- type1, name1, type2, name2, type3, name3, lfmType, lfmName, comment, queued, lfgStatus, lfmStatus, autoaddStatus = GetLookingForGroup()
    lfg.current = {}
    local current = lfg.current
    tooltip:AddLine("Current:", 1.0, 1.0, 1.0)
    for i=1,5,2 do
        local type, name = select(i, GetLookingForGroup())
        type, name = t[type], getLFG(type, name)
        if name then
            current[name] = type ~= LFG_TYPE_NONE and type or nil
        end
    end 
    for k,v in pairs(current) do
        tooltip:AddLine("    "..v..": "..k)
    end

    tooltip:AddLine("", 1.0, 1.0, 1.0)

	tooltip:AddLine("Types:", 1.0, 1.0, 1.0)
    for i,v in ipairs(t) do
    	tooltip:AddLine("  "..v, 0.4, 1.0, 0.4)
        if i == lfg.index then
            addTypeLine(tooltip, GetLFGTypeEntries(i))
        end             
    end    
end

