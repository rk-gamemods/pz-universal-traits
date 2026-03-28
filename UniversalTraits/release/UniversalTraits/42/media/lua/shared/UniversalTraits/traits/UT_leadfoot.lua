-- UT_leadfoot.lua
-- Increases stomp power on equipped shoes (match MoreTraits LeadFoot pattern).

local TRAIT_ID = "UniversalTraits:UT_leadfoot"

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local shoes = player:getClothingItem_Feet()
    if not shoes then return end

    local itemdata = shoes:getModData()
    if not itemdata then return end

    if itemdata.UT_origStomp == nil then
        itemdata.UT_origStomp    = shoes:getStompPower()
        itemdata.UT_stompState   = "Normal"
    end

    if itemdata.UT_stompState ~= "LeadFoot" then
        shoes:setStompPower((itemdata.UT_origStomp * 2) + 1)
        itemdata.UT_stompState = "LeadFoot"
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)
