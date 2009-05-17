


--local addon = LibStub("AceAddon-3.0"):NewAddon("MANA", "AceConsole-3.0", "AceTimer-3.0", "AceHook-3.0")

--@debug@ 
--addon.Version = "MANA (|cff8080ff".."DEBUG".."|r)"
--@end-debug@

--[===[@non-debug@
--addon.Version  = "MANA (|cff8080ff".."@project-revision@".."|r)"
--@end-non-debug@]===]


local MANASources = {
    chat,
    blizzmana
}

local PlayerInfoServices = {
    who,
    inspect,
    historical,
    notes
}

     




local Providers = setmetatable({}, { __index=addon })

mana = { db = {}, savedinstance={} }
   
-- MANA Data Record (keyed by charname:lower())
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





mana.frame = CreateFrame("Frame")
mana.frame.mana = mana
mana.frame:SetScript("OnEvent", function(frame, event, ...)  mana:OnEvent(frame, event, ...) end )
mana.frame:Show()          
mana.frame:RegisterEvent("ADDON_LOADED")

mana.svc={}

local waittime = 5
local timerfunc = function() return end
local function onUpdate(self, elapsed)
    waittime = waittime - elapsed
    if waittime <= 0 then
        timerfunc()
        self:SetScript("OnUpdate", nil)
    end
end

local function delayCall(time, func)
    waittime = time
    timerfunc = func
    mana.frame:SetScript("OnUpdate", onUpdate)
end
        

local function dbg(...)
    Prat:PrintLiteral(...)
end


local function getSvcOnEvent(svc, event, ...) 
    return function(frame, event, ...) 
        local f=svc 
        if f[event] then f[event](f) end
    end 
end

function mana:OnEvent(frame, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(...)
        return
    end

    if self[event] then return self[event](self, event, ...) end
end

function mana:OnCombatEvent(...)
    self:COMBAT_LOG_EVENT_UNFILTERED(...)
end


local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local manaLDB = LDB:NewDataObject("mana-dev", {
	type = "data source",
	text = "mana-dev",
	icon = [[Interface\ICONS\INV_Misc_Eye_02]],
})



local function dbg(...) Prat:PrintLiteral(...) end


local manaEvents = {
    SPELL_ENERGIZE = true,
    SPELL_DRAIN = true, 
    SPELL_LEECH = true,
    SPELL_PERIODIC_ENERGIZE = true,
    SPELL_PERIODIC_DRAIN = true, 
    SPELL_PERIODIC_LEECH = true,
}

local manaUseEvents = {
    SPELL_CAST_SUCCESS = true,
}

local combatEvents = {
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
}
 mana.samplerate = 0.25
local function sample(self, elapsed)
    

    if mana.FSR then 
        mana.FSR = mana.FSR - elapsed
        if mana.FSR <= 0 then
            mana.FSR = nil
        end
    end

    mana.samplerate = mana.samplerate - elapsed

    if mana.samplerate <= 0 then 
        mana:takeSample(mana.db, elapsed) 
        mana.samplerate = 0.25
    end
end

function mana:ADDON_LOADED()
    self.frame:UnregisterAllEvents()

    self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")


    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self.guid = UnitGUID("player")

    self.db.timestamp = 0
    self.db.slicetime = 0

    mana.frame:SetScript("OnUpdate", sample)
end

function mana:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
--local info = ChatTypeInfo["COMBAT_MISC_INFO"];
--		
--		local message = format("%s, %s, %s, 0x%x, %s, %s, 0x%x",
--				       --date("%H:%M:%S", timestamp), 
--		                       event,
--		                       sourceGUID, sourceName or "nil", sourceFlags,
--		                       destGUID, destName or "nil", destFlags);
--		
--		for i = 1, select("#", ...) do
--			message = message..", "..(select(i, ...) or "nil");
--		end
--		ChatFrame1:AddMessage(message, info.r, info.g, info.b);

    if sourceGUID == self.guid then
        -- dbg(event)
        if manaEvents[event] then 
            local  spellId, spellName, spellSchool, amount, powerType, extraAmount = ...
            dbg(spellName.." +"..amount.." mana ("..event..")")
--            dbg({timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...})
--            dbg({...})
        end
        local spellId, spellName, spellSchool, amount, powerType = ...

        local name, rank, icon, powerCost, isFunnel, powerType, castingTime, minRange, maxRange = GetSpellInfo(spellId)
        if powerType == 0 and powerCost > 0 and event == "SPELL_CAST_SUCCESS" then
            local regenloss = (5-(self.FSR or 0))*(self.db.regenbase-self.db.regencasting)
            dbg(name.." -"..powerCost.." mana (-"..format("%.2f", regenloss).." lost regen) ("..event..")")
            self.FSR = 5
            self.db.manaspent = (self.db.manaspent or 0) - powerCost
        end
    end
end

function mana:PLAYER_REGEN_DISABLED(...)
end
function mana:PLAYER_REGEN_ENABLED(...)
end



function mana:takeSample(data, elapsed)
    local newtime = elapsed and (data.timestamp + elapsed) or time()
    local oldtime = data.timestamp
    data.timedelta = newtime - data.timestamp
    data.timestamp = newtime
    data.regenbase, data.regencasting = GetManaRegen()
    data.regenfromspi = GetUnitManaRegenRateFromSpirit("player")
    data.int_stat, data.int_effectiveStat, data.int_posBuff, data.int_negBuff = UnitStat("player", 4)
    data.spi_stat, data.spi_effectiveStat, data.spi_posBuff, data.spi_negBuff = UnitStat("player", 5)

    if mana.FSR then 
        data.infsrtime = (data.infsrtime or 0) + data.timedelta
    end        
    data.mana, data.manamax = UnitPower("player"), UnitPowerMax("player")
    
    data.manalog = data.manalog or {}
 data.manamodlog = data.manamodlog or {}
    if data.manalog[oldtime] and data.manalog[oldtime] == data.mana then
        data.manalog[oldtime] = nil
    end

    data.manamodlog[data.timestamp] = data.manaspent
    data.manaspent = 0

    data.manalog[data.timestamp] = data.mana

    local sma, starttime = 0, data.timestamp
    for k,v in pairs(data.manalog) do
        if data.timestamp - k < 10 then  
            if starttime > k then
                starttime = k
            end
        end
    end

    if starttime ~= data.timestamp then
        local mods = 0
         for k,v in pairs(data.manamodlog) do
            if k >= starttime then
                mods = mods + v
            end
         end
        sma = math.floor((data.mana - data.manalog[starttime] - mods) / (data.timestamp - starttime))
    end

    if data.mana == data.manamax and sma ~= 0 then
        data.manadelta = 0
        data.manalog = { [data.timestamp] = data.mana }
        data.manamodlog = { [data.timestamp] = 0 }
        sma = 0
        dbg("Full Mana")
    end
    manaLDB.text = data.mana .. "/" .. data.manamax .. "  " .. sma .." mp/s " .. format("%.2f", mana.FSR and mana.FSR or "0") .. " sec"
    
end




local icon = LibStub("LibDBIcon-1.0", true)

icon:Register("mana-dev", manaLDB, mana.db)

local LTT = LibStub:GetLibrary( "LibQTip-1.0" )



local function anchor_OnEnter(self)
   
   -- Acquire a tooltip with 3 columns, respectively aligned to left, center and right
   local tooltip = LTT:Acquire( "MANA_TT", 2, "LEFT", "RIGHT" )
   self.tooltip = tooltip 
   

   
 end
 
 local function anchor_OnLeave(self)
   
   self.tooltip:Hide()

   -- Release the tooltip
   LTT:Release(self.tooltip)
   self.tooltip = nil
   
 end


--tooltip:AddHeader
--tooltip:AddLine
function manaLDB.OnEnter(self)
    if self.tooltip == nil then
        anchor_OnEnter(self)
    end

    self.tooltip:Clear()

    manaLDB.DrawTooltip(self)

   -- Use smart anchoring code to anchor the tooltip to our frame
   self.tooltip:SmartAnchorTo(self)
   
   -- Show it, et voil  !
   self.tooltip:Show()

end 

function manaLDB.OnLeave(self)
    anchor_OnLeave(self)
end

function manaLDB.OnClick(self, button)
	if button == "RightButton" then
            manaLDB.OnEnter(self)
            print("right-click")
	else
		if IsShiftKeyDown() then

			print("shift-click")
		elseif IsAltKeyDown() then
            manaLDB.OnEnter(self)
			print("alt-click")
		else
            manaLDB.OnEnter(self)
		end
	end
end


--local function tail2(a, b, ...)
--    if select("#", ...) == 0 then
--        return a
--    end
--
--    return a, tail2(...)
--end

local function proc2(a,b)
    
end


local function list2(...)
   local list = {...}
   local a,b

   for i = 1,select("#", list),2 do
        a,b = select(i, list)

        print(a..b)
   end

end

local function tail2(a, b, ...)
    if not a then return end
    print(a..b)
    return tail2(...)
end

local new, del
do
	local wipe = wipe
	local cache = setmetatable({}, {__mode='k'})
	function new(...)
		local t = next(cache)
		if t then
			cache[t] = nil
			return t
		else
			return {}
		end
	end
	function del(t)
		wipe(t)
		cache[t] = true
		return nil
	end
end

    
--
--function mana:recieve(prod)
--    local status, value = coroutine.resume(prod)
--    if status == false then
--        mana.scan = nil
--    end
--    dbg(status, value) 
--    return value
--end
--
--function mana:send(val)
--    coroutine.yield(val)
--end
--
--function mana:producer()
--    return coroutine.create(
--    function()
--        local requery = {}
--        for manatype=2, #mana.types do
--            for mananame=1, select("#", GetMANATypeEntries(manatype)) do
----                repeat
--                    if mana:SendMANAQuery(manatype, mananame) then
--                        requery[#requery] = manatype*1000+mananame
--                    end
--                    mana:send(false)
----                until not requery
--                for i=1, GetNumMANAResults(manatype, mananame) do
--                    mana:send({GetMANAResults(manatype, mananame, i)})
--                end
--                mana:send(true)
--            end
--        end
--
--        while #requery > 0 do
--            local n = requery[#requery]
--                
--            if mana:SendMANAQuery(n/1000, math.fmod(n, 1000)) then
--                table.insert(requery,1, n)
--            end
--        end
--    end)
--end     
--           

--function PaperDollFrame_SetManaRegen(statFrame)
--	getglobal(statFrame:GetName().."Label"):SetText(MANA_REGEN..":");
--	local text = getglobal(statFrame:GetName().."StatText");
--	if ( not UnitHasMana("player") ) then
--		text:SetText(NOT_APPLICABLE);
--		statFrame.tooltip = nil;
--		return;
--	end
--	
--	local base, casting = GetManaRegen();
--	-- All mana regen stats are displayed as mana/5 sec.
--	base = floor( base * 5.0 );
--	casting = floor( casting * 5.0 );
--	text:SetText(base);
--	statFrame.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. MANA_REGEN .. FONT_COLOR_CODE_CLOSE;
--	statFrame.tooltip2 = format(MANA_REGEN_TOOLTIP, base, casting);
--	statFrame:Show();
--end     


local LABEL_LFM = "|cff0a0affLFM|r"
local LABEL_MANA = "|cff0aff0aMANA|r"
local LABEL_NONE = "None"

local LABEL_LF = { LABEL_NONE, LABEL_MANA, LABEL_LFM }

--function mana:MANA_UPDATE(event, ...)
--    local type1, name1, type2, name2, type3, name3, lfmType, lfmName, comment, queued, manaStatus, lfmStatus, autoaddStatus = GetLookingForGroup()
--
--    self.lftype = (lfmStatus or manaStatus) and (lfmStatus and LFTYPE_MORE or LFTYPE_GROUP) or LFTYPE_NONE
--
--    print(("MANA_UPDATE: type=%d"):format(self.lftype))
--end

local function Color(c, t) return "|cff"..c..t.."|r" end
local function HGreen(t) return Color("80ff80", t) end
local function HYellow(t) return Color("ffffa0", t) end
local function Green(t) return Color("80ff80", t) end
local function Blue(t) return Color("8080ff", t) end
local function Red(t) return Color("ff8080", t) end
local function White(t) return Color("ffffff", t) end
local function WhiteParens(t) return "|cffffffff(|r"..t.."|cffffffff)|r" end

local function toDeltaUnitsPerSecond(deltavalue, timedelta) math.floor(deltavalue / timedelta ) end

function manaLDB.DrawTooltip(self)   
    local tooltip = self.tooltip
    tooltip:AddHeader(HYellow("Stat"), HYellow("Value"))

    tooltip:AddLine("INT", mana.db.int_effectiveStat)
    tooltip:AddLine("SPI", mana.db.spi_effectiveStat)

    tooltip:AddLine("Mana/Max",  Blue(mana.db.mana) .. White("/") ..  Blue(mana.db.manamax))
    tooltip:AddLine("")

    tooltip:AddHeader(HYellow("Regen"), HYellow("Amount"))
    tooltip:AddLine("o5SR", format("%.2f", mana.db.regenbase*5))
    tooltip:AddLine("i5SR", format("%.2f", mana.db.regencasting*5))
    tooltip:AddLine("SPI", mana.db.regenfromspi)

    tooltip:AddLine("Live Value", Blue(math.floor( mana.db.manadelta /  mana.db.timedelta )))

    tooltip:AddLine("")

    tooltip:AddHeader(HYellow("Time"), HYellow("Amount"))
    tooltip:AddLine("Time", mana.db.timestamp)
    tooltip:AddLine("Time Delta", mana.db.timedelta)



    for k,v in pairs(mana.db) do
        tooltip:AddLine(k, tostring(v))
    end

end



local manaLog = LDB:NewDataObject("mana-mainlog", {
	type = "mana-log",
	text = "",

    mana = 0,
    maxmana = 0,

    starttime = 0,
    lastupdate = 0,

    log = {
        mana = {},
        maxmana = {},
    },
})

function manaLog.Update(self, elapsed, sync)
    self.mana, self.maxmana = UnitPower("player"), UnitPowerMax("player")
    
    if not sync then
        if self.log.mana[lastupdate] == self.mana then
            self.log.mana[lastupdate] = nil
        end
        if self.log.maxmana[lastupdate] == self.maxmana then
            self.log.maxmana[lastupdate] = nil
        end
    end
    lastupdate = lastupdate + elapsed

    self.log.mana[lastupdate] = self.mana
    self.log.maxmana[lastupdate] = self.maxmana

    return lastupdate
end

function manaLog.StartSnapshot(self)
   local snapshot = setmetatable({}, { __index = function(t,k) return t[k] end })

   snapshot.starttime = manaLog:Update(nil, true)
--   snapshot.log.mana[snapshot.starttime] = self.log.mana[snapshot.starttime]
--   snapshot.log.maxmana[snapshot.starttime] = self.log.maxmana[snapshot.starttime]
    
end

function manaLog.EndSnapshot(self, snapshot)
    snapshot.lastupdate = manaLog:Update(nil, true)

end


local manaLevelFilter = LDB:NewDataObject("Level Filter", {
	type = "mana-filter",
	text = "",
})

local manaInstanceFilter = LDB:NewDataObject("Instance Filter", {
	type = "mana-filter",
	text = "",
})

local manaDataObjects = LDB:NewDataObject("MANA DataObject Collection", {
	type = "mana-dataobject-list",
    
    list = {},
})


local manaChannel = LDB:NewDataObject("MANA DataObject", {
	type = "mana-dataobject",

    player = "",
    class = "",
    level = "",

    manatype = "",
    manatypedetail = "",
})

local manaChannel = LDB:NewDataObject("LFM DataObject", {
	type = "mana-dataobject",

    player = "",
    class = "",
    level = "",

    manatype = "",
    manatypedetail = "",
})


local manaChannel = LDB:NewDataObject("DO Multiplexer", {
	type = "data object mux",

    objs = { },


})









