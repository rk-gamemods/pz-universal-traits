-- UT_strongnimble.lua
-- Strong & Nimble: never fall when climbing fences or ropes.
-- Monitors the player every tick for a falling state following a climb action
-- and cancels it. Also attempts to hook OnFenceClimb / OnClimbFence for a
-- cleaner interception; both hooks are guarded with pcall.

local TRAIT_ID = "UniversalTraits:UT_strongnimble"

local function tryStopFall(player)
    if not player or not player.isFalling or not player:isFalling() then return end
    if player.stopFalling then
        pcall(function()
            player:stopFalling()
        end)
    end
end

local function onPlayerUpdate(player)
    if not UTCore or not UTCore.hasTrait(player, TRAIT_ID) then return end

    -- Inspect current action state for climb/fall transitions when the API exists.
    local actionState = nil
    if player.getCurrentActionContextStateName then
        actionState = player:getCurrentActionContextStateName()
    end
    if actionState then
        local actionName = tostring(actionState):lower()
        if actionName:find("fall") or actionName:find("climb") or actionName:find("rope") then
            tryStopFall(player)
        end
    end

    -- Catch a falling state even without a labelled action.
    if player.isFalling and player:isFalling() then
        tryStopFall(player)
    end
end

-- Clean fence-climb hooks — guarded so missing events don't error on load.
local function onFenceClimb(player)
    if not player then return end
    if not UTCore or not UTCore.hasTrait(player, TRAIT_ID) then return end
    tryStopFall(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
if Events.OnFenceClimb then Events.OnFenceClimb.Add(onFenceClimb) end
if Events.OnClimbFence then Events.OnClimbFence.Add(onFenceClimb) end
