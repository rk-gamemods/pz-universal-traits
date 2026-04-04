-- UT_butterfingers.lua
-- Butter fingers: occasional item drop
-- Every 300 ticks there is a 3% chance to set UT_dropNext.
-- The consumer below reads UT_dropNext each tick and drops the primary-hand item.

local TRAIT_ID = "UniversalTraits:UT_butterfingers"

local lastCheckTick = {}

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local playerId = player:getPlayerNum()
    local currentTick = getGameTime():getTicks()

    lastCheckTick[playerId] = lastCheckTick[playerId] or 0

    -- Drop consumer: runs first so the flag set this tick fires next tick
    local md = player:getModData()
    if md["UT_dropNext"] then
        md["UT_dropNext"] = nil
        pcall(function()
            local item = player:getPrimaryHandItem()
            if item then
                -- Remove from hands and inventory, then place on the ground tile
                player:removeFromHands()
                player:getInventory():Remove(item)
                local square = player:getCurrentSquare()
                if square then
                    square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
                end
            end
        end)
    end

    -- Periodic chance to schedule a drop (runs after consumer so flag set here lives until next tick)
    if currentTick - lastCheckTick[playerId] >= 300 then
        lastCheckTick[playerId] = currentTick
        if ZombRand(100) < 3 then
            player:getModData()["UT_dropNext"] = true
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
