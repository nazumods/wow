local _, ns = ...
-- luacheck: globals tinsert C_TransmogSets
local tinsert = tinsert

ns.Sets = {}

-- https://warcraft.wiki.gg/wiki/ClassId

ns.Releases = {
  "Vanilla",
  "The Burning Crusade",
  "Wrath of the Lich King",
  "Cataclysm",
  "Mists of Pandaria",
  "Warlords of Draenor",
  "Legion",
  "Battle for Azeroth",
  "Shadowlands",
  "Dragonflight",
  "The War Within",
}

-- find group id: https://wago.tools/db2/TransmogSetGroup?filter%5BName_lang%5D=Black&page=1&sort%5BName_lang%5D=asc
-- find group sets: https://wago.tools/db2/TransmogSet?filter%5BTransmogSetGroupID%5D=exact%3A43&page=1&sort%5BClassMask%5D=asc

-- https://warcraft.wiki.gg/wiki/TransmogSetID
-- sets.id is base set id

-- Vanilla
tinsert(ns.Sets, {
  id = 44,
  name = "Molten Core",
  release = 1,
  instance = 409,
  difficulty = 9,
  minLevel = 70,
  sets = {
    { id = 853, name = "Battlegear of Might", classId = 1 },
    { id = 902, name = "Lawbringer Armor", classId = 2 },
    { id = 917, name = "Giantstalker Armor", classId = 3 },
    { id = 894, name = "Nightslayer Armor", classId = 4 },
    { id = 357, name = "Vestments of Prophecy", classId = 5 },
    {},
    { id = 876, name = "The Earthfury", classId = 7 },
    { id = 910, name = "Arcanist Regalia", classId = 8 },
    { id = 868, name = "Felheart Raiment", classId = 9 },
    {},
    { id = 928, name = "Cenarion Raiment", classId = 11 },
  },
})

tinsert(ns.Sets, {
  id = 43,
  name = "Blackwing Lair",
  release = 1,
  minLevel = 70,
  sets = {
    { id = 852, name = "Battlegear of Wrath", classId = 1 },
    { id = 901, name = "Judgement Armor", classId = 2 },
    { id = 916, name = "Dragonstalker Armor", classId = 3 },
    { id = 893, name = "Bloodfang Armor", classId = 4 },
    { id = 356, name = "Vestments of Transcendence", classId = 5 },
    {},
    { id = 875, name = "The Ten Storms", classId = 7 },
    { id = 909, name = "Netherwind Regalia", classId = 8 },
    { id = 867, name = "Nemesis Raiment", classId = 9 },
    {},
    { id = 927, name = "Stormrage Raiment", classId = 11 },
  },
})

tinsert(ns.Sets, {
  id = 51,
  name = "Temple of Ahn'Qiraj",
  release = 1,
  minLevel = 70,
  sets = {
    { id = 851, name = "Conqueror's Battlegear", classId = 1 },
    { id = 900, name = "Avenger's Battlegear", classId = 2 },
    { id = 915, name = "Striker's Garb", classId = 3 },
    { id = 892, name = "Deathdealer's Embrace", },
    { id = 358, name = "Garments of the Oracle", },
    {},
    { id = 874, name = "Stormcaller's Garb", },
    { id = 908, name = "Enigma Vestments", },
    { id = 866, name = "Doomcaller's Attire", },
    {},
    { id = 926, name = "Genesis Raiment", },
  },
})

-- Burning Crusade
tinsert(ns.Sets, {
  id = 41,
  name = "Gruul's Lair",
  release = 2,
  minLevel = 70,
  sets = {
    { id = 849, name = "Warbringer Armor", },
    { id = 906, name = "Justicar Armor", },
    { id = 913, name = "Demon Stalker Armor", },
    { id = 890, name = "Netherblade", },
    { id = 354, name = "Incarnate Regalia", },
    {},
    { id = 872, name = "Cyclone Regalia", },
    { id = 898, name = "Aldor Regalia", },
    { id = 864, name = "Voidheart Raiment", },
    {},
    { id = 922, name = "Malorne Raiment", },
  },
})

tinsert(ns.Sets, {
  id = 40,
  name = "Serpentshrine Cavern",
  release = 2,
  minLevel = 70,
  sets = {
    { id = 848, name = "Destroyer Armor" },
    { id = 897, name = "Crystalforge Armor" },
    { id = 918, name = "Rift Stalker Armor" },
    { id = 889, name = "Deathmantle" },
    { id = 353, name = "Avatar Regalia"},
    {},
    { id = 871, name = "Cataclysm Regalia" },
    { id = 905, name = "Tirisfal Regalia" },
    { id = 863, name = "Corruptor Raiment" },
    {},
    { id = 921, name = "Nordrassil Raiment" },
  },
})

tinsert(ns.Sets, {
  id = 39,
  name = "Black Temple",
  release = 2,
  minLevel = 70,
  sets = {
    { id = 847, name = "Onslaught Armor" },
    { id = 896, name = "Lightbringer Armor" },
    { id = 912, name = "Gronnstalker's Armor" },
    { id = 888, name = "Slayer's Armor" }, 
    { id = 351, name = "Absolution Regalia" },
    { },
    { id = 870, name = "Skyshatter Regalia" },
    { id = 904, name = "Tempest Regalia" },
    { id = 862, name = "Malefic Raiment" },
    { },
    { id = 920, name = "Thunderheart Raiment" },
  },
})

tinsert(ns.Sets, {
  id = 50,
  name = "Sunwell Plateau",
  release = 2,
  minLevel = 70,
  sets = {
    { id = 931, name = "Onslaught Battlegear" },
    { id = 895, name = "Lightbringer Battlegear" },
    { id = 911, name = "Gronnstalker's Battlegear" },
    { id = 887, name = "Slayer's Battlegear" },
    { id = 352, name = "Vestments of Absolution" },
    { },
    { id = 869, name = "Skyshatter Raiment" },
    { id = 903, name = "Tempest Garb" },
    { id = 932, name = "Malefic Regalia" },
    { },
    { id = 919, name = "Thunderheart Regalia" },
  },
})

-- Wrath of the Lich King
tinsert(ns.Sets, {
  id = 38,
  name = "Naxxramas (10 Normal)",
  release = 3,
  minLevel = 70,
  sets = {
    { id = 661, name = "Heroes' Dreadnaught Battlegear" },
    { id = 710, name = "Heroes' Redemption Plate" },
    { id = 742, name = "Heroes' Crypstalker Battlegear" },
    { id = 694, name = "Heroes' Bonescythe Battlegear" },
    { id = 361, name = "Heroes' Regalia of Faith" },
    { id = 845, name = "Heroes' Scourgeborne Plate" },
    { id = 644, name = "Heroes' Earthshatter Regalia" },
    { id = 726, name = "Heroes' Frostfire Garb" },
    { id = 678, name = "Heroes' Plagueheart Garb" },
    {},
    { id = 829, name = "Heroes' Dreamwalker Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 38,
  name = "Naxxramas (25 Normal)",
  release = 3,
  minLevel = 70,
  sets = {
    { id = 662, name = "Valourous Dreadnaught Battlegear" },
    { id = 711, name = "Valourous Redemption Plate" },
    { id = 743, name = "Valourous Crypstalker Battlegear" },
    { id = 695, name = "Valourous Bonescythe Battlegear" },
    { id = 362, name = "Valourous Regalia of Faith" },
    { id = 846, name = "Valourous Scourgeborne Plate" },
    { id = 645, name = "Valourous Earthshatter Regalia" },
    { id = 727, name = "Valourous Frostfire Garb" },
    { id = 679, name = "Valourous Plagueheart Garb" },
    {},
    { id = 830, name = "Valourous Dreamwalker Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 37,
  name = "Ulduar (10 Normal)",
  release = 3,
  minLevel = 70,
  sets = {
    { id = 659, name = "Valourous Siegebreaker Battlegear" },
    { id = 708, name = "Valourous Aegis Plate" },
    { id = 740, name = "Valourous Scourgestalker Battlegear" },
    { id = 692, name = "Valourous Terrorblade Battlegear" },
    { id = 363, name = "Valourous Sanctification Regalia" },
    { id = 843, name = "Valourous Darkruned Plate" },
    { id = 642, name = "Valourous Worldbreaker Regalia" },
    { id = 724, name = "Valourous Kirin Tor Garb" },
    { id = 676, name = "Valourous Deathbringer Garb" },
    {},
    { id = 827, name = "Valourous Nightsong Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 37,
  name = "Ulduar (25 Normal)",
  release = 3,
  instance = 603,
  difficulty = 14,
  minLevel = 70,
  sets = {
    { id = 660, name = "Conqueror's Siegebreaker Battlegear" },
    { id = 709, name = "Conqueror's Aegis Plate" },
    { id = 741, name = "Conqueror's Scourgestalker Battlegear" },
    { id = 693, name = "Conqueror's Terrorblade Battlegear" },
    { id = 364, name = "Conqueror's Sanctification Regalia" },
    { id = 844, name = "Conqueror's Darkruned Plate" },
    { id = 643, name = "Conqueror's Worldbreaker Regalia" },
    { id = 725, name = "Conqueror's Kirin Tor Garb" },
    { id = 677, name = "Conqueror's Deathbringer Garb" },
    {},
    { id = 828, name = "Conqueror's Nightsong Battlegear" },
  },
})

-- trial of the crusader 36 - had horde/allance sets

tinsert(ns.Sets, {
  id = 35,
  name = "Icecrown Citadel (10 Normal)",
  release = 3,
  minLevel = 70,
  sets = {
    { id = 655, name = "Ymirjar Lord's Battlegear" },
    { id = 703, name = "Lightsworn Plate" },
    { id = 735, name = "Ahn'Kahar Blood Hunter's Battlegear" },
    { id = 687, name = "Shadowblade's Battlegear" },
    { id = 346, name = "Crimson Acolyte's Regalia" },
    { id = 838, name = "Scourgelord's Plate" },
    { id = 637, name = "Frost Witch's Regalia" },
    { id = 719, name = "Bloodmage's Regalia" },
    { id = 671, name = "Dark Coven's Regalia" },
    {},
    { id = 822, name = "Lasherweave Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 35,
  name = "Icecrown Citadel (25 Normal)",
  release = 3,
  minLevel = 70,
  sets = {
    { id = 656, name = "Sanctified Ymirjar Lord's Battlegear" },
    { id = 704, name = "Sanctified Lightsworn Plate" },
    { id = 736, name = "Sanctified Ahn'Kahar Blood Hunter's Battlegear" },
    { id = 688, name = "Sanctified Shadowblade's Battlegear" },
    { id = 347, name = "Sanctified Crimson Acolyte's Regalia" },
    { id = 839, name = "Sanctified Scourgelord's Plate" },
    { id = 638, name = "Frost Witch's Regalia" },
    { id = 720, name = "Sanctified Bloodmage's Regalia" },
    { id = 672, name = "Sanctified Dark Coven's Regalia" },
    {},
    { id = 823, name = "Sanctified Lasherweave Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 35,
  name = "Icecrown Citadel (25 Heroic)",
  release = 3,
  instance = 631,
  difficulty = 6,
  minLevel = 70,
  sets = {
    { id = 298, name = "Sanctified Ymirjar Lord's Battlegear" },
    { id = 705, name = "Sanctified Lightsworn Plate" },
    { id = 737, name = "Sanctified Ahn'Kahar Blood Hunter's Battlegear" },
    { id = 689, name = "Sanctified Shadowblade's Battlegear" },
    { id = 348, name = "Sanctified Crimson Acolyte's Regalia" },
    { id = 840, name = "Sanctified Scourgelord's Plate" },
    { id = 639, name = "Frost Witch's Regalia" },
    { id = 721, name = "Sanctified Bloodmage's Regalia" },
    { id = 673, name = "Sanctified Dark Coven's Regalia" },
    {},
    { id = 824, name = "Sanctified Lasherweave Battlegear" },
  },
})

-- Cataclysm
tinsert(ns.Sets, {
  id = 34,
  name = "Bastion of Twilight (Normal)",
  release = 4,
  minLevel = 70,
  sets = {
    { id = 653, name = "Earthen Battleplate" }, -- class 1
    { id = 701, name = "Reinforced Sapphirium Battleplate" }, --class 2
    { id = 733, name = "Lightning-Charged Battlegear" }, --class4
    { id = 685, name = "Wind Dancer's Regalia" }, --class 8
    { id = 344, name = "Mercurial Regalia" }, --class 16
    { id = 836, name = "Magma Plated Battlearmor" }, --class 32
    { id = 635, name = "Regalia of the Raging Elements" }, --class 64
    { id = 717, name = "Firelord's Vestments" }, --class 128
    { id = 669, name = "Shadowflame Regalia" }, --class 256
    {},
    { id = 820, name = "Stormrider's Vestments" }, --class 1024
  },
})

tinsert(ns.Sets, {
  id = 34,
  name = "Bastion of Twilight (Heroic)",
  release = 4,
  minLevel = 70,
  sets = {
    { id = 654, name = "Earthen Battleplate" }, -- class 1
    { id = 702, name = "Reinforced Sapphirium Battleplate" }, --class 2
    { id = 734, name = "Lightning-Charged Battlegear" }, --class4
    { id = 686, name = "Wind Dancer's Regalia" }, --class 8
    { id = 345, name = "Mercurial Regalia" }, --class 16
    { id = 837, name = "Magma Plated Battlearmor" }, --class 32
    { id = 636, name = "Regalia of the Raging Elements" }, --class 64
    { id = 718, name = "Firelord's Vestments" }, --class 128
    { id = 670, name = "Shadowflame Regalia" }, --class 256
    {},
    { id = 821, name = "Stormrider's Vestments" }, --class 1024
  },
})

tinsert(ns.Sets, {
  id = 33,
  name = "Firelands (Normal)",
  release = 4,
  minLevel = 70,
  sets = {
    { id = 651, name = "Molten Giant Battleplate" }, -- class 1
    { id = 699, name = "Battleplate of Immolation" }, --class 2
    { id = 732, name = "Flamewaker's Battlegear" }, --class 4
    { id = 684, name = "Vestments of the Dark Phoenix" }, --class 8
    { id = 342, name = "Regalia of the Cleansing Flame" }, --class 16
    { id = 834, name = "Elementium Deathplate Battlearmor" }, --class 32
    { id = 633, name = "Volcanic Regalia" }, --class 64
    { id = 715, name = "Firehawk Robes of Conflagration" }, --class 128
    { id = 667, name = "Balespider's Burning Vestments" }, --class 256
    {},
    { id = 818, name = "Obsidian Arborweave Vestments" }, --class 1024
  },
})

tinsert(ns.Sets, {
  id = 33,
  name = "Firelands (Heroic)",
  release = 4,
  minLevel = 70,
  sets = {
    { id = 652, name = "Molten Giant Battleplate" }, -- class 1
    { id = 700, name = "Battleplate of Immolation" }, --class 2
    { id = 733, name = "Flamewaker's Battlegear" }, --class 4
    { id = 685, name = "Vestments of the Dark Phoenix" }, --class 8
    { id = 343, name = "Regalia of the Cleansing Flame" }, --class 16
    { id = 835, name = "Elementium Deathplate Battlearmor" }, --class 32
    { id = 634, name = "Volcanic Regalia" }, --class 64
    { id = 716, name = "Firehawk Robes of Conflagration" }, --class 128
    { id = 668, name = "Balespider's Burning Vestments" }, --class 256
    {},
    { id = 819, name = "Obsidian Arborweave Vestments" }, --class 1024
  },
})

tinsert(ns.Sets, {
  id = 32,
  name = "Dragon Soul (Raid Finder)",
  release = 4,
  minLevel = 70,
  sets = {
    { id = 650, name = "Colossal Dragonplate Battlegear" },
    { id = 697, name = "Battleplate of Radiant Glory" },
    { id = 729, name = "Wyrmstalker Battlegear" },
    { id = 681, name = "Blackfang Battleweave" },
    { id = 340, name = "Regalia of Dying Light" },
    { id = 832, name = "Necrotic Boneplate Armor" },
    { id = 632, name = "Spiritwalker's Regalia" },
    { id = 713, name = "Time Lord's Regalia" },
    { id = 665, name = "Vestments of the Faceless Shroud" },
	  {},
    { id = 816, name = "Deep Earth Vestments" },
  },
})

tinsert(ns.Sets, {
  id = 32,
  name = "Dragon Soul (Normal)",
  release = 4,
  instance = 967,
  difficulty = 4,
  minLevel = 70,
  sets = {
    { id = 649, name = "Colossal Dragonplate Battlegear" },
    { id = 696, name = "Battleplate of Radiant Glory" },
    { id = 728, name = "Wyrmstalker Battlegear" },
    { id = 680, name = "Blackfang Battleweave" },
    { id = 339, name = "Regalia of Dying Light" },
    { id = 831, name = "Necrotic Boneplate Armor" },
    { id = 630, name = "Spiritwalker's Regalia" },
    { id = 712, name = "Time Lord's Regalia" },
    { id = 664, name = "Vestments of the Faceless Shroud" },
	  {},
    { id = 815, name = "Deep Earth Vestments" },
  },
})

tinsert(ns.Sets, {
  id = 32,
  name = "Dragon Soul (Heroic)",
  release = 4,
  minLevel = 70,
  sets = {
    { id = 631, name = "Colossal Dragonplate Battlegear" },
    { id = 698, name = "Battleplate of Radiant Glory" },
    { id = 730, name = "Wyrmstalker Battlegear" },
    { id = 682, name = "Blackfang Battleweave" },
    { id = 341, name = "Regalia of Dying Light" },
    { id = 833, name = "Necrotic Boneplate Armor" },
    { id = 663, name = "Spiritwalker's Regalia" },
    { id = 714, name = "Time Lord's Regalia" },
    { id = 666, name = "Vestments of the Faceless Shroud" },
	  {},
    { id = 817, name = "Deep Earth Vestments" },
  },
})

-- Mists of Pandaria
tinsert(ns.Sets, {
  id = 31,
  name = "Heart of Fear (Raid Finder)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 446, name = "Battleplate of Resounding Rings" },
    { id = 495, name = "White Tiger Battlegear" },
    { id = 546, name = "Yaungol Slayer Battlegear" },
    { id = 479, name = "Battlegear of the Thousandfold Blades" },
    { id = 337, name = "Guardian Serpent Regalia" },
    { id = 579, name = "Plate of the Lost Catacomb" },
    { id = 428, name = "Regalia of the Firebird" },
    { id = 531, name = "Regalia of the Burning Scroll" },
    { id = 462, name = "Sha Skin Regalia" },
    { id = 515, name = "Vestments of the Red Crane" },
    { id = 565, name = "Vestments of the Eternal Blossom" },
  },
})

tinsert(ns.Sets, {
  id = 31,
  name = "Heart of Fear (Normal)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 444, name = "Battleplate of Resounding Rings" },
    { id = 493, name = "White Tiger Battlegear" },
    { id = 545, name = "Yaungol Slayer Battlegear" },
    { id = 478, name = "Battlegear of the Thousandfold Blades" },
    { id = 336, name = "Guardian Serpent Regalia" },
    { id = 578, name = "Plate of the Lost Catacomb" },
    { id = 427, name = "Regalia of the Firebird" },
    { id = 529, name = "Regalia of the Burning Scroll" },
    { id = 461, name = "Sha Skin Regalia" },
    { id = 513, name = "Vestments of the Red Crane" },
    { id = 563, name = "Vestments of the Eternal Blossom" },
  },
})

tinsert(ns.Sets, {
  id = 31,
  name = "Heart of Fear (Heroic)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 445, name = "Battleplate of Resounding Rings" },
    { id = 494, name = "White Tiger Battlegear" },
    { id = 547, name = "Yaungol Slayer Battlegear" },
    { id = 477, name = "Battlegear of the Thousandfold Blades" },
    { id = 429, name = "Guardian Serpent Regalia" },
    { id = 580, name = "Plate of the Lost Catacomb" },
    { id = 338, name = "Regalia of the Firebird" },
    { id = 530, name = "Regalia of the Burning Scroll" },
    { id = 463, name = "Sha Skin Regalia" },
    { id = 514, name = "Vestments of the Red Crane" },
    { id = 564, name = "Vestments of the Eternal Blossom" },
  },
})

tinsert(ns.Sets, {
  id = 31,
  name = "Heart of Fear (Timerunning/Remix)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 3440, name = "Battleplate of Resounding Rings" },
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
  },
})

tinsert(ns.Sets, {
  id = 10,
  name = "Throne Of Thunder (Raid Finder)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 442, name = "Battleplate of the Last Mogu" }, --1641
    { id = 492, name = "Battlegear of the Lightning Emperor" },
    { id = 543, name = "Battlegear of the Saurok Stalker" },
    { id = 476, name = "Nine-Tail Battlegear" },
    { id = 335, name = "Regalia of the Exorcist" },
    { id = 576, name = "Battleplate of the All-Consuming Maw" },
    { id = 426, name = "Regalia of the Witch Doctor" },
    { id = 528, name = "Regalia of the Chromatic Hydra" },
    { id = 459, name = "Regalia of the Thousandfold Hells" },
    { id = 512, name = "Fire-Charm Vestments" },
    { id = 562, name = "Vestments of the Haunted Forest" },
  },
})

tinsert(ns.Sets, {
  id = 10,
  name = "Throne Of Thunder (Normal)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 441, name = "Battleplate of the Last Mogu" }, --13193
    { id = 490, name = "Battlegear of the Lightning Emperor" },
    { id = 542, name = "Battlegear of the Saurok Stalker" },
    { id = 474, name = "Nine-Tail Battlegear" },
    { id = 310, name = "Regalia of the Exorcist" },
    { id = 575, name = "Battleplate of the All-Consuming Maw" },
    { id = 424, name = "Regalia of the Witch Doctor" },
    { id = 526, name = "Regalia of the Chromatic Hydra" },
    { id = 458, name = "Regalia of the Thousandfold Hells" },
    { id = 510, name = "Fire-Charm Vestments" },
    { id = 560, name = "Vestments of the Haunted Forest" },
  },
})

tinsert(ns.Sets, {
  id = 10,
  name = "Throne Of Thunder (Heroic)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 443, name = "Battleplate of the Last Mogu" }, --2015
    { id = 491, name = "Battlegear of the Lightning Emperor" },
    { id = 544, name = "Battlegear of the Saurok Stalker" },
    { id = 475, name = "Nine-Tail Battlegear" },
    { id = 334, name = "Regalia of the Exorcist" },
    { id = 577, name = "Battleplate of the All-Consuming Maw" },
    { id = 425, name = "Regalia of the Witch Doctor" },
    { id = 527, name = "Regalia of the Chromatic Hydra" },
    { id = 460, name = "Regalia of the Thousandfold Hells" },
    { id = 511, name = "Fire-Charm Vestments" },
    { id = 561, name = "Vestments of the Haunted Forest" },
  },
})

tinsert(ns.Sets, {
  id = 30,
  name = "Siege Of Orgrimmar (Raid Finder)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 440, name = "Battleplate of the Prehistoric Marauder" }, --1641
    { id = 489, name = "Vestments of Winged Triumph" },
    { id = 541, name = "Battlegear of the Unblinking Vigil" },
    { id = 473, name = "Barbed Assassin Battlegear" },
    { id = 333, name = "Regalia of Ternion Glory" },
    { id = 574, name = "Battleplate of Cyclopean Dread" },
    { id = 423, name = "Regalia of Celestial Harmony" },
    { id = 525, name = "Chronomancer Regalia" },
    { id = 457, name = "Regalia of the Horned Nightmare" },
    { id = 508, name = "Vestments of the Seven Sacred Seals" },
    { id = 559, name = "Vestments of the Shattered Vale" },
  },
})

tinsert(ns.Sets, {
  id = 30,
  name = "Siege Of Orgrimmar (Normal)",
  release = 5,
  minLevel = 70,
  sets = {
    { id = 438, name = "Battleplate of the Prehistoric Marauder" }, --13193
    { id = 487, name = "Vestments of Winged Triumph" },
    { id = 539, name = "Battlegear of the Unblinking Vigil" },
    { id = 471, name = "Barbed Assassin Battlegear" },
    { id = 331, name = "Regalia of Ternion Glory" },
    { id = 572, name = "Battleplate of Cyclopean Dread" },
    { id = 421, name = "Regalia of Celestial Harmony" },
    { id = 523, name = "Chronomancer Regalia" },
    { id = 455, name = "Regalia of the Horned Nightmare" },
    { id = 506, name = "Vestments of the Seven Sacred Seals" },
    { id = 557, name = "Vestments of the Shattered Vale" },
  },
})

tinsert(ns.Sets, {
  id = 30,
  name = "Siege Of Orgrimmar (Mythic)",
  release = 5,
  minLevel = 70,
  sets = {
{ id = 439, name = "Battleplate of the Prehistoric Marauder" }, --13145
{ id = 488, name = "Vestments of Winged Triumph" },
{ id = 540, name = "Battlegear of the Unblinking Vigil" },
{ id = 472, name = "Barbed Assassin Battlegear" },
{ id = 332, name = "Regalia of Ternion Glory" },
{ id = 573, name = "Battleplate of Cyclopean Dread" },
{ id = 422, name = "Regalia of Celestial Harmony" },
{ id = 524, name = "Chronomancer Regalia" },
{ id = 456, name = "Regalia of the Horned Nightmare" },
{ id = 507, name = "Vestments of the Seven Sacred Seals" },
{ id = 558, name = "Vestments of the Shattered Vale" },
  },
})

-- Warlords of Draenor
tinsert(ns.Sets, {
  id = 29,
  name = "Blackrock Foundry (Normal)",
  release = 6,
  minLevel = 70,
  sets = {
    { id = 435, name = "Blackhand's Battlegear" },
    { id = 483, name = "Battlegear of Guiding Light" },
    { id = 536, name = "Rylakstalker's Battlegear" },
    { id = 468, name = "Poisoner's Battlegear" },
    { id = 327, name = "Soul Priest's Raiment" },
    { id = 569, name = "Ogreskull Boneplate Battlegear" },
    { id = 418, name = "Windspeaker's Regalia" },
    { id = 520, name = "Arcanoshatter Regalia" },
    { id = 452, name = "Shadow Council's Garb" },
    { id = 498, name = "Battlegear of the Somber Gaze" },
    { id = 554, name = "Living Wood Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 29,
  name = "Blackrock Foundry (Heroic)",
  release = 6,
  minLevel = 70,
  sets = {
    { id = 436, name = "Blackhand's Battlegear" },
    { id = 484, name = "Battlegear of Guiding Light" },
    { id = 537, name = "Rylakstalker's Battlegear" },
    { id = 469, name = "Poisoner's Battlegear" },
    { id = 419, name = "Soul Priest's Raiment" },
    { id = 570, name = "Ogreskull Boneplate Battlegear" },
    { id = 328, name = "Windspeaker's Regalia" },
    { id = 521, name = "Arcanoshatter Regalia" },
    { id = 454, name = "Shadow Council's Garb" },
    { id = 500, name = "Battlegear of the Somber Gaze" },
    { id = 555, name = "Living Wood Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 29,
  name = "Blackrock Foundry (Mythic)",
  release = 6,
  minLevel = 70,
  sets = {
    { id = 437, name = "Blackhand's Battlegear" },
    { id = 485, name = "Battlegear of Guiding Light" },
    { id = 538, name = "Rylakstalker's Battlegear" },
    { id = 470, name = "Poisoner's Battlegear" },
    { id = 329, name = "Soul Priest's Raiment" },
    { id = 571, name = "Ogreskull Boneplate Battlegear" },
    { id = 420, name = "Windspeaker's Regalia" },
    { id = 522, name = "Arcanoshatter Regalia" },
    { id = 453, name = "Shadow Council's Garb" },
    { id = 501, name = "Battlegear of the Somber Gaze" },
    { id = 556, name = "Living Wood Battlegear" },
  },
})

tinsert(ns.Sets, {
  id = 28,
  name = "Hellfire Citadel (Normal)",
  release = 6,
  minLevel = 70,
  sets = {
    { id = 432, name = "Battlegear of Iron Wrath" }, --class mask=1,Type=13193
    { id = 480, name = "Watch of the Ceaseless Vigil" }, --class mask=2,Type=13193
    { id = 533, name = "Battlegear of the Savage Hunt" }, --class mask=4,Type=13193
    { id = 465, name = "Felblade Armor" }, --class mask=8,Type=13193
    { id = 323, name = "Attire of Piety" }, --class mask=16,Type=13193
    { id = 566, name = "Demongaze Armor" }, --class mask=32,Type=13193
    { id = 415, name = "Embrace of the Living Mountain" }, --class mask=64,Type=13193
    { id = 517, name = "Raiment of the Arcanic Conclave" }, --class mask=128,Type=13193
    { id = 449, name = "Deathrattle Regalia" }, --class mask=256,Type=13193
    { id = 502, name = "Battlewrap of the Hurricane's Eye" }, --class mask=512,Type=13193
    { id = 551, name = "Oathclaw Wargarb" }, --class mask=1024,Type=13193
  },
})

tinsert(ns.Sets, {
  id = 28,
  name = "Hellfire Citadel (Heroic)",
  release = 6,
  minLevel = 70,
  sets = {
    { id = 433, name = "Battlegear of Iron Wrath" }, --class mask=1,Type=2015
    { id = 481, name = "Watch of the Ceaseless Vigil" }, --class mask=2,Type=2015
    { id = 534, name = "Battlegear of the Savage Hunt" }, --class mask=4,Type=2015
    { id = 466, name = "Felblade Armor" }, --class mask=8,Type=2015
    { id = 324, name = "Attire of Piety" }, --class mask=16,Type=2015
    { id = 567, name = "Demongaze Armor" }, --class mask=32,Type=2015
    { id = 416, name = "Embrace of the Living Mountain" }, --class mask=64,Type=2015
    { id = 519, name = "Raiment of the Arcanic Conclave" }, --class mask=128,Type=2015
    { id = 451, name = "Deathrattle Regalia" }, --class mask=256,Type=2015
    { id = 503, name = "Battlewrap of the Hurricane's Eye" }, --class mask=512,Type=2015
    { id = 552, name = "Oathclaw Wargarb" }, --class mask=1024,Type=2015
  },
})

tinsert(ns.Sets, {
  id = 28,
  name = "Hellfire Citadel (Mythic)",
  release = 6,
  minLevel = 70,
  sets = {
    { id = 434, name = "Battlegear of Iron Wrath" }, --class mask=1,Type=13145
    { id = 482, name = "Watch of the Ceaseless Vigil" }, --class mask=2,Type=13145
    { id = 535, name = "Battlegear of the Savage Hunt" }, --class mask=4,Type=13145
    { id = 467, name = "Felblade Armor" }, --class mask=8,Type=13145
    { id = 325, name = "Attire of Piety" }, --class mask=16,Type=13145
    { id = 568, name = "Demongaze Armor" }, --class mask=32,Type=13145
    { id = 417, name = "Embrace of the Living Mountain" }, --class mask=64,Type=13145
    { id = 518, name = "Raiment of the Arcanic Conclave" }, --class mask=128,Type=13145
    { id = 450, name = "Deathrattle Regalia" }, --class mask=256,Type=13145
    { id = 505, name = "Battlewrap of the Hurricane's Eye" }, --class mask=512,Type=13145
    { id = 553, name = "Oathclaw Wargarb" }, --class mask=1024,Type=13145
  },
})

tinsert(ns.Sets, {
  id = 54,
  name = "Hellfire Citadel (Raid Finder)",
  release = 6,
  minLevel = 70,
  sets = {
  { id = 	584	, name = "	Demonbreaker Battleplate	" },	 --	class mask=	35,Type=1641 Plate
  { id = 	584	, name = "	Demonbreaker Battleplate	" },	 --	class mask=	35,Type=1641 Plate
  { id = 	583	, name = "	Rancorbite Armor	" },	 --	class mask=	4164,Type=1641 Mail
  { id = 	582	, name = "	Ironpelt Garb	" },	 --	class mask=	3592,Type=1641 Leather
  { id = 	581	, name = "	Felfume Raiment	" },	 --	class mask=	400,Type=1641  Cloth
  { id = 	584	, name = "	Demonbreaker Battleplate	" },	 --	class mask=	35,Type=1641 Plate
  { id = 	583	, name = "	Rancorbite Armor	" },	 --	class mask=	4164,Type=1641 Mail
  { id = 	581	, name = "	Felfume Raiment	" },	 --	class mask=	400,Type=1641  Cloth
  { id = 	581	, name = "	Felfume Raiment	" },	 --	class mask=	400,Type=1641  Cloth
  { id = 	582	, name = "	Ironpelt Garb	" },	 --	class mask=	3592,Type=1641 Leather
  { id = 	582	, name = "	Ironpelt Garb	" },	 --	class mask=	3592,Type=1641 Leather
  { id = 	582	, name = "	Ironpelt Garb	" },	 --	class mask=	3592,Type=1641 Leather
  },
})

-- Legion
tinsert(ns.Sets, {
  id = 47,
  name = "Trial Of Valor (Raid Finder)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 186, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=1641,Plate
    { id = 186, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=1641,Plate
    { id = 182, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=1641,Mail
    { id = 178, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=1641,Leather
    { id = 174, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=1641,Cloth
    { id = 186, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=1641,Plate
    { id = 182, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=1641,Mail
    { id = 174, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=1641,Cloth
    { id = 174, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=1641,Cloth
    { id = 178, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=1641,Leather
    { id = 178, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=1641,Leather
    { id = 178, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=1641,Leather
  },
})

tinsert(ns.Sets, {
  id = 47,
  name = "Trial Of Valor (Normal)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 183, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=13193,Plate
    { id = 183, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=13193,Plate
    { id = 179, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=13193,Mail
    { id = 175, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13193,Leather
    { id = 171, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=13193,Cloth
    { id = 183, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=13193,Plate
    { id = 179, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=13193,Mail
    { id = 171, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=13193,Cloth
    { id = 171, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=13193,Cloth
    { id = 175, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13193,Leather
    { id = 175, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13193,Leather
    { id = 175, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13193,Leather
  },
})

tinsert(ns.Sets, {
  id = 47,
  name = "Trial Of Valor (Heroic)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 184, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=2015,Plate
    { id = 184, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=2015,Plate
    { id = 180, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=2015,Mail
    { id = 176, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=2015,Leather
    { id = 172, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=2015,Cloth
    { id = 184, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=2015,Plate
    { id = 180, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=2015,Mail
    { id = 172, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=2015,Cloth
    { id = 172, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=2015,Cloth
    { id = 176, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=2015,Leather
    { id = 176, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=2015,Leather
    { id = 176, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=2015,Leather
  },
})

tinsert(ns.Sets, {
  id = 47,
  name = "Trial Of Valor (Mythic)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 185, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=13145,Plate 1
    { id = 185, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=13145,Plate 2
    { id = 181, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=13145,Mail 3
    { id = 177, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13145,Leather 4
    { id = 173, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=13145,Cloth 5
    { id = 185, name = "Funerary Plate of the Chosen Dead" }, --class mask=35,Type=13145,Plate 6
    { id = 181, name = "Chains of the Chosen Dead" }, --class mask=4164,Type=13145,Mail 7
    { id = 173, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=13145,Cloth 8
    { id = 173, name = "Regalia of the Chosen Dead" }, --class mask=400,Type=13145,Cloth 9
    { id = 177, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13145,Leather 10
    { id = 177, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13145,Leather 11
    { id = 177, name = "Garb of the Chosen Dead" }, --class mask=3592,Type=13145,Leather 12
  },
})

tinsert(ns.Sets, {
  id = 47,
  name = "Trial Of Valor (Trading Post)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 2343, name = "Battleplate of the Honored Valarjar" }, --class mask=35,Type=13978,Plate
    { id = 2343, name = "Battleplate of the Honored Valarjar" }, --class mask=35,Type=13978,Plate
    { id = 2331, name = "Chains of the Honored Valarjar" }, --class mask=4164,Type=13978,Mail
    { id = 2334, name = "Battlewraps of the Honored Valarjar" }, --class mask=3592,Type=13978,Leather
    { id = 2321, name = "Vestment of the Honored Valarjar" }, --class mask=400,Type=13978,Cloth
    { id = 2343, name = "Battleplate of the Honored Valarjar" }, --class mask=35,Type=13978,Plate
    { id = 2331, name = "Chains of the Honored Valarjar" }, --class mask=4164,Type=13978,Mail
    { id = 2321, name = "Vestment of the Honored Valarjar" }, --class mask=400,Type=13978,Cloth
    { id = 2321, name = "Vestment of the Honored Valarjar" }, --class mask=400,Type=13978,Cloth
    { id = 2334, name = "Battlewraps of the Honored Valarjar" }, --class mask=3592,Type=13978,Leather
    { id = 2334, name = "Battlewraps of the Honored Valarjar" }, --class mask=3592,Type=13978,Leather
    { id = 2334, name = "Battlewraps of the Honored Valarjar" }, --class mask=3592,Type=13978,Leather
  },
})

tinsert(ns.Sets, {
  id = 8,
  name = "The Nighthold (Raid Finder)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 940, name = "Warplate of the Obsidian Aspect" }, --class mask=1,Type=1641,Warrior
    { id = 981, name = "Battleplate of the Highlord" }, --class mask=2,Type=1641,Paladin
    { id = 993, name = "Eagletalon Battlegear" }, --class mask=4,Type=1641,Hunter
    { id = 945, name = "Doomblade Battlegear" }, --class mask=8,Type=1641,Rogue
    { id = 322, name = "Vestments of the Purifier" }, --class mask=16,Type=1641,Priest
    { id = 1005, name = "Dreadwyrm Battleplate" }, --class mask=32,Type=1641,Death Knight
    { id = 936, name = "Regalia of Shackled Elements" }, --class mask=64,Type=1641,Shaman
    { id = 989, name = "Regalia of Everburning Knowledge" }, --class mask=128,Type=1641,Mage
    { id = 941, name = "Legacy of Azj'aqir" }, --class mask=256,Type=1641,Warlock
    { id = 985, name = "Vestments of Enveloped Dissonance" }, --class mask=512,Type=1641,Monk
    { id = 997, name = "Garb of the Astral Warden" }, --class mask=1024,Type=1641,Druid
    { id = 1001, name = "Vestment of Second Sight" }, --class mask=2048,Type=1641,Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 8,
  name = "The Nighthold (Normal)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 937, name = "Warplate of the Obsidian Aspect" }, --class mask=1,Type=13193,Warrior
    { id = 978, name = "Battleplate of the Highlord" }, --class mask=2,Type=13193,Paladin
    { id = 990, name = "Eagletalon Battlegear" }, --class mask=4,Type=13193,Hunter
    { id = 942, name = "Doomblade Battlegear" }, --class mask=8,Type=13193,Rogue
    { id = 308, name = "Vestments of the Purifier" }, --class mask=16,Type=13193,Priest
    { id = 1002, name = "Dreadwyrm Battleplate" }, --class mask=32,Type=13193,Death Knight
    { id = 933, name = "Regalia of Shackled Elements" }, --class mask=64,Type=13193,Shaman
    { id = 986, name = "Regalia of Everburning Knowledge" }, --class mask=128,Type=13193,Mage
    { id = 315, name = "Legacy of Azj'Aqir" }, --class mask=256,Type=13193,Warlock
    { id = 982, name = "Vestments of Enveloped Dissonance" }, --class mask=512,Type=13193,Monk
    { id = 994, name = "Garb of the Astral Warden" }, --class mask=1024,Type=13193,Druid
    { id = 998, name = "Vestment of Second Sight" }, --class mask=2048,Type=13193,Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 8,
  name = "The Nighthold (Heroic)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 938, name = "Warplate of the Obsidian Aspect" }, --class mask=1,Type=2015,Warrior
    { id = 979, name = "Battleplate of the Highlord" }, --class mask=2,Type=2015,Paladin
    { id = 991, name = "Eagletalon Battlegear" }, --class mask=4,Type=2015,Hunter
    { id = 943, name = "Doomblade Battlegear" }, --class mask=8,Type=2015,Rogue
    { id = 309, name = "Vestments of the Purifier" }, --class mask=16,Type=2015,Priest
    { id = 1003, name = "Dreadwyrm Battleplate" }, --class mask=32,Type=2015,Death Knight
    { id = 934, name = "Regalia of Shackled Elements" }, --class mask=64,Type=2015,Shaman
    { id = 987, name = "Regalia of Everburning Knowledge" }, --class mask=128,Type=2015,Mage
    { id = 316, name = "Legacy of Azj'Aqir" }, --class mask=256,Type=2015,Warlock
    { id = 983, name = "Vestments of Enveloped Dissonance" }, --class mask=512,Type=2015,Monk
    { id = 995, name = "Garb of the Astral Warden" }, --class mask=1024,Type=2015,Druid
    { id = 999, name = "Vestment of Second Sight" }, --class mask=2048,Type=2015,Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 8,
  name = "The Nighthold (Mythic)",
  release = 7,
  instance = 1530,
  difficulty = 16,
  minLevel = 70,
  sets = {
    { id = 939, name = "Warplate of the Obsidian Aspect" }, --class mask=1,Type=13145,Warrior
    { id = 980, name = "Battleplate of the Highlord" }, --class mask=2,Type=13145,Paladin
    { id = 992, name = "Eagletalon Battlegear" }, --class mask=4,Type=13145,Hunter
    { id = 944, name = "Doomblade Battlegear" }, --class mask=8,Type=13145,Rogue
    { id = 311, name = "Vestments of the Purifier" }, --class mask=16,Type=13145,Priest
    { id = 1004, name = "Dreadwyrm Battleplate" }, --class mask=32,Type=13145,Death Knight
    { id = 935, name = "Regalia of Shackled Elements" }, --class mask=64,Type=13145,Shaman
    { id = 988, name = "Regalia of Everburning Knowledge" }, --class mask=128,Type=13145,Mage
    { id = 321, name = "Legacy of Azj'Aqir" }, --class mask=256,Type=13145,Warlock
    { id = 984, name = "Vestments of Enveloped Dissonance" }, --class mask=512,Type=13145,Monk
    { id = 996, name = "Garb of the Astral Warden" }, --class mask=1024,Type=13145,Druid
    { id = 1000, name = "Vestment of Second Sight" }, --class mask=2048,Type=13145,Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 56,
  name = "Tomb of Sargeras (Raid Finder)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1296, name = "Titanic Onslaught Armor" },	 --	class mask=	1	,Type=	1641	,	Warrior
    { id = 1315, name = "Radiant Lightbringer Armor" },	 --	class mask=	2	,Type=	1641	,	Paladin
    { id = 1327, name = "Wildstalker Armor" },	 --	class mask=	4	,Type=	1641	,	Hunter
    { id = 1306, name = "Fanged Slayer's Armor" },	 --	class mask=	8	,Type=	1641	,	Rogue
    { id = 1342, name = "Vestments of Blind Absolution" },	 --	class mask=	16	,Type=	1641	,	Priest
    { id = 1339, name = "Gravewarden Armaments" },	 --	class mask=	32	,Type=	1641	,	Death Knight
    { id = 1302, name = "Regalia of the Skybreaker" },	 --	class mask=	64	,Type=	1641	,	Shaman
    { id = 1323, name = "Regalia of the Arcane Tempest" },	 --	class mask=	128	,Type=	1641	,	Mage
    { id = 1300, name = "Diabolic Raiment" },	 --	class mask=	256	,Type=	1641	,	Warlock
    { id = 1319, name = "Xuen's Battlegear" },	 --	class mask=	512	,Type=	1641	,	Monk
    { id = 1331, name = "Stormheart Raiment" },	 --	class mask=	1024	,Type=	1641	,	Druid
    { id = 1335, name = "Demonbane Armor" },	 --	class mask=	2048	,Type=	1641	,	Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 56,
  name = "Tomb of Sargeras (Normal)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1293, name = "Titanic Onslaught Armor" },	 --	class mask=	1	,Type=	13193	,	Warrior
    { id = 1313, name = "Radiant Lightbringer Armor" },	 --	class mask=	2	,Type=	13193	,	Paladin
    { id = 1325, name = "Wildstalker Armor" },	 --	class mask=	4	,Type=	13193	,	Hunter
    { id = 1305, name = "Fanged Slayer's Armor" },	 --	class mask=	8	,Type=	13193	,	Rogue
    { id = 1309, name = "Vestments of Blind Absolution" },	 --	class mask=	16	,Type=	13193	,	Priest
    { id = 1337, name = "Gravewarden Armaments" },	 --	class mask=	32	,Type=	13193	,	Death Knight
    { id = 1301, name = "Regalia of the Skybreaker" },	 --	class mask=	64	,Type=	13193	,	Shaman
    { id = 1321, name = "Regalia of the Arcane Tempest" },	 --	class mask=	128	,Type=	13193	,	Mage
    { id = 1297, name = "Diabolic Raiment" },	 --	class mask=	256	,Type=	13193	,	Warlock
    { id = 1317, name = "Xuen's Battlegear" },	 --	class mask=	512	,Type=	13193	,	Monk
    { id = 1329, name = "Stormheart Raiment" },	 --	class mask=	1024	,Type=	13193	,	Druid
    { id = 1333, name = "Demonbane Armor" },	 --	class mask=	2048	,Type=	13193	,	Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 56,
  name = "Tomb of Sargeras (Heroic)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1294, name = "Titanic Onslaught Armor" },	 --	class mask=	1	,Type=	2015	,	Warrior
    { id = 1316, name = "Radiant Lightbringer Armor" },	 --	class mask=	2	,Type=	2015	,	Paladin
    { id = 1328, name = "Wildstalker Armor" },	 --	class mask=	4	,Type=	2015	,	Hunter
    { id = 1307, name = "Fanged Slayer's Armor" },	 --	class mask=	8	,Type=	2015	,	Rogue
    { id = 1312, name = "Vestments of Blind Absolution" },	 --	class mask=	16	,Type=	2015	,	Priest
    { id = 1340, name = "Gravewarden Armaments" },	 --	class mask=	32	,Type=	2015	,	Death Knight
    { id = 1303, name = "Regalia of the Skybreaker" },	 --	class mask=	64	,Type=	2015	,	Shaman
    { id = 1324, name = "Regalia of the Arcane Tempest" },	 --	class mask=	128	,Type=	2015	,	Mage
    { id = 1298, name = "Diabolic Raiment" },	 --	class mask=	256	,Type=	2015	,	Warlock
    { id = 1320, name = "Xuen's Battlegear" },	 --	class mask=	512	,Type=	2015	,	Monk
    { id = 1332, name = "Stormheart Raiment" },	 --	class mask=	1024	,Type=	2015	,	Druid
    { id = 1336, name = "Demonbane Armor" },	 --	class mask=	2048	,Type=	2015	,	Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 56,
  name = "Tomb of Sargeras (Mythic)",
  release = 7,
  instance = 1676,
  difficulty = 16,
  minLevel = 70,
  sets = {
    { id = 1295, name = "Titanic Onslaught Armor" },	 --	class mask=	1	,Type=	13145	,	Warrior
    { id = 1314, name = "Radiant Lightbringer Armor" },	 --	class mask=	2	,Type=	13145	,	Paladin
    { id = 1326, name = "Wildstalker Armor" },	 --	class mask=	4	,Type=	13145	,	Hunter
    { id = 1308, name = "Fanged Slayer's Armor" },	 --	class mask=	8	,Type=	13145	,	Rogue
    { id = 1310, name = "Vestments of Blind Absolution" },	 --	class mask=	16	,Type=	13145	,	Priest
    { id = 1338, name = "Gravewarden Armaments" },	 --	class mask=	32	,Type=	13145	,	Death Knight
    { id = 1304, name = "Regalia of the Skybreaker" },	 --	class mask=	64	,Type=	13145	,	Shaman
    { id = 1322, name = "Regalia of the Arcane Tempest" },	 --	class mask=	128	,Type=	13145	,	Mage
    { id = 1299, name = "Diabolic Raiment" },	 --	class mask=	256	,Type=	13145	,	Warlock
    { id = 1318, name = "Xuen's Battlegear" },	 --	class mask=	512	,Type=	13145	,	Monk
    { id = 1330, name = "Stormheart Raiment" },	 --	class mask=	1024	,Type=	13145	,	Druid
    { id = 1334, name = "Demonbane Armor" },	 --	class mask=	2048	,Type=	13145	,	Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 56,
  name = "Tomb of Sargeras (Timewarped/Legion Remix?)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 2305, name = "Titanic Onslaught Armor" },	 --	class mask=	1	,Type=	13216		Warrior
    { id = 2300, name = "Radiant Lightbringer Armor" },	 --	class mask=	2	,Type=	13216		Paladin
    { id = 2297, name = "Wildstalker Armor" },	 --	class mask=	4	,Type=	13216		Hunter
    { id = 2302, name = "Fanged Slayer's Armor" },	 --	class mask=	8	,Type=	13216		Rogue
    { id = 2301, name = "Vestments of Blind Absolution" },	 --	class mask=	16	,Type=	13216		Priest
    { id = 2294, name = "Gravewarden Armaments" },	 --	class mask=	32	,Type=	13216		Death Knight
    { id = 2303, name = "Regalia of the Skybreaker" },	 --	class mask=	64	,Type=	13216		Shaman
    { id = 2298, name = "Regalia of the Arcane Tempest" },	 --	class mask=	128	,Type=	13216		Mage
    { id = 2304, name = "Diabolic Raiment" },	 --	class mask=	256	,Type=	13216		Warlock
    { id = 2299, name = "Xuen's Battlegear" },	 --	class mask=	512	,Type=	13216		Monk
    { id = 2296, name = "Stormheart Raiment" },	 --	class mask=	1024	,Type=	13216		Druid
    { id = 2295, name = "Demonbane Armor" },	 --	class mask=	2048	,Type=	13216		Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 62,
  name = "Antorus, The Burning Throne (Raid Finder)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1519, name = "Juggernaut Battlegear" }, --class mask=1,Type=1641,Warrior
    { id = 1499, name = "Light's Vanguard Battleplate" }, --class mask=2,Type=1641,Paladin
    { id = 1487, name = "Serpentstalker Guise" }, --class mask=4,Type=1641,Hunter
    { id = 1507, name = "Regalia of the Dashing Scoundrel" }, --class mask=8,Type=1641,Rogue
    { id = 1503, name = "Gilded Seraph's Raiment" }, --class mask=16,Type=1641,Priest
    { id = 1475, name = "Dreadwake Armor" }, --class mask=32,Type=1641,Death Knight
    { id = 1511, name = "Garb of Venerated Spirits" }, --class mask=64,Type=1641,Shaman
    { id = 1491, name = "Runebound Regalia" }, --class mask=128,Type=1641,Mage
    { id = 1515, name = "Grim Inquisitor's Regalia" }, --class mask=256,Type=1641,Warlock
    { id = 1495, name = "Chi-Ji's Battlegear" }, --class mask=512,Type=1641,Monk
    { id = 1483, name = "Bearmantle Battlegear" }, --class mask=1024,Type=1641,Druid
    { id = 1479, name = "Felreaper Vestments" }, --class mask=2048,Type=1641,Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 62,
  name = "Antorus, The Burning Throne (Normal)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1516, name = "Juggernaut Battlegear" }, --class mask=1,Type=13193,Warrior
    { id = 1496, name = "Light's Vanguard Battleplate" }, --class mask=2,Type=13193,Paladin
    { id = 1484, name = "Serpentstalker Guise" }, --class mask=4,Type=13193,Hunter
    { id = 1504, name = "Regalia of the Dashing Scoundrel" }, --class mask=8,Type=13193,Rogue
    { id = 1500, name = "Gilded Seraph's Raiment" }, --class mask=16,Type=13193,Priest
    { id = 1472, name = "Dreadwake Armor" }, --class mask=32,Type=13193,Death Knight
    { id = 1508, name = "Garb of Venerated Spirits" }, --class mask=64,Type=13193,Shaman
    { id = 1488, name = "Runebound Regalia" }, --class mask=128,Type=13193,Mage
    { id = 1512, name = "Grim Inquisitor's Regalia" }, --class mask=256,Type=13193,Warlock
    { id = 1492, name = "Chi-Ji's Battlegear" }, --class mask=512,Type=13193,Monk
    { id = 1480, name = "Bearmantle Battlegear" }, --class mask=1024,Type=13193,Druid
    { id = 1476, name = "Felreaper Vestments" }, --class mask=2048,Type=13193,Demon Hunter
   },
})

tinsert(ns.Sets, {
  id = 62,
  name = "Antorus, The Burning Throne (Heroic)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1517, name = "Juggernaut Battlegear" }, --class mask=1,Type=2015,Warrior
    { id = 1497, name = "Light's Vanguard Battleplate" }, --class mask=2,Type=2015,Paladin
    { id = 1485, name = "Serpentstalker Guise" }, --class mask=4,Type=2015,Hunter
    { id = 1505, name = "Regalia of the Dashing Scoundrel" }, --class mask=8,Type=2015,Rogue
    { id = 1501, name = "Gilded Seraph's Raiment" }, --class mask=16,Type=2015,Priest
    { id = 1473, name = "Dreadwake Armor" }, --class mask=32,Type=2015,Death Knight
    { id = 1509, name = "Garb of Venerated Spirits" }, --class mask=64,Type=2015,Shaman
    { id = 1489, name = "Runebound Regalia" }, --class mask=128,Type=2015,Mage
    { id = 1513, name = "Grim Inquisitor's Regalia" }, --class mask=256,Type=2015,Warlock
    { id = 1493, name = "Chi-Ji's Battlegear" }, --class mask=512,Type=2015,Monk
    { id = 1481, name = "Bearmantle Battlegear" }, --class mask=1024,Type=2015,Druid
    { id = 1477, name = "Felreaper Vestments" }, --class mask=2048,Type=2015,Demon Hunter
  },
})

tinsert(ns.Sets, {
  id = 62,
  name = "Antorus, The Burning Throne (Mythic)",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 1518, name = "Juggernaut Battlegear" }, --class mask=1,Type=13145,Warrior
    { id = 1498, name = "Light's Vanguard Battleplate" }, --class mask=2,Type=13145,Paladin
    { id = 1486, name = "Serpentstalker Guise" }, --class mask=4,Type=13145,Hunter
    { id = 1506, name = "Regalia of the Dashing Scoundrel" }, --class mask=8,Type=13145,Rogue
    { id = 1502, name = "Gilded Seraph's Raiment" }, --class mask=16,Type=13145,Priest
    { id = 1474, name = "Dreadwake Armor" }, --class mask=32,Type=13145,Death Knight
    { id = 1510, name = "Garb of Venerated Spirits" }, --class mask=64,Type=13145,Shaman
    { id = 1490, name = "Runebound Regalia" }, --class mask=128,Type=13145,Mage
    { id = 1514, name = "Grim Inquisitor's Regalia" }, --class mask=256,Type=13145,Warlock
    { id = 1494, name = "Chi-Ji's Battlegear" }, --class mask=512,Type=13145,Monk
    { id = 1482, name = "Bearmantle Battlegear" }, --class mask=1024,Type=13145,Druid
    { id = 1478, name = "Felreaper Vestments" }, --class mask=2048,Type=13145,Demon Hunter
  },
})

-- legion invasions 48
tinsert(ns.Sets, {
  id = 48,
  name = "Legion Invasions",
  release = 7,
  minLevel = 70,
  sets = {
    { id = 157, name = "Felforged Armor" }, --class mask=35,Type=0,Plate
    { id = 157, name = "Felforged Armor" }, --class mask=35,Type=0,Plate
    { id = 158, name = "Fel-Chain Armor" }, --class mask=4164,Type=0,Mail
    { id = 159, name = "Felshroud Armor" }, --class mask=3592,Type=0,Leather
    { id = 160, name = "Fel-Infused Armor" }, --class mask=400,Type=0,Cloth
    { id = 157, name = "Felforged Armor" }, --class mask=35,Type=0,Plate
    { id = 158, name = "Fel-Chain Armor" }, --class mask=4164,Type=0,Mail
    { id = 160, name = "Fel-Infused Armor" }, --class mask=400,Type=0,Cloth
    { id = 160, name = "Fel-Infused Armor" }, --class mask=400,Type=0,Cloth
    { id = 159, name = "Felshroud Armor" }, --class mask=3592,Type=0,Leather
    { id = 159, name = "Felshroud Armor" }, --class mask=3592,Type=0,Leather
    { id = 159, name = "Felshroud Armor" }, --class mask=3592,Type=0,Leather
  },
})

-- release 8
-- uldir 166
tinsert(ns.Sets, {
  id = 166,
  name = "Uldir (Raid Finder)",
  instance = 1861,
  release = 8,
  minLevel = 70,
  sets = {
    { id = 1653, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=1641,Plate
    { id = 1653, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=1641,Plate
    { id = 1649, name = "Eternal Curator's Chains" }, --class mask=4164,Type=1641,Mail
    { id = 1645, name = "Eternal Curator's Garb" }, --class mask=3592,Type=1641,Leather
    { id = 1641, name = "Eternal Curator's Vestment" }, --class mask=400,Type=1641,Cloth
    { id = 1653, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=1641,Plate
    { id = 1649, name = "Eternal Curator's Chains" }, --class mask=4164,Type=1641,Mail
    { id = 1641, name = "Eternal Curator's Vestment" }, --class mask=400,Type=1641,Cloth
    { id = 1641, name = "Eternal Curator's Vestment" }, --class mask=400,Type=1641,Cloth
    { id = 1645, name = "Eternal Curator's Garb" }, --class mask=3592,Type=1641,Leather
    { id = 1645, name = "Eternal Curator's Garb" }, --class mask=3592,Type=1641,Leather
    { id = 1645, name = "Eternal Curator's Garb" }, --class mask=3592,Type=1641,Leather
  },
})
tinsert(ns.Sets, {
  id = 166,
  name = "Uldir (Normal)",
  instance = 1861,
  release = 8,
  minLevel = 70,
  sets = {
    { id = 1650, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=13193,Plate
    { id = 1650, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=13193,Plate
    { id = 1646, name = "Eternal Curator's Chains" }, --class mask=4164,Type=13193,Mail
    { id = 1642, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13193,Leather
    { id = 1638, name = "Eternal Curator's Vestment" }, --class mask=400,Type=13193,Cloth
    { id = 1650, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=13193,Plate
    { id = 1646, name = "Eternal Curator's Chains" }, --class mask=4164,Type=13193,Mail
    { id = 1638, name = "Eternal Curator's Vestment" }, --class mask=400,Type=13193,Cloth
    { id = 1638, name = "Eternal Curator's Vestment" }, --class mask=400,Type=13193,Cloth
    { id = 1642, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13193,Leather
    { id = 1642, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13193,Leather
    { id = 1642, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13193,Leather
  },
})
tinsert(ns.Sets, {
  id = 166,
  name = "Uldir (Heroic)",
  instance = 1861,
  release = 8,
  minLevel = 70,
  sets = {
    { id = 1651, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=2015,Plate
    { id = 1651, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=2015,Plate
    { id = 1647, name = "Eternal Curator's Chains" }, --class mask=4164,Type=2015,Mail
    { id = 1643, name = "Eternal Curator's Garb" }, --class mask=3592,Type=2015,Leather
    { id = 1639, name = "Eternal Curator's Vestment" }, --class mask=400,Type=2015,Cloth
    { id = 1651, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=2015,Plate
    { id = 1647, name = "Eternal Curator's Chains" }, --class mask=4164,Type=2015,Mail
    { id = 1639, name = "Eternal Curator's Vestment" }, --class mask=400,Type=2015,Cloth
    { id = 1639, name = "Eternal Curator's Vestment" }, --class mask=400,Type=2015,Cloth
    { id = 1643, name = "Eternal Curator's Garb" }, --class mask=3592,Type=2015,Leather
    { id = 1643, name = "Eternal Curator's Garb" }, --class mask=3592,Type=2015,Leather
    { id = 1643, name = "Eternal Curator's Garb" }, --class mask=3592,Type=2015,Leather
  },
})
tinsert(ns.Sets, {
  id = 166,
  name = "Uldir (Mythic)",
  instance = 1861,
  release = 8,
  minLevel = 70,
  sets = {
    { id = 1652, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=13145,Plate
    { id = 1652, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=13145,Plate
    { id = 1648, name = "Eternal Curator's Chains" }, --class mask=4164,Type=13145,Mail
    { id = 1644, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13145,Leather
    { id = 1640, name = "Eternal Curator's Vestment" }, --class mask=400,Type=13145,Cloth
    { id = 1652, name = "Eternal Curator's Protectorate" }, --class mask=35,Type=13145,Plate
    { id = 1648, name = "Eternal Curator's Chains" }, --class mask=4164,Type=13145,Mail
    { id = 1640, name = "Eternal Curator's Vestment" }, --class mask=400,Type=13145,Cloth
    { id = 1640, name = "Eternal Curator's Vestment" }, --class mask=400,Type=13145,Cloth
    { id = 1644, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13145,Leather
    { id = 1644, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13145,Leather
    { id = 1644, name = "Eternal Curator's Garb" }, --class mask=3592,Type=13145,Leather
  },
})
-- battle of dazar'alor 169
tinsert(ns.Sets, {
  id = 169,
  name = "Battle of Dazar'alor (Raid Finder)", 
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1819,name="Gravelord's Direplate"}, -- classmask=35,Type=1641,Plate
    {id = 1819,name="Gravelord's Direplate"}, -- classmask=35,Type=1641,Plate
    {id = 1815,name="Death-Devourer Vestments"}, -- classmask=4164,Type=1641,Mail
    {id = 1811,name="Boneblade Battlegear"}, -- classmask=3592,Type=1641,Leather
    {id = 1807,name="Soul Reaper's Raiment"}, -- classmask=400,Type=1641,Cloth
    {id = 1819,name="Gravelord's Direplate"}, -- classmask=35,Type=1641,Plate
    {id = 1815,name="Death-Devourer Vestments"}, -- classmask=4164,Type=1641,Mail
    {id = 1807,name="Soul Reaper's Raiment"}, -- classmask=400,Type=1641,Cloth
    {id = 1807,name="Soul Reaper's Raiment"}, -- classmask=400,Type=1641,Cloth
    {id = 1811,name="Boneblade Battlegear"}, -- classmask=3592,Type=1641,Leather
    {id = 1811,name="Boneblade Battlegear"}, -- classmask=3592,Type=1641,Leather
    {id = 1811,name="Boneblade Battlegear"}, -- classmask=3592,Type=1641,Leather
  },
})
tinsert(ns.Sets, {
  id = 169,
  name = "Battle of Dazar'alor (Normal)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1818,name="Gravelord's Direplate"}, -- classmask=35,Type=13193,Plate
    {id = 1818,name="Gravelord's Direplate"}, -- classmask=35,Type=13193,Plate
    {id = 1814,name="Death-Devourer Vestments"}, -- classmask=4164,Type=13193,Mail
    {id = 1810,name="Boneblade Battlegear"}, -- classmask=3592,Type=13193,Leather
    {id = 1806,name="Soul Reaper's Raiment"}, -- classmask=400,Type=13193,Cloth
    {id = 1818,name="Gravelord's Direplate"}, -- classmask=35,Type=13193,Plate
    {id = 1814,name="Death-Devourer Vestments"}, -- classmask=4164,Type=13193,Mail
    {id = 1806,name="Soul Reaper's Raiment"}, -- classmask=400,Type=13193,Cloth
    {id = 1806,name="Soul Reaper's Raiment"}, -- classmask=400,Type=13193,Cloth
    {id = 1810,name="Boneblade Battlegear"}, -- classmask=3592,Type=13193,Leather
    {id = 1810,name="Boneblade Battlegear"}, -- classmask=3592,Type=13193,Leather
    {id = 1810,name="Boneblade Battlegear"}, -- classmask=3592,Type=13193,Leather
  },
})
tinsert(ns.Sets, {
  id = 169,
  name = "Battle of Dazar'alor (Heroic)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1820,name="Gravelord's Direplate"}, -- classmask=35,Type=2015,Plate
    {id = 1820,name="Gravelord's Direplate"}, -- classmask=35,Type=2015,Plate
    {id = 1816,name="Death-Devourer Vestments"}, -- classmask=4164,Type=2015,Mail
    {id = 1812,name="Boneblade Battlegear"}, -- classmask=3592,Type=2015,Leather
    {id = 1808,name="Soul Reaper's Raiment"}, -- classmask=400,Type=2015,Cloth
    {id = 1820,name="Gravelord's Direplate"}, -- classmask=35,Type=2015,Plate
    {id = 1816,name="Death-Devourer Vestments"}, -- classmask=4164,Type=2015,Mail
    {id = 1808,name="Soul Reaper's Raiment"}, -- classmask=400,Type=2015,Cloth
    {id = 1808,name="Soul Reaper's Raiment"}, -- classmask=400,Type=2015,Cloth
    {id = 1812,name="Boneblade Battlegear"}, -- classmask=3592,Type=2015,Leather
    {id = 1812,name="Boneblade Battlegear"}, -- classmask=3592,Type=2015,Leather
    {id = 1812,name="Boneblade Battlegear"}, -- classmask=3592,Type=2015,Leather
  },
})
tinsert(ns.Sets, {
  id = 169,
  name = "Battle of Dazar'alor (Mythic)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1821,name="Gravelord's Direplate"}, -- classmask=35,Type=13145,Plate
    {id = 1821,name="Gravelord's Direplate"}, -- classmask=35,Type=13145,Plate
    {id = 1817,name="Death-Devourer Vestments"}, -- classmask=4164,Type=13145,Mail
    {id = 1813,name="Boneblade Battlegear"}, -- classmask=3592,Type=13145,Leather
    {id = 1809,name="Soul Reaper's Raiment"}, -- classmask=400,Type=13145,Cloth
    {id = 1821,name="Gravelord's Direplate"}, -- classmask=35,Type=13145,Plate
    {id = 1817,name="Death-Devourer Vestments"}, -- classmask=4164,Type=13145,Mail
    {id = 1809,name="Soul Reaper's Raiment"}, -- classmask=400,Type=13145,Cloth
    {id = 1809,name="Soul Reaper's Raiment"}, -- classmask=400,Type=13145,Cloth
    {id = 1813,name="Boneblade Battlegear"}, -- classmask=3592,Type=13145,Leather
    {id = 1813,name="Boneblade Battlegear"}, -- classmask=3592,Type=13145,Leather
    {id = 1813,name="Boneblade Battlegear"}, -- classmask=3592,Type=13145,Leather
  },
})
-- the eternal palace 172
tinsert(ns.Sets, {
  id = 172,
  name = "The Eternal Palace (Raid Finder)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1842,name="Naga Lord's Warplate"}, -- classmask=35,Type=1641,Plate
    {id = 1842,name="Naga Lord's Warplate"}, -- classmask=35,Type=1641,Plate
    {id = 1843,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=1641,Mail
    {id = 1844,name="Razorfin Regalia"}, -- classmask=3592,Type=1641,Leather
    {id = 1845,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=1641,Cloth
    {id = 1842,name="Naga Lord's Warplate"}, -- classmask=35,Type=1641,Plate
    {id = 1843,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=1641,Mail
    {id = 1845,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=1641,Cloth
    {id = 1845,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=1641,Cloth
    {id = 1844,name="Razorfin Regalia"}, -- classmask=3592,Type=1641,Leather
    {id = 1844,name="Razorfin Regalia"}, -- classmask=3592,Type=1641,Leather
    {id = 1844,name="Razorfin Regalia"}, -- classmask=3592,Type=1641,Leather
  },
})
tinsert(ns.Sets, {
  id = 172,
  name = "The Eternal Palace (Normal)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1830,name="Naga Lord's Warplate"}, -- classmask=35,Type=13193,Plate
    {id = 1830,name="Naga Lord's Warplate"}, -- classmask=35,Type=13193,Plate
    {id = 1831,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=13193,Mail
    {id = 1832,name="Razorfin Regalia"}, -- classmask=3592,Type=13193,Leather
    {id = 1833,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=13193,Cloth
    {id = 1830,name="Naga Lord's Warplate"}, -- classmask=35,Type=13193,Plate
    {id = 1831,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=13193,Mail
    {id = 1833,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=13193,Cloth
    {id = 1833,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=13193,Cloth
    {id = 1832,name="Razorfin Regalia"}, -- classmask=3592,Type=13193,Leather
    {id = 1832,name="Razorfin Regalia"}, -- classmask=3592,Type=13193,Leather
    {id = 1832,name="Razorfin Regalia"}, -- classmask=3592,Type=13193,Leather
  },
})
tinsert(ns.Sets, {
  id = 172,
  name = "The Eternal Palace (Heroic)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1834,name="Naga Lord's Warplate"}, -- classmask=35,Type=2015,Plate
    {id = 1834,name="Naga Lord's Warplate"}, -- classmask=35,Type=2015,Plate
    {id = 1835,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=2015,Mail
    {id = 1836,name="Razorfin Regalia"}, -- classmask=3592,Type=2015,Leather
    {id = 1837,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=2015,Cloth
    {id = 1834,name="Naga Lord's Warplate"}, -- classmask=35,Type=2015,Plate
    {id = 1835,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=2015,Mail
    {id = 1837,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=2015,Cloth
    {id = 1837,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=2015,Cloth
    {id = 1836,name="Razorfin Regalia"}, -- classmask=3592,Type=2015,Leather
    {id = 1836,name="Razorfin Regalia"}, -- classmask=3592,Type=2015,Leather
    {id = 1836,name="Razorfin Regalia"}, -- classmask=3592,Type=2015,Leather
  },
})
tinsert(ns.Sets, {
  id = 172,
  name = "The Eternal Palace (Mythic)", 
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1838,name="Naga Lord's Warplate"}, -- classmask=35,Type=13145,Plate
    {id = 1838,name="Naga Lord's Warplate"}, -- classmask=35,Type=13145,Plate
    {id = 1839,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=13145,Mail
    {id = 1840,name="Razorfin Regalia"}, -- classmask=3592,Type=13145,Leather
    {id = 1841,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=13145,Cloth
    {id = 1838,name="Naga Lord's Warplate"}, -- classmask=35,Type=13145,Plate
    {id = 1839,name="Queen's Guard Scalemail"}, -- classmask=4164,Type=13145,Mail
    {id = 1841,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=13145,Cloth
    {id = 1841,name="Frilled Harbinger's Vestments"}, -- classmask=400,Type=13145,Cloth
    {id = 1840,name="Razorfin Regalia"}, -- classmask=3592,Type=13145,Leather
    {id = 1840,name="Razorfin Regalia"}, -- classmask=3592,Type=13145,Leather
    {id = 1840,name="Razorfin Regalia"}, -- classmask=3592,Type=13145,Leather
  },
})
-- ny'alotha, the waking city 176
tinsert(ns.Sets, {
  id = 176,
  name = "Ny'alotha, The Waking City (Raid Finder)",
  instance = 2164,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1983,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=1641,Plate
    {id = 1983,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=1641,Plate
    {id = 1987,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=1641,Mail
    {id = 1991,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=1641,Leather
    {id = 1995,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=1641,Cloth
    {id = 1983,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=1641,Plate
    {id = 1987,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=1641,Mail
    {id = 1995,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=1641,Cloth
    {id = 1995,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=1641,Cloth
    {id = 1991,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=1641,Leather
    {id = 1991,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=1641,Leather
    {id = 1991,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=1641,Leather
  },
})
tinsert(ns.Sets, {
  id = 176,
  name = "Ny'alotha, The Waking City (Normal)",
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1982,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=13193,Plate
    {id = 1982,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=13193,Plate
    {id = 1986,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=13193,Mail
    {id = 1990,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13193,Leather
    {id = 1994,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=13193,Cloth
    {id = 1982,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=13193,Plate
    {id = 1986,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=13193,Mail
    {id = 1994,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=13193,Cloth
    {id = 1994,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=13193,Cloth
    {id = 1990,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13193,Leather
    {id = 1990,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13193,Leather
    {id = 1990,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13193,Leather
  },
})
tinsert(ns.Sets, {
  id = 176,
  name = "Ny'alotha, The Waking City (Heroic)",
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1984,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=2015,Plate
    {id = 1984,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=2015,Plate
    {id = 1988,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=2015,Mail
    {id = 1992,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=2015,Leather
    {id = 1996,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=2015,Cloth
    {id = 1984,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=2015,Plate
    {id = 1988,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=2015,Mail
    {id = 1996,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=2015,Cloth
    {id = 1996,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=2015,Cloth
    {id = 1992,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=2015,Leather
    {id = 1992,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=2015,Leather
    {id = 1992,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=2015,Leather
  },
})
tinsert(ns.Sets, {
  id = 176,
  name = "Ny'alotha, The Waking City (Mythic)",
  instance = 2070,
  release = 8,
  minLevel = 70,
  sets = {
    {id = 1985,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=13145,Plate
    {id = 1985,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=13145,Plate
    {id = 1989,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=13145,Mail
    {id = 1993,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13145,Leather
    {id = 1997,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=13145,Cloth
    {id = 1985,name="Cosmic Aberration's Plate"}, -- classmask=35,Type=13145,Plate
    {id = 1989,name="Lurking Defiler's Scalemail"}, -- classmask=4164,Type=13145,Mail
    {id = 1997,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=13145,Cloth
    {id = 1997,name="Oblivion Cultist's Robes"}, -- classmask=400,Type=13145,Cloth
    {id = 1993,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13145,Leather
    {id = 1993,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13145,Leather
    {id = 1993,name="Treacherous Schemer's Leathers"}, -- classmask=3592,Type=13145,Leather
  },
})  
-- release 9
-- castle nathria 183
tinsert(ns.Sets, {
  id = 183,
  name = "Castle Nathria (Raid Finder)",
  instance = 2296,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2151,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=1641,Plate
    {id = 2151,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=1641,Plate
    {id = 2155,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=1641,Mail
    {id = 2163,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=1641,Leather
    {id = 2159,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=1641,Cloth
    {id = 2151,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=1641,Plate
    {id = 2155,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=1641,Mail
    {id = 2159,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=1641,Cloth
    {id = 2159,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=1641,Cloth
    {id = 2163,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=1641,Leather
    {id = 2163,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=1641,Leather
    {id = 2163,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=1641,Leather
  },
})
tinsert(ns.Sets, {
  id = 183,
  name = "Castle Nathria (Normal)",
  instance = 2296,
  release = 9,
  minLevel = 70,
  sets = {      
    {id = 2150,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=13193,Plate
    {id = 2150,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=13193,Plate
    {id = 2154,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=13193,Mail
    {id = 2162,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13193,Leather
    {id = 2158,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=13193,Cloth
    {id = 2150,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=13193,Plate
    {id = 2154,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=13193,Mail
    {id = 2158,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=13193,Cloth
    {id = 2158,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=13193,Cloth
    {id = 2162,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13193,Leather
    {id = 2162,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13193,Leather
    {id = 2162,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13193,Leather
  },
})  
tinsert(ns.Sets, {
  id = 183,
  name = "Castle Nathria (Heroic)",
  instance = 2296,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2152,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=2015,Plate
    {id = 2152,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=2015,Plate
    {id = 2156,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=2015,Mail
    {id = 2164,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=2015,Leather
    {id = 2160,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=2015,Cloth
    {id = 2152,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=2015,Plate
    {id = 2156,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=2015,Mail
    {id = 2160,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=2015,Cloth
    {id = 2160,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=2015,Cloth
    {id = 2164,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=2015,Leather
    {id = 2164,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=2015,Leather
    {id = 2164,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=2015,Leather
  },
})
tinsert(ns.Sets, {
  id = 183,
  name = "Castle Nathria (Mythic)",
  instance = 2296,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2153,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=13145,Plate
    {id = 2153,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=13145,Plate
    {id = 2157,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=13145,Mail
    {id = 2165,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13145,Leather
    {id = 2161,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=13145,Cloth
    {id = 2153,name="Grand Sentinel's Greatplate"}, -- classmask=35,Type=13145,Plate
    {id = 2157,name="Inexorable Castigator's Guise"}, -- classmask=4164,Type=13145,Mail
    {id = 2161,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=13145,Cloth
    {id = 2161,name="Depraved Beguiler's Visage"}, -- classmask=400,Type=13145,Cloth
    {id = 2165,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13145,Leather
    {id = 2165,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13145,Leather
    {id = 2165,name="Sin Slayer's Leathers"}, -- classmask=3592,Type=13145,Leather
  },
})  

-- sanctum of domination 190
tinsert(ns.Sets, {
  id = 190,
  name = "Sanctum of Domination (Raid Finder)",
  instance = 2450,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2251,name="Soulforged Dreadplate"}, -- classmask=35,Type=1641,Plate
    {id = 2251,name="Soulforged Dreadplate"}, -- classmask=35,Type=1641,Plate
    {id = 2255,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=1641,Mail
    {id = 2259,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=1641,Leather
    {id = 2263,name="Dark Supplicant's Garb"}, -- classmask=400,Type=1641,Cloth
    {id = 2251,name="Soulforged Dreadplate"}, -- classmask=35,Type=1641,Plate
    {id = 2255,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=1641,Mail
    {id = 2263,name="Dark Supplicant's Garb"}, -- classmask=400,Type=1641,Cloth
    {id = 2263,name="Dark Supplicant's Garb"}, -- classmask=400,Type=1641,Cloth
    {id = 2259,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=1641,Leather
    {id = 2259,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=1641,Leather
    {id = 2259,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=1641,Leather
  },
})
tinsert(ns.Sets, {
  id = 190,
  name = "Sanctum of Domination (Normal)",
  instance = 2450,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2250,name="Soulforged Dreadplate"}, -- classmask=35,Type=13193,Plate
    {id = 2250,name="Soulforged Dreadplate"}, -- classmask=35,Type=13193,Plate
    {id = 2254,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=13193,Mail
    {id = 2258,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13193,Leather
    {id = 2262,name="Dark Supplicant's Garb"}, -- classmask=400,Type=13193,Cloth
    {id = 2250,name="Soulforged Dreadplate"}, -- classmask=35,Type=13193,Plate
    {id = 2254,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=13193,Mail
    {id = 2262,name="Dark Supplicant's Garb"}, -- classmask=400,Type=13193,Cloth
    {id = 2262,name="Dark Supplicant's Garb"}, -- classmask=400,Type=13193,Cloth
    {id = 2258,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13193,Leather
    {id = 2258,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13193,Leather
    {id = 2258,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13193,Leather
  },
})
tinsert(ns.Sets, {
  id = 190,
  name = "Sanctum of Domination (Heroic)",
  instance = 2450,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2252,name="Soulforged Dreadplate"}, -- classmask=35,Type=2015,Plate
    {id = 2252,name="Soulforged Dreadplate"}, -- classmask=35,Type=2015,Plate
    {id = 2256,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=2015,Mail
    {id = 2260,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=2015,Leather
    {id = 2264,name="Dark Supplicant's Garb"}, -- classmask=400,Type=2015,Cloth
    {id = 2252,name="Soulforged Dreadplate"}, -- classmask=35,Type=2015,Plate
    {id = 2256,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=2015,Mail
    {id = 2264,name="Dark Supplicant's Garb"}, -- classmask=400,Type=2015,Cloth
    {id = 2264,name="Dark Supplicant's Garb"}, -- classmask=400,Type=2015,Cloth
    {id = 2260,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=2015,Leather
    {id = 2260,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=2015,Leather
    {id = 2260,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=2015,Leather
  },
})
tinsert(ns.Sets, {
  id = 190,
  name = "Sanctum of Domination (Mythic)",
  instance = 2450,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2253,name="Soulforged Dreadplate"}, -- classmask=35,Type=13145,Plate
    {id = 2253,name="Soulforged Dreadplate"}, -- classmask=35,Type=13145,Plate
    {id = 2257,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=13145,Mail
    {id = 2261,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13145,Leather
    {id = 2265,name="Dark Supplicant's Garb"}, -- classmask=400,Type=13145,Cloth
    {id = 2253,name="Soulforged Dreadplate"}, -- classmask=35,Type=13145,Plate
    {id = 2257,name="Tower Ascendant's Battlegear"}, -- classmask=4164,Type=13145,Mail
    {id = 2265,name="Dark Supplicant's Garb"}, -- classmask=400,Type=13145,Cloth
    {id = 2265,name="Dark Supplicant's Garb"}, -- classmask=400,Type=13145,Cloth
    {id = 2261,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13145,Leather
    {id = 2261,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13145,Leather
    {id = 2261,name="Sanctum Assailant's Trappings"}, -- classmask=3592,Type=13145,Leather
  },
})
-- sepulcher of the first ones 192
tinsert(ns.Sets, {
  id = 192,
  name = "Sepulcher of the First Ones (Raid Finder)",
  instance = 2481,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2415,name="Armaments of the Infinite Infantry"}, -- classmask=1,Type=1641,Warrior
    {id = 2385,name="Luminous Chevalier's Gallantry"}, -- classmask=2,Type=1641,Paladin
    {id = 2367,name="Godstalker's Battlegear"}, -- classmask=4,Type=1641,Hunter
    {id = 2397,name="Soulblade Shadowhide"}, -- classmask=8,Type=1641,Rogue
    {id = 2391,name="Habiliments of the Empyrean"}, -- classmask=16,Type=1641,Priest
    {id = 2349,name="The First Eidolon's Soulsteel"}, -- classmask=32,Type=1641,Death Knight
    {id = 2403,name="Theurgic Starspeaker's Regalia"}, -- classmask=64,Type=1641,Shaman
    {id = 2373,name="Erudite Occultist's Vestments"}, -- classmask=128,Type=1641,Mage
    {id = 2409,name="Shroud of the Demon Star"}, -- classmask=256,Type=1641,Warlock
    {id = 2379,name="Garb of the Grand Upwelling"}, -- classmask=512,Type=1641,Monk
    {id = 2361,name="Tapestry of the Fixed Stars"}, -- classmask=1024,Type=1641,Druid
    {id = 2355,name="Mercurial Punisher's Painweave"}, -- classmask=2048,Type=1641,Demon Hunter
  },
})
tinsert(ns.Sets, {
  id = 192,
  name = "Sepulcher of the First Ones (Normal)",
  instance = 2481,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2414,name="Armaments of the Infinite Infantry"}, -- classmask=1,Type=13193,Warrior
    {id = 2384,name="Luminous Chevalier's Gallantry"}, -- classmask=2,Type=13193,Paladin
    {id = 2366,name="Godstalker's Battlegear"}, -- classmask=4,Type=13193,Hunter
    {id = 2396,name="Soulblade Shadowhide"}, -- classmask=8,Type=13193,Rogue
    {id = 2390,name="Habiliments of the Empyrean"}, -- classmask=16,Type=13193,Priest
    {id = 2348,name="The First Eidolon's Soulsteel"}, -- classmask=32,Type=13193,Death Knight
    {id = 2402,name="Theurgic Starspeaker's Regalia"}, -- classmask=64,Type=13193,Shaman
    {id = 2372,name="Erudite Occultist's Vestments"}, -- classmask=128,Type=13193,Mage
    {id = 2408,name="Shroud of the Demon Star"}, -- classmask=256,Type=13193,Warlock
    {id = 2378,name="Garb of the Grand Upwelling"}, -- classmask=512,Type=13193,Monk
    {id = 2360,name="Tapestry of the Fixed Stars"}, -- classmask=1024,Type=13193,Druid
    {id = 2354,name="Mercurial Punisher's Painweave"}, -- classmask=2048,Type=13193,Demon Hunter
  },
})
tinsert(ns.Sets, {
  id = 192,
  name = "Sepulcher of the First Ones (Heroic)",
  instance = 2481,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2416,name="Armaments of the Infinite Infantry"}, -- classmask=1,Type=2015,Warrior
    {id = 2386,name="Luminous Chevalier's Gallantry"}, -- classmask=2,Type=2015,Paladin
    {id = 2368,name="Godstalker's Battlegear"}, -- classmask=4,Type=2015,Hunter
    {id = 2398,name="Soulblade Shadowhide"}, -- classmask=8,Type=2015,Rogue
    {id = 2392,name="Habiliments of the Empyrean"}, -- classmask=16,Type=2015,Priest
    {id = 2350,name="The First Eidolon's Soulsteel"}, -- classmask=32,Type=2015,Death Knight
    {id = 2404,name="Theurgic Starspeaker's Regalia"}, -- classmask=64,Type=2015,Shaman
    {id = 2374,name="Erudite Occultist's Vestments"}, -- classmask=128,Type=2015,Mage
    {id = 2410,name="Shroud of the Demon Star"}, -- classmask=256,Type=2015,Warlock
    {id = 2380,name="Garb of the Grand Upwelling"}, -- classmask=512,Type=2015,Monk
    {id = 2362,name="Tapestry of the Fixed Stars"}, -- classmask=1024,Type=2015,Druid
    {id = 2356,name="Mercurial Punisher's Painweave"}, -- classmask=2048,Type=2015,Demon Hunter
  },
})
tinsert(ns.Sets, {
  id = 192,
  name = "Sepulcher of the First Ones (Mythic)",
  instance = 2481,
  release = 9,
  minLevel = 70,
  sets = {
    {id = 2417,name="Armaments of the Infinite Infantry"}, -- classmask=1,Type=13145,Warrior
    {id = 2387,name="Luminous Chevalier's Gallantry"}, -- classmask=2,Type=13145,Paladin
    {id = 2369,name="Godstalker's Battlegear"}, -- classmask=4,Type=13145,Hunter
    {id = 2399,name="Soulblade Shadowhide"}, -- classmask=8,Type=13145,Rogue
    {id = 2393,name="Habiliments of the Empyrean"}, -- classmask=16,Type=13145,Priest
    {id = 2351,name="The First Eidolon's Soulsteel"}, -- classmask=32,Type=13145,Death Knight
    {id = 2405,name="Theurgic Starspeaker's Regalia"}, -- classmask=64,Type=13145,Shaman
    {id = 2375,name="Erudite Occultist's Vestments"}, -- classmask=128,Type=13145,Mage
    {id = 2411,name="Shroud of the Demon Star"}, -- classmask=256,Type=13145,Warlock
    {id = 2381,name="Garb of the Grand Upwelling"}, -- classmask=512,Type=13145,Monk
    {id = 2363,name="Tapestry of the Fixed Stars"}, -- classmask=1024,Type=13145,Druid
    {id = 2357,name="Mercurial Punisher's Painweave"}, -- classmask=2048,Type=13145,Demon Hunter
  },
})
-- release 10
-- vault of the incarnates 195
tinsert(ns.Sets, {
  id = 195,
  name = "Vault of the Incarnates (Raid Finder)",
  instance = 2522,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2652,name="Stones of the Walking Mountain"}, -- classmask=1,Type=1641,Warrior
    {id = 2637,name="Virtuous Silver Cataphract"}, -- classmask=2,Type=1641,Paladin
    {id = 2628,name="Stormwing Harrier's Camouflage"}, -- classmask=4,Type=1641,Hunter
    {id = 2643,name="Vault Delver's Toolkit"}, -- classmask=8,Type=1641,Rogue
    {id = 2640,name="Draconic Hierophant's Finery"}, -- classmask=16,Type=1641,Priest
    {id = 2616,name="Haunted Frostbrood Remains"}, -- classmask=32,Type=1641,Death Knight
    {id = 2646,name="Elements of Infused Earth"}, -- classmask=64,Type=1641,Shaman
    {id = 2631,name="Bindings of the Crystal Scholar"}, -- classmask=128,Type=1641,Mage
    {id = 2649,name="Scalesworn Cultist's Habit"}, -- classmask=256,Type=1641,Warlock
    {id = 2634,name="Wrappings of the Waking Fist"}, -- classmask=512,Type=1641,Monk
    {id = 2622,name="Lost Landcaller's Vesture"}, -- classmask=1024,Type=1641,Druid
    {id = 2619,name="Skybound Avenger's Flightwear"}, -- classmask=2048,Type=1641,Demon Hunter
    {id = 2625,name="Scales of the Awakened"}, -- classmask=4096,Type=1641,Evoker
  },
})
tinsert(ns.Sets, {
  id = 195,
  name = "Vault of the Incarnates (Normal)",
  instance = 2522,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2613,name="Stones of the Walking Mountain"}, -- classmask=1,Type=13193,Warrior
    {id = 2608,name="Virtuous Silver Cataphract"}, -- classmask=2,Type=13193,Paladin
    {id = 2605,name="Stormwing Harrier's Camouflage"}, -- classmask=4,Type=13193,Hunter
    {id = 2610,name="Vault Delver's Toolkit"}, -- classmask=8,Type=13193,Rogue
    {id = 2609,name="Draconic Hierophant's Finery"}, -- classmask=16,Type=13193,Priest
    {id = 2601,name="Haunted Frostbrood Remains"}, -- classmask=32,Type=13193,Death Knight
    {id = 2611,name="Elements of Infused Earth"}, -- classmask=64,Type=13193,Shaman
    {id = 2606,name="Bindings of the Crystal Scholar"}, -- classmask=128,Type=13193,Mage
    {id = 2612,name="Scalesworn Cultist's Habit"}, -- classmask=256,Type=13193,Warlock
    {id = 2607,name="Wrappings of the Waking Fist"}, -- classmask=512,Type=13193,Monk
    {id = 2603,name="Lost Landcaller's Vesture"}, -- classmask=1024,Type=13193,Druid
    {id = 2602,name="Skybound Avenger's Flightwear"}, -- classmask=2048,Type=13193,Demon Hunter
    {id = 2604,name="Scales of the Awakened"}, -- classmask=4096,Type=13193,Evoker
  },
})
tinsert(ns.Sets, {
  id = 195,
  name = "Vault of the Incarnates (Heroic)",
  instance = 2522,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2650,name="Stones of the Walking Mountain"}, -- classmask=1,Type=2015,Warrior
    {id = 2635,name="Virtuous Silver Cataphract"}, -- classmask=2,Type=2015,Paladin
    {id = 2626,name="Stormwing Harrier's Camouflage"}, -- classmask=4,Type=2015,Hunter
    {id = 2641,name="Vault Delver's Toolkit"}, -- classmask=8,Type=2015,Rogue
    {id = 2638,name="Draconic Hierophant's Finery"}, -- classmask=16,Type=2015,Priest
    {id = 2614,name="Haunted Frostbrood Remains"}, -- classmask=32,Type=2015,Death Knight
    {id = 2644,name="Elements of Infused Earth"}, -- classmask=64,Type=2015,Shaman
    {id = 2629,name="Bindings of the Crystal Scholar"}, -- classmask=128,Type=2015,Mage
    {id = 2647,name="Scalesworn Cultist's Habit"}, -- classmask=256,Type=2015,Warlock
    {id = 2632,name="Wrappings of the Waking Fist"}, -- classmask=512,Type=2015,Monk
    {id = 2620,name="Lost Landcaller's Vesture"}, -- classmask=1024,Type=2015,Druid
    {id = 2617,name="Skybound Avenger's Flightwear"}, -- classmask=2048,Type=2015,Demon Hunter
    {id = 2623,name="Scales of the Awakened"}, -- classmask=4096,Type=2015,Evoker
  },
})
tinsert(ns.Sets, {
  id = 195,
  name = "Vault of the Incarnates (Mythic)",
  instance = 2522,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2651,name="Stones of the Walking Mountain"}, -- classmask=1,Type=13145,Warrior
    {id = 2636,name="Virtuous Silver Cataphract"}, -- classmask=2,Type=13145,Paladin
    {id = 2627,name="Stormwing Harrier's Camouflage"}, -- classmask=4,Type=13145,Hunter
    {id = 2642,name="Vault Delver's Toolkit"}, -- classmask=8,Type=13145,Rogue
    {id = 2639,name="Draconic Hierophant's Finery"}, -- classmask=16,Type=13145,Priest
    {id = 2615,name="Haunted Frostbrood Remains"}, -- classmask=32,Type=13145,Death Knight
    {id = 2645,name="Elements of Infused Earth"}, -- classmask=64,Type=13145,Shaman
    {id = 2630,name="Bindings of the Crystal Scholar"}, -- classmask=128,Type=13145,Mage
    {id = 2648,name="Scalesworn Cultist's Habit"}, -- classmask=256,Type=13145,Warlock
    {id = 2633,name="Wrappings of the Waking Fist"}, -- classmask=512,Type=13145,Monk
    {id = 2621,name="Lost Landcaller's Vesture"}, -- classmask=1024,Type=13145,Druid
    {id = 2618,name="Skybound Avenger's Flightwear"}, -- classmask=2048,Type=13145,Demon Hunter
    {id = 2624,name="Scales of the Awakened"}, -- classmask=4096,Type=13145,Evoker
  },
})
-- aberrus, the shadowed crucible 211
tinsert(ns.Sets, {
  id = 211,
  name = "Aberrus, The Shadowed Crucible (Raid Finder)",
  instance = 2569,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2900,name="Irons of the Onyx Crucible"}, -- classmask=1,Type=1641,Warrior
    {id = 2873,name="Heartfire Sentinel's Authority"}, -- classmask=2,Type=1641,Paladin
    {id = 2891,name="Ashen Predator's Scaleform"}, -- classmask=4,Type=1641,Hunter
    {id = 2882,name="Lurking Specter's Shadeweave"}, -- classmask=8,Type=1641,Rogue
    {id = 2885,name="The Furnace Seraph's Verdict"}, -- classmask=16,Type=1641,Priest
    {id = 2897,name="Lingering Phantom's Encasement"}, -- classmask=32,Type=1641,Death Knight
    {id = 2879,name="Runes of the Cinderwolf"}, -- classmask=64,Type=1641,Shaman
    {id = 2909,name="Underlight Conjurer's Brilliance"}, -- classmask=128,Type=1641,Mage
    {id = 2876,name="Sinister Savant's Cursethreads"}, -- classmask=256,Type=1641,Warlock
    {id = 2888,name="Fangs of the Vermillion Forge"}, -- classmask=512,Type=1641,Monk
    {id = 2894,name="Strands of the Autumn Blaze"}, -- classmask=1024,Type=1641,Druid
    {id = 2903,name="Kinslayer's Burdens"}, -- classmask=2048,Type=1641,Demon Hunter
    {id = 2906,name="Legacy of Obsidian Secrets"}, -- classmask=4096,Type=1641,Evoker
  },
})
tinsert(ns.Sets, {
  id = 211,
  name = "Aberrus, The Shadowed Crucible (Normal)",
  instance = 2569,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2858,name="Irons of the Onyx Crucible"}, -- classmask=1,Type=13193,Warrior
    {id = 2859,name="Heartfire Sentinel's Authority"}, -- classmask=2,Type=13193,Paladin
    {id = 2866,name="Ashen Predator's Scaleform"}, -- classmask=4,Type=13193,Hunter
    {id = 2862,name="Lurking Specter's Shadeweave"}, -- classmask=8,Type=13193,Rogue
    {id = 2863,name="The Furnace Seraph's Verdict"}, -- classmask=16,Type=13193,Priest
    {id = 2870,name="Lingering Phantom's Encasement"}, -- classmask=32,Type=13193,Death Knight
    {id = 2861,name="Runes of the Cinderwolf"}, -- classmask=64,Type=13193,Shaman
    {id = 2865,name="Underlight Conjurer's Brilliance"}, -- classmask=128,Type=13193,Mage
    {id = 2860,name="Sinister Savant's Cursethreads"}, -- classmask=256,Type=13193,Warlock
    {id = 2864,name="Fangs of the Vermillion Forge"}, -- classmask=512,Type=13193,Monk
    {id = 2868,name="Strands of the Autumn Blaze"}, -- classmask=1024,Type=13193,Druid
    {id = 2869,name="Kinslayer's Burdens"}, -- classmask=2048,Type=13193,Demon Hunter
    {id = 2867,name="Legacy of Obsidian Secrets"}, -- classmask=4096,Type=13193,Evoker
  },
})
tinsert(ns.Sets, {
  id = 211,
  name = "Aberrus, The Shadowed Crucible (Heroic)",
  instance = 2569,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2898,name="Irons of the Onyx Crucible"}, -- classmask=1,Type=2015,Warrior
    {id = 2871,name="Heartfire Sentinel's Authority"}, -- classmask=2,Type=2015,Paladin
    {id = 2889,name="Ashen Predator's Scaleform"}, -- classmask=4,Type=2015,Hunter
    {id = 2880,name="Lurking Specter's Shadeweave"}, -- classmask=8,Type=2015,Rogue
    {id = 2883,name="The Furnace Seraph's Verdict"}, -- classmask=16,Type=2015,Priest
    {id = 2895,name="Lingering Phantom's Encasement"}, -- classmask=32,Type=2015,Death Knight
    {id = 2877,name="Runes of the Cinderwolf"}, -- classmask=64,Type=2015,Shaman
    {id = 2907,name="Underlight Conjurer's Brilliance"}, -- classmask=128,Type=2015,Mage
    {id = 2874,name="Sinister Savant's Cursethreads"}, -- classmask=256,Type=2015,Warlock
    {id = 2886,name="Fangs of the Vermillion Forge"}, -- classmask=512,Type=2015,Monk
    {id = 2892,name="Strands of the Autumn Blaze"}, -- classmask=1024,Type=2015,Druid
    {id = 2901,name="Kinslayer's Burdens"}, -- classmask=2048,Type=2015,Demon Hunter
    {id = 2904,name="Legacy of Obsidian Secrets"}, -- classmask=4096,Type=2015,Evoker
  },
})
tinsert(ns.Sets, {
  id = 211,
  name = "Aberrus, The Shadowed Crucible (Mythic)",
  instance = 2569,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 2899,name="Irons of the Onyx Crucible"}, -- classmask=1,Type=13145,Warrior
    {id = 2872,name="Heartfire Sentinel's Authority"}, -- classmask=2,Type=13145,Paladin
    {id = 2890,name="Ashen Predator's Scaleform"}, -- classmask=4,Type=13145,Hunter
    {id = 2881,name="Lurking Specter's Shadeweave"}, -- classmask=8,Type=13145,Rogue
    {id = 2884,name="The Furnace Seraph's Verdict"}, -- classmask=16,Type=13145,Priest
    {id = 2896,name="Lingering Phantom's Encasement"}, -- classmask=32,Type=13145,Death Knight
    {id = 2878,name="Runes of the Cinderwolf"}, -- classmask=64,Type=13145,Shaman
    {id = 2908,name="Underlight Conjurer's Brilliance"}, -- classmask=128,Type=13145,Mage
    {id = 2875,name="Sinister Savant's Cursethreads"}, -- classmask=256,Type=13145,Warlock
    {id = 2887,name="Fangs of the Vermillion Forge"}, -- classmask=512,Type=13145,Monk
    {id = 2893,name="Strands of the Autumn Blaze"}, -- classmask=1024,Type=13145,Druid
    {id = 2902,name="Kinslayer's Burdens"}, -- classmask=2048,Type=13145,Demon Hunter
    {id = 2905,name="Legacy of Obsidian Secrets"}, -- classmask=4096,Type=13145,Evoker
  },
})
-- amirdrassil, the dream's hope 225
tinsert(ns.Sets, {
  id = 225,
  name = "Amirdrassil, The Dream's Hope (Raid Finder)",
  instance = 2549,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 3152,name="Molten Vanguard's Mortarplate"}, -- classmask=1,Type=1641,Warrior
    {id = 3147,name="Zealous Pyreknight's Ardor"}, -- classmask=2,Type=1641,Paladin
    {id = 3138,name="Blazing Dreamstalker's Trophies"}, -- classmask=4,Type=1641,Hunter
    {id = 3167,name="Lucid Shadewalker's Silence"}, -- classmask=8,Type=1641,Rogue
    {id = 3181,name="Blessings of Lunar Communion"}, -- classmask=16,Type=1641,Priest
    {id = 3162,name="Risen Nightmare's Gravemantle"}, -- classmask=32,Type=1641,Death Knight
    {id = 3171,name="Vision of the Greatwolf Outcast"}, -- classmask=64,Type=1641,Shaman
    {id = 3185,name="Wayward Chronomancer's Clockwork"}, -- classmask=128,Type=1641,Mage
    {id = 3176,name="Devout Ashdevil's Pactweave"}, -- classmask=256,Type=1641,Warlock
    {id = 3142,name="Mystic Heron's Discipline"}, -- classmask=512,Type=1641,Monk
    {id = 3179,name="Benevolent Embersage's Guidance"}, -- classmask=1024,Type=1641,Druid
    {id = 3154,name="Screaming Torchfiend's Brutality"}, -- classmask=2048,Type=1641,Demon Hunter
    {id = 3160,name="Weyrnkeeper's Timeless Vigil"}, -- classmask=4096,Type=1641,Evoker
  },
})
tinsert(ns.Sets, {
  id = 225,
  name = "Amirdrassil, The Dream's Hope (Normal)",
  instance = 2549,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 3150,name="Molten Vanguard's Mortarplate"}, -- classmask=1,Type=13193,Warrior
    {id = 3148,name="Zealous Pyreknight's Ardor"}, -- classmask=2,Type=13193,Paladin
    {id = 3137,name="Blazing Dreamstalker's Trophies"}, -- classmask=4,Type=13193,Hunter
    {id = 3165,name="Lucid Shadewalker's Silence"}, -- classmask=8,Type=13193,Rogue
    {id = 3184,name="Blessings of Lunar Communion"}, -- classmask=16,Type=13193,Priest
    {id = 3163,name="Risen Nightmare's Gravemantle"}, -- classmask=32,Type=13193,Death Knight
    {id = 3169,name="Vision of the Greatwolf Outcast"}, -- classmask=64,Type=13193,Shaman
    {id = 3186,name="Wayward Chronomancer's Clockwork"}, -- classmask=128,Type=13193,Mage
    {id = 3175,name="Devout Ashdevil's Pactweave"}, -- classmask=256,Type=13193,Warlock
    {id = 3144,name="Mystic Heron's Discipline"}, -- classmask=512,Type=13193,Monk
    {id = 3177,name="Benevolent Embersage's Guidance"}, -- classmask=1024,Type=13193,Druid
    {id = 3153,name="Screaming Torchfiend's Brutality"}, -- classmask=2048,Type=13193,Demon Hunter
    {id = 3157,name="Weyrnkeeper's Timeless Vigil"}, -- classmask=4096,Type=13193,Evoker
  },
})
tinsert(ns.Sets, {
  id = 225,
  name = "Amirdrassil, The Dream's Hope (Heroic)",
  instance = 2549,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 3149,name="Molten Vanguard's Mortarplate"}, -- classmask=1,Type=2015,Warrior
    {id = 3146,name="Zealous Pyreknight's Ardor"}, -- classmask=2,Type=2015,Paladin
    {id = 3140,name="Blazing Dreamstalker's Trophies"}, -- classmask=4,Type=2015,Hunter
    {id = 3168,name="Lucid Shadewalker's Silence"}, -- classmask=8,Type=2015,Rogue
    {id = 3183,name="Blessings of Lunar Communion"}, -- classmask=16,Type=2015,Priest
    {id = 3161,name="Risen Nightmare's Gravemantle"}, -- classmask=32,Type=2015,Death Knight
    {id = 3170,name="Vision of the Greatwolf Outcast"}, -- classmask=64,Type=2015,Shaman
    {id = 3187,name="Wayward Chronomancer's Clockwork"}, -- classmask=128,Type=2015,Mage
    {id = 3174,name="Devout Ashdevil's Pactweave"}, -- classmask=256,Type=2015,Warlock
    {id = 3143,name="Mystic Heron's Discipline"}, -- classmask=512,Type=2015,Monk
    {id = 3178,name="Benevolent Embersage's Guidance"}, -- classmask=1024,Type=2015,Druid
    {id = 3155,name="Screaming Torchfiend's Brutality"}, -- classmask=2048,Type=2015,Demon Hunter
    {id = 3158,name="Weyrnkeeper's Timeless Vigil"}, -- classmask=4096,Type=2015,Evoker
  },
})
tinsert(ns.Sets, {
  id = 225,
  name = "Amirdrassil, The Dream's Hope (Mythic)",
  instance = 2549,
  release = 10,
  minLevel = 70,
  sets = {
    {id = 3151,name="Molten Vanguard's Mortarplate"}, -- classmask=1,Type=13145,Warrior
    {id = 3145,name="Zealous Pyreknight's Ardor"}, -- classmask=2,Type=13145,Paladin
    {id = 3139,name="Blazing Dreamstalker's Trophies"}, -- classmask=4,Type=13145,Hunter
    {id = 3166,name="Lucid Shadewalker's Silence"}, -- classmask=8,Type=13145,Rogue
    {id = 3182,name="Blessings of Lunar Communion"}, -- classmask=16,Type=13145,Priest
    {id = 3164,name="Risen Nightmare's Gravemantle"}, -- classmask=32,Type=13145,Death Knight
    {id = 3172,name="Vision of the Greatwolf Outcast"}, -- classmask=64,Type=13145,Shaman
    {id = 3188,name="Wayward Chronomancer's Clockwork"}, -- classmask=128,Type=13145,Mage
    {id = 3173,name="Devout Ashdevil's Pactweave"}, -- classmask=256,Type=13145,Warlock
    {id = 3141,name="Mystic Heron's Discipline"}, -- classmask=512,Type=13145,Monk
    {id = 3180,name="Benevolent Embersage's Guidance"}, -- classmask=1024,Type=13145,Druid
    {id = 3156,name="Screaming Torchfiend's Brutality"}, -- classmask=2048,Type=13145,Demon Hunter
    {id = 3159,name="Weyrnkeeper's Timeless Vigil"}, -- classmask=4096,Type=13145,Evoker
  },
})
-- release 11
-- nerub-ar palace 273
tinsert(ns.Sets, {
  id = 273,
  name = "Nerub-ar Palace (Raid Finder)",
  instance = 2657,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 3768,name="Warsculptor's Masterwork"}, -- classmask=1,Type=1641,Warrior
    {id = 3748,name="Entombed Seraph's Radiance"}, -- classmask=2,Type=1641,Paladin
    {id = 3736,name="Lightless Scavenger's Necessities"}, -- classmask=4,Type=1641,Hunter
    {id = 3756,name="K'areshi Phantom's Bindings"}, -- classmask=8,Type=1641,Rogue
    {id = 3752,name="Shards of Living Luster"}, -- classmask=16,Type=1641,Priest
    {id = 3720,name="Exhumed Centurion's Relics"}, -- classmask=32,Type=1641,Death Knight
    {id = 3760,name="Waves of the Forgotten Reservoir"}, -- classmask=64,Type=1641,Shaman
    {id = 3740,name="Sparks of Violet Rebirth"}, -- classmask=128,Type=1641,Mage
    {id = 3764,name="Rites of the Hexflame Coven"}, -- classmask=256,Type=1641,Warlock
    {id = 3744,name="Gatecrasher's Fortitude"}, -- classmask=512,Type=1641,Monk
    {id = 3728,name="Mane of the Greatlynx"}, -- classmask=1024,Type=1641,Druid
    {id = 3724,name="Husk of the Hypogeal Nemesis"}, -- classmask=2048,Type=1641,Demon Hunter
    {id = 3732,name="Destroyer's Scarred Wards"}, -- classmask=4096,Type=1641,Evoker
  },
})
tinsert(ns.Sets, {
  id = 273,
  name = "Nerub-ar Palace (Normal)",
  instance = 2657,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 3767,name="Warsculptor's Masterwork"}, -- classmask=1,Type=13193,Warrior
    {id = 3747,name="Entombed Seraph's Radiance"}, -- classmask=2,Type=13193,Paladin
    {id = 3735,name="Lightless Scavenger's Necessities"}, -- classmask=4,Type=13193,Hunter
    {id = 3755,name="K'areshi Phantom's Bindings"}, -- classmask=8,Type=13193,Rogue
    {id = 3751,name="Shards of Living Luster"}, -- classmask=16,Type=13193,Priest
    {id = 3711,name="Exhumed Centurion's Relics"}, -- classmask=32,Type=13193,Death Knight
    {id = 3759,name="Waves of the Forgotten Reservoir"}, -- classmask=64,Type=13193,Shaman
    {id = 3739,name="Sparks of Violet Rebirth"}, -- classmask=128,Type=13193,Mage
    {id = 3763,name="Rites of the Hexflame Coven"}, -- classmask=256,Type=13193,Warlock
    {id = 3743,name="Gatecrasher's Fortitude"}, -- classmask=512,Type=13193,Monk
    {id = 3727,name="Mane of the Greatlynx"}, -- classmask=1024,Type=13193,Druid
    {id = 3723,name="Husk of the Hypogeal Nemesis"}, -- classmask=2048,Type=13193,Demon Hunter
    {id = 3731,name="Destroyer's Scarred Wards"}, -- classmask=4096,Type=13193,Evoker
  },
})
tinsert(ns.Sets, {
  id = 273,
  name = "Nerub-ar Palace (Heroic)",
  instance = 2657,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 3765,name="Warsculptor's Masterwork"}, -- classmask=1,Type=2015,Warrior
    {id = 3745,name="Entombed Seraph's Radiance"}, -- classmask=2,Type=2015,Paladin
    {id = 3733,name="Lightless Scavenger's Necessities"}, -- classmask=4,Type=2015,Hunter
    {id = 3753,name="K'areshi Phantom's Bindings"}, -- classmask=8,Type=2015,Rogue
    {id = 3749,name="Shards of Living Luster"}, -- classmask=16,Type=2015,Priest
    {id = 3718,name="Exhumed Centurion's Relics"}, -- classmask=32,Type=2015,Death Knight
    {id = 3757,name="Waves of the Forgotten Reservoir"}, -- classmask=64,Type=2015,Shaman
    {id = 3737,name="Sparks of Violet Rebirth"}, -- classmask=128,Type=2015,Mage
    {id = 3761,name="Rites of the Hexflame Coven"}, -- classmask=256,Type=2015,Warlock
    {id = 3741,name="Gatecrasher's Fortitude"}, -- classmask=512,Type=2015,Monk
    {id = 3725,name="Mane of the Greatlynx"}, -- classmask=1024,Type=2015,Druid
    {id = 3721,name="Husk of the Hypogeal Nemesis"}, -- classmask=2048,Type=2015,Demon Hunter
    {id = 3729,name="Destroyer's Scarred Wards"}, -- classmask=4096,Type=2015,Evoker
  },
})
tinsert(ns.Sets, {
  id = 273,
  name = "Nerub-ar Palace (Mythic)",
  instance = 2657,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 3766,name="Warsculptor's Masterwork"}, -- classmask=1,Type=13145,Warrior
    {id = 3746,name="Entombed Seraph's Radiance"}, -- classmask=2,Type=13145,Paladin
    {id = 3734,name="Lightless Scavenger's Necessities"}, -- classmask=4,Type=13145,Hunter
    {id = 3754,name="K'areshi Phantom's Bindings"}, -- classmask=8,Type=13145,Rogue
    {id = 3750,name="Shards of Living Luster"}, -- classmask=16,Type=13145,Priest
    {id = 3719,name="Exhumed Centurion's Relics"}, -- classmask=32,Type=13145,Death Knight
    {id = 3758,name="Waves of the Forgotten Reservoir"}, -- classmask=64,Type=13145,Shaman
    {id = 3738,name="Sparks of Violet Rebirth"}, -- classmask=128,Type=13145,Mage
    {id = 3762,name="Rites of the Hexflame Coven"}, -- classmask=256,Type=13145,Warlock
    {id = 3742,name="Gatecrasher's Fortitude"}, -- classmask=512,Type=13145,Monk
    {id = 3726,name="Mane of the Greatlynx"}, -- classmask=1024,Type=13145,Druid
    {id = 3722,name="Husk of the Hypogeal Nemesis"}, -- classmask=2048,Type=13145,Demon Hunter
    {id = 3730,name="Destroyer's Scarred Wards"}, -- classmask=4096,Type=13145,Evoker
  },
})
-- liberation of undermine 305
tinsert(ns.Sets, {
  id = 305,
  name = "Liberation of Undermine (Raid Finder)",
  instance = 2769,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 4326,name="Enforcer's Backalley Brawlplate"}, -- classmask=1,Type=1641,Warrior
    {id = 4306,name="Oath of the Aureate Sentry"}, -- classmask=2,Type=1641,Paladin
    {id = 4294,name="Tireless Collector's Bounties"}, -- classmask=4,Type=1641,Hunter
    {id = 4314,name="Spectral Gambler's Last Call"}, -- classmask=8,Type=1641,Rogue
    {id = 4310,name="Confessor's Unshakable Virtue"}, -- classmask=16,Type=1641,Priest
    {id = 4278,name="Cauldron Champion's Encore"}, -- classmask=32,Type=1641,Death Knight
    {id = 4318,name="Currents of the Gale Sovereign"}, -- classmask=64,Type=1641,Shaman
    {id = 4298,name="Jewels of the Aspectral Emissary"}, -- classmask=128,Type=1641,Mage
    {id = 4322,name="Spliced Fiendtrader's Influence"}, -- classmask=256,Type=1641,Warlock
    {id = 4302,name="Ageless Serpent's Foresight"}, -- classmask=512,Type=1641,Monk
    {id = 4286,name="Roots of Reclaiming Blight"}, -- classmask=1024,Type=1641,Druid
    {id = 4282,name="Fel-Dealer's Contraband"}, -- classmask=2048,Type=1641,Demon Hunter
    {id = 4290,name="Opulent Treasurescale's Hoard"}, -- classmask=4096,Type=1641,Evoker
  },
})
tinsert(ns.Sets, {
  id = 305,
  name = "Liberation of Undermine (Normal)",
  instance = 2769,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 4325,name="Enforcer's Backalley Brawlplate"}, -- classmask=1,Type=13193,Warrior
    {id = 4305,name="Oath of the Aureate Sentry"}, -- classmask=2,Type=13193,Paladin
    {id = 4293,name="Tireless Collector's Bounties"}, -- classmask=4,Type=13193,Hunter
    {id = 4313,name="Spectral Gambler's Last Call"}, -- classmask=8,Type=13193,Rogue
    {id = 4309,name="Confessor's Unshakable Virtue"}, -- classmask=16,Type=13193,Priest
    {id = 4277,name="Cauldron Champion's Encore"}, -- classmask=32,Type=13193,Death Knight
    {id = 4317,name="Currents of the Gale Sovereign"}, -- classmask=64,Type=13193,Shaman
    {id = 4297,name="Jewels of the Aspectral Emissary"}, -- classmask=128,Type=13193,Mage
    {id = 4321,name="Spliced Fiendtrader's Influence"}, -- classmask=256,Type=13193,Warlock
    {id = 4301,name="Ageless Serpent's Foresight"}, -- classmask=512,Type=13193,Monk
    {id = 4285,name="Roots of Reclaiming Blight"}, -- classmask=1024,Type=13193,Druid
    {id = 4281,name="Fel-Dealer's Contraband"}, -- classmask=2048,Type=13193,Demon Hunter
    {id = 4289,name="Opulent Treasurescale's Hoard"}, -- classmask=4096,Type=13193,Evoker
 } ,
})
tinsert(ns.Sets, {
  id = 305,
  name = "Liberation of Undermine (Heroic)",
  instance = 2769,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 4323,name="Enforcer's Backalley Brawlplate"}, -- classmask=1,Type=2015,Warrior
    {id = 4303,name="Oath of the Aureate Sentry"}, -- classmask=2,Type=2015,Paladin
    {id = 4291,name="Tireless Collector's Bounties"}, -- classmask=4,Type=2015,Hunter
    {id = 4311,name="Spectral Gambler's Last Call"}, -- classmask=8,Type=2015,Rogue
    {id = 4307,name="Confessor's Unshakable Virtue"}, -- classmask=16,Type=2015,Priest
    {id = 4275,name="Cauldron Champion's Encore"}, -- classmask=32,Type=2015,Death Knight
    {id = 4315,name="Currents of the Gale Sovereign"}, -- classmask=64,Type=2015,Shaman
    {id = 4295,name="Jewels of the Aspectral Emissary"}, -- classmask=128,Type=2015,Mage
    {id = 4319,name="Spliced Fiendtrader's Influence"}, -- classmask=256,Type=2015,Warlock
    {id = 4299,name="Ageless Serpent's Foresight"}, -- classmask=512,Type=2015,Monk
    {id = 4283,name="Roots of Reclaiming Blight"}, -- classmask=1024,Type=2015,Druid
    {id = 4279,name="Fel-Dealer's Contraband"}, -- classmask=2048,Type=2015,Demon Hunter
    {id = 4287,name="Opulent Treasurescale's Hoard"}, -- classmask=4096,Type=2015,Evoker
  },
})
tinsert(ns.Sets, {
  id = 305,
  name = "Liberation of Undermine (Mythic)",
  instance = 2769,
  release = 11,
  minLevel = 80,
  sets = {
    {id = 4324,name="Enforcer's Backalley Brawlplate"}, -- classmask=1,Type=13145,Warrior
    {id = 4304,name="Oath of the Aureate Sentry"}, -- classmask=2,Type=13145,Paladin
    {id = 4292,name="Tireless Collector's Bounties"}, -- classmask=4,Type=13145,Hunter
    {id = 4312,name="Spectral Gambler's Last Call"}, -- classmask=8,Type=13145,Rogue
    {id = 4308,name="Confessor's Unshakable Virtue"}, -- classmask=16,Type=13145,Priest
    {id = 4276,name="Cauldron Champion's Encore"}, -- classmask=32,Type=13145,Death Knight
    {id = 4316,name="Currents of the Gale Sovereign"}, -- classmask=64,Type=13145,Shaman
    {id = 4296,name="Jewels of the Aspectral Emissary"}, -- classmask=128,Type=13145,Mage
    {id = 4320,name="Spliced Fiendtrader's Influence"}, -- classmask=256,Type=13145,Warlock
    {id = 4300,name="Ageless Serpent's Foresight"}, -- classmask=512,Type=13145,Monk
    {id = 4284,name="Roots of Reclaiming Blight"}, -- classmask=1024,Type=13145,Druid
    {id = 4280,name="Fel-Dealer's Contraband"}, -- classmask=2048,Type=13145,Demon Hunter
    {id = 4288,name="Opulent Treasurescale's Hoard"}, -- classmask=4096,Type=13145,Evoker
  },
})

tinsert(ns.Sets, {
  id = 330,
  name = "Manaforge Omega (Raid Finder)",
  instance = 16178,
  release = 11,
  minLevel = 80,
  sets = {
{id = 5148,name="Chains of the Living Weapon"}, -- classmask=1,Type=1641,Warrior
{id = 5128,name="Vows of the Lucent Battalion"}, -- classmask=2,Type=1641,Paladin
{id = 5116,name="Midnight Herald's Pledge"}, -- classmask=4,Type=1641,Hunter
{id = 5136,name="Shroud of the Sudden Eclipse"}, -- classmask=8,Type=1641,Rogue
{id = 5132,name="Eulogy to a Dying Star"}, -- classmask=16,Type=1641,Priest
{id = 5100,name="Hollow Sentinel's Vigil"}, -- classmask=32,Type=1641,Death Knight
{id = 5140,name="Howls of Channeled Fury"}, -- classmask=64,Type=1641,Shaman
{id = 5120,name="Augur's Ephemeral Plumage"}, -- classmask=128,Type=1641,Mage
{id = 5144,name="Inquisitor's Feast of Madness"}, -- classmask=256,Type=1641,Warlock
{id = 5124,name="Crash of Fallen Storms"}, -- classmask=512,Type=1641,Monk
{id = 5108,name="Ornaments of the Mother Eagle"}, -- classmask=1024,Type=1641,Druid
{id = 5104,name="Charhound's Vicious Hunt"}, -- classmask=2048,Type=1641,Demon Hunter
{id = 5112,name="Spellweaver's Immaculate Design"}, -- classmask=4096,Type=1641,Evoker
  },
})

tinsert(ns.Sets, {
  id = 330,
  name = "Manaforge Omega (Normal)",
  instance = 16178,
  release = 11,
  minLevel = 80,
  sets = {
{id = 5145,name="Chains of the Living Weapon"}, -- classmask=1,Type=2015,Warrior
{id = 5125,name="Vows of the Lucent Battalion"}, -- classmask=2,Type=2015,Paladin
{id = 5113,name="Midnight Herald's Pledge"}, -- classmask=4,Type=2015,Hunter
{id = 5133,name="Shroud of the Sudden Eclipse"}, -- classmask=8,Type=2015,Rogue
{id = 5129,name="Eulogy to a Dying Star"}, -- classmask=16,Type=2015,Priest
{id = 5097,name="Hollow Sentinel's Vigil"}, -- classmask=32,Type=2015,Death Knight
{id = 5137,name="Howls of Channeled Fury"}, -- classmask=64,Type=2015,Shaman
{id = 5117,name="Augur's Ephemeral Plumage"}, -- classmask=128,Type=2015,Mage
{id = 5141,name="Inquisitor's Feast of Madness"}, -- classmask=256,Type=2015,Warlock
{id = 5121,name="Crash of Fallen Storms"}, -- classmask=512,Type=2015,Monk
{id = 5105,name="Ornaments of the Mother Eagle"}, -- classmask=1024,Type=2015,Druid
{id = 5101,name="Charhound's Vicious Hunt"}, -- classmask=2048,Type=2015,Demon Hunter
{id = 5109,name="Spellweaver's Immaculate Design"}, -- classmask=4096,Type=2015,Evoker
  },
})

tinsert(ns.Sets, {
  id = 330,
  name = "Manaforge Omega (Heroic)",
  instance = 16178,
  release = 11,
  minLevel = 80,
  sets = {
{id = 5146,name="Chains of the Living Weapon"}, -- classmask=1,Type=13145,Warrior
{id = 5126,name="Vows of the Lucent Battalion"}, -- classmask=2,Type=13145,Paladin
{id = 5114,name="Midnight Herald's Pledge"}, -- classmask=4,Type=13145,Hunter
{id = 5134,name="Shroud of the Sudden Eclipse"}, -- classmask=8,Type=13145,Rogue
{id = 5130,name="Eulogy to a Dying Star"}, -- classmask=16,Type=13145,Priest
{id = 5098,name="Hollow Sentinel's Vigil"}, -- classmask=32,Type=13145,Death Knight
{id = 5138,name="Howls of Channeled Fury"}, -- classmask=64,Type=13145,Shaman
{id = 5118,name="Augur's Ephemeral Plumage"}, -- classmask=128,Type=13145,Mage
{id = 5142,name="Inquisitor's Feast of Madness"}, -- classmask=256,Type=13145,Warlock
{id = 5122,name="Crash of Fallen Storms"}, -- classmask=512,Type=13145,Monk
{id = 5106,name="Ornaments of the Mother Eagle"}, -- classmask=1024,Type=13145,Druid
{id = 5102,name="Charhound's Vicious Hunt"}, -- classmask=2048,Type=13145,Demon Hunter
{id = 5110,name="Spellweaver's Immaculate Design"}, -- classmask=4096,Type=13145,Evoker
  },
})

tinsert(ns.Sets, {
  id = 330,
  name = "Manaforge Omega (Mythic)",
  instance = 16178,
  release = 11,
  minLevel = 80,
  sets = {
{id = 5147,name="Chains of the Living Weapon"}, -- classmask=1,Type=13193,Warrior
{id = 5127,name="Vows of the Lucent Battalion"}, -- classmask=2,Type=13193,Paladin
{id = 5115,name="Midnight Herald's Pledge"}, -- classmask=4,Type=13193,Hunter
{id = 5135,name="Shroud of the Sudden Eclipse"}, -- classmask=8,Type=13193,Rogue
{id = 5131,name="Eulogy to a Dying Star"}, -- classmask=16,Type=13193,Priest
{id = 5099,name="Hollow Sentinel's Vigil"}, -- classmask=32,Type=13193,Death Knight
{id = 5139,name="Howls of Channeled Fury"}, -- classmask=64,Type=13193,Shaman
{id = 5119,name="Augur's Ephemeral Plumage"}, -- classmask=128,Type=13193,Mage
{id = 5143,name="Inquisitor's Feast of Madness"}, -- classmask=256,Type=13193,Warlock
{id = 5123,name="Crash of Fallen Storms"}, -- classmask=512,Type=13193,Monk
{id = 5107,name="Ornaments of the Mother Eagle"}, -- classmask=1024,Type=13193,Druid
{id = 5103,name="Charhound's Vicious Hunt"}, -- classmask=2048,Type=13193,Demon Hunter
{id = 5111,name="Spellweaver's Immaculate Design"}, -- classmask=4096,Type=13193,Evoker
  },
})