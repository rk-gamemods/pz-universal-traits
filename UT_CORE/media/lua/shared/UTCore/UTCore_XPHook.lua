-- UTCore_XPHook.lua
-- Intercepts Events.AddXP to apply UT_ XP multipliers, disables, and multi-skill penalties.

UTCore = UTCore or {}

local _xpPerksThisMinute = {}

-- Reset tracking every in-game minute
if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(function() _xpPerksThisMinute = {} end)
end

local function onAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local md = player:getModData()

    -- 1. XP disable: cancel the full amount
    if md["UT_xpDisable_" .. perk] then
        player:getXp():AddXP(perk, -amount, false, false, false)
        return
    end

    -- 2. XP multiplier: add the bonus delta
    local mult = md["UT_xpMult_" .. perk]
    if mult and mult ~= 1.0 then
        local bonus = math.floor(amount * (mult - 1.0))
        if bonus ~= 0 then
            player:getXp():AddXP(perk, bonus, false, false, false)
        end
    end

    -- 3. Multi-skill penalty (UT_onetrickpony): 50% penalty on 2nd+ perk per minute
    if md["UT_multiSkillPenalty"] then
        local pid = tostring(player)
        if not _xpPerksThisMinute[pid] then _xpPerksThisMinute[pid] = {} end
        local seen = _xpPerksThisMinute[pid]
        seen[perk] = true
        local count = 0
        for _ in pairs(seen) do count = count + 1 end
        if count > 1 then
            player:getXp():AddXP(perk, -math.floor(amount * 0.5), false, false, false)
        end
    end
end

if Events and Events.AddXP then
    Events.AddXP.Add(onAddXP)
end
