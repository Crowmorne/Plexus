--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    Resurrect.lua
    Plexus status module for resurrections.

    This file holds the parts shared by every client, including the
    INCOMING_RESURRECT_CHANGED handler. Clients that need more to detect
    resurrections load mechanism files in addition, picked in the .toc:
      ResurrectFromCasts.lua     - resurrection spell casts
      ResurrectFromCombatLog.lua - mass resurrections via the combat log
    A mechanism file defines handlers for its events and adds the event
    names to PlexusStatusResurrect.trackedEvents.
----------------------------------------------------------------------]]

local _, Plexus = ...
local L = Plexus.L

local GetTime = GetTime

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
local UnitGUID = UnitGUID
local UnitHasIncomingResurrection = UnitHasIncomingResurrection

local PlexusRoster = Plexus:GetModule("PlexusRoster")

local PlexusStatusResurrect = Plexus:NewStatusModule("PlexusStatusResurrect", "AceTimer-3.0")
PlexusStatusResurrect.menuName = L["Resurrection"]
PlexusStatusResurrect.options = false

PlexusStatusResurrect.defaultDB = {
    alert_resurrect = {
        enable = true,
        text = L["RES"],
        color = { r = 0.8, g = 1, b = 0, a = 1 },
        color2 = { r = 0.2, g = 1, b = 0, a = 1 },
        priority = 50,
    },
}

-- Mechanism files add the events they handle to this table.
PlexusStatusResurrect.trackedEvents = {}

local extraOptionsForStatus = {
    color = false,
    colors = {
        type = "group",
        dialogInline = true,
        name = L["Resurrection colors"],
        order = 86,
        args = {
            color = {
                order = 100,
                name = L["Casting color"],
                desc = L["Use this color for resurrections that are currently being cast."],
                type = "color",
                hasAlpha = true,
                get = function(t) --luacheck: ignore 212
                    local color = PlexusStatusResurrect.db.profile.alert_resurrect.color
                    return color.r, color.g, color.b, color.a or 1
                end,
                set = function(t, r, g, b, a) --luacheck: ignore 212
                    local color = PlexusStatusResurrect.db.profile.alert_resurrect.color
                    color.r, color.g, color.b, color.a = r, g, b, a or 1
                end,
            },
            color2 = {
                order = 101,
                name = L["Pending color"],
                desc = L["Use this color for resurrections that have finished casting and are waiting to be accepted."],
                type = "color",
                hasAlpha = true,
                get = function(t) --luacheck: ignore 212
                    local color = PlexusStatusResurrect.db.profile.alert_resurrect.color2
                    return color.r, color.g, color.b, color.a or 1
                end,
                set = function(t, r, g, b, a) --luacheck: ignore 212
                    local color = PlexusStatusResurrect.db.profile.alert_resurrect.color2
                    color.r, color.g, color.b, color.a = r, g, b, a or 1
                end,
            },
        },
    },
}

local function GetSpellName(spellid)
    local info = GetSpellInfo(spellid)
    if Plexus:IsRetailWow() then
        if info and info.name then
            return info.name
        end
    else
        return info
    end
end
PlexusStatusResurrect.GetSpellName = GetSpellName

-- Spell lists used by the mechanism files.
PlexusStatusResurrect.ResSpells = {
    -- Class Abilities
    [2008]   = GetSpellName(2008),   -- Ancestral Spirit (Shaman)
    [7328]   = GetSpellName(7328),   -- Redemption (Paladin)
    [2006]   = GetSpellName(2006),   -- Resurrection (Priest)
    [115178] = GetSpellName(115178), -- Resuscitate (Monk)
    [50769]  = GetSpellName(50769),  -- Revive (Druid)
    [20484]  = GetSpellName(20484),  -- Rebirth (Druid)
    --[982]    = GetSpellName(982),    -- Revive Pet (Hunter)
    [361227] = GetSpellName(361227), -- Return (Evoker)
    -- Items
    [8342]   = GetSpellName(8342),   -- Defibrillate (Goblin Jumper Cables)
    [22999]  = GetSpellName(22999),  -- Defibrillate (Goblin Jumper Cables XL)
    [54732]  = GetSpellName(54732),  -- Defibrillate (Gnomish Army Knife)
    [164729] = GetSpellName(164729), -- Defibrillate (Ultimate Gnomish Army Knife)
    [265116] = GetSpellName(265116), -- Defibrillate (Unstable Temporal Time Shifter)
    [199119] = GetSpellName(199119), -- Failure Detection Aura (Failure Detection Pylon) -- NEEDS CHECK
    [187777] = GetSpellName(187777), -- Reawaken (Brazier of Awakening)
    -- pening souslstone ank etc
    [160029] = GetSpellName(160029), -- Resurrecting aka pending
    --[27740] = GetSpellName(27740), -- Reincarnation
    --[20608] = GetSpellName(20608), -- Reincarnation
    --[225080] = GetSpellName(225080), -- Reincarnation
    --[21169] = GetSpellName(21169), -- Reincarnation
}
PlexusStatusResurrect.MassResSpells = {
    -- massSpells
    [212056] = GetSpellName(212056), -- Absolution (Holy Paladin)
    [212048] = GetSpellName(212048), -- Ancestral Vision (Restoration Shaman)
    [212036] = GetSpellName(212036), -- Mass Resurrection (Discipline/Holy Priest)
    [212051] = GetSpellName(212051), -- Reawaken (Mistweaver Monk)
    [212040] = GetSpellName(212040), -- Revitalize (Restoration Druid)
    [361178] = GetSpellName(361178)  -- Mass Return (Preservation Evoker)
}

------------------------------------------------------------------------

function PlexusStatusResurrect:PostInitialize()
    self:Debug("PostInitialize")

    self:RegisterStatus("alert_resurrect", L["Resurrection"], extraOptionsForStatus, true)

    self.core.options.args.alert_resurrect.args.range = nil
end

function PlexusStatusResurrect:OnStatusEnable(status)
    self:Debug("OnStatusEnable", status)

    self:RegisterEvent("INCOMING_RESURRECT_CHANGED")
    for _, event in ipairs(self.trackedEvents) do
        self:RegisterEvent(event)
    end
end

function PlexusStatusResurrect:OnStatusDisable(status)
    self:Debug("OnStatusDisable", status)

    self:UnregisterEvent("INCOMING_RESURRECT_CHANGED")
    for _, event in ipairs(self.trackedEvents) do
        self:UnregisterEvent(event)
    end

    self.core:SendStatusLostAllUnits("alert_resurrect")
end

------------------------------------------------------------------------

function PlexusStatusResurrect:INCOMING_RESURRECT_CHANGED(event, unit) --luacheck: ignore 212
    if not unit then return end
    local guid = UnitGUID(unit)
    local db = self.db.profile.alert_resurrect
    if not PlexusRoster:IsGUIDInRaid(guid) then return end
    local startTime = GetTime()
    local duration = 10
    if UnitHasIncomingResurrection(unit) then
        self.core:SendStatusGained(guid, "alert_resurrect",
            db.priority,
            nil,
            db.color,
            db.text,
            nil,
            nil,
            "Interface\\ICONS\\Spell_holy_guardianspirit",
            startTime,
            duration)
    else
        self.core:SendStatusLost(guid, "alert_resurrect")
    end
end
