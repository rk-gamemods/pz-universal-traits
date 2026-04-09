-- UT_tavernbrawler.lua
-- Extra stomp damage: stomping a downed zombie deals an additional 30 HP of damage.
--
-- Stomp detection uses OnHitZombie.  A stomp is identified by the zombie being
-- on the ground (prone/crawling) at the moment of the hit — the same condition
-- PZ itself uses to permit stomps.  The bonus damage is applied inside a pcall;
-- if the zombie reaches 0 HP it is killed immediately via zombie:Kill(attacker).

local TRAIT_ID = "UniversalTraits:UT_tavernbrawler"
local STOMP_BONUS_DAMAGE = 30

local function onHitZombie(zombie, attacker, weapon, damage)
    if not attacker or attacker ~= getSpecificPlayer(0) then return end
    if not UTCore.hasTrait(attacker, TRAIT_ID) then return end
    if not zombie or not zombie:isKnockedDown() then return end
    pcall(function()
        local hp = zombie:getHealth()
        zombie:setHealth(hp - STOMP_BONUS_DAMAGE)
        if zombie:getHealth() <= 0 then
            zombie:Kill(attacker)
        end
    end)
end

Events.OnHitZombie.Add(onHitZombie)
