-- UTCore_StuckMovementWatchdog.lua
-- Detects prolonged movement-blocking states and force-clears them.
--
-- PZ has several animation states that block movement:
--   BumpedState: setBlockMovement(true), exits when BumpDone=true
--   PlayerKnockedDown: setBlockMovement(true), exits when animation finishes
--   PlayerGetUpState: setBlockMovement(true), exits when standup animation finishes
--   PlayerHitReactionState: setIgnoreMovement(true), exits when hitReaction cleared
--
-- If any state gets stuck (animation doesn't finish, re-entry loop, etc.),
-- the player is permanently frozen. This watchdog detects that and intervenes.
--
-- DETECTION:
--   Every OnPlayerUpdate tick, check if blockMovement is true OR hitReaction
--   is non-empty. Track consecutive ticks where either condition holds.
--
-- RECOVERY (after STUCK_THRESHOLD ticks):
--   blockMovement → false
--   BumpDone → true              (triggers BumpedState.exit())
--   BumpFallAnimFinished → true  (clears animation gate)
--   BumpAnimFinished → true      (clears animation gate)
--   hitReaction → ""             (triggers PlayerHitReactionState.exit()
--                                 → setIgnoreMovement(false))
--
-- THRESHOLD RATIONALE:
--   Legitimate blocking states last at most:
--     BumpedState stagger: ~30-60 frames (~1-2 sec)
--     PlayerKnockedDown: up to ~60 frames (~2 sec)
--     PlayerGetUpState: ~30-60 frames (~1-2 sec)
--     Worst legitimate chain (knocked down → getup): ~4 sec
--   STUCK_THRESHOLD = 180 ticks (~6 sec) provides margin for all cases.

UTCore = UTCore or {}

local STUCK_THRESHOLD = 180

local _stuckTicks = 0

local function isMovementBlocked(player)
    -- blockMovement flag (BumpedState, knockdown, getup states)
    if player.isBlockMovement then
        if player:isBlockMovement() then return true end
    elseif player.getBlockMovement then
        if player:getBlockMovement() then return true end
    end
    -- hitReaction (PlayerHitReactionState → ignoreMovement)
    -- Can't read ignoreMovement from Lua, but non-empty hitReaction means
    -- the state is active and therefore ignoreMovement is true.
    if player.getHitReaction then
        local hr = player:getHitReaction()
        if hr and hr ~= "" then return true end
    end
    return false
end

local function forceRecovery(player)
    if player.setBlockMovement then
        pcall(player.setBlockMovement, player, false)
    end
    if player.setBumpDone then
        pcall(player.setBumpDone, player, true)
    end
    if player.setVariable then
        pcall(player.setVariable, player, "BumpFallAnimFinished", true)
        pcall(player.setVariable, player, "BumpAnimFinished", true)
    end
    if player.setHitReaction then
        pcall(player.setHitReaction, player, "")
    end
    print("[UTCore:Watchdog] Cleared stuck movement after " .. STUCK_THRESHOLD .. " ticks")
end

local function onPlayerUpdate(player)
    if not player then _stuckTicks = 0; return end
    if player:isDead() then _stuckTicks = 0; return end
    if player:getVehicle() ~= nil then _stuckTicks = 0; return end

    if isMovementBlocked(player) then
        _stuckTicks = _stuckTicks + 1
        if _stuckTicks >= STUCK_THRESHOLD then
            forceRecovery(player)
            _stuckTicks = 0
        end
    else
        _stuckTicks = 0
    end
end

-- Expose internals for testing
UTCore._watchdogOnPlayerUpdate = onPlayerUpdate
UTCore._watchdogIsBlocked = isMovementBlocked
UTCore._watchdogForceRecovery = forceRecovery
UTCore._getWatchdogStuckTicks = function() return _stuckTicks end
UTCore._resetWatchdogStuckTicks = function() _stuckTicks = 0 end
UTCore.WATCHDOG_THRESHOLD = STUCK_THRESHOLD

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
