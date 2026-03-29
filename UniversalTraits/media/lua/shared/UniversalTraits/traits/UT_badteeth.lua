-- UT_badteeth.lua
-- Source: MoreTraits badteethtrait() — eating causes head pain proportional to food healing.
-- OnPlayerUpdate: monitors food heal timer, applies head pain when timer rises above 1000.

local TRAIT_ID = "UniversalTraits:UT_badteeth"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local bd = player:getBodyDamage()
    if not bd then return end
    local timer = bd:getHealthFromFoodTimer()
    local prev = UTCore.getModData(player, "badteethTimer", 0)
    UTCore.setModData(player, "badteethTimer", timer)
    if timer > 1000 and timer > prev then
        local head = bd:getBodyPart(BodyPartType.Head)
        if head then
            local current = head:getAdditionalPain()
            head:setAdditionalPain(math.min(current + (timer - prev) * 0.01, 100))
        end
    end
end

UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
