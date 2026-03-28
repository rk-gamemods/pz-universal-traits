-- UT_gunspecialist_III.lua
-- Runtime bonuses: +10% reload/aim speed (written to moddata), jam immunity on equipped weapons.

local TRAIT_ID = "UniversalTraits:UT_gunspecialist_III"

local tickCounter = 0

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local moddata = player:getModData()
    moddata["UT_gunspec3"]          = true
    moddata["UT_reloadSpeedBonus"]  = 0.1
    moddata["UT_aimSpeedBonus"]     = 0.1
end

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local moddata = player:getModData()
    -- Ensure moddata keys are present (e.g. loaded save)
    if not moddata["UT_gunspec3"] then
        moddata["UT_gunspec3"]         = true
        moddata["UT_reloadSpeedBonus"] = 0.1
        moddata["UT_aimSpeedBonus"]    = 0.1
    end

    -- Jam immunity: unjam any currently equipped firearm
    local primary   = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()
    if primary   and primary:isJammed   and primary:isJammed()   then primary:setJammed(false)   end
    if secondary and secondary:isJammed and secondary:isJammed() then secondary:setJammed(false) end
end

Events.OnNewGame.Add(onNewGame)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
