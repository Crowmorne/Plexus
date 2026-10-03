--[[--------------------------------------------------------------------
    Plexus
    Compact party and raid unit frames.
    Copyright (c) 2006-2009 Kyle Smith (Pastamancer)
    Copyright (c) 2009-2018 Phanx <addons@phanx.net>
    Copyright (c) 2018-2026 Doadin <doadinaddons@gmail.com>
    All rights reserved. See the accompanying LICENSE file for details.
------------------------------------------------------------------------
    ResurrectFromCombatLog.lua
    Resurrection mechanism for Resurrect.lua: guesses mass resurrections
    and pending resurrections from the combat log, and clears them when
    the cast stops or is interrupted.
----------------------------------------------------------------------]]

local _, Plexus = ...

local GetTime = GetTime

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
local UnitCastingInfo = UnitCastingInfo
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost

local PlexusRoster = Plexus:GetModule("PlexusRoster")
local PlexusStatusResurrect = Plexus:GetModule("PlexusStatus"):GetModule("PlexusStatusResurrect")

local GetSpellName = PlexusStatusResurrect.GetSpellName
local ResSpells = PlexusStatusResurrect.ResSpells
local MassResSpells = PlexusStatusResurrect.MassResSpells

local trackedEvents = PlexusStatusResurrect.trackedEvents
trackedEvents[#trackedEvents + 1] = "COMBAT_LOG_EVENT_UNFILTERED"
trackedEvents[#trackedEvents + 1] = "UNIT_SPELLCAST_STOP"
trackedEvents[#trackedEvents + 1] = "UNIT_SPELLCAST_INTERRUPTED"

function PlexusStatusResurrect:UNIT_SPELLCAST_STOP(event, eventunit, castguid, spellid) --luacheck: ignore 212
    --print(event)
    for spelllistid, _ in pairs(MassResSpells) do
        if spellid == spelllistid then
            self.core:SendStatusLostAllUnits("alert_resurrect")
        end
    end
end
function PlexusStatusResurrect:UNIT_SPELLCAST_INTERRUPTED(event, unit, castguid, spellid) --luacheck: ignore 212
    for spelllistid, _ in pairs(MassResSpells) do
        if spellid == spelllistid then
            self.core:SendStatusLostAllUnits("alert_resurrect")
        end
    end
end
-- Guess mass ress from combat log since INCOMING_RESURRECT_CHANGED event doesnt fire
function PlexusStatusResurrect:COMBAT_LOG_EVENT_UNFILTERED(event, eventunit, castguid, spellid) --luacheck: ignore 212
    --print(CombatLogGetCurrentEventInfo())
    --timestamp, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName, _
    local timestamp, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, _, spellName, _ = CombatLogGetCurrentEventInfo()
    if not PlexusRoster:IsGUIDInGroup(sourceGUID) then
        return
    end
    --Dead Players Cant Cast
    if sourceGUID and (not UnitIsDead(sourceGUID) or not UnitIsGhost(sourceGUID) or not UnitIsDeadOrGhost(sourceGUID)) then
        self.core:SendStatusLost(sourceGUID, "alert_resurrect")
    end
    local db = self.db.profile.alert_resurrect
    for _, spelllistname in pairs(MassResSpells) do --check that the spell casted is a mass res
        if spellName == spelllistname then
            if eventType == "SPELL_CAST_START" then
                for guid, unit in PlexusRoster:IterateRoster() do
                    if (UnitIsDead(unit) or UnitIsGhost(unit) or UnitIsDeadOrGhost(unit)) then
                        local startTime = GetTime()
                        local casterUnitID = PlexusRoster:GetUnitidByGUID(sourceGUID)
                        local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo(casterUnitID)
                        local duration = (endTimeMS and startTimeMS and (endTimeMS - startTimeMS) / 1000) or 10
                        local icon
                        if Plexus:IsRetailWow() then
                            icon = spellid and GetSpellInfo(spellid).originalIconID or "Interface\\ICONS\\Spell_holy_guardianspirit"
                        else
                            icon = spellid and select(3,GetSpellInfo(spellid)) or "Interface\\ICONS\\Spell_holy_guardianspirit"
                        end
                        self.core:SendStatusGained(guid, "alert_resurrect",
                        db.priority,
                        nil,
                        db.color,
                        db.text,
                        nil,
                        nil,
                        icon,
                        startTime,
                        duration)
                    end
                end
            end
            if eventType == "SPELL_CAST_SUCCESS" then
                self.core:SendStatusLostAllUnits("alert_resurrect")
            end
            if eventType == "SPELL_CAST_FAILED" then --luacheck: ignore 631
                self.core:SendStatusLostAllUnits("alert_resurrect")
            end
        end
    end
    for spelllistid, spelllistname in pairs(ResSpells) do --check that the spell casted is a single res
        if spellName == spelllistname then
            if eventType == "SPELL_CAST_SUCCESS" then
                self.core:SendStatusLost(destGUID, "alert_resurrect")
            end
            if eventType == "SPELL_CAST_FAILED" then
                self.core:SendStatusLost(destGUID, "alert_resurrect")
            end
            if eventType == "SPELL_AURA_APPLIED" then
                local icon = spelllistid and select(3,GetSpellName(spelllistid)) or "Interface\\ICONS\\Spell_holy_guardianspirit"
                if not timestamp then timestamp = GetTime() end
                local startTime = GetTime()
                self.core:SendStatusGained(destGUID, "alert_resurrect",
                db.priority,
                nil,
                db.color2,
                db.text,
                nil,
                nil,
                icon,
                startTime,
                60)
            end
            if eventType == "SPELL_AURA_REMOVED" then
                self.core:SendStatusLost(destGUID, "alert_resurrect")
            end
        end
    end
end
