-- UTCore_FractureHook.lua
-- Reads UT_fractureMult from player moddata.
-- When the local player takes a weapon hit, rolls an additional fracture chance
-- scaled by the multiplier. On success, fractures one non-fractured load-bearing
-- body part chosen at random.
--
-- Base fracture chance per hit: 4%.
-- With UT_fractureMult = 1.5: 4% × 1.5 = 6%.
--
-- Eligible parts: Leg_L, Leg_R, UpperArm_L, UpperArm_R, LowerArm_L, LowerArm_R.
-- Only parts that are NOT already fractured are eligible.
-- If all eligible parts are already fractured, the roll is skipped gracefully.
--
-- Cooldown: 10 in-game seconds between fracture rolls, measured from
-- world-age hours so it expires with elapsed time rather than incoming hits.

UTCore = UTCore or {}

local BASE_CHANCE  = 4   -- percent
local COOLDOWN_HOURS = 10 / 3600

-- Parts ordered by priority: legs first (most impactful in PZ)
local ELIGIBLE_PART_TYPES = {
    BodyPartType.Leg_L,
    BodyPartType.Leg_R,
    BodyPartType.UpperArm_L,
    BodyPartType.UpperArm_R,
    BodyPartType.LowerArm_L,
    BodyPartType.LowerArm_R,
}

local function onWeaponHitCharacter(attacker, target, weapon, damage)
    local player = getPlayer()
    if not player or target ~= player then return end

    local md = player:getModData()
    local mult = md["UT_fractureMult"]
    if not mult or mult <= 1.0 then return end

    -- Remove the obsolete hit-count cooldown from older saves.
    md["UT_fractureCooldown"] = nil
    local now = getGameTime():getWorldAgeHours()
    local cooldownUntil = md["UT_fractureCooldownUntil"] or 0
    if now < cooldownUntil then return end

    local chance = math.floor(BASE_CHANCE * mult)
    if ZombRand(100) >= chance then return end

    -- Collect non-fractured eligible parts
    local bd = player:getBodyDamage()
    if not bd then return end

    local eligible = {}
    for _, partType in ipairs(ELIGIBLE_PART_TYPES) do
        local ok, part = pcall(function() return bd:getBodyPart(partType) end)
        if ok and part and not (part:getFractureTime() > 0) then
            eligible[#eligible + 1] = part
        end
    end

    if #eligible == 0 then return end

    -- Fracture a random eligible part
    local idx = ZombRand(#eligible) + 1
    eligible[idx]:setFractured(true)
    md["UT_fractureCooldownUntil"] = now + COOLDOWN_HOURS
end

if Events and Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
end
