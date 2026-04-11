-- UT_physicallyactive.lua
-- Physically active: exercise-specific XP bonus, mood boosts during exercise,
-- and endurance immunity during gym exercises at Fitness level 10.
--
-- XP multiplier for Fitness and Sprinting: handled via XPBoosts in the script file
--   (XPBoosts = Fitness=1;Sprinting=1 giving ×2 XP, native PZ, no hook needed).
--
-- Runtime effects via ISFitnessAction:exeLooped override:
--   - Stress -0.015 per exercise loop (relief from the workout high)
--   - Boredom -5 per exercise loop (exercise is fulfilling)
--   - Fitness level 10 gate: endurance is NOT consumed by gym exercises
--     (you run sprints with no energy cost because your body is perfectly conditioned).
--     Regular movement/sprinting still consumes endurance normally.
--
-- Exercises covered: squats, pushups, situps, burpees, barbellcurl,
--   dumbbellpress, bicepscurl, treadmill, benchpress.

local TRAIT_ID = "UniversalTraits:UT_physicallyactive"

local function installFitnessHook()
    if not _G["ISFitnessAction"] then return end
    if ISFitnessAction._UT_physActive_hooked then return end
    ISFitnessAction._UT_physActive_hooked = true

    local original_exeLooped = ISFitnessAction.exeLooped
    function ISFitnessAction:exeLooped()
        local player = self.character
        local preEndurance = nil

        -- Capture endurance before exercise if Fitness 10 immunity applies
        if player and UTCore.hasTrait(player, TRAIT_ID) then
            if player:getPerkLevel(Perks.Fitness) >= 10 then
                pcall(function()
                    preEndurance = player:getStats():get(CharacterStat.ENDURANCE)
                end)
            end
        end

        -- Call original exercise tick
        original_exeLooped(self)

        if not player or not UTCore.hasTrait(player, TRAIT_ID) then return end

        pcall(function()
            local stats = player:getStats()

            -- Stress relief from exercise
            stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.015))

            -- Boredom relief from exercise
            stats:set(CharacterStat.BOREDOM, math.max(0, stats:get(CharacterStat.BOREDOM) - 5))

            -- Fitness 10: restore any endurance lost to this exercise loop
            if preEndurance ~= nil then
                local postEndurance = stats:get(CharacterStat.ENDURANCE)
                if postEndurance < preEndurance then
                    stats:set(CharacterStat.ENDURANCE, preEndurance)
                end
            end
        end)
    end
end

-- Install hook when the game is ready (ISFitnessAction must be loaded first)
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(installFitnessHook)
end
