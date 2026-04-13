-- UTCore_SpeedHook.lua
-- Applies the aggregated UT_speedMod to player movement by scaling the engine's
-- pending animation delta (nextX/nextY), NOT by rewriting absolute position.
--
-- ==================== ENGINE CONTRACT ====================
-- This hook depends on PZ's IsoMovingObject frame pipeline:
--
--   1. preupdate()          → nextX = x  (reset pending target)
--   2. doDeferredMovement() → nextX += animDelta  (animation writes here)
--   3. update()             → OnPlayerMove fires  ★ THIS HOOK RUNS HERE
--   4. postupdate()         → applies dx = nextX - x, commits into x
--
-- We read the pending delta (nextX - x) that doDeferredMovement() wrote,
-- scale it by (1 + UT_speedMod), and write the result back via setNextX().
--
-- CRITICAL: we use setNextX/setNextY, NOT setX/setY.
--   setX()     → clobbers x, nextX, AND scriptNextX (destroys pending movement)
--   setNextX() → only sets nextX (preserves x and scriptNextX)
--
-- This lets postupdate() see a scaled delta and commit it normally, preserving
-- the engine's collision checking, animation pipeline, and compatibility with
-- other mods that also write to nextX.
--
-- ==================== WHY NOT setX/setY? ====================
-- The previous implementation used setX/setY to rewrite absolute position.
-- This created a position-pinning feedback loop:
--   - getX() returns stale pre-movement x
--   - setX() clobbers nextX to equal x (zero delta)
--   - postupdate() sees dx=0, player never moves
-- See research/movement-bug/proof/P011 for the full kill-mechanism proof.
--
-- ==================== TRAITS DON'T NEED TO KNOW ====================
-- Traits call UTCore.applySpeedModifier(player, amount, sourceId) once.
-- That writes into the modifier bucket system (UTCore_StatModifiers.lua).
-- This hook reads the aggregated UT_speedMod from moddata and applies it.
-- Traits never touch position, nextX, or the frame pipeline directly.
-- =================================================================

UTCore = UTCore or {}

-- Skip if pending animation delta exceeds this (teleport, map load, fast travel).
local TELEPORT_GUARD = 5.0

-- Per-frame movement cap in tiles. Prevents extreme jumps from corrupted moddata
-- or extreme modifier stacking. At 60 FPS, 1.5 tiles/frame = 90 tiles/sec
-- (~18x sprint). Will never trigger during normal gameplay.
local MAX_DELTA_PER_FRAME = 1.5

local function onPlayerMove()
    local player = getPlayer()
    if not player then return end
    if not player:isLocalPlayer() then return end

    -- Ensure the aggregated modifier cache is current before reading UT_speedMod.
    if UTCore.refreshAggregatedModifierCache then
        UTCore.refreshAggregatedModifierCache(player)
    end

    local md = player:getModData()
    local mod = md["UT_speedMod"]

    -- No speed modifier active — nothing to do. This is the common case for
    -- characters without speed traits (UT_fast, UT_pacer, UT_gimp, etc.).
    if not mod or mod == 0 then return end

    -- Read the pending movement delta that doDeferredMovement() accumulated
    -- into nextX/nextY during this frame's update() phase.
    local x = player:getX()
    local y = player:getY()
    local nextX = player:getNextX()
    local nextY = player:getNextY()

    local dx = nextX - x
    local dy = nextY - y

    -- No pending movement this frame — nothing to scale.
    if dx == 0 and dy == 0 then return end

    -- Teleport guard: skip if the pending delta is unreasonably large.
    -- This fires on map loads, debug teleports, or vehicle entry/exit.
    if math.abs(dx) > TELEPORT_GUARD or math.abs(dy) > TELEPORT_GUARD then return end

    -- Scale the pending delta by the speed modifier.
    -- factor > 1.0 → faster (e.g., UT_fast +0.3 → factor 1.3)
    -- factor < 1.0 → slower (e.g., UT_gimp -0.5 → factor 0.5)
    -- factor is always > 0 because UT_speedMod is clamped to [-0.75, +1.0]
    -- in UTCore_StatModifiers.lua, giving a factor range of [0.25, 2.0].
    local factor = 1.0 + mod
    local scaledDx = dx * factor
    local scaledDy = dy * factor

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("movement.frame-pipeline", string.format("mod=%.3f", mod))
    end

    -- Per-frame delta cap: clamp the scaled delta so no single frame moves
    -- the player more than MAX_DELTA_PER_FRAME tiles in any direction.
    local len = math.sqrt(scaledDx * scaledDx + scaledDy * scaledDy)
    if len > MAX_DELTA_PER_FRAME then
        local scale = MAX_DELTA_PER_FRAME / len
        scaledDx = scaledDx * scale
        scaledDy = scaledDy * scale
    end

    -- Write back to nextX/nextY ONLY.
    -- setNextX() only sets the nx field — it does NOT clobber x or scriptNextX.
    -- postupdate() will then see the scaled delta and commit it into x normally.
    player:setNextX(x + scaledDx)
    player:setNextY(y + scaledDy)

    -- ACTION-KILL DIAGNOSIS: log if SpeedHook fires while an action is active
    pcall(function()
        local actions = player:getCharacterActions()
        if actions:size() > 0 then
            print("[UT_ADIAG] SPEEDHOOK_WHILE_ACTION mod=" .. tostring(mod)
                .. " dx=" .. string.format("%.6f", dx) .. " dy=" .. string.format("%.6f", dy)
                .. " scaled_dx=" .. string.format("%.6f", scaledDx) .. " scaled_dy=" .. string.format("%.6f", scaledDy)
                .. " actionCount=" .. actions:size())
        end
    end)
end

if Events and Events.OnPlayerMove then
    Events.OnPlayerMove.Add(onPlayerMove)
end
