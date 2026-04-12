-- UT_evasive.lua
-- Evasive: 50% chance to completely avoid damage when hit.
-- Monitors player health every tick; when health drops between ticks, there is
-- a 50% chance the full amount is restored (dodge). lastHealth is seeded on
-- first update to avoid a false dodge on load.

local TRAIT_ID = "UniversalTraits:UT_evasive"

local lastHealth = nil

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local currentHealth = player:getHealth()

    if lastHealth ~= nil and currentHealth < lastHealth then
        -- Player took damage this tick — roll dodge.
        if ZombRand(100) < 50 then
            player:setHealth(lastHealth)
            -- Re-read after restoration so lastHealth stays accurate.
            currentHealth = lastHealth
        end
    end

    lastHealth = player:getHealth()
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
