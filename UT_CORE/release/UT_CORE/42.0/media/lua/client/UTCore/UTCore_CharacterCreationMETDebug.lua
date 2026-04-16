require "OptionScreens/CharacterCreationProfession"

-- Gated by UTCore.MET_DEBUG_ENABLED (set in UTCore_API.lua).
-- When disabled, the crash-guard wrapper and MET audit are skipped entirely.
if not UTCore or not UTCore.MET_DEBUG_ENABLED then
    return
end

if CharacterCreationProfession and not CharacterCreationProfession._UTCoreMetDebugWrapped then
    local originalDoTestForMutuallyExclusiveTraits = CharacterCreationProfession.doTestForMutuallyExclusiveTraits

    -- Crash-safe replacement: logs broken exclusions instead of crashing, then skips the nil entry.
    function CharacterCreationProfession:doTestForMutuallyExclusiveTraits(trait, isRemovingTrait)
        local mutexList = trait and trait.getMutuallyExclusiveTraits and trait:getMutuallyExclusiveTraits()

        if mutexList and CharacterTraitDefinition and CharacterTraitDefinition.getCharacterTraitDefinition then
            for index = 0, mutexList:size() - 1 do
                local exclusiveTrait = mutexList:get(index)
                local exclusiveDefinition = CharacterTraitDefinition.getCharacterTraitDefinition(exclusiveTrait)
                if exclusiveDefinition == nil then
                    UTCore.logCharacterCreationMetNull(trait, exclusiveTrait, index, isRemovingTrait)
                    -- Skip this nil entry to prevent the vanilla crash.
                    -- Log all nil entries so the full list is visible in console.txt.
                end
            end
        end

        -- Call the original, which will still crash on nil entries.
        -- We use pcall to catch the crash, log it, and continue.
        local ok, err = pcall(originalDoTestForMutuallyExclusiveTraits, self, trait, isRemovingTrait)
        if not ok then
            local selectedId = UTCore.getTraitDefinitionId(trait)
            print(string.format(
                "[UT_MET_DEBUG] CRASH prevented in doTestForMutuallyExclusiveTraits selected=%s removing=%s err=%s",
                selectedId, tostring(isRemovingTrait), tostring(err)
            ))
        end
    end

    CharacterCreationProfession._UTCoreMetDebugWrapped = true
end

local function auditUniversalTraitDefinitions()
    if not UTTraitsRegistries then
        print("[UT_MET_AUDIT] UTTraitsRegistries missing; UniversalTraits may not be loaded yet.")
        return
    end
    if not CharacterTraitDefinition or type(CharacterTraitDefinition.getCharacterTraitDefinition) ~= "function" then
        print("[UT_MET_AUDIT] CharacterTraitDefinition API unavailable.")
        return
    end

    local missingDefinitions = 0
    local brokenExclusions = 0

    for registryKey, traitObject in pairs(UTTraitsRegistries) do
        local traitId = UTCore.getCharacterTraitId(traitObject)
        local traitDefinition = CharacterTraitDefinition.getCharacterTraitDefinition(traitObject)

        if traitDefinition == nil then
            missingDefinitions = missingDefinitions + 1
            print(string.format(
                "[UT_MET_AUDIT] missing_definition registry_key=%s trait=%s",
                tostring(registryKey),
                traitId
            ))
        else
            local mutexList = traitDefinition:getMutuallyExclusiveTraits()
            if mutexList and type(mutexList.size) == "function" and type(mutexList.get) == "function" then
                for index = 0, mutexList:size() - 1 do
                    local exclusiveTrait = mutexList:get(index)
                    local exclusiveDefinition = CharacterTraitDefinition.getCharacterTraitDefinition(exclusiveTrait)
                    if exclusiveDefinition == nil then
                        brokenExclusions = brokenExclusions + 1
                        print(string.format(
                            "[UT_MET_AUDIT] broken_exclusive source=%s index=%d exclusive=%s",
                            traitId,
                            index,
                            UTCore.getCharacterTraitId(exclusiveTrait)
                        ))
                    end
                end
            end
        end
    end

    print(string.format(
        "[UT_MET_AUDIT] summary missing_definitions=%d broken_exclusions=%d",
        missingDefinitions,
        brokenExclusions
    ))
end

if Events and Events.OnMainMenuEnter and not _G.UTCoreCharacterCreationMetauditRegistered then
    Events.OnMainMenuEnter.Add(auditUniversalTraitDefinitions)
    _G.UTCoreCharacterCreationMetauditRegistered = true
end