--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    HealsFromCalculator.lua
    Incoming heals mechanism for Heals.lua, using the heal prediction
    calculator API. Amounts may be secret, so they are passed through
    without comparing them.
----------------------------------------------------------------------]]

local _, Plexus = ...

local UnitGroupRolesAssigned = UnitGroupRolesAssigned

local PlexusFrame = Plexus:GetModule("PlexusFrame")
local PlexusStatusHeals = Plexus:GetModule("PlexusStatus"):GetModule("PlexusStatusHeals")

-- This mechanism sends the incoming amount alone, not health + incoming, so by default
-- show it on the Incoming Healing Bar, which starts at the end of the health fill,
-- instead of the Healing Bar, which expects health + incoming.
PlexusFrame.defaultDB.statusmap.healingBar.alert_heals = false
PlexusFrame.defaultDB.statusmap.ei_bar_barfour = PlexusFrame.defaultDB.statusmap.ei_bar_barfour or {}
PlexusFrame.defaultDB.statusmap.ei_bar_barfour.alert_heals = true

local calculator

-- Nothing to start or stop: the calculator only needs the game's heal and
-- health events, which Heals.lua registers itself.
function PlexusStatusHeals:StartTracking() --luacheck: ignore 212
end

function PlexusStatusHeals:StopTracking() --luacheck: ignore 212
end

function PlexusStatusHeals:UpdateIncomingHeals(unit, guid, settings)
    if not calculator then
        calculator = CreateUnitHealPredictionCalculator()
    else
        calculator:Reset()
    end
    local role = UnitGroupRolesAssigned(unit)
    local healer = role == "HEALER" and unit or nil
    UnitGetDetailedHealPrediction(unit, healer, calculator)  -- 'calculator' is updated with new data after this call.
    local incoming, _, incomingHealsFromOthers = calculator:GetIncomingHeals()
    if settings.ignore_self then
        incoming = incomingHealsFromOthers or 0
    end

    self:SendIncomingHealsStatus(guid, incoming, incoming, Plexus:CalcMaxHP(unit))
end
