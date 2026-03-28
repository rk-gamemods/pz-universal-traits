-- UT_MET.lua
-- Universal Traits Mutual Exclusivity Table
-- Runtime reference for cross-referencing which traits are mutually exclusive with each other.
-- Organized by MET group from UT_character_traits.txt.

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

-- Weapon class: Axes (3 mutually exclusive)
UT_MET.WeaponAxes = {
	"UniversalTraits:UT_axes",
	"UniversalTraits:UT_twohanded_axes",
	"UniversalTraits:UT_onehanded_axes",
}

-- Weapon class: Blunts (5 mutually exclusive)
UT_MET.WeaponBlunts = {
	"UniversalTraits:UT_blunts",
	"UniversalTraits:UT_twohanded_blunts",
	"UniversalTraits:UT_onehanded_blunts",
	"UniversalTraits:UT_long_blunts",
	"UniversalTraits:UT_short_blunts",
}

-- Weapon class: Blades (5 mutually exclusive)
UT_MET.WeaponBlades = {
	"UniversalTraits:UT_blades",
	"UniversalTraits:UT_twohanded_blades",
	"UniversalTraits:UT_onehanded_blades",
	"UniversalTraits:UT_long_blades",
	"UniversalTraits:UT_short_blades",
}

-- Twohand/Onehand (2 mutually exclusive)
UT_MET.HandType = {
	"UniversalTraits:UT_twohanded",
	"UniversalTraits:UT_onehanded",
}

-- Prowess (4 mutually exclusive)
UT_MET.Prowess = {
	"UniversalTraits:UT_problunt",
	"UniversalTraits:UT_problade",
	"UniversalTraits:UT_progun",
	"UniversalTraits:UT_prospear",
}

-- Helper function: Get the MET group containing a given trait ID
-- Returns the group array if found, or nil if the trait is not in any group
function UT_MET.getGroupFor(traitId)
	local groups = {
		UT_MET.Specialization,
		UT_MET.WeaponAxes,
		UT_MET.WeaponBlunts,
		UT_MET.WeaponBlades,
		UT_MET.HandType,
		UT_MET.Prowess,
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

