-- UT_pitcrew.lua
-- Car mechanics actions are 50% faster.
--
-- Two mechanisms are used together:
--   1. OnNewGame calls UTCore.applyMechanicsSpeed (if present in UTCore) to register
--      a persistent speed multiplier for vehicle mechanic actions.
--   2. OnActionAdded intercepts timed actions whose class name matches common
--      vehicle/mechanic action keywords and halves their max time directly.
-- Both hooks are registered inside pcall so missing events or API methods degrade
-- gracefully without breaking other traits.

local TRAIT_ID = "UniversalTraits:UT_pitcrew"

local MECHANIC_KEYWORDS = {
    "Vehicle", "Mechanic", "RepairVehicle", "ChangeVehicle",
    "InstallVehicle", "UninstallVehicle", "InflateTire",
}

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_pitcrewActive"] = true
    pcall(function()
        if UTCore.applyMechanicsSpeed then
            UTCore.applyMechanicsSpeed(player, 0.5)
        end
    end)
end

local function getActionType(action)
    if not action then return "" end
    if action.Type ~= nil then return tostring(action.Type) end
    return tostring(action)
end

local function onActionAdd(action)
    local player = getSpecificPlayer(0)
    if not player or not UTCore.hasTrait(player, TRAIT_ID) then return end
    pcall(function()
        local actionType = getActionType(action)
        for _, keyword in ipairs(MECHANIC_KEYWORDS) do
            if actionType:find(keyword) then
                local currentTime = action.maxTime
                if type(currentTime) == "number" then
                    action.maxTime = math.floor(currentTime * 0.5)
                elseif action.getMaxTime and action.setMaxTime then
                    currentTime = action:getMaxTime()
                    if currentTime then
                        action:setMaxTime(math.floor(currentTime * 0.5))
                    end
                end
                break
            end
        end
    end)
end

Events.OnNewGame.Add(onNewGame)
if Events.OnActionAdded then Events.OnActionAdded.Add(onActionAdd) end
