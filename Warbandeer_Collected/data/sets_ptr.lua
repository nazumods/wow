---@type Warbandeer_Collected
local ns = select(2, ...)
local tinsert = tinsert
-- Generated from wago.tools TransmogSet PTR delta (live 12.0.7.68275 vs PTR 12.1.0.68301, 2026-06-24) by tools/update-sets.ps1 -PtrDelta.
-- Sets present on the PTR but not yet on live ("upcoming"). VOLATILE — regenerate
-- on demand; not part of the weekly live refresh. release tags the newest expansion;
-- instance/difficulty are omitted (no lockouts for unreleased content).

---@class Warbandeer_Collected
---@field PtrSets table[] PTR-only set groups (same shape as ns.Sets)
---@field PtrBuild { live: string, ptr: string } the builds this delta was generated from
ns.PtrSets = {}
ns.PtrBuild = { live = "12.0.7.68275", ptr = "12.1.0.68301" }

tinsert(ns.PtrSets, {
  id = 396,
  name = "Regalia of the Loa",
  release = 12,
  sets = {
    { id = 5719, name = "Warplate of Nalorakk's Chosen", classId = 1 },
    { id = 5719, name = "Warplate of Nalorakk's Chosen", classId = 2 },
    { id = 5718, name = "Chainmail of Jan'alai's Chosen", classId = 3 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 4 },
    { id = 5716, name = "Vestments of Akil'zon's Chosen", classId = 5 },
    { id = 5719, name = "Warplate of Nalorakk's Chosen", classId = 6 },
    { id = 5718, name = "Chainmail of Jan'alai's Chosen", classId = 7 },
    { id = 5716, name = "Vestments of Akil'zon's Chosen", classId = 8 },
    { id = 5716, name = "Vestments of Akil'zon's Chosen", classId = 9 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 10 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 11 },
    { id = 5717, name = "Battlegear of Halazzi's Chosen", classId = 12 },
    { id = 5718, name = "Chainmail of Jan'alai's Chosen", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 397,
  name = "Altar of Fangs",
  release = 12,
  sets = {
    { id = 5830, name = "Venom-Cursed Bear's Guard", classId = 1 },
    { id = 5830, name = "Venom-Cursed Bear's Guard", classId = 2 },
    { id = 5829, name = "Venom-Cursed Dragonhawk's Scales", classId = 3 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 4 },
    { id = 5827, name = "Venom-Cursed Eagle's Raiment", classId = 5 },
    { id = 5830, name = "Venom-Cursed Bear's Guard", classId = 6 },
    { id = 5829, name = "Venom-Cursed Dragonhawk's Scales", classId = 7 },
    { id = 5827, name = "Venom-Cursed Eagle's Raiment", classId = 8 },
    { id = 5827, name = "Venom-Cursed Eagle's Raiment", classId = 9 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 10 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 11 },
    { id = 5828, name = "Venom-Cursed Lynx's Garb", classId = 12 },
    { id = 5829, name = "Venom-Cursed Dragonhawk's Scales", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 401,
  name = "Midnight Season 2",
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
  name = "The Venomous Abyss",
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
  id = 408,
  name = "Amani Gear",
  release = 12,
  sets = {
    { id = 5902, name = "Pledgebearer's Warplate", classId = 1 },
    { id = 5902, name = "Pledgebearer's Warplate", classId = 2 },
    { id = 5901, name = "Pyrewalker's Battlegear", classId = 3 },
    { id = 5900, name = "Miststalker's Harness", classId = 4 },
    { id = 5898, name = "Galerider's Panoply", classId = 5 },
    { id = 5902, name = "Pledgebearer's Warplate", classId = 6 },
    { id = 5901, name = "Pyrewalker's Battlegear", classId = 7 },
    { id = 5898, name = "Galerider's Panoply", classId = 8 },
    { id = 5898, name = "Galerider's Panoply", classId = 9 },
    { id = 5900, name = "Miststalker's Harness", classId = 10 },
    { id = 5900, name = "Miststalker's Harness", classId = 11 },
    { id = 5900, name = "Miststalker's Harness", classId = 12 },
    { id = 5901, name = "Pyrewalker's Battlegear", classId = 13 },
  },
})

tinsert(ns.PtrSets, {
  id = 409,
  name = "Atal'Utek Armor",
  release = 12,
  sets = {
    { id = 5896, name = "Stonehide Plate", classId = 1 },
    { id = 5896, name = "Stonehide Plate", classId = 2 },
    { id = 5895, name = "Flamebeak Chainmail", classId = 3 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 4 },
    { id = 5893, name = "Skytalon Vestments", classId = 5 },
    { id = 5896, name = "Stonehide Plate", classId = 6 },
    { id = 5895, name = "Flamebeak Chainmail", classId = 7 },
    { id = 5893, name = "Skytalon Vestments", classId = 8 },
    { id = 5893, name = "Skytalon Vestments", classId = 9 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 10 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 11 },
    { id = 5894, name = "Shadowclaw Leathers", classId = 12 },
    { id = 5895, name = "Flamebeak Chainmail", classId = 13 },
  },
})
