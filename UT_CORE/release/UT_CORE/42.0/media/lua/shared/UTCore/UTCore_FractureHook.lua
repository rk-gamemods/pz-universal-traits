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
-- Cooldown: 10 seconds (300 ticks) between fracture rolls to prevent fracture spam
-- from rapid zombie attacks.

UTCore = UTCore or {}

local BASE_CHANCE  = 4   -- percent
local COOLDOWN     = 300 -- ticks (~10 seconds at 30 ticks/sec)

-- Parts ordered by priority: legs first (most impactful in PZ)
local ELIGIBLE_PART_TYPES = {
    BodyPartType.Leg_L,
    BodyPartType.Leg_R,
    BodyPartType.UpperArm_L,
    BodyPartType.UpperArm_R,
    BodyPartType.LowerArm_L,
    BodyPartType.LowerArm_R,
}

local function onWeaponHitCharacter(attacker, weapon, target)
    local player = getPlayer()
    if not player or target ~= player then return end

    local md = player:getModData()
    local mult = md["UT_fractureMult"]
    if not mult or mult <= 1.0 then return end

    -- Cooldown check
    local cooldown = md["UT_fractureCooldown"] or 0
    if cooldown > 0 then
        md["UT_fractureCooldown"] = cooldown - 1
        return
    end

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
    md["UT_fractureCooldown"] = COOLDOWN
end

if Events and Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
end
