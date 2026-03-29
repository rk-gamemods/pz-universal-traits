-- registries.lua
-- Registers all UniversalTraits trait IDs with the B42 CharacterTrait system.
-- This file is loaded by PZ at startup from media/registries.lua.

UTTraitsRegistries = {}

-- ============================================================
-- PHASE 1 — XP BOOST: PREPARED SERIES
-- ============================================================
UTTraitsRegistries.UT_preparedfood        = CharacterTrait.register("UniversalTraits:UT_preparedfood")
UTTraitsRegistries.UT_preparedammo        = CharacterTrait.register("UniversalTraits:UT_preparedammo")
UTTraitsRegistries.UT_preparedmedical     = CharacterTrait.register("UniversalTraits:UT_preparedmedical")
UTTraitsRegistries.UT_preparedcarpentry   = CharacterTrait.register("UniversalTraits:UT_preparedcarpentry")
UTTraitsRegistries.UT_preparedcamp        = CharacterTrait.register("UniversalTraits:UT_preparedcamp")
UTTraitsRegistries.UT_preparedweapons     = CharacterTrait.register("UniversalTraits:UT_preparedweapons")
UTTraitsRegistries.UT_preparedcars        = CharacterTrait.register("UniversalTraits:UT_preparedcars")

-- ============================================================
-- PHASE 1 — XP BOOST: MOVEMENT & STEALTH
-- ============================================================
UTTraitsRegistries.UT_swift         = CharacterTrait.register("UniversalTraits:UT_swift")
UTTraitsRegistries.UT_flexible      = CharacterTrait.register("UniversalTraits:UT_flexible")
UTTraitsRegistries.UT_quiet         = CharacterTrait.register("UniversalTraits:UT_quiet")
UTTraitsRegistries.UT_olympian      = CharacterTrait.register("UniversalTraits:UT_olympian")
UTTraitsRegistries.UT_evasive       = CharacterTrait.register("UniversalTraits:UT_evasive")
UTTraitsRegistries.UT_marathonrunner = CharacterTrait.register("UniversalTraits:UT_marathonrunner")
UTTraitsRegistries.UT_strongnimble  = CharacterTrait.register("UniversalTraits:UT_strongnimble")
UTTraitsRegistries.UT_taut          = CharacterTrait.register("UniversalTraits:UT_taut")
UTTraitsRegistries.UT_ninjaway      = CharacterTrait.register("UniversalTraits:UT_ninjaway")
UTTraitsRegistries.UT_gymgoer       = CharacterTrait.register("UniversalTraits:UT_gymgoer")
UTTraitsRegistries.UT_sprintdemon   = CharacterTrait.register("UniversalTraits:UT_sprintdemon")
UTTraitsRegistries.UT_trekker       = CharacterTrait.register("UniversalTraits:UT_trekker")

-- ============================================================
-- PHASE 1 — XP BOOST: COMBAT (MELEE)
-- ============================================================
UTTraitsRegistries.UT_martial        = CharacterTrait.register("UniversalTraits:UT_martial")
UTTraitsRegistries.UT_bladetwirl     = CharacterTrait.register("UniversalTraits:UT_bladetwirl")
UTTraitsRegistries.UT_blunttwirl     = CharacterTrait.register("UniversalTraits:UT_blunttwirl")
UTTraitsRegistries.UT_tavernbrawler  = CharacterTrait.register("UniversalTraits:UT_tavernbrawler")
UTTraitsRegistries.UT_grunt          = CharacterTrait.register("UniversalTraits:UT_grunt")
UTTraitsRegistries.UT_actionhero     = CharacterTrait.register("UniversalTraits:UT_actionhero")
UTTraitsRegistries.UT_cruelty        = CharacterTrait.register("UniversalTraits:UT_cruelty")
UTTraitsRegistries.UT_sharpshooter   = CharacterTrait.register("UniversalTraits:UT_sharpshooter")

-- ============================================================
-- PHASE 1 — XP BOOST: COMBAT (PROWESS SERIES)
-- ============================================================
UTTraitsRegistries.UT_problunt  = CharacterTrait.register("UniversalTraits:UT_problunt")
UTTraitsRegistries.UT_problade  = CharacterTrait.register("UniversalTraits:UT_problade")
UTTraitsRegistries.UT_progun    = CharacterTrait.register("UniversalTraits:UT_progun")
UTTraitsRegistries.UT_prospear  = CharacterTrait.register("UniversalTraits:UT_prospear")

-- ============================================================
-- PHASE 1 — XP BOOST: COMBAT (SPECIALIZATION SERIES)
-- ============================================================
UTTraitsRegistries.UT_specweapons = CharacterTrait.register("UniversalTraits:UT_specweapons")
UTTraitsRegistries.UT_speccrafting = CharacterTrait.register("UniversalTraits:UT_speccrafting")
UTTraitsRegistries.UT_specfood    = CharacterTrait.register("UniversalTraits:UT_specfood")
UTTraitsRegistries.UT_specguns    = CharacterTrait.register("UniversalTraits:UT_specguns")
UTTraitsRegistries.UT_specmove    = CharacterTrait.register("UniversalTraits:UT_specmove")
UTTraitsRegistries.UT_specaid     = CharacterTrait.register("UniversalTraits:UT_specaid")
UTTraitsRegistries.UT_terminator  = CharacterTrait.register("UniversalTraits:UT_terminator")

-- ============================================================
-- PHASE 1 — XP BOOST: COMBATTRAITS WEAPON TREE
-- ============================================================
UTTraitsRegistries.UT_heavyswing       = CharacterTrait.register("UniversalTraits:UT_heavyswing")
UTTraitsRegistries.UT_twohanded        = CharacterTrait.register("UniversalTraits:UT_twohanded")
UTTraitsRegistries.UT_onehanded        = CharacterTrait.register("UniversalTraits:UT_onehanded")
UTTraitsRegistries.UT_axes             = CharacterTrait.register("UniversalTraits:UT_axes")
UTTraitsRegistries.UT_twohanded_axes   = CharacterTrait.register("UniversalTraits:UT_twohanded_axes")
UTTraitsRegistries.UT_onehanded_axes   = CharacterTrait.register("UniversalTraits:UT_onehanded_axes")
UTTraitsRegistries.UT_blunts           = CharacterTrait.register("UniversalTraits:UT_blunts")
UTTraitsRegistries.UT_twohanded_blunts = CharacterTrait.register("UniversalTraits:UT_twohanded_blunts")
UTTraitsRegistries.UT_onehanded_blunts = CharacterTrait.register("UniversalTraits:UT_onehanded_blunts")
UTTraitsRegistries.UT_long_blunts      = CharacterTrait.register("UniversalTraits:UT_long_blunts")
UTTraitsRegistries.UT_short_blunts     = CharacterTrait.register("UniversalTraits:UT_short_blunts")
UTTraitsRegistries.UT_blades           = CharacterTrait.register("UniversalTraits:UT_blades")
UTTraitsRegistries.UT_twohanded_blades = CharacterTrait.register("UniversalTraits:UT_twohanded_blades")
UTTraitsRegistries.UT_onehanded_blades = CharacterTrait.register("UniversalTraits:UT_onehanded_blades")
UTTraitsRegistries.UT_long_blades      = CharacterTrait.register("UniversalTraits:UT_long_blades")
UTTraitsRegistries.UT_short_blades     = CharacterTrait.register("UniversalTraits:UT_short_blades")
UTTraitsRegistries.UT_spears           = CharacterTrait.register("UniversalTraits:UT_spears")

-- ============================================================
-- PHASE 1 — XP BOOST: CRAFTING & KNOWLEDGE
-- ============================================================
UTTraitsRegistries.UT_ingenuitive        = CharacterTrait.register("UniversalTraits:UT_ingenuitive")
UTTraitsRegistries.UT_generator          = CharacterTrait.register("UniversalTraits:UT_generator")
UTTraitsRegistries.UT_tinkerer           = CharacterTrait.register("UniversalTraits:UT_tinkerer")
UTTraitsRegistries.UT_scrapper           = CharacterTrait.register("UniversalTraits:UT_scrapper")
UTTraitsRegistries.UT_scrounger          = CharacterTrait.register("UniversalTraits:UT_scrounger")
UTTraitsRegistries.UT_natural            = CharacterTrait.register("UniversalTraits:UT_natural")
UTTraitsRegistries.UT_wildsman           = CharacterTrait.register("UniversalTraits:UT_wildsman")
UTTraitsRegistries.UT_mushroomer         = CharacterTrait.register("UniversalTraits:UT_mushroomer")
UTTraitsRegistries.UT_antique            = CharacterTrait.register("UniversalTraits:UT_antique")
UTTraitsRegistries.UT_blissful           = CharacterTrait.register("UniversalTraits:UT_blissful")
UTTraitsRegistries.UT_gordanite          = CharacterTrait.register("UniversalTraits:UT_gordanite")
UTTraitsRegistries.UT_graverobber        = CharacterTrait.register("UniversalTraits:UT_graverobber")
UTTraitsRegistries.UT_vagabond           = CharacterTrait.register("UniversalTraits:UT_vagabond")
UTTraitsRegistries.UT_crafty             = CharacterTrait.register("UniversalTraits:UT_crafty")
UTTraitsRegistries.UT_paramedic          = CharacterTrait.register("UniversalTraits:UT_paramedic")
UTTraitsRegistries.UT_pitcrew            = CharacterTrait.register("UniversalTraits:UT_pitcrew")
UTTraitsRegistries.UT_prodigy            = CharacterTrait.register("UniversalTraits:UT_prodigy")
UTTraitsRegistries.UT_driver             = CharacterTrait.register("UniversalTraits:UT_driver")
UTTraitsRegistries.UT_amateurelectrician = CharacterTrait.register("UniversalTraits:UT_amateurelectrician")

-- ============================================================
-- PHASE 1 — XP BOOST: FILLTERTRAITS
-- ============================================================
UTTraitsRegistries.UT_trackman      = CharacterTrait.register("UniversalTraits:UT_trackman")
UTTraitsRegistries.UT_cleaver       = CharacterTrait.register("UniversalTraits:UT_cleaver")
UTTraitsRegistries.UT_woodsplitter  = CharacterTrait.register("UniversalTraits:UT_woodsplitter")
UTTraitsRegistries.UT_improviser    = CharacterTrait.register("UniversalTraits:UT_improviser")

-- ============================================================
-- PHASE 1 — STAT MODIFIERS (SIMPLE, NO RUNTIME LUA)
-- ============================================================
UTTraitsRegistries.UT_packmule      = CharacterTrait.register("UniversalTraits:UT_packmule")
UTTraitsRegistries.UT_packmouse     = CharacterTrait.register("UniversalTraits:UT_packmouse")
UTTraitsRegistries.UT_gimp          = CharacterTrait.register("UniversalTraits:UT_gimp")
UTTraitsRegistries.UT_anemic        = CharacterTrait.register("UniversalTraits:UT_anemic")
UTTraitsRegistries.UT_badteeth      = CharacterTrait.register("UniversalTraits:UT_badteeth")
UTTraitsRegistries.UT_deprived      = CharacterTrait.register("UniversalTraits:UT_deprived")
UTTraitsRegistries.UT_couchdweller  = CharacterTrait.register("UniversalTraits:UT_couchdweller")
UTTraitsRegistries.UT_sloth         = CharacterTrait.register("UniversalTraits:UT_sloth")
UTTraitsRegistries.UT_squirrel      = CharacterTrait.register("UniversalTraits:UT_squirrel")
UTTraitsRegistries.UT_antivaxxer    = CharacterTrait.register("UniversalTraits:UT_antivaxxer")
UTTraitsRegistries.UT_flimsy        = CharacterTrait.register("UniversalTraits:UT_flimsy")
UTTraitsRegistries.UT_sundayrunner  = CharacterTrait.register("UniversalTraits:UT_sundayrunner")
UTTraitsRegistries.UT_lesssweaty    = CharacterTrait.register("UniversalTraits:UT_lesssweaty")
UTTraitsRegistries.UT_highsweaty    = CharacterTrait.register("UniversalTraits:UT_highsweaty")
UTTraitsRegistries.UT_cangrabmore   = CharacterTrait.register("UniversalTraits:UT_cangrabmore")
UTTraitsRegistries.UT_cangrabless   = CharacterTrait.register("UniversalTraits:UT_cangrabless")
UTTraitsRegistries.UT_backpacker    = CharacterTrait.register("UniversalTraits:UT_backpacker")
UTTraitsRegistries.UT_topheavy      = CharacterTrait.register("UniversalTraits:UT_topheavy")
UTTraitsRegistries.UT_sore          = CharacterTrait.register("UniversalTraits:UT_sore")
UTTraitsRegistries.UT_staunch       = CharacterTrait.register("UniversalTraits:UT_staunch")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: SPAWN / INVENTORY
-- ============================================================
UTTraitsRegistries.UT_preparedpack      = CharacterTrait.register("UniversalTraits:UT_preparedpack")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: MOVEMENT
-- ============================================================
UTTraitsRegistries.UT_fast              = CharacterTrait.register("UniversalTraits:UT_fast")
UTTraitsRegistries.UT_noodlelegs        = CharacterTrait.register("UniversalTraits:UT_noodlelegs")
UTTraitsRegistries.UT_pacer             = CharacterTrait.register("UniversalTraits:UT_pacer")
UTTraitsRegistries.UT_lurcher           = CharacterTrait.register("UniversalTraits:UT_lurcher")
UTTraitsRegistries.UT_sorelegs          = CharacterTrait.register("UniversalTraits:UT_sorelegs")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: WORK SPEED
-- ============================================================
UTTraitsRegistries.UT_quickworker       = CharacterTrait.register("UniversalTraits:UT_quickworker")
UTTraitsRegistries.UT_slowworker        = CharacterTrait.register("UniversalTraits:UT_slowworker")
UTTraitsRegistries.UT_slack             = CharacterTrait.register("UniversalTraits:UT_slack")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: COMBAT & PHYSICAL
-- ============================================================
UTTraitsRegistries.UT_batteringram      = CharacterTrait.register("UniversalTraits:UT_batteringram")
UTTraitsRegistries.UT_fitted            = CharacterTrait.register("UniversalTraits:UT_fitted")
UTTraitsRegistries.UT_glassbody         = CharacterTrait.register("UniversalTraits:UT_glassbody")
UTTraitsRegistries.UT_brittle           = CharacterTrait.register("UniversalTraits:UT_brittle")
UTTraitsRegistries.UT_flailer           = CharacterTrait.register("UniversalTraits:UT_flailer")
UTTraitsRegistries.UT_fasthands         = CharacterTrait.register("UniversalTraits:UT_fasthands")
UTTraitsRegistries.UT_analgesia         = CharacterTrait.register("UniversalTraits:UT_analgesia")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: BLEEDING
-- ============================================================
UTTraitsRegistries.UT_thickblood            = CharacterTrait.register("UniversalTraits:UT_thickblood")
UTTraitsRegistries.UT_heavilybleedingwounds = CharacterTrait.register("UniversalTraits:UT_heavilybleedingwounds")
UTTraitsRegistries.UT_weaklybleedingwounds  = CharacterTrait.register("UniversalTraits:UT_weaklybleedingwounds")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: SLEEP & REST
-- ============================================================
UTTraitsRegistries.UT_restfulsleeper    = CharacterTrait.register("UniversalTraits:UT_restfulsleeper")
UTTraitsRegistries.UT_quickrest         = CharacterTrait.register("UniversalTraits:UT_quickrest")
UTTraitsRegistries.UT_snorer            = CharacterTrait.register("UniversalTraits:UT_snorer")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: PSYCHOLOGY & MODIFIERS
-- ============================================================
UTTraitsRegistries.UT_unwavering        = CharacterTrait.register("UniversalTraits:UT_unwavering")
UTTraitsRegistries.UT_idealweight       = CharacterTrait.register("UniversalTraits:UT_idealweight")
UTTraitsRegistries.UT_mundane           = CharacterTrait.register("UniversalTraits:UT_mundane")
UTTraitsRegistries.UT_incomprehensive   = CharacterTrait.register("UniversalTraits:UT_incomprehensive")
UTTraitsRegistries.UT_photographicmemory = CharacterTrait.register("UniversalTraits:UT_photographicmemory")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: XP PENALTIES
-- ============================================================
UTTraitsRegistries.UT_antigun           = CharacterTrait.register("UniversalTraits:UT_antigun")
UTTraitsRegistries.UT_flatearther       = CharacterTrait.register("UniversalTraits:UT_flatearther")
UTTraitsRegistries.UT_luddite           = CharacterTrait.register("UniversalTraits:UT_luddite")
UTTraitsRegistries.UT_onetrickpony      = CharacterTrait.register("UniversalTraits:UT_onetrickpony")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: NO-XP SERIES
-- ============================================================
UTTraitsRegistries.UT_noxpshooter       = CharacterTrait.register("UniversalTraits:UT_noxpshooter")
UTTraitsRegistries.UT_noxptechnician    = CharacterTrait.register("UniversalTraits:UT_noxptechnician")
UTTraitsRegistries.UT_noxpaxe           = CharacterTrait.register("UniversalTraits:UT_noxpaxe")
UTTraitsRegistries.UT_noxpfirstaid      = CharacterTrait.register("UniversalTraits:UT_noxpfirstaid")
UTTraitsRegistries.UT_noxpmaintenance   = CharacterTrait.register("UniversalTraits:UT_noxpmaintenance")
UTTraitsRegistries.UT_noxpsneaky        = CharacterTrait.register("UniversalTraits:UT_noxpsneaky")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: TIMED / CIRCADIAN
-- ============================================================
UTTraitsRegistries.UT_owlperson         = CharacterTrait.register("UniversalTraits:UT_owlperson")
UTTraitsRegistries.UT_larkperson        = CharacterTrait.register("UniversalTraits:UT_larkperson")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: VEHICLE
-- ============================================================
UTTraitsRegistries.UT_leadfoot          = CharacterTrait.register("UniversalTraits:UT_leadfoot")
UTTraitsRegistries.UT_expertdriver      = CharacterTrait.register("UniversalTraits:UT_expertdriver")
UTTraitsRegistries.UT_poordriver        = CharacterTrait.register("UniversalTraits:UT_poordriver")

-- ============================================================
-- PHASE 2 — LUA-DRIVEN: ITEM / CONSUMPTION
-- ============================================================
UTTraitsRegistries.UT_ironliver         = CharacterTrait.register("UniversalTraits:UT_ironliver")
UTTraitsRegistries.UT_durability        = CharacterTrait.register("UniversalTraits:UT_durability")
UTTraitsRegistries.UT_gourmand          = CharacterTrait.register("UniversalTraits:UT_gourmand")
UTTraitsRegistries.UT_ascetic           = CharacterTrait.register("UniversalTraits:UT_ascetic")

-- ============================================================
-- PHASE 3a — SPAWN-WITH-CONDITION
-- ============================================================
UTTraitsRegistries.UT_injured_I         = CharacterTrait.register("UniversalTraits:UT_injured_I")
UTTraitsRegistries.UT_injured_II        = CharacterTrait.register("UniversalTraits:UT_injured_II")
UTTraitsRegistries.UT_broke             = CharacterTrait.register("UniversalTraits:UT_broke")
UTTraitsRegistries.UT_burned            = CharacterTrait.register("UniversalTraits:UT_burned")

-- ============================================================
-- PHASE 3b — PERIODIC-CHECK TRAITS
-- ============================================================
UTTraitsRegistries.UT_depressive        = CharacterTrait.register("UniversalTraits:UT_depressive")
UTTraitsRegistries.UT_paranoia          = CharacterTrait.register("UniversalTraits:UT_paranoia")
UTTraitsRegistries.UT_selfdestructive   = CharacterTrait.register("UniversalTraits:UT_selfdestructive")
UTTraitsRegistries.UT_melancholic       = CharacterTrait.register("UniversalTraits:UT_melancholic")
UTTraitsRegistries.UT_immuneresponse    = CharacterTrait.register("UniversalTraits:UT_immuneresponse")
UTTraitsRegistries.UT_ravenous          = CharacterTrait.register("UniversalTraits:UT_ravenous")
UTTraitsRegistries.UT_optimist          = CharacterTrait.register("UniversalTraits:UT_optimist")
UTTraitsRegistries.UT_pessimist         = CharacterTrait.register("UniversalTraits:UT_pessimist")
UTTraitsRegistries.UT_mstoptimist       = CharacterTrait.register("UniversalTraits:UT_mstoptimist")
UTTraitsRegistries.UT_adaptivemetabolism = CharacterTrait.register("UniversalTraits:UT_adaptivemetabolism")
UTTraitsRegistries.UT_accmetabolism     = CharacterTrait.register("UniversalTraits:UT_accmetabolism")
UTTraitsRegistries.UT_albino            = CharacterTrait.register("UniversalTraits:UT_albino")
UTTraitsRegistries.UT_fibromyalgia      = CharacterTrait.register("UniversalTraits:UT_fibromyalgia")
UTTraitsRegistries.UT_bigorexia         = CharacterTrait.register("UniversalTraits:UT_bigorexia")
UTTraitsRegistries.UT_weathersensitive  = CharacterTrait.register("UniversalTraits:UT_weathersensitive")
UTTraitsRegistries.UT_panicattacks      = CharacterTrait.register("UniversalTraits:UT_panicattacks")
UTTraitsRegistries.UT_fearofthedark     = CharacterTrait.register("UniversalTraits:UT_fearofthedark")
UTTraitsRegistries.UT_coldsensitive     = CharacterTrait.register("UniversalTraits:UT_coldsensitive")
UTTraitsRegistries.UT_heatsensitive     = CharacterTrait.register("UniversalTraits:UT_heatsensitive")
UTTraitsRegistries.UT_sedentary         = CharacterTrait.register("UniversalTraits:UT_sedentary")
UTTraitsRegistries.UT_alcoholic_I       = CharacterTrait.register("UniversalTraits:UT_alcoholic_I")
UTTraitsRegistries.UT_alcoholic_II      = CharacterTrait.register("UniversalTraits:UT_alcoholic_II")
UTTraitsRegistries.UT_alcoholic_III     = CharacterTrait.register("UniversalTraits:UT_alcoholic_III")
UTTraitsRegistries.UT_addictedtocaffeine = CharacterTrait.register("UniversalTraits:UT_addictedtocaffeine")
UTTraitsRegistries.UT_immunocompromised = CharacterTrait.register("UniversalTraits:UT_immunocompromised")

-- ============================================================
-- PHASE 3c — EVENT-DRIVEN TRAITS
-- ============================================================
UTTraitsRegistries.UT_fearful           = CharacterTrait.register("UniversalTraits:UT_fearful")
UTTraitsRegistries.UT_nervouswreck      = CharacterTrait.register("UniversalTraits:UT_nervouswreck")
UTTraitsRegistries.UT_scardycat         = CharacterTrait.register("UniversalTraits:UT_scardycat")
UTTraitsRegistries.UT_maniac            = CharacterTrait.register("UniversalTraits:UT_maniac")
UTTraitsRegistries.UT_anorexy           = CharacterTrait.register("UniversalTraits:UT_anorexy")
UTTraitsRegistries.UT_pillsallergy      = CharacterTrait.register("UniversalTraits:UT_pillsallergy")
UTTraitsRegistries.UT_wildplantsallergy = CharacterTrait.register("UniversalTraits:UT_wildplantsallergy")
UTTraitsRegistries.UT_allergic          = CharacterTrait.register("UniversalTraits:UT_allergic")
UTTraitsRegistries.UT_competitiveeater  = CharacterTrait.register("UniversalTraits:UT_competitiveeater")
UTTraitsRegistries.UT_sensitivestomach  = CharacterTrait.register("UniversalTraits:UT_sensitivestomach")
UTTraitsRegistries.UT_butterfingers     = CharacterTrait.register("UniversalTraits:UT_butterfingers")
UTTraitsRegistries.UT_acrophobic        = CharacterTrait.register("UniversalTraits:UT_acrophobic")
UTTraitsRegistries.UT_vehophobic        = CharacterTrait.register("UniversalTraits:UT_vehophobic")
UTTraitsRegistries.UT_motionsickness    = CharacterTrait.register("UniversalTraits:UT_motionsickness")
UTTraitsRegistries.UT_physicallyactive  = CharacterTrait.register("UniversalTraits:UT_physicallyactive")
UTTraitsRegistries.UT_humanhamster      = CharacterTrait.register("UniversalTraits:UT_humanhamster")
UTTraitsRegistries.UT_superimmune       = CharacterTrait.register("UniversalTraits:UT_superimmune")
UTTraitsRegistries.UT_bouncer_I         = CharacterTrait.register("UniversalTraits:UT_bouncer_I")
UTTraitsRegistries.UT_bouncer_II        = CharacterTrait.register("UniversalTraits:UT_bouncer_II")
UTTraitsRegistries.UT_gunspecialist_I   = CharacterTrait.register("UniversalTraits:UT_gunspecialist_I")
UTTraitsRegistries.UT_gunspecialist_II  = CharacterTrait.register("UniversalTraits:UT_gunspecialist_II")
UTTraitsRegistries.UT_gunspecialist_III = CharacterTrait.register("UniversalTraits:UT_gunspecialist_III")

-- ============================================================
-- PHASE 3d — COMPLEX STATE TRAITS
-- ============================================================
UTTraitsRegistries.UT_indefatigable     = CharacterTrait.register("UniversalTraits:UT_indefatigable")
UTTraitsRegistries.UT_hardy             = CharacterTrait.register("UniversalTraits:UT_hardy")
UTTraitsRegistries.UT_secondwind        = CharacterTrait.register("UniversalTraits:UT_secondwind")
