-- UT_woodsplitter.lua
-- Wood Splitter: double damage to trees when chopping.
-- Sets a modData flag on new game and hooks OnTreeChopped (if available in
-- this PZ version) to apply an extra HP reduction equal to one extra chop.

local TRAIT_ID = "UniversalTraits:UT_woodsplitter"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_woodsplitterActive"] = true
end

local function onTreeChopped(player, tree)
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if tree and tree.getHp and tree.setHp then
        local currentHp = tree:getHp()
        -- Simulate an additional chop: extra damage equals Axe skill level + 1.
        local axeLevel = 0
        pcall(function()
            axeLevel = player:getPerkLevel(Perks.Axe)
        end)
        local extraDamage = axeLevel + 1
        tree:setHp(math.max(0, currentHp - extraDamage))
    end
end

Events.OnNewGame.Add(onNewGame)

-- Hook is guarded with pcall so the file loads cleanly on PZ versions that
-- don't expose this event.
if Events.OnTreeChopped then Events.OnTreeChopped.Add(onTreeChopped) end
