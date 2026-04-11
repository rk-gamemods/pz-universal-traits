-- UT_flimsy.lua
-- Source: SomewhatTraits SWTraitsCore_server.lua — SWFlimsy().
-- EveryOneMinute: heavy backpack (>20 weight) causes arm pain proportional to weight.

local TRAIT_ID = "UniversalTraits:UT_flimsy"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local pack = player:getClothingItem_Back()
    local bd = player:getBodyDamage()
    if not bd then return end
    local armL = bd:getBodyPart(BodyPartType.UpperArm_L)
    local armR = bd:getBodyPart(BodyPartType.UpperArm_R)
    if not armL or not armR then return end
    if pack then
        local weight = pack:getContentsWeight()
        if weight > 20 then
            local pain = math.min(weight * 0.1, 20)
            armL:setAdditionalPain(pain)
            armR:setAdditionalPain(pain)
        else
            armL:setAdditionalPain(0)
            armR:setAdditionalPain(0)
        end
    else
        armL:setAdditionalPain(0)
        armR:setAdditionalPain(0)
    end
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
