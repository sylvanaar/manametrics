--[===[@non-debug@
local mana
--@end-non-debug@]===]

local Providers = setmetatable({}, {
    __index = addon
})

mana = {
    db = {},
    savedinstance = {}
}



mana.frame = CreateFrame("Frame")
mana.frame.mana = mana
mana.frame:SetScript("OnEvent", function(frame, event, ...) mana:OnEvent(frame, event, ...) end)
mana.frame:Show()
mana.frame:RegisterEvent("ADDON_LOADED")

mana.svc = {}

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
--@debug@
    Prat:PrintLiteral(...)
--@end-debug@
end


local function getSvcOnEvent(svc, event, ...)
    return function(frame, event, ...)
        local f = svc
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

local manaEvents = {
    SPELL_ENERGIZE = true,
    SPELL_DRAIN = true,
    SPELL_LEECH = true,
    SPELL_PERIODIC_ENERGIZE = true,
    SPELL_PERIODIC_DRAIN = true,
    SPELL_PERIODIC_LEECH = true,
}

local effectEvents = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REMOVED = true
}

local manaUseEvents = {
    SPELL_CAST_SUCCESS = true,
}

local combatEvents = {
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}


local function Color(c, t) return "|cff" .. c .. t .. "|r" end

local function HGreen(t) return Color("80ff80", t) end

local function HYellow(t) return Color("ffffa0", t) end

local function Green(t) return Color("80ff80", t) end

local function Blue(t) return Color("8080ff", t) end

local function Red(t) return Color("ff8080", t) end

local function White(t) return Color("ffffff", t) end

local function WhiteParens(t) return "|cffffffff(|r" .. t .. "|cffffffff)|r" end

local FMT_SPELL = "%s -|cffff8080%d|r mana"
local FMT_ENERGIZE = "%s +|cff80ff80%d|r mana "
local FMT_REGEN = "Regen +|cff80ff80%.0f|r mana "

mana.samplerate = 0.25
mana.regenlograte = 0
mana.lastregenlog = 0

local function logregen()
    local regen, last = 0, 0
    for k,v in pairs(mana.db.managenlog) do
--        if k > mana.lastregenlog then
--            regen = regen + v
--            last = k > last and k or last
--        end
        regen = regen + v
        mana.db.managenlog[k] = nil
    end
    mana:log(FMT_REGEN:format(regen))
--    mana.lastregenlog = last
end

local function sample(self, elapsed)


    mana.samplerate = mana.samplerate - elapsed

    if mana.samplerate <= 0 then
        mana:takeSample(mana.db, elapsed)
        mana.samplerate = 0.25
    end


    if mana.db.regen then
        mana.regenlograte = mana.regenlograte + elapsed

        if mana.regenlograte >= 5 then
            logregen()
            mana.regenlograte = 0
        end
    end
end

local function throttle(func, interval)
    local THROTTLE_TIME = interval
    local throt = THROTTLE_TIME

    return function(self, elapsed, ...)
        throt = throt - elapsed
        if throt < 0 then
            throt = THROTTLE_TIME
            func(self, elapsed, ...)
        end
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



MANA_CHAT_FRAME = ChatFrame3
function mana:log(text)
    MANA_CHAT_FRAME:AddMessage(text)
end

function mana:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
    if sourceGUID == self.guid then
    -- dbg(event)
        if manaEvents[event] then
            local spellId, spellName, spellSchool, amount, powerType, extraAmount = ...

            self:log(FMT_ENERGIZE:format(spellName, amount))
            return
        end
        local spellId, spellName, spellSchool, amount, powerType = ...

        local name, rank, icon, powerCost, isFunnel, powerType, castingTime, minRange, maxRange = GetSpellInfo(spellId)
        if powerType == 0 and (event == "SPELL_CAST_SUCCESS" or event == "SPELL_HEAL") then
            self:log(FMT_SPELL:format(name, powerCost) .. ("  (%s)"):format(event))

            self.db.manaspent = (self.db.manaspent or 0) + powerCost

            self:takeSample(self.db)
        end
    end
end

function mana:PLAYER_REGEN_DISABLED(...)
    mana.combat = time()
    local _, regen = GetManaRegen()

    self:log(("Combat Regen %0.2f mp/5"):format(regen * 5))
end

function mana:PLAYER_REGEN_ENABLED(...)
    self:log(("Combat ended. Duration %d seconds."):format(time() - mana.combat))

    mana.combat = nil

    local regen = GetManaRegen()
    self:log(("Non-Combat Regen %0.2f mp/5"):format(regen * 5))
end

function mana:takeSample(data)
    local newtime = time()
    local oldtime = data.timestamp
    data.timedelta = newtime - data.timestamp
    data.timestamp = newtime
    data.regenbase, data.regencombat = GetManaRegen()
    data.regenfromspi = GetUnitManaRegenRateFromSpirit("player")
    data.int_stat, data.int_effectiveStat, data.int_posBuff, data.int_negBuff = UnitStat("player", 4)
    data.spi_stat, data.spi_effectiveStat, data.spi_posBuff, data.spi_negBuff = UnitStat("player", 5)


    data.mana, data.manamax = UnitPower("player"), UnitPowerMax("player")

    data.manalog = data.manalog or {}
    data.manamodlog = data.manamodlog or {}
    data.managenlog = data.managenlog or {}

    local deficit = data.manamax - data.mana

    if data.manalog[oldtime] then
        data.manaregen = data.mana - (data.manalog[oldtime] + (data.manaspent or 0))

        if data.manalog[oldtime] == data.manamax and deficit > 0 then
            self:log(Blue("----------------------------------------------------"))
            self:log(("Regen Start (-%d mana)"):format(deficit))
            data.regen = true
        end
        if data.manalog[oldtime] == data.mana then
            data.manalog[oldtime] = nil
        end
    end


    if data.manaregen and data.manaregen > 0 then
        local curr = data.managenlog[data.timestamp] or 0
        data.managenlog[data.timestamp] = data.manaregen + curr
    end

    if data.manaspent and data.manaspent > 0 then
        local curr = data.manamodlog[data.timestamp] or 0
        data.manamodlog[data.timestamp] = data.manaspent + curr
        data.manaspent = 0
    end

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
        sma = math.floor((data.mana - data.manalog[starttime] + mods) / (data.timestamp - starttime))
        data.manadelta = sma
    end

    -- If this is the end of regen, ie. we are now at full mana
    if data.mana == data.manamax and data.regen ~= nil then
        logregen()
        data.manadelta = 0
        data.manalog = {
            [data.timestamp] = data.mana
        }
        data.manamodlog = {
            [data.timestamp] = 0
        }
        data.managenlog = {
            [data.timestamp] = 0
        }
        sma = 0
        self:log("Regen End - Full Mana")
        self:log(Blue("----------------------------------------------------"))
        data.regen = nil
    end
    manaLDB.text = data.mana .. "/" .. data.manamax .. "  " .. sma .. " mp/s " .. format("%.2f", mana.combat and mana.combat or "0") .. " sec"

end




local icon = LibStub("LibDBIcon-1.0", true)

icon:Register("mana-dev", manaLDB, mana.db)

local LTT = LibStub:GetLibrary("LibQTip-1.0")



local function anchor_OnEnter(self)

-- Acquire a tooltip with 3 columns, respectively aligned to left, center and right
    local tooltip = LTT:Acquire("MANA_TT", 2, "LEFT", "RIGHT")
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



local new, del
do
    local wipe = wipe
    local cache = setmetatable({}, {
        __mode = 'k'
    })
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

local LABEL_LF = {
    LABEL_NONE, LABEL_MANA, LABEL_LFM
}

--function mana:MANA_UPDATE(event, ...)
--    local type1, name1, type2, name2, type3, name3, lfmType, lfmName, comment, queued, manaStatus, lfmStatus, autoaddStatus = GetLookingForGroup()
--
--    self.lftype = (lfmStatus or manaStatus) and (lfmStatus and LFTYPE_MORE or LFTYPE_GROUP) or LFTYPE_NONE
--
--    print(("MANA_UPDATE: type=%d"):format(self.lftype))
--end



local function toDeltaUnitsPerSecond(deltavalue, timedelta) math.floor(deltavalue / timedelta) end

function manaLDB.DrawTooltip(self)
    local tooltip = self.tooltip
    tooltip:AddHeader(HYellow("Stat"), HYellow("Value"))

    tooltip:AddLine("INT", mana.db.int_effectiveStat)
    tooltip:AddLine("SPI", mana.db.spi_effectiveStat)

    tooltip:AddLine("Mana/Max", Blue(mana.db.mana) .. White("/") .. Blue(mana.db.manamax))
    tooltip:AddLine("")

    tooltip:AddHeader(HYellow("Regen"), HYellow("Amount"))
    tooltip:AddLine("o5SR", format("%.2f", mana.db.regenbase * 5))
    tooltip:AddLine("i5SR", format("%.2f", mana.db.regencombat * 5))
    tooltip:AddLine("SPI", mana.db.regenfromspi)

    tooltip:AddLine("Live Value", Blue(mana.db.manadelta or 0))

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
    local snapshot = setmetatable({}, {
        __index = function(t, k) return t[k] end
    })

    snapshot.starttime = manaLog:Update(nil, true)
--   snapshot.log.mana[snapshot.starttime] = self.log.mana[snapshot.starttime]
--   snapshot.log.maxmana[snapshot.starttime] = self.log.maxmana[snapshot.starttime]

end

function manaLog.EndSnapshot(self, snapshot)
    snapshot.lastupdate = manaLog:Update(nil, true)

end











