-- UT_bouncer_I.lua
-- Bouncer (I & II): injury downgrade. Experience handling rough crowds
-- means the character rolls with hits, downgrading NEW injuries to
-- lesser ones on a cooldown timer.
--
-- ONLY reacts to injuries that appear AFTER bouncer becomes ready.
-- A snapshot of current injuries is taken at init and whenever the
-- cooldown reaches 0. Injuries present in the snapshot are baseline
-- and ignored; only deltas (snapshot→live) trigger a downgrade.
--
-- Downgrade table (checked in per-part severity order, NEW injuries only):
--   NEW Bite        → Deep wound; clears infection unless pre-existing
--                     (infected at snapshot time)
--   NEW Deep wound  → Scratch
--   NEW Fracture    → Halved fracture time
--
-- Cooldown scales with Strength (per-tier scaling):
--   Tier I:  max(10, 300 - STR * 10) seconds
--   Tier II: max(10, 220 - STR * 20) seconds
--
-- Architecture: injury detection reads the shared UTCore.getInjuries lazy
-- accessor, built once per tick and shared with other medical traits. Direct
-- Java body-part access occurs only after one injury is selected, for the
-- required mutation and diagnostic part name.

local TRAIT_I  = "UniversalTraits:UT_bouncer_I"
local TRAIT_II = "UniversalTraits:UT_bouncer_II"

local BASE_SEC_I     = 300
local BASE_SEC_II    = 220
local SEC_PER_STR_I  = 10
local SEC_PER_STR_II = 20
local MIN_CD_SEC     = 10

local SNAPSHOT_KEY = "UT_bouncer_snapshot"
local COOLDOWN_KEY = "UT_bouncer_cooldown"

--- Build a snapshot table from tick.injuries (plain Lua, serializable).
local function takeSnapshot(injuries)
    local snap = { count = injuries.count }
    for i = 0, injuries.count - 1 do
        local e = injuries[i]
        snap[i] = {
            bitten       = e.bitten,
            deepWounded  = e.deepWounded,
            hasFracture  = (e.fractureTime or 0) > 1,
            infected     = e.infected,
        }
    end
    return snap
end

--- Look up a clean-slate snapshot entry for an index not present in snap
--- (handles save/load where a part was never recorded).
local CLEAN_ENTRY = { bitten=false, deepWounded=false, hasFracture=false, infected=false }

local function snapPart(snap, i)
    return (snap and snap[i]) or CLEAN_ENTRY
end

--- Scan for the first NEW injury (delta between snap and live injuries).
--- Returns partIndex, kind ("bite"|"deep"|"fracture"), or nil.
--- Logs MULTI_NEW if more than one new injury is detected this sweep.
local function scanForNewInjury(injuries, snap)
    local firstIdx, firstKind = nil, nil
    local newCount = 0
    for i = 0, injuries.count - 1 do
        local live = injuries[i]
        local prev = snapPart(snap, i)
        local kind = nil
        if live.bitten and not prev.bitten then
            kind = "bite"
        elseif live.deepWounded and not prev.deepWounded then
            kind = "deep"
        elseif (live.fractureTime or 0) > 1 and not prev.hasFracture then
            kind = "fracture"
        end
        if kind then
            newCount = newCount + 1
            if firstIdx == nil then
                firstIdx, firstKind = i, kind
            end
        end
    end
    if newCount > 1 then
        UTCore.diagLog("bouncer", "MULTI_NEW",
            "count=" .. newCount .. " picked=" .. tostring(firstIdx) .. " kind=" .. tostring(firstKind))
    end
    return firstIdx, firstKind
end

--- Apply the downgrade for a given part via Java setters.
--- Returns a log tag string describing the action.
local function applyDowngrade(bd, partIndex, kind, snap)
    local part = bd:getBodyParts():get(partIndex)
    if kind == "bite" then
        part:SetBitten(false)
        part:setBiteTime(0)
        local prev = snapPart(snap, partIndex)
        local keptInfection
        if prev.infected then
            keptInfection = true
        else
            part:SetInfected(false)
            part:SetFakeInfected(false)
            keptInfection = false
        end
        part:setDeepWounded(true)
        part:setDeepWoundTime(20)
        return keptInfection
            and "bite->deepwound(kept infection)"
            or  "bite->deepwound"
    elseif kind == "deep" then
        part:setDeepWounded(false)
        part:setDeepWoundTime(0)
        part:setScratched(true, true)
        return "deepwound->scratch"
    elseif kind == "fracture" then
        local ft = part:getFractureTime()
        part:setFractureTime(ft * 0.5)
        return string.format("fracture %.1f->%.1f", ft, ft * 0.5)
    end
    return "unknown"
end

--- Compute cooldown seconds based on tier and player strength.
local function computeCooldown(player, isTierII)
    local baseSec   = isTierII and BASE_SEC_II or BASE_SEC_I
    local secPerStr = isTierII and SEC_PER_STR_II or SEC_PER_STR_I
    local strength = 0
    pcall(function() strength = player:getPerkLevel(Perks.Strength) end)
    local cdSec = math.max(MIN_CD_SEC, baseSec - strength * secPerStr)
    return cdSec, strength, cdSec
end

local function onTick(player, tick)
    local md = tick.modData
    local isTierII = UTCore.hasTrait(player, TRAIT_II)

    -- Init: first-ever tick. Take baseline snapshot so pre-existing
    -- injuries (e.g. from save load) are recorded before any trigger.
    if md[COOLDOWN_KEY] == nil then
        md[COOLDOWN_KEY] = 0
        local injuries = UTCore.getInjuries(tick)
        md[SNAPSHOT_KEY] = takeSnapshot(injuries)
        return
    end

    -- Both tiers are specified in real-world seconds, so use the engine's
    -- frame-rate-adjusted elapsed-seconds delta.
    if md[COOLDOWN_KEY] > 0 then
        local elapsed = getGameTime():getRealworldSecondsSinceLastUpdate()
        md[COOLDOWN_KEY] = math.max(0, md[COOLDOWN_KEY] - elapsed)
        -- Cooldown just expired this tick: re-baseline the snapshot.
        -- Whatever exists now is treated as pre-existing and ignored
        -- on future ticks.
        if md[COOLDOWN_KEY] == 0 then
            local injuries = UTCore.getInjuries(tick)
            md[SNAPSHOT_KEY] = takeSnapshot(injuries)
        end
        return
    end

    -- READY (cooldown==0, snapshot exists): scan for deltas.
    local injuries = UTCore.getInjuries(tick)
    if injuries.count == 0 then
        return  -- empty body, nothing to compare
    end
    local snap = md[SNAPSHOT_KEY]
    if snap == nil then
        -- Defensive: no snapshot yet (shouldn't happen after init).
        md[SNAPSHOT_KEY] = takeSnapshot(injuries)
        return
    end

    local partIdx, kind = scanForNewInjury(injuries, snap)
    if partIdx == nil then return end

    -- Downgrade this new injury.
    local cooldown, strength, cdSec = computeCooldown(player, isTierII)
    local bd = tick.bodyDamage
    local action = applyDowngrade(bd, partIdx, kind, snap)
    md[COOLDOWN_KEY] = cooldown

    local partName = "?"
    pcall(function()
        partName = BodyPartType.ToString(bd:getBodyParts():get(partIdx):getType())
    end)
    UTCore.diagLog("bouncer", "DOWNGRADE",
        partName .. " " .. action .. " STR=" .. strength .. " cd=" .. cdSec .. "s")
end

UTCore.registerTickHandler(TRAIT_I, onTick, {
    anyTrait = { TRAIT_I, TRAIT_II }
})
