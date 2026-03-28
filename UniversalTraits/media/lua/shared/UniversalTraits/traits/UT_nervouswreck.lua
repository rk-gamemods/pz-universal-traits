-- UT_nervouswreck.lua
-- Nervous wreck: amplifies panic buildup when stressed.
-- Uses CharacterStat.PANIC (0-100 scale) + stats:add() — correct B42 API.

local TRAIT_ID = "UniversalTraits:UT_nervouswreck"

local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local panic = stats:get(CharacterStat.PANIC)
    local stress = stats:get(CharacterStat.STRESS)

    -- Amplify existing panic
    if panic > 0 then
        stats:add(CharacterStat.PANIC, panic * 0.3)
    end
    -- Extra spike when highly stressed
    if stress > 70 then
        stats:add(CharacterStat.PANIC, 5)
    end
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)
