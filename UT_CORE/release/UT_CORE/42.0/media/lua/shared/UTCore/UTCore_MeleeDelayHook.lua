-- UTCore_MeleeDelayHook.lua
-- Reduces melee delay for players with weapon-category traits.
-- Standard weapon-category traits apply a 50% delay reduction.
-- UT_heavyswing applies a strength-scaled reduction: delay * (strength * 0.1).
-- Uses moddata flag UT_meleeDelaySet to prevent re-application within a swing.
-- Flag is cleared when meleeDelay returns to 0 (swing complete).

UTCore = UTCore or {}

-- ---------------------------------------------------------------------------
-- Weapon category detection
-- ---------------------------------------------------------------------------

local function getWeaponCategories(weapon)
    local categories = {}
    if not weapon or not weapon.isOfWeaponCategory or not WeaponCategory then
        return categories
    end

    categories.axe = weapon:isOfWeaponCategory(WeaponCategory.AXE)
    categories.longBlunt = weapon:isOfWeaponCategory(WeaponCategory.BLUNT)
    categories.shortBlunt = weapon:isOfWeaponCategory(WeaponCategory.SMALL_BLUNT)
    categories.longBlade = weapon:isOfWeaponCategory(WeaponCategory.LONG_BLADE)
    categories.shortBlade = weapon:isOfWeaponCategory(WeaponCategory.SMALL_BLADE)
    categories.spear = weapon:isOfWeaponCategory(WeaponCategory.SPEAR)
    categories.melee = categories.axe or categories.longBlunt or categories.shortBlunt
        or categories.longBlade or categories.shortBlade or categories.spear
    categories.twoHanded = categories.melee and weapon.isTwoHandWeapon
        and weapon:isTwoHandWeapon() or false
    categories.oneHanded = categories.melee and not categories.twoHanded
    return categories
end

-- ---------------------------------------------------------------------------
-- Trait-to-category mapping
-- ---------------------------------------------------------------------------

-- Each entry: { traitId, category predicate }. Broad traits explicitly combine
-- the exact engine categories they own; handed traits also require handedness.
local MELEE_TRAITS = {
    { "UniversalTraits:UT_axes",             function(c) return c.axe end },
    { "UniversalTraits:UT_twohanded_axes",   function(c) return c.axe and c.twoHanded end },
    { "UniversalTraits:UT_onehanded_axes",   function(c) return c.axe and c.oneHanded end },
    { "UniversalTraits:UT_blunts",           function(c) return c.longBlunt or c.shortBlunt end },
    { "UniversalTraits:UT_twohanded_blunts", function(c) return c.longBlunt and c.twoHanded end },
    { "UniversalTraits:UT_onehanded_blunts", function(c) return c.shortBlunt and c.oneHanded end },
    { "UniversalTraits:UT_long_blunts",      function(c) return c.longBlunt end },
    { "UniversalTraits:UT_short_blunts",     function(c) return c.shortBlunt end },
    { "UniversalTraits:UT_blades",           function(c) return c.longBlade or c.shortBlade end },
    { "UniversalTraits:UT_twohanded_blades", function(c) return c.longBlade and c.twoHanded end },
    { "UniversalTraits:UT_onehanded_blades", function(c) return c.shortBlade and c.oneHanded end },
    { "UniversalTraits:UT_long_blades",      function(c) return c.longBlade end },
    { "UniversalTraits:UT_short_blades",     function(c) return c.shortBlade end },
    { "UniversalTraits:UT_spears",           function(c) return c.spear end },
    { "UniversalTraits:UT_twohanded",        function(c) return c.twoHanded end },
    { "UniversalTraits:UT_onehanded",        function(c) return c.oneHanded and (c.shortBlade or c.shortBlunt) end },
}

-- ---------------------------------------------------------------------------
-- OnPlayerUpdate handler
-- ---------------------------------------------------------------------------

-- Exposed as UTCore._meleeDelayOnPlayerUpdate so tests can call it directly.
local _lastWeapon = nil
local _lastCategories = nil

local function onPlayerUpdate(player, tick)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then return end

    local weapon = tick and tick.primaryWeapon or (player.getPrimaryHandItem and player:getPrimaryHandItem())
    if not weapon then
        _lastWeapon = nil
        _lastCategories = nil
        return
    end

    local md = tick and tick.modData or player:getModData()
    local meleeDelay = player:getMeleeDelay()

    -- Reset flag when the swing is fully complete (delay returned to 0).
    -- This is the only place the flag is cleared — never mid-swing.
    if not meleeDelay or meleeDelay <= 0 then
        md["UT_meleeDelaySet"] = false
        return
    end

    -- Prevent re-application within the same swing
    if md["UT_meleeDelaySet"] then return end

    -- Cache weapon category: string.find is expensive per-tick for the same weapon.
    local categories
    if weapon == _lastWeapon and _lastCategories then
        categories = _lastCategories
    else
        categories = getWeaponCategories(weapon)
        _lastWeapon = weapon
        _lastCategories = categories
    end
    local newDelay = nil

    if categories.melee and UTSmoke and UTSmoke.record then
        UTSmoke.record("combat.weapon-runtime", "melee")
    end

    -- Check standard 50% reduction traits
    for _, entry in ipairs(MELEE_TRAITS) do
        local traitId, matchesCategory = entry[1], entry[2]
        if matchesCategory(categories) and UTCore.hasTrait(player, traitId) then
            local candidate = meleeDelay * 0.5
            if newDelay == nil or candidate < newDelay then
                newDelay = candidate
            end
        end
    end

    -- Check UT_heavyswing (strength-scaled, any melee weapon)
    if categories.melee and UTCore.hasTrait(player, "UniversalTraits:UT_heavyswing") then
        local strength = 5
        if player.getPerkLevel then
            local perksStrength = Perks and Perks.Strength or "Strength"
            local ok, val = pcall(function() return player:getPerkLevel(perksStrength) end)
            if ok and type(val) == "number" then strength = val end
        end
        local candidate = meleeDelay - meleeDelay * (strength * 0.1)
        if newDelay == nil or candidate < newDelay then
            newDelay = candidate
        end
    end

    if newDelay ~= nil and newDelay < meleeDelay then
        newDelay = math.max(0, newDelay)
        player:setMeleeDelay(newDelay)
        md["UT_meleeDelaySet"] = true
    end
end

UTCore._meleeDelayOnPlayerUpdate = onPlayerUpdate

-- ---------------------------------------------------------------------------
-- Save-load recovery: clear stuck meleeDelay and flag on player creation.
-- Fixes saves that were written while the player was frozen mid-swing.
-- ---------------------------------------------------------------------------

local function onCreatePlayer(_playerIndex, player)
    if not player then return end
    local md = player:getModData()
    if not md["UT_meleeDelaySet"] then return end

    local meleeDelay = player:getMeleeDelay()
    md["UT_meleeDelaySet"] = false
    if meleeDelay and meleeDelay > 0 then
        player:setMeleeDelay(0)
    end
end

-- ---------------------------------------------------------------------------
-- Register with events
-- ---------------------------------------------------------------------------

if UTCore.registerCoreHandler then
    UTCore.registerCoreHandler("MeleeDelayHook", onPlayerUpdate, { priority = 0 })
else
    if Events and Events.OnPlayerUpdate then
        if UTCore._meleeDelayRegisteredOnPlayerUpdate and Events.OnPlayerUpdate.Remove then
            Events.OnPlayerUpdate.Remove(UTCore._meleeDelayRegisteredOnPlayerUpdate)
        end
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
        UTCore._meleeDelayRegisteredOnPlayerUpdate = onPlayerUpdate
    end
end

if Events and Events.OnCreatePlayer then
    if UTCore._meleeDelayOnCreatePlayer and Events.OnCreatePlayer.Remove then
        Events.OnCreatePlayer.Remove(UTCore._meleeDelayOnCreatePlayer)
    end
    UTCore._meleeDelayOnCreatePlayer = onCreatePlayer
    Events.OnCreatePlayer.Add(onCreatePlayer)
end
