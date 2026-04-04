-- UTCore_PainHook.lua
-- Reads UT_painImmune from player moddata every OnPlayerUpdate tick.
-- If true, zeroes out the pain stat so the player feels no pain regardless of injuries.
--
-- Pain in PZ is a 0–100 float (IsoStats.getPain/setPain).
-- This hook clears it every tick, overriding any native pain additions from wounds.
-- Note: this does NOT suppress the wound or injury itself — only the pain sensation.
-- The player can still die from blood loss; they just won't feel it.

UTCore = UTCore or {}

local function onPlayerUpdate(player)
    if not player then return end
    local md = player:getModData()
    if not md["UT_painImmune"] then return end

    local stats = player:getStats()
    if not stats then return end

    if stats:getPain() > 0 then
        stats:setPain(0)
    end
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
