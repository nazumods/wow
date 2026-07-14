---@type Warbandeer_Characters
local ns = select(2, ...)

-- Static appearance-glyph catalog, split into the two systems current retail exposes:
--
--  * `ns.AppearanceGlyphs` — the classic cosmetic glyphs a character *applies* to a
--    spell (e.g. Glyph of Stars on Moonkin Form). Applied state is PER-CHARACTER and
--    PER-SPEC and only readable from the logged-in character's spellbook, so the
--    `glyphs` broker (data/glyphs.lua) records it as a last-seen per-spec snapshot.
--    Each entry carries the `glyph` id embedded in an applied spell's hyperlink
--    (…::<glyph>:…) — the value the broker matches — plus the `specs` it's usable by.
--
--  * `ns.AppearanceUnlocks` — Druid barbershop **Marks** / travel-form glyphs and
--    Warlock demon **Grimoires**. These are ACCOUNT-WIDE unlocks (identical for every
--    character of the class), read live via C_QuestLog.IsQuestFlaggedCompletedOnAccount,
--    so they need no per-character storage. Only Druid + Warlock have them.
--
-- Item / glyph / quest / spell ids are ported from the community GlyphList addon's
-- GlyphData.lua (kept current per patch) and confirmed in-game via `/wbc dump glyphs`,
-- which prints each entry's live-resolved item name beside the label below.
--
-- Keyed by classId (1 Warrior · 2 Paladin · 3 Hunter · 4 Rogue · 5 Priest · 6 Death
-- Knight · 7 Shaman · 8 Mage · 9 Warlock · 10 Monk · 11 Druid · 12 Demon Hunter;
-- Evoker (13) has no appearance glyphs).

---@class GlyphInfo
---@field itemID integer   the glyph item
---@field glyph integer    glyph id embedded in an applied spell's hyperlink
---@field label string     glyph item name (English; the probe verifies it live)
---@field specs table<integer, boolean>?  specs the glyph is usable by (nil = all specs)

---@type table<integer, GlyphInfo[]>
ns.AppearanceGlyphs = {
  [1] = { -- Warrior (71 Arms, 72 Fury, 73 Protection)
    { itemID = 80588,  glyph = 991,  label = "Glyph of Burning Anger",     specs = {[72]=true} },
    { itemID = 141898, glyph = 1286, label = "Glyph of Falling Thunder" },
    { itemID = 43398,  glyph = 486,  label = "Glyph of Gushing Wound",     specs = {[73]=true} },
    { itemID = 80587,  glyph = 990,  label = "Glyph of Hawk Feast" },
    { itemID = 43400,  glyph = 488,  label = "Glyph of Mighty Victory" },
    { itemID = 217584, glyph = 1444, label = "Glyph of Spear of Bastion" },
    { itemID = 137188, glyph = 1223, label = "Glyph of the Blazing Savior" },
    { itemID = 85221,  glyph = 1020, label = "Glyph of the Blazing Trail" },
    { itemID = 203763, glyph = 1432, label = "Glyph of the Heaved Armament" },
    { itemID = 104138, glyph = 1101, label = "Glyph of the Weaponmaster",  specs = {[72]=true} },
    { itemID = 49084,  glyph = 851,  label = "Glyph of Thunder Strike" },
  },
  [2] = { -- Paladin (65 Holy, 66 Protection, 70 Retribution)
    { itemID = 217588, glyph = 1455, label = "Glyph of Blessing of the Seasons", specs = {[65]=true} },
    { itemID = 217587, glyph = 1454, label = "Glyph of Divine Toll" },
    { itemID = 43369,  glyph = 457,  label = "Glyph of Fire From the Heavens", specs = {[70]=true, [65]=true, [66]=true} },
    { itemID = 104108, glyph = 1083, label = "Glyph of Pillar of Light",   specs = {[65]=true} },
    { itemID = 41100,  glyph = 190,  label = "Glyph of the Luminous Charger" },
    { itemID = 137293, glyph = 1245, label = "Glyph of the Queen",         specs = {[66]=true} },
    { itemID = 143588, glyph = 1287, label = "Glyph of the Trusted Steed" },
    { itemID = 43366,  glyph = 454,  label = "Glyph of Winged Vengeance" },
    { itemID = 153177, glyph = 1306, label = "Golden Charger's Bridle" },
    { itemID = 153174, glyph = 1303, label = "Valorous Charger's Bridle" },
    { itemID = 153175, glyph = 1304, label = "Vengeful Charger's Bridle" },
    { itemID = 153176, glyph = 1305, label = "Vigilant Charger's Bridle" },
  },
  [3] = { -- Hunter (253 Beast Mastery, 254 Marksmanship, 255 Survival)
    { itemID = 137249, glyph = 1234, label = "Glyph of Arachnophobia",     specs = {[253]=true} },
    { itemID = 217593, glyph = 1450, label = "Glyph of Death Chakram" },
    { itemID = 170173, glyph = 1415, label = "Glyph of Dire Bees",         specs = {[253]=true} },
    { itemID = 43350,  glyph = 440,  label = "Glyph of Lesser Proportion" },
    { itemID = 137250, glyph = 1235, label = "Glyph of Nesingwary's Nemeses", specs = {[253]=true} },
    { itemID = 137269, glyph = 1239, label = "Glyph of Stellar Flare" },
    { itemID = 139288, glyph = 1253, label = "Glyph of the Dire Stable",   specs = {[253]=true} },
    { itemID = 137267, glyph = 1238, label = "Glyph of the Goblin Anti-Grav Flare" },
    { itemID = 137239, glyph = 1231, label = "Glyph of the Hook",          specs = {[255]=true} },
    { itemID = 243051, glyph = 1473, label = "Glyph of the Strix",         specs = {[254]=true} },
    { itemID = 137238, glyph = 1230, label = "Glyph of the Trident",       specs = {[255]=true} },
  },
  [4] = { -- Rogue (259 Assassination, 260 Outlaw, 261 Subtlety)
    { itemID = 139358, glyph = 1272, label = "Glyph of Blackout" },
    { itemID = 139442, glyph = 1283, label = "Glyph of Burnout" },
    { itemID = 45768,  glyph = 733,  label = "Glyph of Disguise" },
    { itemID = 217597, glyph = 1457, label = "Glyph of Echoing Reprimand" },
    { itemID = 217598, glyph = 1459, label = "Glyph of Flagellation",      specs = {[261]=true} },
    { itemID = 129020, glyph = 1271, label = "Glyph of Flash Bang" },
    { itemID = 217583, glyph = 1458, label = "Glyph of Sepsis",            specs = {[261]=true} },
    { itemID = 234246, glyph = 1469, label = "Glyph of the Admiral's Pistol Shot", specs = {[260]=true} },
    { itemID = 234245, glyph = 1468, label = "Glyph of the Ashvane Pistol Shot",   specs = {[260]=true} },
    { itemID = 234247, glyph = 1471, label = "Glyph of the Gilded Pistol Shot",    specs = {[260]=true} },
    { itemID = 234248, glyph = 1472, label = "Glyph of the Twilight Pistol Shot",  specs = {[260]=true} },
  },
  [5] = { -- Priest (256 Discipline, 257 Holy, 258 Shadow)
    { itemID = 149755, glyph = 1295, label = "Glyph of Angels",            specs = {[257]=true} },
    { itemID = 153036, glyph = 1302, label = "Glyph of Dark Absolution",   specs = {[256]=true} },
    { itemID = 129017, glyph = 1270, label = "Glyph of Ghostly Fade" },
    { itemID = 104122, glyph = 1087, label = "Glyph of Inspired Hymns",    specs = {[257]=true} },
    { itemID = 217589, glyph = 1456, label = "Glyph of Mindgames",         specs = {[256]=true, [258]=true} },
    { itemID = 43373,  glyph = 461,  label = "Glyph of Shackle Undead" },
    { itemID = 77101,  glyph = 961,  label = "Glyph of Shadow",            specs = {[258]=true} },
    { itemID = 87392,  glyph = 1052, label = "Glyph of Shadowy Friends",   specs = {[258]=true} },
    { itemID = 79538,  glyph = 1007, label = "Glyph of the Heavens" },
    { itemID = 153031, glyph = 1299, label = "Glyph of the Lightspawn",    specs = {[256]=true} },
    { itemID = 104120, glyph = 1085, label = "Glyph of the Sha",           specs = {[256]=true, [258]=true} },
    { itemID = 207088, glyph = 1439, label = "Glyph of the Shath'Yar",     specs = {[258]=true} },
    { itemID = 87277,  glyph = 1049, label = "Glyph of the Val'kyr",       specs = {[257]=true} },
    { itemID = 153033, glyph = 1301, label = "Glyph of the Voidling",      specs = {[258]=true} },
  },
  [6] = { -- Death Knight (250 Blood, 251 Frost, 252 Unholy)
    { itemID = 217596, glyph = 1462, label = "Glyph of Abomination Limb",  specs = {[250]=true} },
    { itemID = 137274, glyph = 1240, label = "Glyph of Cracked Ice" },
    { itemID = 43551,  glyph = 529,  label = "Glyph of Foul Menagerie",    specs = {[252]=true} },
    { itemID = 139271, glyph = 1247, label = "Glyph of the Chilled Shell" },
    { itemID = 139270, glyph = 1246, label = "Glyph of the Crimson Shell" },
    { itemID = 43535,  glyph = 514,  label = "Glyph of the Geist",         specs = {[252]=true, [250]=true, [251]=true} },
    { itemID = 104099, glyph = 1074, label = "Glyph of the Skeleton",      specs = {[252]=true, [250]=true, [251]=true} },
  },
  [7] = { -- Shaman (262 Elemental, 263 Enhancement, 264 Restoration)
    { itemID = 139289, glyph = 1254, label = "Glyph of Critterhex" },
    { itemID = 232622, glyph = 1467, label = "Glyph of Energetic Ascendance", specs = {[262]=true, [263]=true, [264]=true} },
    { itemID = 137289, glyph = 1244, label = "Glyph of Flickering",        specs = {[262]=true} },
    { itemID = 104127, glyph = 1091, label = "Glyph of Lingering Ancestors" },
    { itemID = 137288, glyph = 1243, label = "Glyph of Pebbles" },
    { itemID = 217599, glyph = 1460, label = "Glyph of Primordial Wave",   specs = {[262]=true, [263]=true, [264]=true} },
    { itemID = 104126, glyph = 1090, label = "Glyph of Spirit Raptors",    specs = {[263]=true} },
    { itemID = 190378, glyph = 1426, label = "Glyph of the Spectral Lupine" },
    { itemID = 137287, glyph = 1242, label = "Glyph of the Spectral Raptor" },
    { itemID = 190380, glyph = 1427, label = "Glyph of the Spectral Vulpine" },
    { itemID = 43386,  glyph = 471,  label = "Glyph of the Spectral Wolf" },
    { itemID = 232527, glyph = 1466, label = "Glyph of Traditional Ascendance", specs = {[262]=true, [263]=true, [264]=true} },
  },
  [8] = { -- Mage (62 Arcane, 63 Fire, 64 Frost)
    { itemID = 232521, glyph = 1465, label = "Glyph of Arcane Familiar",   specs = {[62]=true} },
    { itemID = 42751,  glyph = 328,  label = "Glyph of Crittermorph" },
    { itemID = 167539, glyph = 1410, label = "Glyph of Dalaran Brilliance" },
    { itemID = 104105, glyph = 1080, label = "Glyph of Evaporation",       specs = {[64]=true} },
    { itemID = 172449, glyph = 1416, label = "Glyph of Lavish Servings" },
    { itemID = 139352, glyph = 1269, label = "Glyph of Polymorphic Proportions" },
    { itemID = 217586, glyph = 1452, label = "Glyph of Radiant Spark",     specs = {[62]=true} },
    { itemID = 217594, glyph = 1451, label = "Glyph of Shifting Power" },
    { itemID = 139348, glyph = 1267, label = "Glyph of Smolder",           specs = {[63]=true} },
    { itemID = 129019, glyph = 1266, label = "Glyph of Sparkles" },
    { itemID = 170165, glyph = 1413, label = "Glyph of Steaming Fury",     specs = {[64]=true} },
    { itemID = 166664, glyph = 1408, label = "Glyph of Storm's Wake",      specs = {[64]=true} },
    { itemID = 170168, glyph = 1414, label = "Glyph of the Cold Waves",    specs = {[64]=true} },
    { itemID = 170164, glyph = 1412, label = "Glyph of the Dark Depths",   specs = {[64]=true} },
    { itemID = 166583, glyph = 1407, label = "Glyph of the Tides",         specs = {[64]=true} },
    { itemID = 104104, glyph = 1079, label = "Glyph of the Unbound Elemental", specs = {[64]=true} },
  },
  [9] = { -- Warlock (265 Affliction, 266 Demonology, 267 Destruction)
    { itemID = 207101, glyph = 1440, label = "Glyph of Banehollow's Soulstone" },
    { itemID = 45789,  glyph = 761,  label = "Glyph of Crimson Banish" },
    { itemID = 151538, glyph = 1296, label = "Glyph of Ember Shards",      specs = {[267]=true} },
    { itemID = 151542, glyph = 1298, label = "Glyph of Fel-Touched Shards" },
    { itemID = 42459,  glyph = 278,  label = "Glyph of Felguard",          specs = {[266]=true} },
    { itemID = 151540, glyph = 1297, label = "Glyph of Floating Shards" },
    { itemID = 217600, glyph = 1461, label = "Glyph of Soul Rot",          specs = {[265]=true} },
    { itemID = 43394,  glyph = 482,  label = "Glyph of Soulwell" },
    { itemID = 137191, glyph = 1224, label = "Glyph of the Inquisitor's Eye" },
  },
  [10] = { -- Monk (268 Brewmaster, 269 Windwalker, 270 Mistweaver)
    { itemID = 139338, glyph = 1264, label = "Glyph of Crackling Crane Lightning" },
    { itemID = 129022, glyph = 1263, label = "Glyph of Crackling Ox Lightning" },
    { itemID = 87881,  glyph = 1045, label = "Glyph of Crackling Tiger Lightning" },
    { itemID = 217494, glyph = 1443, label = "Glyph of Faeline Stomp",     specs = {[269]=true, [270]=true} },
    { itemID = 87888,  glyph = 1041, label = "Glyph of Fighting Pose" },
    { itemID = 87883,  glyph = 1039, label = "Glyph of Honor" },
    { itemID = 232491, glyph = 1464, label = "Glyph of Jab",               specs = {[268]=true, [269]=true} },
    { itemID = 87885,  glyph = 1028, label = "Glyph of Rising Tiger Kick", specs = {[269]=true, [270]=true} },
    { itemID = 217595, glyph = 1453, label = "Glyph of Weapons of Order",  specs = {[268]=true} },
    { itemID = 139339, glyph = 1265, label = "Glyph of Yu'lon's Grace",    specs = {[268]=true} },
  },
  [11] = { -- Druid (102 Balance, 103 Feral, 104 Guardian, 105 Restoration)
    { itemID = 217592, glyph = 1449, label = "Glyph of Adaptive Swarm",    specs = {[103]=true, [105]=true} },
    { itemID = 136826, glyph = 1221, label = "Glyph of Autumnal Bloom",    specs = {[105]=true} },
    { itemID = 217585, glyph = 1448, label = "Glyph of Convoke the Spirits" },
    { itemID = 44922,  glyph = 613,  label = "Glyph of Stars" },
    { itemID = 184100, glyph = 1421, label = "Glyph of the Aerial Chameleon" },
    { itemID = 184097, glyph = 1420, label = "Glyph of the Aquatic Chameleon" },
    { itemID = 136825, glyph = 1220, label = "Glyph of the Feral Chameleon" },
    { itemID = 139278, glyph = 1252, label = "Glyph of the Forest Path" },
    { itemID = 211400, glyph = 1441, label = "Glyph of the Lunar Chameleon" },
    { itemID = 118061, glyph = 1206, label = "Glyph of the Sun",           specs = {[102]=true} },
    { itemID = 184096, glyph = 1419, label = "Glyph of the Swift Chameleon" },
    { itemID = 43334,  glyph = 432,  label = "Glyph of the Ursol Chameleon" },
    { itemID = 188164, glyph = 1423, label = "Glyph of the Wild Mushroom", specs = {[105]=true} },
    { itemID = 143750, glyph = 1288, label = "Glyph of Twilight Bloom",    specs = {[105]=true} },
  },
  [12] = { -- Demon Hunter (577 Havoc, 581 Vengeance, 1480 Devourer)
    { itemID = 129029, glyph = 1275, label = "Glyph of Crackling Flames" },
    { itemID = 217591, glyph = 1447, label = "Glyph of Elysian Decree" },
    { itemID = 139417, glyph = 1276, label = "Glyph of Fallow Wings" },
    { itemID = 129028, glyph = 1273, label = "Glyph of Fel Touched Souls", specs = {[577]=true, [581]=true} },
    { itemID = 139435, glyph = 1277, label = "Glyph of Fel Wings" },
    { itemID = 139437, glyph = 1279, label = "Glyph of Fel-Enemies" },
    { itemID = 139362, glyph = 1274, label = "Glyph of Mana Touched Souls", specs = {[577]=true, [581]=true} },
    { itemID = 139438, glyph = 1280, label = "Glyph of Shadow-Enemies" },
    { itemID = 139436, glyph = 1278, label = "Glyph of Tattered Wings" },
    { itemID = 203762, glyph = 1431, label = "Glyph of the Chosen Glaive", specs = {[577]=true, [581]=true} },
    { itemID = 217590, glyph = 1445, label = "Glyph of the Hunt" },
  },
}

---@class UnlockInfo
---@field itemID integer   the unlock item (Mark / Grimoire / travel glyph)
---@field quest integer    account-completed quest that grants the unlock
---@field spell integer    the unlock/appearance spell (reference)
---@field label string     item name (English; the probe verifies it live)

---@type table<integer, UnlockInfo[]>
ns.AppearanceUnlocks = {
  [9] = { -- Warlock — demon Grimoires (barbershop demon appearances)
    { itemID = 139314, quest = 76370, spell = 219460, label = "Grimoire of the Abyssal" },
    { itemID = 213016, quest = 79457, spell = 433534, label = "Grimoire of the Abyssal Darkglare" },
    { itemID = 212750, quest = 79359, spell = 432954, label = "Grimoire of the Ancient Observer" },
    { itemID = 208051, quest = 77180, spell = 417546, label = "Grimoire of the Antoran Felhunter" },
    { itemID = 212983, quest = 79443, spell = 433451, label = "Grimoire of the Blasted Observer" },
    { itemID = 212779, quest = 79374, spell = 433077, label = "Grimoire of the Bloodrage Tyrant" },
    { itemID = 207178, quest = 76743, spell = 416352, label = "Grimoire of the Darkfire Imp" },
    { itemID = 212991, quest = 79447, spell = 433467, label = "Grimoire of the Dire Observer" },
    { itemID = 207295, quest = 76744, spell = 416364, label = "Grimoire of the Dreadfire Imp" },
    { itemID = 213015, quest = 79456, spell = 433533, label = "Grimoire of the Eredathian Darkglare" },
    { itemID = 129018, quest = 76369, spell = 219425, label = "Grimoire of the Fel Imp" },
    { itemID = 207297, quest = 76746, spell = 416368, label = "Grimoire of the Felblaze Imp" },
    { itemID = 212780, quest = 79375, spell = 433081, label = "Grimoire of the Felbrute Tyrant" },
    { itemID = 207294, quest = 76747, spell = 416360, label = "Grimoire of the Felfrost Imp" },
    { itemID = 207114, quest = 76742, spell = 416344, label = "Grimoire of the Fiendish Imp" },
    { itemID = 207111, quest = 76737, spell = 416330, label = "Grimoire of the Hellfire Fel Imp" },
    { itemID = 212989, quest = 79446, spell = 433456, label = "Grimoire of the Mana-Gorged Observer" },
    { itemID = 207296, quest = 76745, spell = 416366, label = "Grimoire of the Netherbound Imp" },
    { itemID = 212783, quest = 79376, spell = 433083, label = "Grimoire of the Netherwalk Tyrant" },
    { itemID = 212993, quest = 79449, spell = 433468, label = "Grimoire of the Plagued Observer" },
    { itemID = 213017, quest = 79458, spell = 433535, label = "Grimoire of the Riftsmolder Darkglare" },
    { itemID = 147119, quest = 76372, spell = 240271, label = "Grimoire of the Shadow Succubus" },
    { itemID = 139310, quest = 76373, spell = 219437, label = "Grimoire of the Shivarra" },
    { itemID = 207113, quest = 76741, spell = 416339, label = "Grimoire of the Trickster Fel Imp" },
    { itemID = 207112, quest = 76740, spell = 416336, label = "Grimoire of the Void-Touched Fel Imp" },
    { itemID = 139311, quest = 76375, spell = 219446, label = "Grimoire of the Voidlord" },
    { itemID = 208052, quest = 77181, spell = 417547, label = "Grimoire of the Voracious Felmaw" },
    { itemID = 139315, quest = 76376, spell = 219468, label = "Grimoire of the Wrathguard" },
    { itemID = 208050, quest = 77183, spell = 417529, label = "Grimoire of the Xorothian Felhunter" },
    { itemID = 147117, quest = 76377, spell = 240268, label = "Orb of the Fel Temptress" },
    { itemID = 212778, quest = 79373, spell = 433076, label = "Grimoire of the Vile Tyrant" },
    { itemID = 208048, quest = 77182, spell = 417510, label = "Ritual of the Voidmaw Felhunter" },
    { itemID = 212995, quest = 79450, spell = 433469, label = "Grimoire of the Whispering Observer" },
    { itemID = 213014, quest = 79455, spell = 433532, label = "Grimoire of the Xorothian Darkglare" },
    { itemID = 212984, quest = 79444, spell = 433452, label = "Grimoire of the Zealous Observer" },
  },
  [11] = { -- Druid — travel-form glyphs + barbershop shapeshift Marks
    { itemID = 210645, quest = 78479, spell = 426328, label = "Feather of Friends" },
    { itemID = 210754, quest = 78527, spell = 426478, label = "Feather of the Blazing Somnowl" },
    { itemID = 211280, quest = 78525, spell = 428622, label = "Feather of the Smoke Red Moon" },
    { itemID = 89868,  quest = 62677, spell = 131151, label = "Glyph of the Cheetah" },
    { itemID = 140630, quest = 62678, spell = 224123, label = "Glyph of the Doe" },
    { itemID = 162022, quest = 62674, spell = 276058, label = "Glyph of the Dolphin" },
    { itemID = 162029, quest = 62676, spell = 276120, label = "Glyph of the Humble Flyer" },
    { itemID = 40919,  quest = 62673, spell = 54872,  label = "Glyph of the Orca" },
    { itemID = 129021, quest = 62675, spell = 219064, label = "Glyph of the Sentinel" },
    { itemID = 162027, quest = 62672, spell = 276087, label = "Glyph of the Tideskipper" },
    { itemID = 210735, quest = 78523, spell = 426476, label = "Mark of the Auric Dreamstag" },
    { itemID = 211081, quest = 78514, spell = 428050, label = "Mark of the Auroral Dreamtalon" },
    { itemID = 211080, quest = 78512, spell = 428045, label = "Mark of the Boreal Dreamtalon" },
    { itemID = 210683, quest = 78513, spell = 426455, label = "Mark of the Dreamtalon Matriarch" },
    { itemID = 187933, quest = 65058, spell = 360883, label = "Mark of the Duskwing Raven" },
    { itemID = 210669, quest = 78507, spell = 426426, label = "Mark of the Evergreen Dreamsaber" },
    { itemID = 187887, quest = 65048, spell = 360543, label = "Mark of the Gloomstalker Dredbat" },
    { itemID = 210751, quest = 78528, spell = 426483, label = "Mark of the Hibernating Runebear" },
    { itemID = 210650, quest = 78503, spell = 426354, label = "Mark of the Keen-Eyed Dreamsaber" },
    { itemID = 210738, quest = 78519, spell = 426465, label = "Mark of the Loamy Umbraclaw" },
    { itemID = 210731, quest = 78522, spell = 426475, label = "Mark of the Lush Dreamstag" },
    { itemID = 187934, quest = 65061, spell = 360895, label = "Mark of the Midnight Runestag" },
    { itemID = 187931, quest = 65059, spell = 360881, label = "Mark of the Regal Dredbat" },
    { itemID = 187936, quest = 65062, spell = 360900, label = "Mark of the Sable Ardenmoth" },
    { itemID = 210674, quest = 78511, spell = 426439, label = "Mark of the Sable Dreamtalon" },
    { itemID = 187888, quest = 64987, spell = 360547, label = "Mark of the Shimmering Ardenmoth" },
    { itemID = 210535, quest = 78448, spell = 426075, label = "Mark of the Slumbering Somnowl" },
    { itemID = 210736, quest = 78524, spell = 426477, label = "Mark of the Smoldering Dreamstag" },
    { itemID = 210739, quest = 78520, spell = 426473, label = "Mark of the Snowy Umbraclaw" },
    { itemID = 210684, quest = 78515, spell = 426457, label = "Mark of the Thriving Dreamtalon" },
    { itemID = 187884, quest = 64986, spell = 360541, label = "Mark of the Twilight Runestag" },
    { itemID = 210647, quest = 78481, spell = 426335, label = "Mark of the Umbramane" },
    { itemID = 210729, quest = 78517, spell = 426460, label = "Mark of the Verdant Bristlebruin" },
    { itemID = 210728, quest = 78521, spell = 426485, label = "Moon-Blessed Claw" },
    { itemID = 210727, quest = 78518, spell = 426462, label = "Pollenfused Bristlebruin Fur Sample" },
    { itemID = 210753, quest = 78516, spell = 426459, label = "Scale of the Prismatic Whiskerfish" },
  },
}

-- Merge the class's applied-glyph catalog with a character's applied-glyph-id set into a
-- status list, filtered to `specID` (nil = keep all) and preserving catalog order. Pure —
-- no WoW API — so it's unit-tested (spec/glyphs.lua).
---@param list GlyphInfo[]?                 the class's glyph catalog
---@param specID integer?                   active spec to filter to (nil = include every entry)
---@param applied table<integer, boolean>?  the character's applied glyph ids (nil = none scanned)
---@return { itemID: integer, label: string, glyph: integer, applied: boolean }[]
function ns.MergeGlyphStatus(list, specID, applied)
  local out = {}
  for _, e in ipairs(list or {}) do
    if not e.specs or not specID or e.specs[specID] then
      out[#out + 1] = {
        itemID = e.itemID,
        label = e.label,
        glyph = e.glyph,
        applied = applied ~= nil and applied[e.glyph] == true or false,
      }
    end
  end
  return out
end

-- Per-character *learned* class unlocks — items/skills that permanently grant an ability to the
-- character (a "Use: Teaches you …" tome, a crafted matrix, a looted knowledge), so the state is
-- PER CHARACTER, detected via C_SpellBook.IsSpellKnown on the granted spell. Two sets today:
--   * Druid "Tome of the Wilds" (Treant Form + Mount Form are the modern successors to the
--     removed Glyph of the Treant / Glyph of the Stag).
--   * Hunter "Tomes & Tames" — two kinds: Skill Tames (special pet families that need an unlock
--     before taming — Blood Beasts, Feathermanes, Direhorns, Mechanicals, Gargon, Cloud Serpents,
--     Undead, Dragonkin, Nah'qi, Florafaun) and utility ability tomes (Aspect of the Chameleon,
--     Fetch). Abilities with no collectible item — Eyes of the Beast (baseline at 29) and Ottuk
--     Taming (Renown-granted) — are excluded, since every entry needs a real item to show.
-- Keyed by classId → { itemID, spell, label, races? }. `spell` = the granted spell (IsSpellKnown
-- target); `races` (Mechanicals) = race file tokens that grant it innately (Goblin/Gnome hunters
-- tame Mechanicals without the matrix). `ns.LearnedUnlockTitle` names the per-class card section.
-- Ids from Wowhead; verified in-game via `/wbc dump glyphs`.
---@class UnlockLearn
---@field itemID integer   the unlock item
---@field spell integer    the granted spell (the IsSpellKnown target)
---@field label string     display name (pet family / form; the probe verifies the item live)
---@field races table<string, boolean>?  race file tokens that grant it innately (no item needed)

---@type table<integer, UnlockLearn[]>
ns.LearnedUnlocks = {
  [3] = { -- Hunter — Skill Tames + utility ability tomes (title "Tomes & Tames")
    -- Skill Tames — special pet families that require an unlock before taming.
    { itemID = 166502, spell = 288956,  label = "Blood Beasts" },
    { itemID = 147580, spell = 242155,  label = "Feathermanes" },   -- Hybrid Kinship (BM-only exotic)
    { itemID = 94232,  spell = 138430,  label = "Direhorns" },      -- Ancient Zandalari Knowledge
    -- Mecha-Bond Imprint Matrix; Goblin/Gnome hunters tame Mechanicals innately. (Spell id may be
    -- 209646 on 12.0.5+ — the probe confirms which resolves live.)
    { itemID = 134125, spell = 205154,  label = "Mechanicals", races = { Goblin = true, Gnome = true } },
    { itemID = 180705, spell = 334850,  label = "Gargon" },         -- Gargon Training Manual
    { itemID = 183123, spell = 340826,  label = "Cloud Serpents" }, -- How to School Your Serpent
    { itemID = 183124, spell = 340825,  label = "Undead" },         -- Simple Tome of Bone-Binding
    { itemID = 201791, spell = 394788,  label = "Dragonkin" },      -- How to Train a Dragonkin
    { itemID = 211314, spell = 428736,  label = "Nah'qi" },         -- Cinder of Companionship
    { itemID = 264895, spell = 1272785, label = "Florafaun" },      -- Trials of the Florafaun Hunter
    -- Utility ability tomes — teach a hunter/pet skill (not a tame); sold by the Nesingwary vendors.
    { itemID = 136783, spell = 61648,   label = "Aspect of the Chameleon" }, -- The Art of Concealment
    { itemID = 136781, spell = 125050,  label = "Fetch" },                   -- Pet Training Manual: Fetch
  },
  [11] = { -- Druid — Tome of the Wilds
    { itemID = 136787, spell = 114282, label = "Treant Form" },
    { itemID = 136789, spell = 210053, label = "Mount Form" },
    { itemID = 136794, spell = 164862, label = "Flap" },
    { itemID = 136795, spell = 127757, label = "Charm Woodland Creature" },
    { itemID = 136790, spell = 210065, label = "Track Beasts" },
  },
}

-- Per-class section title for the learned-unlock catalog (the Detail card header).
---@type table<integer, string>
ns.LearnedUnlockTitle = {
  [3]  = "Tomes & Tames",
  [11] = "Tome of the Wilds",
}

-- Merge a class's learned-unlock catalog with a character's known-spell set into a status list,
-- preserving order. Pure — no WoW API — so it's unit-tested (spec/glyphs.lua). The known set
-- already folds in any race-innate unlocks (the broker stamps those), so this only reads it.
---@param list UnlockLearn[]?              the class's learned-unlock catalog
---@param known table<integer, boolean>?   the character's known unlock spell ids (nil = none scanned)
---@return { itemID: integer, label: string, spell: integer, known: boolean }[]
function ns.MergeLearnedStatus(list, known)
  local out = {}
  for _, e in ipairs(list or {}) do
    out[#out + 1] = {
      itemID = e.itemID,
      label = e.label,
      spell = e.spell,
      known = known ~= nil and known[e.spell] == true or false,
    }
  end
  return out
end
