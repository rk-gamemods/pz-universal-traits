-- UT_antique.lua
-- Antique: when opening crates or metal shelves, a small chance to find
-- a rare antique item (powerful weapons or high-protection clothing).
-- One roll per container per loot-respawn cycle.
-- Chance: 8 in 1000 per eligible container open (~0.8%).

local TRAIT_ID = "UniversalTraits:UT_antique"

local ITEMS = {
    "UniversalTraits.AntiqueAxe",
    "UniversalTraits.AntiqueKatana",
    "UniversalTraits.AntiqueSpear",
    "UniversalTraits.AntiqueHammer",
    "UniversalTraits.AntiqueJacket",
    "UniversalTraits.AntiqueVest",
    "UniversalTraits.AntiqueBoots",
}

local ROLL_CHANCE = 8     -- numerator
local ROLL_DENOM  = 1000  -- denominator (~0.8%)

local ELIGIBLE_TYPES = { crate = true, metal_shelves = true }

local function getRespawnHours()
    local lr = SandboxVars and SandboxVars.LootRespawn or 1
    if lr == 1 then return nil end   -- no respawn
    if lr == 2 then return 24 end
    if lr == 3 then return 168 end
    if lr == 4 then return 720 end
    if lr == 5 then return 1440 end
    return nil
end

local function rollAntiqueItem(container)
    local i = ZombRand(#ITEMS) + 1
    local item = container:AddItem(ITEMS[i])
    if item then
        sendAddItemToContainer(container, item)
    end
end

local function onContainerUpdate(inventoryPage, state)
    if state ~= "end" then return end

    local player = inventoryPage and getSpecificPlayer(inventoryPage.player)
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local respawnHours = getRespawnHours()
    local now = getGameTime():getWorldAgeHours()

    for _, bp in ipairs(inventoryPage.backpacks or {}) do
        if bp and bp.inventory then
            local inv = bp.inventory
            local containerObj = inv.getParent and inv:getParent()
            if containerObj and instanceof(containerObj, "IsoObject")
               and not instanceof(containerObj, "IsoDeadBody")
               and containerObj:getContainer() then

                local container = containerObj:getContainer()
                if ELIGIBLE_TYPES[container:getType()] then
                    local md = containerObj:getModData()

                    local alreadyRolled = md.UT_antiqueRolled
                    local lastChecked   = md.UT_antiqueChecked or 0

                    local canRoll = false
                    if not alreadyRolled then
                        canRoll = true
                    elseif respawnHours and (lastChecked + respawnHours) <= now then
                        canRoll = true
                    end

                    if canRoll then
                        md.UT_antiqueRolled  = true
                        md.UT_antiqueChecked = now
                        containerObj:transmitModData()

                        if ZombRand(ROLL_DENOM) < ROLL_CHANCE then
                            rollAntiqueItem(container)
                        end
                    end
                end
            end
        end
    end
end

UTAntiqueRuntime = UTAntiqueRuntime or {}
if not UTAntiqueRuntime.registered then
    Events.OnRefreshInventoryWindowContainers.Add(onContainerUpdate)
    UTAntiqueRuntime.registered = true
end
