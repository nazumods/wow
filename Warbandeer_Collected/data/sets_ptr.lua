---@type Warbandeer_Collected
local ns = select(2, ...)
local tinsert = tinsert
-- Generated from wago.tools TransmogSet PTR delta (live 12.0.7.68887 vs PTR 12.1.0.68914, 2026-07-24) by tools/update-sets.ps1 -PtrDelta.
-- Sets present on the PTR but not yet on live ("upcoming"). VOLATILE — regenerate
-- on demand; not part of the weekly live refresh. release tags the newest expansion;
-- instance/difficulty are omitted (no lockouts for unreleased content).

---@class Warbandeer_Collected
---@field PtrSets table[] PTR-only set groups (same shape as ns.Sets)
---@field PtrBuild { live: string, ptr: string } the builds this delta was generated from
ns.PtrSets = {}
ns.PtrBuild = { live = "12.0.7.68887", ptr = "12.1.0.68914" }

tinsert(ns.PtrSets, {
  id = 396,
  name = "Regalia of the Loa",
  release = 12,
  sets = {
    { id = 5719, name = "Warplate of Nalorakk's Chosen", classId = 1 },
    { id = 5719, name = "Warplate of Nalorakk's Chosen", classId = 2 },
    { id = 5718, name = "Chainmail of Akil'zon's Chosen", classId = 3 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 4 },
    { id = 5716, name = "Vestments of Jan'alai's Chosen", classId = 5 },
    { id = 5719, name = "Warplate of Nalorakk's Chosen", classId = 6 },
    { id = 5718, name = "Chainmail of Akil'zon's Chosen", classId = 7 },
    { id = 5716, name = "Vestments of Jan'alai's Chosen", classId = 8 },
    { id = 5716, name = "Vestments of Jan'alai's Chosen", classId = 9 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 10 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 11 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 12 },
    { id = 5718, name = "Chainmail of Akil'zon's Chosen", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 397,
  name = "Altar of Fangs",
  release = 12,
  sets = {
    { id = 5830, name = "Venom-Cursed Bear's Guard", classId = 1 },
    { id = 5830, name = "Venom-Cursed Bear's Guard", classId = 2 },
    { id = 5829, name = "Venom-Cursed Eagle's Scales", classId = 3 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 4 },
    { id = 5827, name = "Venom-Cursed Dragonhawk's Raiment", classId = 5 },
    { id = 5830, name = "Venom-Cursed Bear's Guard", classId = 6 },
    { id = 5829, name = "Venom-Cursed Eagle's Scales", classId = 7 },
    { id = 5827, name = "Venom-Cursed Dragonhawk's Raiment", classId = 8 },
    { id = 5827, name = "Venom-Cursed Dragonhawk's Raiment", classId = 9 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 10 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 11 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 12 },
    { id = 5829, name = "Venom-Cursed Eagle's Scales", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 401,
  name = "Midnight Season 2 (War Mode)",
  release = 12,
  sets = {
    { id = 5724, name = "Venomous Warmonger's Plate Armor", classId = 1 },
    { id = 5724, name = "Venomous Warmonger's Plate Armor", classId = 2 },
    { id = 5723, name = "Venomous Warmonger's Chain Armor", classId = 3 },
    { id = 5722, name = "Venomous Warmonger's Leather Armor", classId = 4 },
    { id = 5721, name = "Venomous Warmonger's Silk Armor", classId = 5 },
    { id = 5724, name = "Venomous Warmonger's Plate Armor", classId = 6 },
    { id = 5723, name = "Venomous Warmonger's Chain Armor", classId = 7 },
    { id = 5721, name = "Venomous Warmonger's Silk Armor", classId = 8 },
    { id = 5721, name = "Venomous Warmonger's Silk Armor", classId = 9 },
    { id = 5722, name = "Venomous Warmonger's Leather Armor", classId = 10 },
    { id = 5722, name = "Venomous Warmonger's Leather Armor", classId = 11 },
    { id = 5722, name = "Venomous Warmonger's Leather Armor", classId = 12 },
    { id = 5723, name = "Venomous Warmonger's Chain Armor", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 401,
  name = "Midnight Season 2 (Gladiator)",
  release = 12,
  sets = {
    { id = 5727, name = "Venomous Gladiator's Plate Armor", classId = 1 },
    { id = 5762, name = "Venomous Gladiator's Plate Armor", classId = 2 },
    { id = 5783, name = "Venomous Gladiator's Chain Armor", classId = 3 },
    { id = 5748, name = "Venomous Gladiator's Leather Armor", classId = 4 },
    { id = 5755, name = "Venomous Gladiator's Silk Armor", classId = 5 },
    { id = 5813, name = "Venomous Gladiator's Plate Armor", classId = 6 },
    { id = 5741, name = "Venomous Gladiator's Chain Armor", classId = 7 },
    { id = 5776, name = "Venomous Gladiator's Silk Armor", classId = 8 },
    { id = 5734, name = "Venomous Gladiator's Silk Armor", classId = 9 },
    { id = 5769, name = "Venomous Gladiator's Leather Armor", classId = 10 },
    { id = 5799, name = "Venomous Gladiator's Leather Armor", classId = 11 },
    { id = 5806, name = "Venomous Gladiator's Leather Armor", classId = 12 },
    { id = 5790, name = "Venomous Gladiator's Chain Armor", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 401,
  name = "Midnight Season 2 (Elite)",
  release = 12,
  sets = {
    { id = 5733, name = "Venomous Gladiator's Plate Armor", classId = 1 },
    { id = 5768, name = "Venomous Gladiator's Plate Armor", classId = 2 },
    { id = 5789, name = "Venomous Gladiator's Chain Armor", classId = 3 },
    { id = 5754, name = "Venomous Gladiator's Leather Armor", classId = 4 },
    { id = 5761, name = "Venomous Gladiator's Silk Armor", classId = 5 },
    { id = 5819, name = "Venomous Gladiator's Plate Armor", classId = 6 },
    { id = 5747, name = "Venomous Gladiator's Chain Armor", classId = 7 },
    { id = 5782, name = "Venomous Gladiator's Silk Armor", classId = 8 },
    { id = 5740, name = "Venomous Gladiator's Silk Armor", classId = 9 },
    { id = 5775, name = "Venomous Gladiator's Leather Armor", classId = 10 },
    { id = 5805, name = "Venomous Gladiator's Leather Armor", classId = 11 },
    { id = 5812, name = "Venomous Gladiator's Leather Armor", classId = 12 },
    { id = 5796, name = "Venomous Gladiator's Chain Armor", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 401,
  name = "Midnight Season 2 (Aspirant and War Mode)",
  release = 12,
  sets = {
    { id = 5826, name = "Venomous Aspirant's Plate Armor", classId = 1 },
    { id = 5826, name = "Venomous Aspirant's Plate Armor", classId = 2 },
    { id = 5825, name = "Venomous Aspirant's Chain Armor", classId = 3 },
    { id = 5824, name = "Venomous Skirmisher's Leather Armor", classId = 4 },
    { id = 5823, name = "Venomous Skirmisher's Silk Armor", classId = 5 },
    { id = 5826, name = "Venomous Aspirant's Plate Armor", classId = 6 },
    { id = 5825, name = "Venomous Aspirant's Chain Armor", classId = 7 },
    { id = 5823, name = "Venomous Skirmisher's Silk Armor", classId = 8 },
    { id = 5823, name = "Venomous Skirmisher's Silk Armor", classId = 9 },
    { id = 5824, name = "Venomous Skirmisher's Leather Armor", classId = 10 },
    { id = 5824, name = "Venomous Skirmisher's Leather Armor", classId = 11 },
    { id = 5824, name = "Venomous Skirmisher's Leather Armor", classId = 12 },
    { id = 5825, name = "Venomous Aspirant's Chain Armor", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 403,
  name = "Preyhunter's Armor",
  release = 12,
  sets = {
    { id = 5831, name = "Preyhunter's Polished Armor", classId = 1 },
    { id = 5831, name = "Preyhunter's Polished Armor", classId = 2 },
    { id = 5832, name = "Preyhunter's Rugged Armor", classId = 3 },
    { id = 5833, name = "Preyhunter's Sleek Armor", classId = 4 },
    { id = 5834, name = "Preyhunter's Refined Armor", classId = 5 },
    { id = 5831, name = "Preyhunter's Polished Armor", classId = 6 },
    { id = 5832, name = "Preyhunter's Rugged Armor", classId = 7 },
    { id = 5834, name = "Preyhunter's Refined Armor", classId = 8 },
    { id = 5834, name = "Preyhunter's Refined Armor", classId = 9 },
    { id = 5833, name = "Preyhunter's Sleek Armor", classId = 10 },
    { id = 5833, name = "Preyhunter's Sleek Armor", classId = 11 },
    { id = 5833, name = "Preyhunter's Sleek Armor", classId = 12 },
    { id = 5832, name = "Preyhunter's Rugged Armor", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 404,
  name = "The Venomous Abyss (Raid Finder)",
  release = 12,
  sets = {
    { id = 5885, name = "Jade Warlord's Dominion", classId = 1 },
    { id = 5865, name = "Radiance of the Consecrated Flame", classId = 2 },
    { id = 5853, name = "Skulking Viper's Ambush", classId = 3 },
    { id = 5873, name = "Chosen Bloodslayer's Hexweave", classId = 4 },
    { id = 5869, name = "Cosmic Penitent's Raiment", classId = 5 },
    { id = 5837, name = "Baleful Grave-Knight's Crucible", classId = 6 },
    { id = 5877, name = "Ophidian Oracle's Prophecy", classId = 7 },
    { id = 5857, name = "Primal Leywarden's Attire", classId = 8 },
    { id = 5881, name = "Damned Necrolyte's Shattered Restraints", classId = 9 },
    { id = 5861, name = "Guile of the Monkey King", classId = 10 },
    { id = 5845, name = "Bark of the Enigmatic Dreamwatcher", classId = 11 },
    { id = 5841, name = "Abyssal Doomhound's Pursuit", classId = 12 },
    { id = 5849, name = "Echo of Calamity", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 404,
  name = "The Venomous Abyss (Normal)",
  release = 12,
  sets = {
    { id = 5886, name = "Jade Warlord's Dominion", classId = 1 },
    { id = 5866, name = "Radiance of the Consecrated Flame", classId = 2 },
    { id = 5854, name = "Skulking Viper's Ambush", classId = 3 },
    { id = 5874, name = "Chosen Bloodslayer's Hexweave", classId = 4 },
    { id = 5870, name = "Cosmic Penitent's Raiment", classId = 5 },
    { id = 5838, name = "Baleful Grave-Knight's Crucible", classId = 6 },
    { id = 5878, name = "Ophidian Oracle's Prophecy", classId = 7 },
    { id = 5858, name = "Primal Leywarden's Attire", classId = 8 },
    { id = 5882, name = "Damned Necrolyte's Shattered Restraints", classId = 9 },
    { id = 5862, name = "Guile of the Monkey King", classId = 10 },
    { id = 5846, name = "Bark of the Enigmatic Dreamwatcher", classId = 11 },
    { id = 5842, name = "Abyssal Doomhound's Pursuit", classId = 12 },
    { id = 5850, name = "Echo of Calamity", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 404,
  name = "The Venomous Abyss (Heroic)",
  release = 12,
  sets = {
    { id = 5887, name = "Jade Warlord's Dominion", classId = 1 },
    { id = 5867, name = "Radiance of the Consecrated Flame", classId = 2 },
    { id = 5855, name = "Skulking Viper's Ambush", classId = 3 },
    { id = 5875, name = "Chosen Bloodslayer's Hexweave", classId = 4 },
    { id = 5871, name = "Cosmic Penitent's Raiment", classId = 5 },
    { id = 5839, name = "Baleful Grave-Knight's Crucible", classId = 6 },
    { id = 5879, name = "Ophidian Oracle's Prophecy", classId = 7 },
    { id = 5859, name = "Primal Leywarden's Attire", classId = 8 },
    { id = 5883, name = "Damned Necrolyte's Shattered Restraints", classId = 9 },
    { id = 5863, name = "Guile of the Monkey King", classId = 10 },
    { id = 5847, name = "Bark of the Enigmatic Dreamwatcher", classId = 11 },
    { id = 5843, name = "Abyssal Doomhound's Pursuit", classId = 12 },
    { id = 5851, name = "Echo of Calamity", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 404,
  name = "The Venomous Abyss (Mythic)",
  release = 12,
  sets = {
    { id = 5888, name = "Jade Warlord's Dominion", classId = 1 },
    { id = 5868, name = "Radiance of the Consecrated Flame", classId = 2 },
    { id = 5856, name = "Skulking Viper's Ambush", classId = 3 },
    { id = 5876, name = "Chosen Bloodslayer's Hexweave", classId = 4 },
    { id = 5872, name = "Cosmic Penitent's Raiment", classId = 5 },
    { id = 5840, name = "Baleful Grave-Knight's Crucible", classId = 6 },
    { id = 5880, name = "Ophidian Oracle's Prophecy", classId = 7 },
    { id = 5860, name = "Primal Leywarden's Attire", classId = 8 },
    { id = 5884, name = "Damned Necrolyte's Shattered Restraints", classId = 9 },
    { id = 5864, name = "Guile of the Monkey King", classId = 10 },
    { id = 5848, name = "Bark of the Enigmatic Dreamwatcher", classId = 11 },
    { id = 5844, name = "Abyssal Doomhound's Pursuit", classId = 12 },
    { id = 5852, name = "Echo of Calamity", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 408,
  name = "Amani Gear",
  release = 12,
  sets = {
    { id = 5902, name = "Pledgebearer's Warplate", classId = 1 },
    { id = 5902, name = "Pledgebearer's Warplate", classId = 2 },
    { id = 5901, name = "Galerider's Battlegear", classId = 3 },
    { id = 5900, name = "Miststalker's Harness", classId = 4 },
    { id = 5898, name = "Pyrewalker's Panoply", classId = 5 },
    { id = 5902, name = "Pledgebearer's Warplate", classId = 6 },
    { id = 5901, name = "Galerider's Battlegear", classId = 7 },
    { id = 5898, name = "Pyrewalker's Panoply", classId = 8 },
    { id = 5898, name = "Pyrewalker's Panoply", classId = 9 },
    { id = 5900, name = "Miststalker's Harness", classId = 10 },
    { id = 5900, name = "Miststalker's Harness", classId = 11 },
    { id = 5900, name = "Miststalker's Harness", classId = 12 },
    { id = 5901, name = "Galerider's Battlegear", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 409,
  name = "Atal'Utek Armor",
  release = 12,
  sets = {
    { id = 5896, name = "Stonehide Plate", classId = 1 },
    { id = 5896, name = "Stonehide Plate", classId = 2 },
    { id = 5895, name = "Skytalon Chainmail", classId = 3 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 4 },
    { id = 5893, name = "Flamebeak Vestments", classId = 5 },
    { id = 5896, name = "Stonehide Plate", classId = 6 },
    { id = 5895, name = "Skytalon Chainmail", classId = 7 },
    { id = 5893, name = "Flamebeak Vestments", classId = 8 },
    { id = 5893, name = "Flamebeak Vestments", classId = 9 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 10 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 11 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 12 },
    { id = 5895, name = "Skytalon Chainmail", classId = 13 },
  },
})
