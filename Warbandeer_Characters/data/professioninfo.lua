---@type Warbandeer_Characters
local ns = select(2, ...)
local API = ns.api

-- Static per-profession identity table (skill-line + Midnight variant ids, the
-- profession spell). Keyed `sl<skillLineID>`. Published on the API so the views
-- (Crafting/Professions/Midnight) and the broker can resolve a profession's ids.
-- Loaded before data/professions.lua, which keys its broker fields off these.
API.professionInfo = {
  sl171 = {
    name = "Alchemy",
    skillLineID = 171,
    skillLineVariantID = 2871,
    midVariantID = 2906,
    spellID = 423321,
  },
  sl164 = {
    name = "Blacksmithing",
    skillLineID = 164,
    skillLineVariantID = 2872,
    midVariantID = 2907,
    spellID = 423332,
  },
  sl333 = {
    name = "Enchanting",
    skillLineID = 333,
    skillLineVariantID = 2874,
    midVariantID = 2909,
    spellID = 423334,
  },
  sl202 = {
    name = "Engineering",
    skillLineID = 202,
    skillLineVariantID = 2875,
    midVariantID = 2910,
    spellID = 423335,
  },
  sl182 = {
    name = "Herbalism",
    skillLineID = 182,
    skillLineVariantID = 2877,
    midVariantID = 2912,
    spellID = 441327,
  },
  sl773 = {
    name = "Inscription",
    skillLineID = 773,
    skillLineVariantID = 2878,
    midVariantID = 2913,
    spellID = 423338,
  },
  sl755 = {
    name = "Jewelcrafting",
    skillLineID = 755,
    skillLineVariantID = 2879,
    midVariantID = 2914,
    spellID = 423339,
  },
  sl165 = {
    name = "Leatherworking",
    skillLineID = 165,
    skillLineVariantID = 2880,
    midVariantID = 2915,
    spellID = 423340,
  },
  sl186 = {
    name = "Mining",
    skillLineID = 186,
    skillLineVariantID = 2881,
    midVariantID = 2916,
    spellID = 423341,
  },
  sl393 = {
    name = "Skinning",
    skillLineID = 393,
    skillLineVariantID = 2882,
    midVariantID = 2917,
    spellID = 423342,
  },
  sl197 = {
    name = "Tailoring",
    skillLineID = 197,
    skillLineVariantID = 2883,
    midVariantID = 2918,
    spellID = 423343,
  },
}
