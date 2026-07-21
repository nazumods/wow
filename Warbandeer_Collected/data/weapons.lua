---@type Warbandeer_Collected
local ns = select(2, ...)
local tinsert = tinsert

-- Class weapon cosmetics — enchant illusions + Legion "arsenal" weapon appearances —
-- surfaced as two extra grid groups under a new "Weapons" category (#516). They live on
-- a DIFFERENT API surface than the C_TransmogSets-backed armor sets: illusions via
-- C_TransmogCollection.GetIllusionInfo, arsenal weapons via PlayerHasTransmog. So each
-- group carries a `kind` discriminator ("illusion"/"arsenal") that ns:Scan branches on
-- (see commands.lua ns:_scanWeaponSet) and that ShowInfoTip / ShowDressingRoom key off.
--
-- IDs are SYNTHETIC and deliberately in a high range: real C_TransmogSets set ids and
-- wago group ids are all < ~100000, so 9_000_0xx can't collide in db.sets or the
-- wanted/rank tables (both keyed by the globally-unique setId). Illusion sourceIDs and
-- weapon itemIDs are the owned-check inputs and never index db.sets.
--
-- `grp.sets` is POSITIONAL: index = classId (1 Warrior .. 13 Evoker), {} where a class
-- has no collectible. CollectedRows renders index i in class column i and pads the rest.
--
-- Illusion cells carry a hard `sourceID` (confirmed 2026-07-18) and are checked via
-- GetIllusionInfo(sourceID).isCollected, which reads ACCOUNT-WIDE and CROSS-CLASS.
-- (GetIllusions() only enumerates the CURRENT character's usable illusions, so matching
-- names against it can't see a class illusion on the wrong class — hence hard ids.
-- Gathered by dumping GetIllusions() on each class; ids run ~5000+, unrelated to the
-- smaller DBC record ids from earlier research.)

local GID_ILLUSIONS, GID_ARSENALS = 9000001, 9000002

tinsert(ns.Sets, {
  id = GID_ILLUSIONS,
  name = "Illusions",
  release = 7,             -- Legion
  category = "Weapons",
  kind = "illusion",
  sets = {
    {}, {}, {},                                                         -- 1 Warrior, 2 Paladin, 3 Hunter
    { id = 9000104, classId = 4, name = "Illusion: Poisoned",           -- 4 Rogue
      obtain = "Rogue only — the applied weapon-poison shimmer",
      illusions = { { sourceID = 5364 } } },
    {},                                                                 -- 5 Priest
    { id = 9000106, classId = 6, name = "Illusion: Rune of Razorice",   -- 6 Death Knight
      obtain = "Death Knight only — the Rune of Razorice runeforge",
      illusions = { { sourceID = 5869 } } },
    { id = 9000107, classId = 7, name = "Shaman Weapon Imbues",         -- 7 Shaman (5 brands)
      obtain = "Shaman only — weapon imbues (Flametongue, Frostbrand, etc.)",
      illusions = {
        { sourceID = 5872 },   -- Flametongue
        { sourceID = 5873 },   -- Frostbrand
        { sourceID = 5871 },   -- Earthliving
        { sourceID = 5875 },   -- Windfury
        { sourceID = 5874 },   -- Rockbiter
      } },
    -- 8..13 padded blank by CollectedRows
  },
})

tinsert(ns.Sets, {
  id = GID_ARSENALS,
  name = "Arsenals",
  release = 7,             -- Legion
  category = "Weapons",
  kind = "arsenal",
  sets = {
    {},                                                                 -- 1 Warrior
    { id = 9000202, classId = 2, name = "Arsenal: Armaments of the Silver Hand",  -- 2 Paladin
      arsenal = 141371,
      obtain = "Broken Shore — bought from Warmage Kath'leen for Nethershards",
      pieces = { 141653, 141654, 141368, 141367, 141370, 150953 } },   -- verify 150953 (Ardent Gavel, an ID outlier) in-game
    {}, {}, {},                                                         -- 3 Hunter, 4 Rogue, 5 Priest
    { id = 9000206, classId = 6, name = "Arsenal: Armaments of the Ebon Blade",   -- 6 Death Knight
      arsenal = 141372,
      obtain = "Broken Shore — bought from Warmage Kath'leen for Nethershards",
      pieces = {   -- 5 weapon types x 3 tints (Bloodied / Icy / Unholy), itemIDs 141362-141382
        141375, 141379, 141366, 141377, 141365,   -- Bloodied  Warsword/Warblade/Halberd/Blade/Axe
        141376, 141363, 141373, 141362, 141381,   -- Icy
        141364, 141380, 141374, 141378, 141382,   -- Unholy
      } },
    {}, {}, {}, {}, {},                                                 -- 7 Shaman .. 11 Druid
    { id = 9000212, classId = 12, name = "Arsenal: The Warglaives of Azzinoth",   -- 12 Demon Hunter
      arsenal = 150372,
      obtain = "Black Temple, Burning Crusade Timewalking — drops from Illidan Stormrage",
      pieces = { 151137, 151138 } },   -- DH 7.2.5 main-hand + off-hand; verify vs the TBC pair 32837/32838 in-game
    -- 13 Evoker padded blank
  },
})
