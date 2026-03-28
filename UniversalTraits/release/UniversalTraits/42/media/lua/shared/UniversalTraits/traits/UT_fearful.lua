-- UT_fearful.lua
-- Fearful: makes noise (shouts) when panicking, with chance scaling by panic level.
-- Matches MoreTraits FearfulUpdate: uses CharacterStat.PANIC (0-100 scale) via OnPlayerUpdate.

local TRAIT_ID = "UniversalTraits:UT_fearful"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    if md["UT_fearful_cooldown"] == nil then md["UT_fearful_cooldown"] = 0 end
    if md["UT_fearful_cooldown"] > 0 then
        md["UT_fearful_cooldown"] = md["UT_fearful_cooldown"] - 1
        return
    end

    local stats = player:getStats()
    local panic = stats:get(CharacterStat.PANIC)

    if panic > 5 then
        local chance = 3 + (panic / 10)
        if ZombRand(0, 1000) <= chance then
            local radius, volume = 5, 10
            if panic > 75 then
                radius, volume = 25, 50
            elseif panic > 50 then
                radius, volume = 20, 25
            elseif panic > 25 then
                radius, volume = 10, 15
            end
            pcall(function()
                player:Say("!")
                addSound(player, player:getX(), player:getY(), player:getZ(), radius, volume)
            end)
            md["UT_fearful_cooldown"] = 60
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
