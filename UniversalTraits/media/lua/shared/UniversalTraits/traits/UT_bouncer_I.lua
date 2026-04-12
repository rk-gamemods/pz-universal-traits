-- UT_bouncer_I.lua
-- Bouncer (I & II): when surrounded by 3+ enemies within 1.75 tiles,
-- 5% chance per update tick to stagger one close enemy back.
-- Cooldown: 60 ticks between triggers (stored in moddata as UT_bouncer_cooldown).
--
-- SAFETY: bouncer must NOT fire during player attack/shove/stomp/grapple animations.
-- Staggering a zombie mid-swing corrupts the animation sequence, causing the
-- SwipeStatePlayer to never exit → blockMovement stuck forever (permanent freeze).
-- See: freeze at frame 101723, UT_bouncer_cooldown=57 (fired 3 ticks before freeze).

local TRAIT_I  = "UniversalTraits:UT_bouncer_I"
local TRAIT_II = "UniversalTraits:UT_bouncer_II"

local function onTick(player, tick)
    local md = tick.modData
    if md["UT_bouncer_cooldown"] == nil then
        md["UT_bouncer_cooldown"] = 0
    end

    -- Decrement cooldown each tick (minimum 0)
    if md["UT_bouncer_cooldown"] > 0 then
        md["UT_bouncer_cooldown"] = md["UT_bouncer_cooldown"] - 1
        return
    end

    -- GUARD: never stagger zombies while the player is mid-attack/shove/stomp/grapple.
    -- Mutating a zombie's bump state during SwipeStatePlayer corrupts the animation
    -- sequence and can permanently lock blockMovement=true (freeze bug).
    if tick.isHostileAnim then
        UTCore.diagLog("bouncer", "SUPPRESSED", "hostile_anim=true")
        return
    end

    -- Build enemy list (lazy in tick context)
    local enemies, enemyCount = UTCore.getLivingEnemies(tick)

    -- Need at least 3 living enemies to trigger
    if enemyCount < 3 then return end

    -- Filter to within 1.75 tiles (distances pre-computed in tick cache)
    local closeEnemies = {}
    for i = 1, enemyCount do
        local e = enemies[i]
        if e.dist < 1.75 then
            closeEnemies[#closeEnemies + 1] = e.zombie
        end
    end

    if #closeEnemies < 3 then return end

    -- GUARD: never stagger while player movement is already blocked.
    -- If player is being bumped, knocked down, or getting up, a stagger
    -- can chain-collide into the player and permanently lock blockMovement.
    if player:isBlockMovement() then
        UTCore.diagLog("bouncer", "SUPPRESSED", "blockMovement=true")
        return
    end

    -- 5% chance to stagger one close enemy
    if ZombRand(100) < 5 then
        local target = closeEnemies[1]
        target:setBumpType("stagger")
        target:setVariable("BumpDone", false)
        target:setVariable("BumpFall", true)
        md["UT_bouncer_cooldown"] = 60
        UTCore.diagLog("bouncer", "STAGGER", "close=" .. #closeEnemies
            .. " blockMov=" .. tostring(player:isBlockMovement()))
    end
end

UTCore.registerTickHandler(TRAIT_I, onTick, {
    anyTrait = { TRAIT_I, TRAIT_II }
})
