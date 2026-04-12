-- UT_sharpshooter.lua
-- +25% accuracy (hit chance) and effective range with equipped firearms.
--
-- Base values are cached in weapon modData (UT_ssBaseHitChance / UT_ssBaseMaxRange)
-- on first encounter so the multiplier is never compounded across weapon swaps or
-- save/loads.  Only ranged weapons are affected.

local TRAIT_ID = "UniversalTraits:UT_sharpshooter"

local function applySharpshooter(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    if not weapon:isRanged() then return end
    pcall(function()
        local wmd = weapon:getModData()
        if wmd["UT_ssBaseHitChance"] == nil then
            wmd["UT_ssBaseHitChance"] = weapon:getHitChance()
        end
        if wmd["UT_ssBaseMaxRange"] == nil then
            wmd["UT_ssBaseMaxRange"] = weapon:getMaxRange()
        end
        local targetHit   = math.min(100, math.floor(wmd["UT_ssBaseHitChance"] * 1.25))
        local targetRange = wmd["UT_ssBaseMaxRange"] * 1.25
        if weapon:getHitChance() ~= targetHit   then weapon:setHitChance(targetHit)   end
        if weapon:getMaxRange()  ~= targetRange  then weapon:setMaxRange(targetRange)  end
    end)
end

local function onTick(player, tick)
    applySharpshooter(tick.primaryWeapon)
    applySharpshooter(tick.secondaryWeapon)
end

UTCore.registerTickHandler(TRAIT_ID, onTick, { throttle = 30 })
