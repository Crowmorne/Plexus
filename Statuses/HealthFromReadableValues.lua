--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    HealthFromReadableValues.lua
    Health mechanism for Health.lua on clients where health values can be
    compared and computed: adds the low health alert, formats the health
    and deficit texts, and applies the deficit threshold.
----------------------------------------------------------------------]]

local _, Plexus = ...
local L = Plexus.L

local format = format

local PlexusStatusHealth = Plexus:GetModule("PlexusStatus"):GetModule("PlexusStatusHealth")

PlexusStatusHealth.defaultDB.alert_lowHealth = {
    text = L["Low HP"],
    enable = true,
    color = { r = 1, g = 1, b = 1, a = 1 },
    priority = 30,
    threshold = 80,
    range = false,
}

local low_healthOptions = {
    threshold = {
        name = L["Low HP threshold"],
        desc = L["Set the HP % for the low HP warning."],
        type = "range", min = 0, max = 100, step = 1, width = "double",
        get = function()
            return PlexusStatusHealth.db.profile.alert_lowHealth.threshold
        end,
        set = function(_, v)
            PlexusStatusHealth.db.profile.alert_lowHealth.threshold = v
            PlexusStatusHealth:UpdateAllUnits()
        end,
    },
}

function PlexusStatusHealth:RegisterMechanismStatuses()
    self:RegisterStatus("alert_lowHealth", L["Low HP warning"], low_healthOptions)
end

function PlexusStatusHealth:UpdateLowHealth(guid, isDead, cur, max)
    if isDead then
        self:StatusLowHealth(guid, false)
    else
        self:StatusLowHealth(guid, (cur / max * 100) <= self.db.profile.alert_lowHealth.threshold)
    end
end

function PlexusStatusHealth:DescribeHealth(unitid, cur, max) --luacheck: ignore 212
    local showDeficit = (cur / max * 100) <= self.db.profile.unit_healthDeficit.threshold

    if cur >= max then
        return nil, nil, true, showDeficit
    end

    local healthText
    if cur > 999 then
        healthText = format("%.1fk", cur / 1000)
    else
        healthText = format("%d", cur)
    end

    local deficitText
    local deficit = max - cur
    if deficit > 999 then
        deficitText = format("-%.1fk", deficit / 1000)
    else
        deficitText = format("-%d", deficit)
    end

    return healthText, deficitText, false, showDeficit
end

function PlexusStatusHealth:IsLowHealth(cur, max)
    return (cur / max * 100) <= self.db.profile.alert_lowHealth.threshold
end

function PlexusStatusHealth:StatusLowHealth(guid, gained)
    local settings = self.db.profile.alert_lowHealth

    -- return if this option isn't enabled
    if not settings.enable then return end

    if gained then
        self.core:SendStatusGained(guid, "alert_lowHealth",
            settings.priority,
            settings.range,
            settings.color,
            settings.text,
            nil,
            nil,
            settings.icon)
    else
        self.core:SendStatusLost(guid, "alert_lowHealth")
    end
end
