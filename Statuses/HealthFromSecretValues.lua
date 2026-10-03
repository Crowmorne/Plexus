--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    HealthFromSecretValues.lua
    Health mechanism for Health.lua on clients where health values are
    secret to addons. They can't be compared or computed, so the texts
    come from game functions that accept secret values, and the deficit
    is always shown.
----------------------------------------------------------------------]]

local _, Plexus = ...

local PlexusStatusHealth = Plexus:GetModule("PlexusStatus"):GetModule("PlexusStatusHealth")

-- No low health alert: comparing a secret value to the threshold isn't possible.
function PlexusStatusHealth:RegisterMechanismStatuses() --luacheck: ignore 212
end

function PlexusStatusHealth:UpdateLowHealth(guid, isDead, cur, max) --luacheck: ignore 212
end

function PlexusStatusHealth:DescribeHealth(unitid, cur, max) --luacheck: ignore 212
    return AbbreviateNumbers(cur), AbbreviateNumbers(UnitHealthMissing(unitid)), false, true
end
