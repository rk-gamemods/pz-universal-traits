-- UT_MET.lua
-- Universal Traits Mutual Exclusivity Table
-- Runtime reference for which traits are mutually exclusive with each other.
-- Groups mirror the MutuallyExclusiveTraits entries in UT_character_traits.txt exactly.
-- Enforcement is done by the game engine via the .txt definitions; this table is a
-- Lua-side reference used by UTCore tooling (audit, debug, synergy checks).

UT_MET = {}

-- Specialization series: all mutually exclusive with each other (6 traits)
UT_MET.Specialization = {
	"UniversalTraits:UT_specweapons",
	"UniversalTraits:UT_speccrafting",
	"UniversalTraits:UT_specfood",
	"UniversalTraits:UT_specguns",
	"UniversalTraits:UT_specmove",
	"UniversalTraits:UT_specaid",
}

-- Weapon tree: all weapon specialisation traits are mutually exclusive with each other (17 traits).
-- Mirrors the MutuallyExclusiveTraits on every weapon tree entry in UT_character_traits.txt.
UT_MET.WeaponTree = {
	"UniversalTraits:UT_heavyswing",
	"UniversalTraits:UT_twohanded",
	"UniversalTraits:UT_onehanded",
	"UniversalTraits:UT_axes",
	"UniversalTraits:UT_twohanded_axes",
	"UniversalTraits:UT_onehanded_axes",
	"UniversalTraits:UT_blunts",
	"UniversalTraits:UT_twohanded_blunts",
	"UniversalTraits:UT_onehanded_blunts",
	"UniversalTraits:UT_long_blunts",
	"UniversalTraits:UT_short_blunts",
	"UniversalTraits:UT_blades",
	"UniversalTraits:UT_twohanded_blades",
	"UniversalTraits:UT_onehanded_blades",
	"UniversalTraits:UT_long_blades",
	"UniversalTraits:UT_short_blades",
	"UniversalTraits:UT_spears",
}

-- Prowess (4 mutually exclusive)
UT_MET.Prowess = {
	"UniversalTraits:UT_problunt",
	"UniversalTraits:UT_problade",
	"UniversalTraits:UT_progun",
	"UniversalTraits:UT_prospear",
}

-- Driving tiers (3 mutually exclusive)
UT_MET.Driving = {
	"UniversalTraits:UT_driver",
	"UniversalTraits:UT_expertdriver",
	"UniversalTraits:UT_poordriver",
}

-- Sleep quality pair (mutually exclusive: stacking would overwrite UT_sleepQualMod)
UT_MET.SleepQuality = {
	"UniversalTraits:UT_restfulsleeper",
	"UniversalTraits:UT_quickrest",
}

-- Bleed rate pair (mutually exclusive: both write UT_bleedDrainMult)
UT_MET.BleedRate = {
	"UniversalTraits:UT_thickblood",
	"UniversalTraits:UT_weaklybleedingwounds",
}

-- Stumble pair (mutually exclusive: double-stumble event spam)
UT_MET.Stumble = {
	"UniversalTraits:UT_flailer",
	"UniversalTraits:UT_lurcher",
}

-- Iron liver vs alcoholism (mutually exclusive: ironliver negates alcoholic dependency loop)
UT_MET.AlcoholDetox = {
	"UniversalTraits:UT_ironliver",
	"UniversalTraits:UT_alcoholic_I",
	"UniversalTraits:UT_alcoholic_II",
	"UniversalTraits:UT_alcoholic_III",
}

-- Helper function: Get the MET group containing a given trait ID.
-- Returns the group array if found, or nil if the trait is not in any group.
function UT_MET.getGroupFor(traitId)
	local groups = {
		UT_MET.Specialization,
		UT_MET.WeaponTree,
		UT_MET.Prowess,
		UT_MET.Driving,
		UT_MET.SleepQuality,
		UT_MET.BleedRate,
		UT_MET.Stumble,
		UT_MET.AlcoholDetox,
	}

	for _, group in ipairs(groups) do
		for _, trait in ipairs(group) do
			if trait == traitId then
				return group
			end
		end
	end

	return nil
end

