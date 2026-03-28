-- UTCore_SpeedHook.lua
-- Applies UT_speedMod moddata to movement via Events.OnPlayerMove.
-- Reads previous position from moddata (UT_prevX, UT_prevY), computes delta,
-- multiplies by (1 + UT_speedMod), repositions player.
-- Teleport guard: skips if delta > 5 tiles on either axis.

UTCore = UTCore or {}

local TELEPORT_GUARD = 5.0

local function onPlayerMove()
    local player = getPlayer()
    if not player then return end
    if not player:isLocalPlayer() then return end

    local md = player:getModData()
    local mod = md["UT_speedMod"]

    local newX = player:getX()
    local newY = player:getY()

    if not mod or mod == 0 then
        md["UT_prevX"] = newX
        md["UT_prevY"] = newY
        return
    end

    local prevX = md["UT_prevX"]
    local prevY = md["UT_prevY"]

    if prevX == nil or prevY == nil then
        md["UT_prevX"] = newX
        md["UT_prevY"] = newY
        return
    end

    local dx = newX - prevX
    local dy = newY - prevY

    -- Teleport guard: skip if movement is too large (e.g. map load, fast travel)
    if math.abs(dx) > TELEPORT_GUARD or math.abs(dy) > TELEPORT_GUARD then
        md["UT_prevX"] = newX
        md["UT_prevY"] = newY
        return
    end

    if dx ~= 0 or dy ~= 0 then
        local factor = 1.0 + mod
        player:setX(prevX + dx * factor)
        player:setY(prevY + dy * factor)
    end

    md["UT_prevX"] = player:getX()
    md["UT_prevY"] = player:getY()
end

if Events and Events.OnPlayerMove then
    Events.OnPlayerMove.Add(onPlayerMove)
end
