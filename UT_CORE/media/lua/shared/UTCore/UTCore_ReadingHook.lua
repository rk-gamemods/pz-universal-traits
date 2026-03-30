-- UTCore_ReadingHook.lua
-- Patches ISReadABook at OnGameBoot to support reading-specific UT_ effects.

UTCore = UTCore or {}

local PHOTO_TRAIT_ID = "UniversalTraits:UT_photographicmemory"

local BOOK_XP_BY_MAX_LEVEL = {
    [2] = 12,
    [4] = 30,
    [6] = 65,
    [8] = 120,
    [10] = 200,
}

local function clampMinZero(value)
    if not value or value < 0 then return 0 end
    return value
end

function UTCore.getSkillBookCompletionXP(item)
    if not item or not item.getNumberOfPages or item:getNumberOfPages() <= 0 then return 0 end
    if not item.getSkillTrained or not item.getMaxLevelTrained then return 0 end
    if not SkillBook then return 0 end

    local skill = item:getSkillTrained()
    if not skill or not SkillBook[skill] then return 0 end

    return BOOK_XP_BY_MAX_LEVEL[item:getMaxLevelTrained()] or 0
end

function UTCore.applyReadingMoodEffects(player, tickScale)
    if not player then return end

    local stats = player:getStats()
    local bd = player:getBodyDamage()
    if not stats or not bd then return end

    local scale = tickScale or 1.0
    local md = player:getModData()

    if md["UT_readCalm"] then
        if stats.setPanic then stats:setPanic(0) end
        if stats.setStress then stats:setStress(0) end
    end

    local moodBonus = md["UT_readMoodBonus"] or 0
    if moodBonus <= 0 then return end

    if bd.getBoredomLevel and bd.setBoredomLevel then
        local boredom = bd:getBoredomLevel()
        bd:setBoredomLevel(clampMinZero(boredom - (moodBonus * scale)))
    end

    local getUnhappy = bd.getUnhappinessLevel or bd.getUnhappynessLevel
    local setUnhappy = bd.setUnhappinessLevel or bd.setUnhappynessLevel
    if getUnhappy and setUnhappy then
        local unhappy = getUnhappy(bd)
        setUnhappy(bd, clampMinZero(unhappy - (moodBonus * scale)))
    end
end

function UTCore.tryAwardSkillBookCompletionXP(player, item, startPages, endPages)
    if not player or not item then return 0 end

    local totalPages = item.getNumberOfPages and item:getNumberOfPages() or 0
    if totalPages <= 0 then return 0 end

    local startValue = startPages or 0
    local endValue = endPages or 0
    if startValue >= totalPages or endValue < totalPages then return 0 end

    local skill = item.getSkillTrained and item:getSkillTrained()
    if not skill or not SkillBook or not SkillBook[skill] or not SkillBook[skill].perk then return 0 end

    local bonus = UTCore.getSkillBookCompletionXP(item)
    if bonus <= 0 then return 0 end

    player:getXp():AddXP(SkillBook[skill].perk, bonus, false, false, false)
    return bonus
end

local function tryPatchReadAction()
    if UTCore._readingHookPatched then return end

    local cls = _G.ISReadABook
    if type(cls) ~= "table" then return end

    local originalStart = cls.start
    if type(originalStart) == "function" then
        cls.start = function(self, ...)
            local item = self.item
            self._utReadStartPages = (item and item.getAlreadyReadPages) and item:getAlreadyReadPages() or 0
            self._utReadXpAwarded = false
            return originalStart(self, ...)
        end
    end

    local originalUpdate = cls.update
    if type(originalUpdate) == "function" then
        cls.update = function(self, ...)
            local result = originalUpdate(self, ...)
            local player = self.character
            if player and UTCore.hasTrait(player, PHOTO_TRAIT_ID) then
                local tickScale = 1.0
                if GameTime and GameTime.getInstance then
                    local gt = GameTime.getInstance()
                    if gt and gt.getMultiplier then
                        tickScale = gt:getMultiplier()
                    end
                end
                UTCore.applyReadingMoodEffects(player, tickScale)
            end
            return result
        end
    end

    local function maybeAward(self)
        if self._utReadXpAwarded then return end

        local player = self.character
        local item = self.item
        if not player or not item or not UTCore.hasTrait(player, PHOTO_TRAIT_ID) then return end

        local endPages = (item.getAlreadyReadPages and item:getAlreadyReadPages()) or 0
        local bonus = UTCore.tryAwardSkillBookCompletionXP(player, item, self._utReadStartPages or 0, endPages)
        if bonus > 0 then
            self._utReadXpAwarded = true
        end
    end

    local originalStop = cls.stop
    if type(originalStop) == "function" then
        cls.stop = function(self, ...)
            maybeAward(self)
            return originalStop(self, ...)
        end
    end

    local originalPerform = cls.perform
    if type(originalPerform) == "function" then
        cls.perform = function(self, ...)
            maybeAward(self)
            return originalPerform(self, ...)
        end
    end

    UTCore._readingHookPatched = true
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(tryPatchReadAction)
end