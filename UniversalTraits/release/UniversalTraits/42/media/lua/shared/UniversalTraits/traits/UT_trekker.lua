-- UT_trekker.lua
-- Walking refunds endurance loss without suppressing normal hunger drift.

local TRAIT_ID = "UniversalTraits:UT_trekker"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    md["UT_trekker_tick"] = (md["UT_trekker_tick"] or 0) + 1
    if md["UT_trekker_tick"] % 10 ~= 0 then return end

    local stats = player:getStats()
    if not stats then return end

    local currentEndurance = stats:get(CharacterStat.ENDURANCE)
    local okMoving, moving = pcall(function() return player:isMoving() end)
    local isWalking = okMoving and moving and not player:isSprinting() and not player:isRunning()

    if not isWalking then
        md["UT_trekker_lastEndurance"] = currentEndurance
        return
    end

    local lastEndurance = md["UT_trekker_lastEndurance"]
    if type(lastEndurance) == "number" and currentEndurance < lastEndurance then
        stats:set(CharacterStat.ENDURANCE, lastEndurance)
        currentEndurance = stats:get(CharacterStat.ENDURANCE)
    end

    md["UT_trekker_lastEndurance"] = currentEndurance
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
