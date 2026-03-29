-- UT_antivaxxer.lua
-- Source: SomewhatTraits 42.12 SWSomewhatTraitsCore.lua — SWAntivaxxer().
-- OnCreatePlayer: hides all recipes containing "Inject" in their name.

local TRAIT_ID = "UniversalTraits:UT_antivaxxer"

local function onCreatePlayer(playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local recipes = getScriptManager():getAllRecipes()
    for i = 0, recipes:size() - 1 do
        local r = recipes:get(i)
        if r and string.find(r:getName(), "Inject") then
            r:setIsHidden(true)
        end
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
