-- UT_bouncer_I.lua
-- Bouncer (I & II): injury downgrade — experience handling rough crowds
-- means the character rolls with hits, reducing serious injuries to
-- lesser ones on a cooldown timer.
--
-- Downgrade table (checked in severity order):
--   Bite        → Deep wound (laceration); clears zombie infection ONLY
--                 if the infection is new (not pre-existing from a prior wound)
--   Deep wound  → Scratch
--   Fracture    → Halved fracture time
--
-- Cooldown scales with Strength (per-tier scaling):
--   Tier I:  max(10, 300 - STR * 10) seconds  →  STR 10 = 200s
--   Tier II: max(10, 220 - STR * 20) seconds  →  STR 10 = 20s
-- Only one downgrade per cooldown. Logs each event to console.
--
-- Infection preservation: each tick, a snapshot of which body parts
-- carry zombie infection is stored in moddata. When a bite is
-- downgraded, the snapshot from the PREVIOUS tick is checked. If that
-- part was already infected before the bite landed, the infection is
-- kept (bouncer prevents the wound, not the pre-existing virus).
--
-- SAFETY: reads + writes only BodyPart boolean/float fields via Java
-- setter methods. No animation, bump, or movement state touched.

local TRAIT_I  = "UniversalTraits:UT_bouncer_I"
local TRAIT_II = "UniversalTraits:UT_bouncer_II"

-- Cooldown formula constants (per-tier)
local BASE_SEC_I     = 300   -- Tier I base cooldown seconds
local BASE_SEC_II    = 220   -- Tier II base cooldown seconds
local SEC_PER_STR_I  = 10    -- Tier I: seconds removed per Strength level
local SEC_PER_STR_II = 20    -- Tier II: seconds removed per Strength level
local MIN_CD_SEC     = 10    -- absolute minimum cooldown (seconds)
local TICKS_PER_SEC  = 60    -- PZ runs at ~60 ticks/second

-- Infection tracking key in moddata
local PREV_INFECTED_KEY = "UT_bouncer_prevInfected"

local BodyPartType = BodyPartType

local function partName(part)
    return BodyPartType.ToString(part:getType())
end

--- Parse previous-tick infected set from moddata.
-- Returns { [partIndex] = true } for parts that had zombie infection
-- on the previous tick.
local function loadPrevInfected(md)
    local s = md[PREV_INFECTED_KEY]
    if not s or s == "" then return {} end
    local set = {}
    for idx in string.gmatch(s, "%d+") do
        set[tonumber(idx)] = true
    end
    return set
end

--- Snapshot current infected parts into moddata for next tick.
local function snapshotInfected(md, parts, count)
    local buf = {}
    for i = 0, count - 1 do
        if parts:get(i):isInfected() then
            buf[#buf + 1] = tostring(i)
        end
    end
    md[PREV_INFECTED_KEY] = table.concat(buf, ",")
end

--- Compute cooldown in ticks based on tier and player strength.
local function computeCooldown(player, isTierII)
    local baseSec   = isTierII and BASE_SEC_II or BASE_SEC_I
    local secPerStr = isTierII and SEC_PER_STR_II or SEC_PER_STR_I
    local strength = 0
    pcall(function() strength = player:getPerkLevel(Perks.Strength) end)
    local cdSec = math.max(MIN_CD_SEC, baseSec - strength * secPerStr)
    return cdSec * TICKS_PER_SEC, strength, cdSec
end

local function onTick(player, tick)
    local md = tick.modData

    -- Access body parts early — needed for infection snapshot every tick
    local bd = player:getBodyDamage()
    local parts = bd:getBodyParts()
    local count = parts:size()

    -- Infection tracking: load last tick's snapshot, then record current
    -- state BEFORE any modifications. Runs every tick (even during
    -- cooldown) so the snapshot stays fresh.
    local prevInfected = loadPrevInfected(md)
    snapshotInfected(md, parts, count)

    -- Init cooldown
    if md["UT_bouncer_cooldown"] == nil then
        md["UT_bouncer_cooldown"] = 0
    end

    -- Decrement cooldown each tick (minimum 0)
    if md["UT_bouncer_cooldown"] > 0 then
        md["UT_bouncer_cooldown"] = md["UT_bouncer_cooldown"] - 1
        return
    end

    -- Determine tier and compute strength-scaled cooldown
    local isTierII = UTCore.hasTrait(player, TRAIT_II)
    local cooldown, strength, cdSec = computeCooldown(player, isTierII)

    -- Scan all body parts for downgradeable injuries (severity order)

    for i = 0, count - 1 do
        local part = parts:get(i)
        local name = partName(part)

        -- Priority 1: Bite → Deep wound (laceration)
        if part:bitten() then
            part:SetBitten(false)
            part:setBiteTime(0)
            -- Only clear infection if it is NEW (not present last tick).
            -- Pre-existing zombie virus is preserved — bouncer prevents
            -- the wound escalation, not an existing infection.
            local keptInfection = false
            if prevInfected[i] then
                keptInfection = true
            else
                part:SetInfected(false)
                part:SetFakeInfected(false)
            end
            -- Apply deep wound as the downgraded injury
            part:setDeepWounded(true)
            part:setDeepWoundTime(20)
            md["UT_bouncer_cooldown"] = cooldown
            local action = keptInfection
                and "bite->deepwound(kept infection)"
                or  "bite->deepwound"
            UTCore.diagLog("bouncer", "DOWNGRADE",
                name .. " " .. action .. " STR=" .. strength .. " cd=" .. cdSec .. "s")
            return
        end

        -- Priority 2: Deep wound → Scratch
        if part:isDeepWounded() then
            part:setDeepWounded(false)
            part:setDeepWoundTime(0)
            -- Apply scratch as the downgraded injury
            part:setScratched(true, true)
            md["UT_bouncer_cooldown"] = cooldown
            UTCore.diagLog("bouncer", "DOWNGRADE",
                name .. " deepwound->scratch STR=" .. strength .. " cd=" .. cdSec .. "s")
            return
        end

        -- Priority 3: Fracture → Halve fracture time
        if part:getFractureTime() > 1 then
            local ft = part:getFractureTime()
            part:setFractureTime(ft * 0.5)
            md["UT_bouncer_cooldown"] = cooldown
            UTCore.diagLog("bouncer", "DOWNGRADE",
                name .. " fracture " .. string.format("%.1f->%.1f", ft, ft * 0.5)
                .. " STR=" .. strength .. " cd=" .. cdSec .. "s")
            return
        end
    end
end

UTCore.registerTickHandler(TRAIT_I, onTick, {
    anyTrait = { TRAIT_I, TRAIT_II }
})
