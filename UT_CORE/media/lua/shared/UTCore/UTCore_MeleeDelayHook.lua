-- UTCore_MeleeDelayHook.lua
-- Reduces melee delay for players with weapon-category traits.
-- Standard weapon-category traits apply a 50% delay reduction.
-- UT_heavyswing applies a strength-scaled reduction: delay * (strength * 0.1).
-- Uses moddata flag UT_meleeDelaySet to prevent re-application within a swing.
-- Flag is cleared on Events.OnWeaponHitCharacter.

UTCore = UTCore or {}

-- ---------------------------------------------------------------------------
-- Weapon category detection
-- ---------------------------------------------------------------------------

local function getWeaponCategory(weapon)
    if not weapon or not weapon.getType then return "other" end
    local wtype = weapon:getType() or ""

    if wtype:find("Axe") or wtype:find("axe") then return "axe" end
    if wtype:find("Spear") or wtype:find("spear") or wtype:find("Pitchfork") then return "spear" end
    if wtype:find("Blade") or wtype:find("blade") or wtype:find("Sword") or wtype:find("sword")
       or wtype:find("Knife") or wtype:find("knife") or wtype:find("Machete") or wtype:find("machete") then
        return "blade"
    end
    if wtype:find("Blunt") or wtype:find("blunt") or wtype:find("Bat") or wtype:find("bat")
       or wtype:find("Hammer") or wtype:find("hammer") or wtype:find("Pipe") or wtype:find("pipe") then
        return "blunt"
    end

    -- Two-handed / one-handed fallback via API
    if weapon.isTwoHandWeapon and weapon:isTwoHandWeapon() then return "twohanded" end
    if weapon.isRanged and not weapon:isRanged() then return "onehanded" end

    return "other"
end

-- ---------------------------------------------------------------------------
-- Trait-to-category mapping
-- ---------------------------------------------------------------------------

-- Each entry: { traitId, weaponCategory, formula }
-- formula = "half" | "heavyswing"
local MELEE_TRAITS = {
    -- Axe traits
    { "UniversalTraits:UT_axes",             "axe",       "half" },
    { "UniversalTraits:UT_twohanded_axes",   "axe",       "half" },
    { "UniversalTraits:UT_onehanded_axes",   "axe",       "half" },
    -- Blunt traits
    { "UniversalTraits:UT_blunts",           "blunt",     "half" },
    { "UniversalTraits:UT_twohanded_blunts", "blunt",     "half" },
    { "UniversalTraits:UT_onehanded_blunts", "blunt",     "half" },
    { "UniversalTraits:UT_long_blunts",      "blunt",     "half" },
    { "UniversalTraits:UT_short_blunts",     "blunt",     "half" },
    -- Blade traits
    { "UniversalTraits:UT_blades",           "blade",     "half" },
    { "UniversalTraits:UT_twohanded_blades", "blade",     "half" },
    { "UniversalTraits:UT_onehanded_blades", "blade",     "half" },
    { "UniversalTraits:UT_long_blades",      "blade",     "half" },
    { "UniversalTraits:UT_short_blades",     "blade",     "half" },
    -- Spear traits
    { "UniversalTraits:UT_spears",           "spear",     "half" },
    -- Generic handedness traits
    { "UniversalTraits:UT_twohanded",        "twohanded", "half" },
    { "UniversalTraits:UT_onehanded",        "onehanded", "half" },
}

-- ---------------------------------------------------------------------------
-- OnPlayerUpdate handler
-- ---------------------------------------------------------------------------

-- Exposed as UTCore._meleeDelayOnPlayerUpdate so tests can call it directly.
local function onPlayerUpdate(player)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then return end

    local weapon = player.getPrimaryHandItem and player:getPrimaryHandItem()
    if not weapon then return end

    local meleeDelay = player:getMeleeDelay()
    if not meleeDelay or meleeDelay <= 0 then return end

    -- Prevent re-application within the same swing
    local md = player:getModData()
    if md["UT_meleeDelaySet"] then return end

    local category = getWeaponCategory(weapon)
    local newDelay = nil

    -- Check standard 50% reduction traits
    for _, entry in ipairs(MELEE_TRAITS) do
        local traitId, reqCategory = entry[1], entry[2]
        if category == reqCategory and UTCore.hasTrait(player, traitId) then
            local candidate = meleeDelay * 0.5
            if newDelay == nil or candidate < newDelay then
                newDelay = candidate
            end
        end
    end

    -- UT_twohanded also matches two-handed weapons; UT_onehanded matches one-handed
    -- (already covered by MELEE_TRAITS above via category == "twohanded" / "onehanded")

    -- Check UT_heavyswing (strength-scaled, any melee weapon)
    if category ~= "other" and UTCore.hasTrait(player, "UniversalTraits:UT_heavyswing") then
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
-- Reset flag when a hit lands (clears for next swing)
-- ---------------------------------------------------------------------------

local function onWeaponHitCharacter(attacker, weapon, target)
    if not attacker or not attacker.getModData then return end
    attacker:getModData()["UT_meleeDelaySet"] = false
end

-- ---------------------------------------------------------------------------
-- Register with events
-- ---------------------------------------------------------------------------

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end

if Events and Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
end
