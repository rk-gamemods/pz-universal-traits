-- UT_vagabond.lua
-- Vagabond: when inspecting a container, 33% chance to find a useful survival item (once per container per session)

local TRAIT_ID = "UniversalTraits:UT_vagabond"

local vagabondItems = {
    "Base.Tuna", "Base.BakedBeans", "Base.SoupCan",
    "Base.Socks", "Base.Tshirt",
    "Base.RoadMap1", "Base.RoadMap2",
    "Base.Screwdriver", "Base.WoodGlue",
}

local function handleContainerInspect(player, container)
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local containerKey
    local getObj = container.getObject
    local obj = getObj and getObj(container)
    if obj and obj.getUniqueId then
        containerKey = tostring(obj:getUniqueId())
    else
        containerKey = tostring(container)
    end

    local md = player:getModData()
    local lootedKey = "UT_vagabond_looted_" .. containerKey
    if md[lootedKey] then return end

    if ZombRand(100) < 33 then
        local itemType = vagabondItems[ZombRand(#vagabondItems) + 1]
        container:AddItem(itemType)
    end

    md[lootedKey] = true
end

-- Expose for testing
_G.UT_vagabond_handleContainerInspect = handleContainerInspect

-- Register with game event if available
if Events.OnRefreshInventoryWindowContainers then
    Events.OnRefreshInventoryWindowContainers.Add(handleContainerInspect)
end
