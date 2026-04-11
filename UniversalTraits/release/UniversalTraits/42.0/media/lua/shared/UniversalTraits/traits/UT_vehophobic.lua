-- UT_vehophobic.lua
-- Vehicle phobic: raises panic and stress while the player is driving.
-- Applied via OnPlayerUpdate + isDriving() check (no OnVehicleEnter event in B42).

local TRAIT_ID = "UniversalTraits:UT_vehophobic"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if not player:isDriving() then return end

    local md = player:getModData()
    if md["UT_vehophobic_cooldown"] == nil then
        md["UT_vehophobic_cooldown"] = 0
    end
    if md["UT_vehophobic_cooldown"] > 0 then
        md["UT_vehophobic_cooldown"] = md["UT_vehophobic_cooldown"] - 1
        return
    end

    local stats = player:getStats()
    pcall(function()
        stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 1))
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.005))
    end)
    md["UT_vehophobic_cooldown"] = 30
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
