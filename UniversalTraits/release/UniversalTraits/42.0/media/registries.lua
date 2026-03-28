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
UTTraitsRegistries.UT_preparedcartography = CharacterTrait.register("UniversalTraits:UT_preparedcartography")

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
