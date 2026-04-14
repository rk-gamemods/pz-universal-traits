-- UT_bouncer_I.lua
-- Bouncer (I & II): injury downgrade — experience handling rough crowds
-- means the character rolls with hits, reducing serious injuries to
-- lesser ones on a cooldown timer.
--
-- Downgrade table (checked in severity order):
--   Bite        → Deep wound (laceration), clears zombie infection
--   Deep wound  → Scratch
--   Fracture    → Halved fracture time
--
-- Cooldown scales with Strength: max(MIN_CD_SEC, baseSec - STR * 10) * 60 ticks
--   Tier I  base = 300s  →  at STR 10 = 200s
--   Tier II base = 240s  →  at STR 10 = 140s
-- Only one downgrade per cooldown. Logs each event to console.
--
-- SAFETY: reads + writes only BodyPart boolean/float fields via Java
-- setter methods. No animation, bump, or movement state touched.

local TRAIT_I  = "UniversalTraits:UT_bouncer_I"
local TRAIT_II = "UniversalTraits:UT_bouncer_II"

-- Cooldown formula constants
local BASE_SEC_I    = 300   -- Tier I base cooldown in real-world seconds
local BASE_SEC_II   = 240   -- Tier II base cooldown in real-world seconds
local SEC_PER_STR   = 10    -- seconds removed per Strength level
local MIN_CD_SEC    = 10    -- absolute minimum cooldown (seconds)
local TICKS_PER_SEC = 60    -- PZ runs at ~60 ticks/second

local BodyPartType = BodyPartType

local function partName(part)
    return BodyPartType.ToString(part:getType())
end

--- Compute cooldown in ticks based on tier and player strength.
local function computeCooldown(player, isTierII)
    local baseSec = isTierII and BASE_SEC_II or BASE_SEC_I
    local strength = 0
    pcall(function() strength = player:getPerkLevel(Perks.Strength) end)
    local cdSec = math.max(MIN_CD_SEC, baseSec - strength * SEC_PER_STR)
    return cdSec * TICKS_PER_SEC, strength, cdSec
end

local function onTick(player, tick)
    local md = tick.modData

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
    local bd = player:getBodyDamage()
    local parts = bd:getBodyParts()
    local count = parts:size()

    for i = 0, count - 1 do
        local part = parts:get(i)
        local name = partName(part)

        -- Priority 1: Bite → Deep wound (laceration)
        if part:bitten() then
            part:SetBitten(false)
            part:setBiteTime(0)
            part:SetInfected(false)
            part:SetFakeInfected(false)
            -- Apply deep wound as the downgraded injury
            part:setDeepWounded(true)
            part:setDeepWoundTime(20)
            md["UT_bouncer_cooldown"] = cooldown
            UTCore.diagLog("bouncer", "DOWNGRADE",
                name .. " bite->deepwound STR=" .. strength .. " cd=" .. cdSec .. "s")
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
