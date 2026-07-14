---@class Warbandeer_Characters
local ns = select(2, ...)

-- Curated "how to obtain" hint text for every collectible on the Detail appearance card
-- (Warbandeer's GlyphBox), keyed by itemID: the cosmetic appearance glyphs (ns.AppearanceGlyphs),
-- the Warlock demon Grimoires + green fire + Druid Marks/travel glyphs (ns.AppearanceUnlocks), and the class
-- books (ns.LearnedUnlocks — Hunter Tomes & Tames, Druid Tome of the Wilds, per-class Legion tomes).
-- WarbandeerApi's GetAppliedGlyphs /
-- GetAppearanceUnlocks / GetLearnedUnlocks attach this as each entry's `source` field, and the UI
-- appends it to the item tooltip when the entry is still UNOWNED/UNAPPLIED. Sourced from Wowhead +
-- Warcraft Wiki and in-game-verified (2026-07-13). For the learned tames the item name is omitted
-- (the row's tooltip already shows it) — just the source. Static game data, no DB storage.

-- Shared phrases, to keep the repeated sources typo-proof.
local AH        = "Inscription — craft or buy on the Auction House"
local JANG      = "Inscription — recipe from Jang Quillpaw, Legion Dalaran"
local KYRIAN    = "Covenant vendor — Kyrian/The Ascended (Honored, 5,000g)"
local NIGHTFAE  = "Covenant vendor — Night Fae/The Wild Hunt (Honored, 5,000g)"
local NECRO     = "Covenant vendor — Necrolord/The Undying Army (Honored, 5,000g)"
local VENTHYR   = "Covenant vendor — Venthyr/Court of Harvesters (Honored, 5,000g)"
local BRIDLE    = "Order Hall — Crusader Lord Dalfors, Sanctum of Light (500 Order Resources)"
local TOME      = "50g from Lorelae Wintersong (Moonglade) / Amurra Thistledew (Dreamgrove)"
local SEEDBLOOM = "Vendor — 1 Seedbloom, Talisa/Sylvia Whisperbloom (Emerald Dream)"
local LANYING   = "Vendor — Flamesmith Lanying, Shaman Class Hall (500g)"

---@type table<integer, string>
ns.CollectibleSources = {
  -- === Appearance glyphs (ns.AppearanceGlyphs) ===
  -- Warrior
  [80588]  = AH,
  [141898] = JANG,
  [43398]  = AH,
  [80587]  = AH,
  [43400]  = AH,
  [217584] = KYRIAN,
  [137188] = JANG,
  [85221]  = AH,
  [203763] = "Inscription — recipe from Scridorsa the Chiseler, Zaralek Cavern",
  [104138] = "Inscription — recipe drops from Jakur of Ordon, Timeless Isle",
  [49084]  = AH,
  -- Paladin
  [217588] = NIGHTFAE,
  [217587] = KYRIAN,
  [43369]  = AH,
  [104108] = "Inscription — recipe drops on Timeless Isle",
  [41100]  = AH,
  [137293] = JANG,
  [143588] = "Inscription — recipe drops in Return to Karazhan",
  [43366]  = AH,
  [153177] = BRIDLE,
  [153174] = BRIDLE,
  [153175] = BRIDLE,
  [153176] = BRIDLE,
  -- Hunter
  [137249] = "Inscription — recipe drops from spiders/insects, Broken Isles",
  [217593] = NECRO,
  [170173] = "Inscription — recipe drops from Fresh Jelly Deposits, Stormsong Valley",
  [43350]  = AH,
  [137250] = "Inscription — recipe from Lucas Sigmund, Trueshot Lodge (Highmountain)",
  [137269] = JANG,
  [139288] = JANG,
  [137267] = "Inscription — recipe from Hobart Grapplehammer, Legion Dalaran",
  [137239] = "Inscription — recipe drops from Scumshell Crab, Azsuna",
  [243051] = "Inscription — recipe from Lyrendal, Dornogal (150 Artisan's Acuity)",
  [137238] = "Inscription — recipe drops from Tidemistress Sashj'tar, Suramar",
  -- Rogue
  [139358] = JANG,
  [139442] = "Inscription — recipe from Cravitz Lorent, Dalaran Underbelly",
  [45768]  = AH,
  [217597] = KYRIAN,
  [217598] = VENTHYR,
  [129020] = "Inscription — recipe from The Widow, Hall of Shadows (Dalaran)",
  [217583] = NIGHTFAE,
  [234246] = "Inscription — recipe drops from Seafarer's Cache, Siren Isle",
  [234245] = "Inscription — recipe pickpocketed from pirates, Siren Isle",
  [234247] = "Inscription — recipe from Soweezi, Siren Isle (350 Flame-Blessed Iron)",
  [234248] = "Inscription — recipe from Taljori, Siren Isle (350 Flame-Blessed Iron)",
  -- Priest
  [149755] = "Inscription — recipe drops in MoP Timewalking dungeons",
  [153036] = "Inscription — recipe drops from L'ura, Seat of the Triumvirate",
  [129017] = JANG,
  [104122] = AH,
  [217589] = VENTHYR,
  [43373]  = AH,
  [77101]  = AH,
  [87392]  = AH,
  [79538]  = AH,
  [153031] = "Inscription — recipe from Vindicator Jaelaana, Antoran Wastes (Veiled Argunite)",
  [104120] = "Inscription — recipe world-drops in Pandaria",
  [207088] = "Inscription — recipe drops in Ny'alotha",
  [87277]  = AH,
  [153033] = "Inscription — recipe drops from Ataxon, Eredath (Argus)",
  -- Death Knight
  [217596] = NECRO,
  [137274] = JANG,
  [43551]  = AH,
  [139271] = "Inscription — recipe world-drops from Broken Isles water elementals",
  [139270] = JANG,
  [43535]  = AH,
  [104099] = "Inscription — recipe drops from Rattleskew, Timeless Isle",
  -- Shaman
  [139289] = "Inscription — recipe from K'huta, Dalaran Underbelly (100 Sightless Eye)",
  [232622] = LANYING,
  [137289] = "Inscription — recipe from Elementalist Sharvak, Nagrand",
  [104127] = AH,
  [137288] = "Inscription — recipe drops from drogbar, Broken Isles",
  [217599] = NECRO,
  [104126] = AH,
  [190378] = "Inscription — recipe from Vilo, Zereth Mortis (1,425g)",
  [137287] = JANG,
  [190380] = "Inscription — recipe from Tribute of the Wild Hunt (Night Fae, Ardenweald)",
  [43386]  = AH,
  [232527] = LANYING,
  -- Mage
  [232521] = "Vendor — Libergo (Valdrakken) / Charys Yserian (Stormwind) (500g)",
  [42751]  = "Inscription — taught by Inscription trainer",
  [167539] = "Inscription — recipe from Endora Moorehead, Northrend Dalaran (500g)",
  [104105] = "Inscription — recipe drops from Jademist Dancer, Dread Wastes",
  [172449] = "Inscription — mage scribes discover it (Conjure Refreshment Table)",
  [139352] = "Inscription — recipe drops from The Rat King, The Arcway",
  [217586] = KYRIAN,
  [217594] = NIGHTFAE,
  [139348] = "Inscription — recipe drops in Firelands",
  [129019] = JANG,
  [170165] = "Inscription — recipe drops in Mardivas's Laboratory, Nazjatar",
  [166664] = "Inscription — recipe from Storm's Wake Supplies (Stormsong Valley)",
  [170168] = "Inscription — recipe from Unshackled/Ankoan Supplies, Nazjatar",
  [170164] = "Inscription — recipe drops from Radiance of Azshara, The Eternal Palace",
  [166583] = "Inscription — recipe drops from Proudmoore Strongbox, Kul Tiras",
  [104104] = "Inscription — recipe drops from Bored Student, Scholomance",
  -- Warlock
  [207101] = "Warlock quest reward \"A Lighter Shade of Fel\"; re-buy from Svat, Booty Bay",
  [45789]  = AH,
  [151538] = "Inscription — recipe drops in Tomb of Sargeras (Spoils of the Legion's Fall)",
  [151542] = "Inscription — recipe drops from Inquisitor Vethroz, Antoran Wastes",
  [42459]  = AH,
  [151540] = "Inscription — recipe from Warmage Kath'leen, Broken Shore",
  [217600] = NIGHTFAE,
  [43394]  = AH,
  [137191] = JANG,
  -- Monk
  [139338] = JANG,
  [129022] = "Inscription — recipe drops in Return to Karazhan",
  [87881]  = AH,
  [217494] = NIGHTFAE,
  [87888]  = AH,
  [87883]  = AH,
  [232491] = "Vendor — Number Nine Jia, Peak of Serenity (Kun-Lai Summit) (500g)",
  [87885]  = AH,
  [217595] = KYRIAN,
  [139339] = JANG,
  -- Druid
  [217592] = NECRO,
  [136826] = JANG,
  [217585] = NIGHTFAE,
  [44922]  = AH,
  [184100] = "Inscription — recipe from Roko, Tiragarde Sound",
  [184097] = "Inscription — recipe from Roko, Tiragarde Sound",
  [136825] = JANG,
  [139278] = "Inscription — recipe from Lorelae Wintersong, Moonglade",
  [211400] = "Inscription — recipe from Mythrin'dir, Emerald Dream",
  [118061] = AH,
  [184096] = "Inscription — recipe from Roko, Tiragarde Sound",
  [43334]  = AH,
  [188164] = "Inscription — recipe from Scribe Au'tehshi, Oribos",
  [143750] = "Inscription — recipe drops from High Botanist Tel'arn, The Nighthold",
  -- Demon Hunter
  [129029] = "Inscription — reward from the Legion Inscription quest, Azsuna",
  [217591] = KYRIAN,
  [139417] = "Inscription — reward from the Legion Inscription quest, Azsuna",
  [129028] = "Inscription — reward from the Legion Inscription quest, Azsuna",
  [139435] = "Inscription — recipe drops from demons, Broken Isles",
  [139437] = JANG,
  [139362] = JANG,
  [139438] = "Inscription — recipe from Oxana Demonslay, Dalaran Underbelly (100 Sightless Eye)",
  [139436] = "Inscription — reward from the Legion Inscription quest, Azsuna",
  [203762] = "Inscription — recipe from Scridorsa the Chiseler, Zaralek Cavern",
  [217590] = NIGHTFAE,

  -- === Warlock green fire (ns.AppearanceUnlocks[9], progressive) ===
  -- Keyed to whichever step the row currently shows: the starter tome until the chain begins,
  -- then the Codex reward until the scenario is completed (account-wide thereafter).
  [92426]  = "Loot the Sealed Tome of the Lost Legion (rare demon drop) and fuse it with a Healthstone to begin the green fire questline",
  [92441]  = "Continue the green fire questline, then defeat Kanrethad in the Pursuing the Black Harvest scenario",

  -- === Warlock demon Grimoires (ns.AppearanceUnlocks[9]) ===
  [129018] = AH,
  [139310] = AH,
  [139311] = AH,
  [139314] = AH,
  [139315] = AH,
  [147119] = AH,
  [147117] = "Drops from Hellblaze Temptress, Cathedral of Eternal Night",
  [207111] = "Drops from Terestian Illhoof, Karazhan (classic raid)",
  [207112] = "TBC Timewalking vendor — Cupri, Shattrath (1,000 Timewarped Badges)",
  [207113] = "Drops from Time Rifts final bosses, Thaldraszus",
  [207114] = "Legion Timewalking vendor — Aridormi, Dalaran (1,000 Timewarped Badges)",
  [207178] = "Order Hall — Imp Mother Dyala, Dreadscar Rift (15,000g)",
  [207294] = "Warlock Darkmoon Faire questline (Twinkle, via Madam Shadow)",
  [207295] = "Talk to Vi'el, Winterspring (Frostwhisper Gorge)",
  [207296] = "Drops from Matron Folnuna, Greater Invasion Point world boss (Argus)",
  [207297] = "Drops from Pusillin, Dire Maul East (Feralas)",
  [208048] = "Return to Karazhan — torn page, Guardian's Study (after Mana Devourer)",
  [208050] = "Antorus — Broken Gateway after Portal Keeper Hasabel (needs Zhar'doom transmog)",
  [208051] = "Drops from Felhounds of Sargeras, Antorus",
  [208052] = "Drops from Time Rifts final bosses, Thaldraszus",
  [212750] = "Durumu the Forgotten, Throne of Thunder (Glass Pupil + brazier puzzle)",
  [212778] = "Radix (in stasis — click), Antoran Wastes (Argus)",
  [212779] = "Ixallon the Soulbreaker, Tomb of Sargeras",
  [212780] = "Archimonde, Hellfire Citadel (Tanaan Jungle)",
  [212783] = "Order Hall — Gigi Gigavoid, Dreadscar Rift (5,000g)",
  [212983] = "Carved Eye at the Dark Portal base, Blasted Lands",
  [212984] = "Carved Eye in old Scarlet Monastery, Tirisfal Glades",
  [212989] = "Carved Eye behind a door at Karazhan, Deadwind Pass",
  [212991] = "Carved Eye in the Dire Maul arena, Feralas",
  [212993] = "Carved Eye by a tree at Stratholme, Eastern Plaguelands",
  [212995] = "Carved Eye in Ahn'Qiraj, Silithus",
  [213014] = "Portal Keeper Hasabel, Antorus",
  [213015] = "Zuraal the Ascended, Seat of the Triumvirate (dungeon)",
  [213016] = "Mistress Sassz'ine, Tomb of Sargeras",
  [213017] = "Viz'aduum the Watcher, Return to Karazhan",

  -- === Druid Marks & travel glyphs (ns.AppearanceUnlocks[11]) ===
  -- classic travel glyphs
  [40919]  = AH,
  [89868]  = AH,
  [129021] = JANG,
  [140630] = "Inscription — recipe drops from deer, Broken Isles (Val'sharah)",
  [162022] = "Inscription — recipe from Collector Kojo (Tortollan Seekers, Revered)",
  [162027] = "Inscription — recipe drops from Corrupted Tideskipper, Stormsong Valley",
  [162029] = "Inscription — recipe from a BfA scribe vendor (150 skill)",
  -- Shadowlands / Ardenweald
  [187884] = "Inscription — recipe from Aithlyn/Liawyn (Wild Hunt, Revered)",
  [187887] = "Inscription — recipe from Ta'tru, the Night Market (Revendreth)",
  [187888] = "Inscription — recipe from Droman Dawnblossom (net a Vale Flitter, Val'sharah)",
  [187931] = "Inscription — recipe drops from Evedwellers, Revendreth",
  [187933] = "Inscription — recipe from Sylvia Hartshorn, Lorlathil (Val'sharah)",
  [187934] = "Inscription — recipe drops from runestags, Ardenweald",
  [187936] = "Inscription — recipe from Spindlenose, Hibernal Hollow (Ardenweald)",
  -- Dragonflight / Emerald Dream
  [210535] = "Inscription — pluck feathers from sleeping Somnowls, Emerald Dream",
  [210645] = "Reward from the Q'onzu quest chain, Emerald Dream",
  [210647] = "Drops from rare Mosa Umbramane, Meandering Rootlands",
  [210650] = "Drops from rare Keen-eyed Cian, Emerald Dream",
  [210669] = "Silent Mark (500g, Thaelishar Groveheart) — attune on 10 Dreamsabers",
  [210674] = "Drops from rare Ristar the Rabid, Emerald Dream",
  [210683] = "Drops from rare Matriarch Keevah, Emerald Dream",
  [210684] = "Silent Mark (500g, Thaelishar Groveheart) — attune on 10 Dreamtalons",
  [210727] = "Ground pickup after Aviana's \"Overseer Oversight\" questline",
  [210728] = "Fill vials at 6 Azeroth moonwells, then the Feral Dreamstone (Emerald Dream)",
  [210729] = "Drops from rare Moragh the Slothful, Emerald Dream",
  [210731] = "Silent Mark (500g, Thaelishar Groveheart) — attune on 10 Gladeharts",
  [210735] = "Inscription — recipe drops from Dreamseed Caches; or AH",
  [210736] = "Drops from roaming rare Talthonei Ashwhisper, Emerald Dream",
  [210738] = "Silent Mark (500g, Thaelishar Groveheart) — attune on 10 Umbraclaws",
  [210739] = SEEDBLOOM,
  [210751] = "World boss Aurostor the Hibernator (weekly), Emerald Dream",
  [210753] = "Fishing — catch Xena the Whiskerfish (Attuned Angler buff)",
  [210754] = "Drops with Reins of Anu'relos from Mythic Fyrakk, Amirdrassil",
  [211080] = SEEDBLOOM,
  [211081] = SEEDBLOOM,
  [211280] = "Drops from Tindral Sageswift, Amirdrassil (any difficulty)",

  -- === Hunter Tomes (ns.LearnedUnlocks[3]) — item name omitted; row tooltip shows it ===
  -- Skill Tames
  [166502] = "Hunter-only drop from Zul, Reborn (Uldir raid)",
  [147580] = "Buy from Pan the Kind Hand, Trueshot Lodge (Hunter order hall)",
  [94232]  = "Rare drop from Zandalari Dinomancers, Isle of Giants (Pandaria)",
  [134125] = "Crafted by Engineering (Goblin/Gnome hunters tame innately)",
  [180705] = "Drops from rare Huntmaster Petrus, Revendreth",
  [183123] = "50g from San Redscale, Jade Forest (Exalted, Order of the Cloud Serpent)",
  [183124] = "Zone drop in Maldraxxus; also Plaguefall dungeon bosses",
  [201791] = "Renown 23 with the Valdrakken Accord (Kaelstrasz, Valdrakken)",
  [211314] = "Awarded with Reins of Anu'relos from Mythic Fyrakk, Amirdrassil",
  [264895] = "Drops from rares in Harandar (Midnight)",
  -- Utility ability tomes
  [136783] = "50g from the Nesingwary vendors (Sholazar Basin / Trueshot Lodge)",
  [136781] = "50g from the Nesingwary vendors (Sholazar Basin / Trueshot Lodge)",
  [136782] = "50g from the Dalaran engineering vendors (Hobart Grapplehammer / Bryan Landers)",
  [136780] = "50g from Outfitter Reynolds, Trueshot Lodge (Highmountain)",

  -- === Druid Tome of the Wilds (ns.LearnedUnlocks[11]) ===
  [136787] = TOME,
  [136789] = TOME,
  [136794] = TOME,
  [136795] = TOME,
  [136790] = TOME,

  -- === Class-book tomes (ns.LearnedUnlocks — Paladin/Rogue/DK/Shaman/Mage/Monk) ===
  -- Paladin — Divine Tome
  [136801] = "50g from Miranda Breechlock, Sanctum of Light (Light's Hope Chapel, EPL)",
  -- Rogue — Dirty Tricks
  [136803] = "50g from Kelsey Steelspark, the Underbelly (Dalaran)",
  -- Death Knight — Necrophile Tome
  [136796] = "50g from Quartermaster Ozorg, Acherus: The Ebon Hold",
  -- Shaman — Tomes of Hex
  [136972] = "50g from Cravitz Lorent, the Underbelly (Dalaran)",
  [136938] = "50g from Elementalist Sharvak, Throne of the Elements (Nagrand)",
  [136969] = "Drops from Nal'tira, The Arcway",
  -- Mage — Mystical Tomes
  [136797] = "50g from Endora Moorehead, Sisters Sorcerous (Dalaran)",
  [136799] = "50g from Endora Moorehead, Sisters Sorcerous (Dalaran)",
  [44709]  = "2,500g (2,000g at Exalted Kirin Tor) from Endora Moorehead, Dalaran",
  [120138] = "Drops from hozen & monkeys, Pandaria",
  [44793]  = "100 Noblegarden Chocolate from Noblegarden vendors (holiday)",
  [120137] = "Drops from Arctic Grizzlies, Dragonblight (~0.5%)",
  [120140] = "Drops from porcupines, Pandaria",
  [22739]  = "Fished from Cataclysm-zone fishing pools",
  -- Monk — Meditation Manual
  [136800] = "50g from Master Hwang, Peak of Serenity (Kun-Lai Summit)",
}
