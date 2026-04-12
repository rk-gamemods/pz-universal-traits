-- UT_blissful.lua
-- Gain a small amount of happiness every ~100 ticks (~every in-game minute).
--
-- PZ stores mood as an unhappiness level on BodyDamage; reducing it raises
-- the player's happiness.  1 point is subtracted from the unhappiness level
-- per interval, floored at 0 so it never goes negative.

local TRAIT_ID = "UniversalTraits:UT_blissful"
local tickCounter = 0

local function onTick(player, tick)
    tickCounter = tickCounter + 1
    if tickCounter % 100 ~= 0 then return end

    local stats = tick.stats
    if not stats then return end

    local unhappy = stats:get(CharacterStat.UNHAPPINESS)
    if unhappy and unhappy > 0 then
        stats:set(CharacterStat.UNHAPPINESS, math.max(0, unhappy - 1))
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
