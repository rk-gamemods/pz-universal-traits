-- UT_strongnimble.lua
-- Strong & Nimble: prevent stochastic fence and intact-rope climb failures.

local TRAIT_ID = "UniversalTraits:UT_strongnimble"

local function onTick(player)
    if not player then return end

    -- ClimbOverFenceState checks this exact outcome before setbFalling(true).
    -- Changing only "fall" leaves falling/rope/obstacle/lunge and ordinary
    -- unsupported-floor falls on their vanilla paths.
    if player.getVariableBoolean and player.isVariable and player.setVariable
    and player:getVariableBoolean("ClimbingFence")
    and player:isVariable("ClimbFenceOutcome", "fall") then
        player:setVariable("ClimbFenceOutcome", "success")
    end

    -- Both sheet-rope states perform their random fall roll only after the
    -- accumulated climb timer crosses a threshold. Resetting the timer before
    -- state execution prevents that roll while preserving the separate
    -- missing-rope fall path.
    if player.isClimbingRope and player.setClimbRopeTime
    and player:isClimbingRope() then
        player:setClimbRopeTime(0)
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
