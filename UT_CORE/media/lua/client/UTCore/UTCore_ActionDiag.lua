-- UTCore_ActionDiag.lua
-- Temporary action-queue diagnostics to find the "bugged action" root cause.
-- Hooks every path that can kill/stop/clear the action queue.
-- All output prefixed with [UT_ADIAG] for easy grep.
--
-- REMOVE THIS FILE once the bug is found and fixed.

local P = "[UT_ADIAG]"

-- Kahlua does NOT have the debug table; debug.traceback crashes with
-- "attempted index: traceback of non-table: null".  Use an empty string;
-- PZ's own error output already includes the Lua call chain.
local function tb()
    return ""
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:create
---------------------------------------------------------------------
local origCreate = ISBaseTimedAction.create
ISBaseTimedAction.create = function(self)
    local atype = self.Type or "???"
    local preMT = self.maxTime
    local ok, err = pcall(origCreate, self)
    if ok then
        print(P .. " create " .. atype
            .. " mt:" .. tostring(preMT) .. "->" .. tostring(self.maxTime)
            .. " action=" .. tostring(self.action ~= nil))

        -- v5: Instance-level isValid wrapper with per-action condition logging
        local concreteIsValid = self.isValid
        if concreteIsValid then
            self.isValid = function(self2)
                local ivOk, ivResult = pcall(concreteIsValid, self2)
                if not ivOk then
                    print(P .. " ISVALID_CRASH " .. atype
                        .. " err=" .. tostring(ivResult))
                    return false
                end
                if not ivResult then
                    print(P .. " ISVALID_FALSE " .. atype
                        .. " result=" .. tostring(ivResult))
                    -- v5: Decompose conditions for known broken actions
                    pcall(function()
                        if atype == "ISTakeWaterAction" then
                            local hasItem = self2.item ~= nil
                            local containerOk = true
                            if hasItem then
                                containerOk = self2.item:getContainer() ~= nil
                            end
                            local hasFluid = self2.waterObject and self2.waterObject:hasFluid()
                            local fullInv = self2.character and self2.character:hasFullInventory()
                            local freeCapStr = "?"
                            pcall(function()
                                freeCapStr = tostring(self2.character:getFreeInventoryCapacity())
                            end)
                            print(P .. " DETAIL item=" .. tostring(hasItem)
                                .. " containerOk=" .. tostring(containerOk)
                                .. " hasFluid=" .. tostring(hasFluid)
                                .. " fullInv=" .. tostring(fullInv)
                                .. " freeCap=" .. freeCapStr)
                        elseif atype == "ISReadABook" then
                            local tooDark = self2.character:tooDarkToRead()
                            local hasItem = self2.item ~= nil
                            local invContains = hasItem and self2.character:getInventory():contains(self2.item)
                            local pages = hasItem and self2.item:getNumberOfPages() or -999
                            local readPg = hasItem and self2.item:getAlreadyReadPages() or -999
                            print(P .. " DETAIL tooDark=" .. tostring(tooDark)
                                .. " hasItem=" .. tostring(hasItem)
                                .. " invContains=" .. tostring(invContains)
                                .. " pages=" .. tostring(pages)
                                .. " readPages=" .. tostring(readPg))
                        else
                            -- Generic: log what we can
                            local hasItem = self2.item ~= nil
                            local hasChr = self2.character ~= nil
                            print(P .. " DETAIL generic item=" .. tostring(hasItem)
                                .. " character=" .. tostring(hasChr)
                                .. " type=" .. atype)
                        end
                    end)
                end
                return ivResult
            end
        end
    else
        print(P .. " create:ERROR " .. atype .. " err=" .. tostring(err))
        error(err, 0)
    end
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:begin
---------------------------------------------------------------------
local origBegin = ISBaseTimedAction.begin
ISBaseTimedAction.begin = function(self)
    local atype = self.Type or "???"
    print(P .. " begin " .. atype .. " mt=" .. tostring(self.maxTime))
    local ok, err = pcall(origBegin, self)
    if not ok then
        print(P .. " begin:ERROR " .. atype .. " err=" .. tostring(err))
        error(err, 0)
        return
    end
    local player = self.character
    if player and self.action then
        pcall(function()
            local actions = player:getCharacterActions()
            -- v4: Check started status from Java action object
            local started = "?"
            pcall(function() started = tostring(self.action.started) end)
            local forceStop = "?"
            pcall(function() forceStop = tostring(self.action.forceStop) end)
            print(P .. " begin:OK " .. atype
                .. " contains=" .. tostring(actions:contains(self.action))
                .. " stack=" .. actions:size()
                .. " mt=" .. tostring(self.maxTime)
                .. " started=" .. started
                .. " forceStop=" .. forceStop)
        end)
    end
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:stop  (Java calls this via LuaTimedActionNew)
---------------------------------------------------------------------
local origStop = ISBaseTimedAction.stop
ISBaseTimedAction.stop = function(self)
    local atype = self.Type or "???"
    print(P .. " STOP " .. atype .. " " .. tb())
    return origStop(self)
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:forceStop
---------------------------------------------------------------------
local origForceStop = ISBaseTimedAction.forceStop
ISBaseTimedAction.forceStop = function(self)
    local atype = self.Type or "???"
    print(P .. " FORCESTOP " .. atype .. " " .. tb())
    return origForceStop(self)
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:forceComplete
---------------------------------------------------------------------
local origForceComplete = ISBaseTimedAction.forceComplete
ISBaseTimedAction.forceComplete = function(self)
    local atype = self.Type or "???"
    print(P .. " FORCECOMPLETE " .. atype .. " " .. tb())
    return origForceComplete(self)
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:forceCancel
---------------------------------------------------------------------
local origForceCancel = ISBaseTimedAction.forceCancel
ISBaseTimedAction.forceCancel = function(self)
    local atype = self.Type or "???"
    print(P .. " FORCECANCEL " .. atype .. " " .. tb())
    return origForceCancel(self)
end

---------------------------------------------------------------------
-- Hook: ISBaseTimedAction:interruptWaitToStart
-- This is what Java calls from StopAllActionQueueWalking/Running
-- when started=false (SP always).  THIS IS THE KILL PATH.
---------------------------------------------------------------------
local origInterruptWait = ISBaseTimedAction.interruptWaitToStart
ISBaseTimedAction.interruptWaitToStart = function(self)
    local atype = self.Type or "???"
    print(P .. " INTERRUPT_WAIT " .. atype .. " " .. tb())
    return origInterruptWait(self)
end

---------------------------------------------------------------------
-- Hook: ISTimedActionQueue:resetQueue
---------------------------------------------------------------------
local origResetQueue = ISTimedActionQueue.resetQueue
ISTimedActionQueue.resetQueue = function(self)
    local atype = self.current and self.current.Type or "none"
    local qlen = self.queue and #self.queue or 0
    print(P .. " RESETQUEUE current=" .. atype .. " qlen=" .. qlen .. " " .. tb())
    return origResetQueue(self)
end

---------------------------------------------------------------------
-- Hook: ISTimedActionQueue:cancelQueue
---------------------------------------------------------------------
local origCancelQueue = ISTimedActionQueue.cancelQueue
ISTimedActionQueue.cancelQueue = function(self)
    local qlen = self.queue and #self.queue or 0
    print(P .. " CANCELQUEUE qlen=" .. qlen .. " " .. tb())
    return origCancelQueue(self)
end

---------------------------------------------------------------------
-- Hook: ISTimedActionQueue:tick
-- Check BEFORE PZ's bugged-action detection fires.
---------------------------------------------------------------------
local origTick = ISTimedActionQueue.tick
ISTimedActionQueue.tick = function(self)
    local action = self.queue and self.queue[1]
    if action and action.character and action.action then
        pcall(function()
            local player = action.character
            local actions = player:getCharacterActions()
            if not actions:contains(action.action) then
                local atype = action.Type or "???"
                print(P .. " BUGGED " .. atype
                    .. " stack=" .. actions:size()
                    .. " mt=" .. tostring(action.maxTime)
                    .. " justMoved=" .. tostring(player:isJustMoved())
                    .. " hasPath=" .. tostring(player:getPath2() ~= nil)
                    .. " isMoving=" .. tostring(player:isMoving())
                    .. " isRunning=" .. tostring(player:isRunning())
                    .. " isSprinting=" .. tostring(player:isSprinting())
                    .. " stopOnWalk=" .. tostring(action.action.stopOnWalk)
                    .. " stopOnRun=" .. tostring(action.action.stopOnRun))
                if UTCore and UTCore.dumpDiagnostics then
                    UTCore.dumpDiagnostics()
                end
            end
        end)
    elseif action and not action.action then
        print(P .. " BUGGED_NIL_ACTION " .. (action.Type or "???"))
    end
    return origTick(self)
end

---------------------------------------------------------------------
-- Hook: ISTimedActionQueue:addToQueue
---------------------------------------------------------------------
local origAddToQueue = ISTimedActionQueue.addToQueue
ISTimedActionQueue.addToQueue = function(self, action)
    local atype = action and action.Type or "???"
    local qlen = self.queue and #self.queue or 0
    print(P .. " addToQueue " .. atype .. " qlen=" .. qlen)
    return origAddToQueue(self, action)
end

-- v4: ISBaseTimedAction.isValid hook REMOVED.
-- It was at the wrong inheritance level — action types override isValid on their
-- own prototype, so this base hook was never reached for real actions.
-- Instance-level wrapper in create hook handles this correctly now.

---------------------------------------------------------------------
-- Monitor characterActions during OnPlayerUpdate (fires BEFORE
-- Java action processing in IsoGameCharacter.updateInternal).
-- This tells us if the action is alive at OUR code's time.
---------------------------------------------------------------------
local _prevActionAlive = false
local function onPlayerUpdateDiag(player)
    if not player then return end
    local ok, _ = pcall(function()
        local actions = player:getCharacterActions()
        local sz = actions:size()
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        local qaction = queue and queue.queue and queue.queue[1]
        if qaction and qaction.action then
            local alive = actions:contains(qaction.action)
            if alive and not _prevActionAlive then
                -- v4: Probe isValid before Java action processing does
                local probeOk, probeResult = pcall(function() return qaction:isValid() end)
                local startedStr = "?"
                pcall(function() startedStr = tostring(qaction.action.started) end)
                print(P .. " OPU_ACTION_ALIVE " .. (qaction.Type or "???") .. " stack=" .. sz
                    .. " isValid=" .. tostring(probeOk) .. "/" .. tostring(probeResult)
                    .. " started=" .. startedStr)
            elseif not alive and _prevActionAlive then
                print(P .. " OPU_ACTION_GONE " .. (qaction.Type or "???") .. " stack=" .. sz
                    .. " justMoved=" .. tostring(player:isJustMoved())
                    .. " hasPath=" .. tostring(player:getPath2() ~= nil))
            end
            _prevActionAlive = alive
        else
            if _prevActionAlive then
                print(P .. " OPU_QUEUE_EMPTY stack=" .. sz)
            end
            _prevActionAlive = false
        end
    end)
end
Events.OnPlayerUpdate.Add(onPlayerUpdateDiag)

---------------------------------------------------------------------
-- One-shot inventory state dump (fires once on first OPU tick)
---------------------------------------------------------------------
local _inventoryDumped = false
local function dumpInventoryState(player)
    if _inventoryDumped then return end
    _inventoryDumped = true
    pcall(function()
        local inv = player:getInventory()
        local maxW = "?"
        pcall(function() maxW = tostring(player:getMaxWeight()) end)
        local maxWB = "?"
        pcall(function() maxWB = tostring(player:getMaxWeightBase()) end)
        local capW = "?"
        pcall(function() capW = tostring(inv:getCapacityWeight()) end)
        local freeCap = "?"
        pcall(function() freeCap = tostring(player:getFreeInventoryCapacity()) end)
        local fullInv = "?"
        pcall(function() fullInv = tostring(player:hasFullInventory()) end)
        print(P .. " INV_STATE maxWeight=" .. maxW
            .. " maxWeightBase=" .. maxWB
            .. " capacityWeight=" .. capW
            .. " freeInventoryCap=" .. freeCap
            .. " hasFullInventory=" .. fullInv)
    end)
end
Events.OnPlayerUpdate.Add(dumpInventoryState)

print(P .. " Action diagnostics hooks installed (v5 - condition decompose)")
