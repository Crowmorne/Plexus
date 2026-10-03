--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    Heals.lua
    Plexus status module for incoming heals.

    This file contains the parts shared by every client. How incoming heals
    are read is up to one of the mechanism files, picked in the .toc:
      HealsFromCalculator.lua    - heal prediction calculator API
      HealsFromIncomingHeals.lua - UnitGetIncomingHeals, optionally LibHealComm
    A mechanism file implements:
      PlexusStatusHeals:StartTracking()   - called when the status is enabled
      PlexusStatusHeals:StopTracking()    - called when the status is disabled
      PlexusStatusHeals:UpdateIncomingHeals(unit, guid, settings)
----------------------------------------------------------------------]]

local _, Plexus = ...
local L = Plexus.L

local format = format

local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsVisible = UnitIsVisible

-- AbbreviateNumbers returns values below its smallest breakpoint unrounded (e.g. "51.777"),
-- and the amount may be secret, so it can't be rounded here. The breakpoint at 1 makes
-- AbbreviateNumbers round it down instead. Custom breakpoints replace the game's defaults,
-- so the usual K/M steps are listed as well.
local abbreviateOptions = {
    breakpointData = {
        { breakpoint = 10000000, abbreviation = SECOND_NUMBER_CAP_NO_SPACE, abbreviationIsGlobal = false, significandDivisor = 1000000, fractionDivisor = 1 },
        { breakpoint = 1000000,  abbreviation = SECOND_NUMBER_CAP_NO_SPACE, abbreviationIsGlobal = false, significandDivisor = 100000,  fractionDivisor = 10 },
        { breakpoint = 10000,    abbreviation = FIRST_NUMBER_CAP_NO_SPACE,  abbreviationIsGlobal = false, significandDivisor = 1000,    fractionDivisor = 1 },
        { breakpoint = 1000,     abbreviation = FIRST_NUMBER_CAP_NO_SPACE,  abbreviationIsGlobal = false, significandDivisor = 100,     fractionDivisor = 10 },
        { breakpoint = 1,        abbreviation = "",                         abbreviationIsGlobal = false, significandDivisor = 1,       fractionDivisor = 1 },
    },
}

local settings

local PlexusRoster = Plexus:GetModule("PlexusRoster")
local PlexusStatusHeals = Plexus:NewStatusModule("PlexusStatusHeals")

PlexusStatusHeals.menuName = L["Heals"]
PlexusStatusHeals.options = false

PlexusStatusHeals.defaultDB = {
    alert_heals = {
        enable = true,
        priority = 50,
        color = { r = 0, g = 1, b = 0, a = 1 },
        text = "+%s",
        icon = nil,
        ignore_self = false,
        ignore_heal_comm = true,
        minimumValue = 0.1,
        reduced_heal_absorb = true,
        deficit = false,
    },
}

-- Mechanism files add their own options to this table.
PlexusStatusHeals.statusOptions = {
    ignoreSelf = {
        type = "toggle", width = "double",
        name = L["Ignore Self"],
        desc = L["Ignore heals cast by you."],
        get = function()
            return PlexusStatusHeals.db.profile.alert_heals.ignore_self
        end,
        set = function(_, v)
            PlexusStatusHeals.db.profile.alert_heals.ignore_self = v
            PlexusStatusHeals:UpdateAllUnits()
        end,
    },
    reduced_heal_absorb = {
        type = "toggle", width = "double",
        name = L["Factor Heal Absorbs"],
        desc = L["Factor heal absorbs into the incoming heals."],
        get = function()
            return PlexusStatusHeals.db.profile.alert_heals.reduced_heal_absorb
        end,
        set = function(_, v)
            PlexusStatusHeals.db.profile.alert_heals.reduced_heal_absorb = v
            PlexusStatusHeals:UpdateAllUnits()
        end,
        hidden = true,
    },
}

function PlexusStatusHeals:PostInitialize()
    settings = PlexusStatusHeals.db.profile.alert_heals
    self:RegisterStatus("alert_heals", L["Incoming heals"], self.statusOptions, true)
end

function PlexusStatusHeals:OnStatusEnable(status)
    if status == "alert_heals" then
        self:RegisterEvent("UNIT_HEALTH", "UpdateUnit")
        self:RegisterEvent("UNIT_MAXHEALTH", "UpdateUnit")
        self:RegisterEvent("UNIT_HEAL_PREDICTION", "UpdateUnit")
        self:StartTracking()
        self:UpdateAllUnits()
    end
end

function PlexusStatusHeals:OnStatusDisable(status)
    if status == "alert_heals" then
        self:UnregisterEvent("UNIT_HEALTH")
        self:UnregisterEvent("UNIT_MAXHEALTH")
        self:UnregisterEvent("UNIT_HEAL_PREDICTION")
        self:StopTracking()
        self.core:SendStatusLostAllUnits("alert_heals")
    end
end

function PlexusStatusHeals:PostReset() --luacheck: ignore 212
    settings = PlexusStatusHeals.db.profile.alert_heals
end

function PlexusStatusHeals:UpdateAllUnits()
    for _, unit in PlexusRoster:IterateRoster() do
        self:UpdateUnit("UpdateAllUnits", unit)
    end
end

function PlexusStatusHeals:UpdateUnit(event, unit)
    self:Debug("UpdateUnit Event: ", event)
    if not unit then return end

    local guid = UnitGUID(unit)
    if not PlexusRoster:IsGUIDInRaid(guid) then return end

    if UnitIsVisible(unit) and not UnitIsDeadOrGhost(unit) then
        self:UpdateIncomingHeals(unit, guid, settings)
    end
end

function PlexusStatusHeals:SendIncomingHealsStatus(guid, incoming, estimatedHealth, maxHealth)
    if not Plexus:issecretvalue(estimatedHealth) and settings.deficit then
        local healthDeficit = maxHealth - estimatedHealth
        local deficitText
        if healthDeficit < 0 then
            if healthDeficit > 0.1 then
                deficitText = tostring(-healthDeficit)  -- Convert to string without "-" sign
            else
                deficitText = format("+%.1fk", -healthDeficit / 1000)
            end
        else
            if healthDeficit <= -0.1 then
                deficitText = tostring(healthDeficit)  -- Convert to string without "+" sign
            else
                deficitText = format("-%.1fk", healthDeficit / 1000)
            end
        end
        local incomingText = format("%s", deficitText, incoming)
        self.core:SendStatusGained(guid, "alert_heals",
            settings.priority,
            settings.range,
            settings.color,
            incomingText,
            estimatedHealth,
            maxHealth)
        return
    end
    local incomingText = incoming
    if not Plexus:issecretvalue(incoming) then
        if incoming > 9999 then
            incomingText = format("%.0fk", incoming / 1000)
        elseif incoming > 999 then
            incomingText = format("%.1fk", incoming / 1000)
        else
            -- amounts can be fractional (heal modifiers), so round them
            incomingText = format("%.0f", incoming)
        end
    else
        incomingText = AbbreviateNumbers(incomingText, abbreviateOptions)
    end
    self.core:SendStatusGained(guid, "alert_heals",
        settings.priority,
        settings.range,
        settings.color,
        not Plexus:issecretvalue(incomingText) and format(settings.text, incomingText) or incomingText,
        estimatedHealth,
        maxHealth)
end
