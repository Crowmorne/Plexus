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
        end
    else
        incomingText = AbbreviateNumbers(incomingText)
    end
    self.core:SendStatusGained(guid, "alert_heals",
        settings.priority,
        settings.range,
        settings.color,
        not Plexus:issecretvalue(incomingText) and format(settings.text, incomingText) or incomingText,
        estimatedHealth,
        maxHealth)
end
