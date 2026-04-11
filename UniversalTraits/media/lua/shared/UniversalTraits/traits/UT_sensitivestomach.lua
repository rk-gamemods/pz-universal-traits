-- UT_sensitivestomach.lua
-- Sensitive stomach: causes pain and nausea as food is digested.
-- Uses getHealthFromFoodTimer() to detect active digestion (match MoreSimpleTraits pattern).

local TRAIT_ID = "UniversalTraits:UT_sensitivestomach"

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local healTimer = player:getBodyDamage():getHealthFromFoodTimer()

    if healTimer > 1000 then
        if md["UT_prevFoodTimer"] == nil then
            md["UT_prevFoodTimer"] = 1000
        end
        if healTimer > md["UT_prevFoodTimer"] then
            -- Food is actively digesting — apply stomach pain
            pcall(function()
                local torsoLower = player:getBodyDamage():getBodyPart(BodyPartType.FromString("Torso_Lower"))
                if torsoLower then
                    local pain = (healTimer - md["UT_prevFoodTimer"]) * (0.003 * (ZombRand(2) + 3))
                    torsoLower:setAdditionalPain(math.min(100, torsoLower:getAdditionalPain() + pain))
                end
            end)
        end
        md["UT_prevFoodTimer"] = healTimer
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
