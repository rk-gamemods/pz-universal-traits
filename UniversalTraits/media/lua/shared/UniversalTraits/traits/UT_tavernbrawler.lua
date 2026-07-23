-- UT_tavernbrawler.lua
-- A true stomp deals 30 direct health damage before vanilla damage.
--
-- SwipeStatePlayer sets isShoveStompAnim before the collision reaches
-- OnHitZombie and clears it when the attack state exits. On SVN 964, the
-- preserved 30-point subtraction kills ordinary zombies immediately.

local TRAIT_ID = "UniversalTraits:UT_tavernbrawler"
local STOMP_BONUS_DAMAGE = 30

local function onHitZombie(zombie, attacker, bodyPart, weapon)
    if not attacker or attacker ~= getSpecificPlayer(0) then return end
    if not UTCore.hasTrait(attacker, TRAIT_ID) then return end
    if not attacker:isShoveStompAnim() then return end
    if not zombie then return end
    pcall(function()
        local hp = zombie:getHealth()
        zombie:setHealth(hp - STOMP_BONUS_DAMAGE)
        if zombie:getHealth() <= 0 then
            zombie:Kill(attacker)
        end
    end)
end

UTTavernBrawler = UTTavernBrawler or {}
if UTTavernBrawler.onHitZombie and Events.OnHitZombie.Remove then
    Events.OnHitZombie.Remove(UTTavernBrawler.onHitZombie)
end
UTTavernBrawler.onHitZombie = onHitZombie
Events.OnHitZombie.Add(UTTavernBrawler.onHitZombie)
