require "OptionScreens/CharacterCreationProfession"

if CharacterCreationProfession and not CharacterCreationProfession._UTCoreMetDebugWrapped then
    local originalDoTestForMutuallyExclusiveTraits = CharacterCreationProfession.doTestForMutuallyExclusiveTraits

    function CharacterCreationProfession:doTestForMutuallyExclusiveTraits(trait, isRemovingTrait)
        local mutexList = trait and trait.getMutuallyExclusiveTraits and trait:getMutuallyExclusiveTraits()

        if mutexList and CharacterTraitDefinition and CharacterTraitDefinition.getCharacterTraitDefinition then
            for index = 0, mutexList:size() - 1 do
                local exclusiveTrait = mutexList:get(index)
                local exclusiveDefinition = CharacterTraitDefinition.getCharacterTraitDefinition(exclusiveTrait)
                if exclusiveDefinition == nil then
                    UTCore.logCharacterCreationMetNull(trait, exclusiveTrait, index, isRemovingTrait)
                    break
                end
            end
        end

        return originalDoTestForMutuallyExclusiveTraits(self, trait, isRemovingTrait)
    end

    CharacterCreationProfession._UTCoreMetDebugWrapped = true
end