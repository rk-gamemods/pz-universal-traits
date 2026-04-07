-- UT_improviser.lua
-- Weapon degradation reduced by 50% (doubles the condition-lower-chance denominator).
--
-- PZ condition loss is governed by getConditionLowerChanceOneIn(): the weapon
-- loses 1 condition point with probability 1/N per hit.  Doubling N halves the
-- degradation rate.  Base values are cached in weapon modData on first encounter
-- so the multiplier is never compounded across swaps or save/loads.

local TRAIT_ID = "UniversalTraits:UT_improviser"
local tickCounter = 0

local function applyDegradeReduction(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    pcall(function()
        local wmd = weapon:getModData()
        if wmd["UT_improviserBaseCondChance"] == nil then
            wmd["UT_improviserBaseCondChance"] = weapon:getConditionLowerChanceOneIn()
        end
        local target = wmd["UT_improviserBaseCondChance"] * 2
        if weapon:getConditionLowerChanceOneIn() ~= target then
            weapon:setConditionLowerChanceOneIn(target)
        end
    end)
end

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end
    applyDegradeReduction(player:getPrimaryHandItem())
    applyDegradeReduction(player:getSecondaryHandItem())
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
