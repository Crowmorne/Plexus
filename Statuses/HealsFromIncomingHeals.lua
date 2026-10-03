--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    HealsFromIncomingHeals.lua
    Incoming heals mechanism for Heals.lua, using the game's
    UnitGetIncomingHeals API.

    LibHealComm-4.0 can replace the game's numbers, but only if another
    addon loaded the library (Plexus doesn't ship it) and the player
    unticked "Ignore LibHealComm" (ignore_heal_comm, on by default).
----------------------------------------------------------------------]]

local _, Plexus = ...
local L = Plexus.L

local format = format

local UnitGetIncomingHeals = UnitGetIncomingHeals
local UnitHealth = UnitHealth

local PlexusStatusHeals = Plexus:GetModule("PlexusStatus"):GetModule("PlexusStatusHeals")

local HealComm

local options = PlexusStatusHeals.statusOptions

options.ignoreHealComm = {
    type = "toggle", width = "double",
    name = L["Ignore LibHealComm"],
    desc = L["Ignore LibHealComm and Use Game API."],
    get = function()
        return PlexusStatusHeals.db.profile.alert_heals.ignore_heal_comm
    end,
    set = function(_, v)
        PlexusStatusHeals.db.profile.alert_heals.ignore_heal_comm = v
        PlexusStatusHeals:UpdateAllUnits()
    end,
}

options.minimumValue = {
    width = "double",
    type = "range", min = 0, max = 0.5, step = 0.005, isPercent = true,
    name = L["Minimum Value"],
    desc = L["Only show incoming heals greater than this percent of the unit's maximum health."],
    get = function()
        return PlexusStatusHeals.db.profile.alert_heals.minimumValue
    end,
    set = function(_, v)
        PlexusStatusHeals.db.profile.alert_heals.minimumValue = v
    end,
}

options.deficit = {
    type = "toggle", width = "double",
    name = L["Work With Health Deficit"],
    desc = L[""],
    get = function()
        return PlexusStatusHeals.db.profile.alert_heals.deficit
    end,
    set = function(_, v)
        PlexusStatusHeals.db.profile.alert_heals.deficit = v
        PlexusStatusHeals:UpdateAllUnits()
    end,
}

function PlexusStatusHeals:StartTracking()
    HealComm = LibStub:GetLibrary("LibHealComm-4.0", true) --luacheck: ignore 111
    if HealComm then
        local function HealComm_Heal_Update()
            self:UpdateAllUnits()
        end
        local function HealComm_Modified()
            self:UpdateAllUnits()
        end
        HealComm.RegisterCallback(self, 'HealComm_HealStarted', HealComm_Heal_Update)
        HealComm.RegisterCallback(self, 'HealComm_HealUpdated', HealComm_Heal_Update)
        HealComm.RegisterCallback(self, 'HealComm_HealDelayed', HealComm_Heal_Update)
        HealComm.RegisterCallback(self, 'HealComm_HealStopped', HealComm_Heal_Update)
        HealComm.RegisterCallback(self, 'HealComm_ModifierChanged', HealComm_Modified)
        HealComm.RegisterCallback(self, 'HealComm_GUIDDisappeared', HealComm_Modified)
    end
end

function PlexusStatusHeals:StopTracking()
    HealComm = LibStub:GetLibrary("LibHealComm-4.0", true) --luacheck: ignore 111
    if HealComm then
        HealComm.UnregisterCallback(self, 'HealComm_HealStarted')
        HealComm.UnregisterCallback(self, 'HealComm_HealUpdated')
        HealComm.UnregisterCallback(self, 'HealComm_HealDelayed')
        HealComm.UnregisterCallback(self, 'HealComm_HealStopped')
        HealComm.UnregisterCallback(self, 'HealComm_ModifierChanged')
        HealComm.UnregisterCallback(self, 'HealComm_GUIDDisappeared')
    end
end

function PlexusStatusHeals:UpdateIncomingHeals(unit, guid, settings)
    local useHealComm = HealComm and not settings.ignore_heal_comm

    local incoming = 0
    if not useHealComm then
        incoming = UnitGetIncomingHeals(unit) or 0
    else
        local myIncomingHeal = (HealComm:GetHealAmount(guid, HealComm.ALL_HEALS) or 0) * (HealComm:GetHealModifier(guid) or 1)
        incoming = (incoming + myIncomingHeal) or 0
    end
    self:Debug("UpdateUnit", unit, incoming, UnitGetIncomingHeals(unit, "player") or 0, format("%.2f%%", incoming / Plexus:CalcMaxHP(unit) * 100))
    if settings.ignore_self and useHealComm then
        incoming = HealComm:GetOthersHealAmount(guid, HealComm.ALL_HEALS) or 0
    end

    local maxHealth = Plexus:CalcMaxHP(unit)
    if incoming > 0 then
        if (incoming / maxHealth) > (settings and settings.minimumValue or 0.1) then
            return self:SendIncomingHealsStatus(guid, incoming, UnitHealth(unit) + incoming, maxHealth)
        end
    else
        self.core:SendStatusLost(guid, "alert_heals")
    end
end
