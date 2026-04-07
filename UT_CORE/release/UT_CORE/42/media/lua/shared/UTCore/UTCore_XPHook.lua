-- UTCore_XPHook.lua
-- Intercepts Events.AddXP to apply UT_ XP multipliers, disables, multi-skill penalties,
-- and skill cap enforcement (UT_skillCapReduction).

UTCore = UTCore or {}

UTCore._xpPerksThisMinute = {}

local function resetXPTracking()
    for k in pairs(UTCore._xpPerksThisMinute) do
        UTCore._xpPerksThisMinute[k] = nil
    end
end

-- Reset tracking every in-game minute
if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(resetXPTracking)
end

local function onAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local md = player:getModData()
    local perkName = tostring(perk)

    -- 1. XP disable: cancel the full amount
    if md["UT_xpDisable_" .. perkName] then
        player:getXp():AddXP(perk, -amount, false, false, false)
        return
    end

    -- 2. Skill cap enforcement (UT_incomprehensive): hard cap at (maxLevel - UT_skillCapReduction).
    -- PZ perk max is 10. If UT_skillCapReduction = 2, the cap is level 8.
    -- Any XP gain that would push the perk over the cap is negated in full.
    local capReduction = md["UT_skillCapReduction"]
    if capReduction and capReduction > 0 then
        local currentLevel = player:getPerkLevel(perk)
        local hardCap = 10 - capReduction
        if currentLevel >= hardCap then
            -- Block all XP at or beyond the cap
            player:getXp():AddXP(perk, -amount, false, false, false)
            return
        end
    end

    -- 3. XP multiplier: add the bonus delta
    local mult = 1.0
    local globalMult = md["UT_xpMult_All"]
    local perkMult = md["UT_xpMult_" .. perkName]
    if globalMult and globalMult ~= 1.0 then
        mult = mult * globalMult
    end
    if perkMult and perkMult ~= 1.0 then
        mult = mult * perkMult
    end
    if mult ~= 1.0 then
        local bonus = math.floor(amount * (mult - 1.0))
        if bonus ~= 0 then
            player:getXp():AddXP(perk, bonus, false, false, false)
        end
    end

    -- 4. Multi-skill penalty (UT_onetrickpony): 50% penalty on 2nd+ perk per minute
    if md["UT_multiSkillPenalty"] then
        local pid = tostring(player)
        if not UTCore._xpPerksThisMinute[pid] then UTCore._xpPerksThisMinute[pid] = {} end
        local seen = UTCore._xpPerksThisMinute[pid]
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
