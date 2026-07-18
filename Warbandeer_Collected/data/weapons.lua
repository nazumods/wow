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
-- Illusion cells resolve their sourceID at scan/hover time by matching the illusion NAME
-- substring (`match`) against C_TransmogCollection.GetIllusions() (cached — see
-- ns._resolveIllusion). Zero-maintenance and works on enUS out of the box; a hard
-- `sourceID` on a piece overrides the match for locale-independence (fill from
-- `/dump C_TransmogCollection.GetIllusions()` if a non-enUS client ever needs it).

local GID_ILLUSIONS, GID_ARSENALS = 9000001, 9000002

tinsert(ns.Sets, {
  id = GID_ILLUSIONS,
  name = "Illusions",
  release = 7,             -- Legion
  category = "Weapons",
  kind = "illusion",
  sets = {
    {}, {}, {},                                                         -- 1 Warrior, 2 Paladin, 3 Hunter
    -- Candidate illusion sourceIDs from #504 research (verify vs `/dump C_TransmogCollection.GetIllusions()`,
    -- then add `sourceID = N` to a piece for locale-safe resolution): Poisoned 35, Razorice 51,
    -- Earthliving 52, Flametongue 53, Frostbrand 54, Rockbiter 55, Windfury 56. Until verified, the
    -- cached name substring `match` resolves the real sourceID at runtime (enUS).
    { id = 9000104, classId = 4, name = "Illusion: Poisoned",           -- 4 Rogue
      illusions = { { match = "Poisoned" } } },
    {},                                                                 -- 5 Priest
    { id = 9000106, classId = 6, name = "Illusion: Rune of Razorice",   -- 6 Death Knight
      illusions = { { match = "Razorice" } } },
    { id = 9000107, classId = 7, name = "Shaman Weapon Imbues",         -- 7 Shaman (5 brands)
      illusions = {
        { match = "Flametongue" }, { match = "Frostbrand" }, { match = "Earthliving" },
        { match = "Windfury" },    { match = "Rockbiter" },
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
      pieces = { 141653, 141654, 141368, 141367, 141370, 150953 } },   -- verify 150953 (Ardent Gavel, an ID outlier) in-game
    {}, {}, {},                                                         -- 3 Hunter, 4 Rogue, 5 Priest
    { id = 9000206, classId = 6, name = "Arsenal: Armaments of the Ebon Blade",   -- 6 Death Knight
      arsenal = 141372,
      pieces = {   -- 5 weapon types x 3 tints (Bloodied / Icy / Unholy), itemIDs 141362-141382
        141375, 141379, 141366, 141377, 141365,   -- Bloodied  Warsword/Warblade/Halberd/Blade/Axe
        141376, 141363, 141373, 141362, 141381,   -- Icy
        141364, 141380, 141374, 141378, 141382,   -- Unholy
      } },
    {}, {}, {}, {}, {},                                                 -- 7 Shaman .. 11 Druid
    { id = 9000212, classId = 12, name = "Arsenal: The Warglaives of Azzinoth",   -- 12 Demon Hunter
      arsenal = 150372,
      pieces = { 151137, 151138 } },   -- DH 7.2.5 main-hand + off-hand; verify vs the TBC pair 32837/32838 in-game
    -- 13 Evoker padded blank
  },
})
