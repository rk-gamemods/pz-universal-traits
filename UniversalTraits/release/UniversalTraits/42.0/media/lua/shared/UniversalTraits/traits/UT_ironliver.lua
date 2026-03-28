-- UT_ironliver.lua
-- Reduces drunkenness by 10% every minute

local TRAIT_ID = "UniversalTraits:UT_ironliver"

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local drunkenness = stats:getDrunkenness()

    if drunkenness > 0.1 then
        stats:setDrunkenness(drunkenness * 0.9)
        player:getModData()["UT_drunkReductionApplied"] = true
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
