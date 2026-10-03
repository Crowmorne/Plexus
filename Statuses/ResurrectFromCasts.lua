--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    ResurrectFromCasts.lua
    Resurrection mechanism for Resurrect.lua: shows resurrections while
    a resurrection spell is being cast on a dead group member.
----------------------------------------------------------------------]]

local _, Plexus = ...

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
local UnitCastingInfo = UnitCastingInfo
local UnitGUID = UnitGUID
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost

local PlexusRoster = Plexus:GetModule("PlexusRoster")
local PlexusStatusResurrect = Plexus:GetModule("PlexusStatus"):GetModule("PlexusStatusResurrect")

local ResSpells = PlexusStatusResurrect.ResSpells

local trackedEvents = PlexusStatusResurrect.trackedEvents
trackedEvents[#trackedEvents + 1] = "UNIT_SPELLCAST_START"

function PlexusStatusResurrect:UNIT_SPELLCAST_START(event, source, destGUID, castguid, spellid) --luacheck: ignore 212
    local sourceguid = UnitGUID(source)
    local db = self.db.profile.alert_resurrect
    for spelllistid, _ in pairs(ResSpells) do
        if spellid == spelllistid then
            for guid, unit in PlexusRoster:IterateRoster() do
                if destGUID ~= guid then return end
                if UnitIsDead(unit) or UnitIsGhost(unit) or UnitIsDeadOrGhost(unit) then
                    local casterUnitID = PlexusRoster:GetUnitidByGUID(sourceguid)
                    local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo(casterUnitID)
                    local icon
                    if Plexus:IsRetailWow() then
                        icon = spellid and GetSpellInfo(spellid).originalIconID or "Interface\\ICONS\\Spell_Shadow_Soulgem"
                    else
                        icon = spellid and select(3,GetSpellInfo(spellid)) or "Interface\\ICONS\\Spell_Shadow_Soulgem"
                    end
                    local duration = (endTimeMS and startTimeMS and (endTimeMS - startTimeMS) / 1000) or 10
                    --combat res does not work with above math.
                    if spellid == (8342 or 22999 or 54732 or 164729 or 265116) then
                        duration = 4
                    end
                    if duration <= 0 then
                        duration = 1
                    end
                    self.core:SendStatusGained(guid, "alert_resurrect",
                    db.priority,
                    nil,
                    db.color,
                    db.text,
                    nil,
                    nil,
                    icon,
                    startTimeMS,
                    duration)
                end
            end
        end
    end
end
