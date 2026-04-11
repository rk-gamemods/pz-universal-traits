-- UT_lesssweaty.lua
-- Source: MoreSimpleTraits MSTMainFile.lua — lesssweatytrait().
-- OnCreatePlayer: configures shared wetness and thermal profiles in UT_CORE.

local TRAIT_ID = "UniversalTraits:UT_lesssweaty"

-- These wetness values are direct CharacterStat.WETNESS points, not percentages or vanilla wetness coefficients.
-- Vanilla CharacterStat.WETNESS is a 0..100 stat, so 3.0 means removing 3 full wetness points from the final bar each in-game minute.
-- Vanilla wetness simulation works much lower in the stack: BodyDamage.
-- UpdateWetness feeds ClothingWetness with WetnessIncrease=0.015 and WetnessDecrease=0.01, then merges body-part wetness back into the final stat.
-- This trait bypasses that lower-level per-body-part math and applies a direct post-vanilla correction to the final 0..100 wetness stat.
-- Indoor 3.0/min is therefore a strong effect: 3 percent of the full wetness bar per minute, or 50 wetness cleared in about 17 minutes.
local WETNESS_REDUCTION_INDOOR = 3.0

-- Outdoor non-rain uses the same direct 0..100 stat scale.
-- 1.5/min removes 1.5 percent of the full wetness bar per minute, or 50 wetness in about 33 minutes.
-- This is deliberately half the indoor rate: meaningful help, but not fast enough to erase exposure pressure outside.
local WETNESS_REDUCTION_OUTDOOR = 1.5

-- Rain reduction is also a direct 0..100 stat correction.
-- 0.5/min removes only 0.5 percent of the wetness bar per minute, or 50 wetness in about 100 minutes.
-- This is intentionally weak relative to the indoor/outdoor values, so rain still wins unless the player also changes conditions.
local WETNESS_REDUCTION_RAIN = 0.5

-- Temperature values here are direct CharacterStat.TEMPERATURE values.
-- Vanilla CharacterStat.TEMPERATURE is clamped to 20..40 and defaults to 37.0, so these are literal body-temperature numbers in the final stat layer.
-- Vanilla thermoregulation normally computes coreHeatDelta from totalHeat * 0.00025 each update, adjusts skin with 0.0025/0.005 multipliers, then writes the resulting core temperature back into CharacterStat.TEMPERATURE.
-- This trait does NOT change vanilla primaryDelta/secondaryDelta/bodyHeatDelta math. It applies a direct post-vanilla subtraction to the final temperature stat once per in-game minute.
-- 37.0 is the vanilla default and set point, so this floor means "pull back toward normal body temperature" and not "grant cold resistance".
local TEMPERATURE_FLOOR = 37.0

-- 37.1 is only 0.1 above vanilla normal (37.0), so this starts helping early in the overheating curve.
-- It is a low trigger, intended to catch creeping heat before the player is deep into hyperthermia.
local WARM_THRESHOLD = 37.1

-- 37.7 is 0.7 above vanilla normal.
-- This is the "actually overheating" breakpoint where the trait switches from light correction to its stronger direct cooling step.
local HOT_THRESHOLD = 37.7

-- 0.08 is a literal subtraction of 0.08 from CharacterStat.TEMPERATURE each in-game minute while above 37.2.
-- On the meaningful hot-side band from 37.0 normal to 40.0 clamp, that is 1/37.5 of the whole band per minute.
-- Over 10 in-game minutes, this removes 0.8 total temperature, so it should noticeably offset ordinary walking heat.
local WARM_COOLING = 0.08

-- 0.12 is a literal subtraction of 0.12 from CharacterStat.TEMPERATURE each in-game minute while above 37.7.
-- On the same 37.0..40.0 hot-side band, that is 1/25 of the whole band per minute.
-- Over 5 in-game minutes it removes 0.6; over 10 minutes it removes 1.2.
-- Strong enough to feel clearly better than baseline in hot weather, but still not full immunity against stacked heat and insulation.
local HOT_COOLING = 0.12

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWetnessReductionProfile(player, WETNESS_REDUCTION_INDOOR, WETNESS_REDUCTION_OUTDOOR, WETNESS_REDUCTION_RAIN)
    UTCore.applyThermalRegulationProfile(player, TEMPERATURE_FLOOR, WARM_THRESHOLD, HOT_THRESHOLD, WARM_COOLING, HOT_COOLING)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
