-- UT_strongnimble.lua
-- Strong & Nimble: prevent the stochastic low-fence climb failure.

local TRAIT_ID = "UniversalTraits:UT_strongnimble"

local function onTick(player)
    if not player or not player.getVariableBoolean or not player.getVariable
    or not player.setVariable then return end

    -- ClimbOverFenceState checks this exact outcome before setbFalling(true).
    -- Changing only "fall" leaves falling/rope/obstacle/lunge and ordinary
    -- unsupported-floor falls on their vanilla paths.
    if player:getVariableBoolean("ClimbingFence")
    and player:getVariable("ClimbFenceOutcome") == "fall" then
        player:setVariable("ClimbFenceOutcome", "success")
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
