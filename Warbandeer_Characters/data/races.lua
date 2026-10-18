---@type Warbandeer_Characters
local ns = select(2, ...)
local unpack = unpack
local API = ns.api

API.ALLIANCE_RACES = {
  "Human",
  "Dwarf",
  "Night Elf",
  "Gnome",
  "Draenei",
  "Worgen",
  "Pandaren",
  "Void Elf",
  "Lightforged Draenei",
  "Dark Iron Dwarf",
  "Kul Tiran",
  "Mechagnome",
  "Dracthyr",
  "Earthen",
  "Haranir",
}

API.HORDE_RACES = {
  "Orc",
  "Undead",
  "Tauren",
  "Troll",
  "Blood Elf",
  "Goblin",
  "Pandaren",
  "Nightborne",
  "Highmountain Tauren",
  "Mag'har Orc",
  "Zandalari Troll",
  "Vulpera",
  "Dracthyr",
  "Earthen",
  "Haranir",
}

-- index, isAlliance
local raceIdToFactionIndex = {
  {1, true},
  {1, false},
  {2, true},
  {3, true},
  {2, false}, -- 5
  {3, false},
  {4, true},
  {4, false},
  {6, false},
  {5, false}, -- 10
  {5, true},
}
raceIdToFactionIndex[22] = {6, true}
raceIdToFactionIndex[25] = {7, true}
raceIdToFactionIndex[26] = {7, false}
raceIdToFactionIndex[27] = {8, false}
raceIdToFactionIndex[28] = {9, false}
raceIdToFactionIndex[29] = {8, true}
raceIdToFactionIndex[30] = {9, true}
raceIdToFactionIndex[31] = {11, false}
raceIdToFactionIndex[32] = {11, true}
raceIdToFactionIndex[34] = {10, true}
raceIdToFactionIndex[35] = {12, false}
raceIdToFactionIndex[36] = {10, false}
raceIdToFactionIndex[37] = {12, true}
raceIdToFactionIndex[52] = {13, true}
raceIdToFactionIndex[70] = {13, false}
raceIdToFactionIndex[84] = {14, false}
raceIdToFactionIndex[85] = {14, true}
raceIdToFactionIndex[86] = {15, true} -- Haranir (Alliance)
raceIdToFactionIndex[91] = {15, false} -- Haranir (Horde); 87 is a non-race creature ("Delver's Dirigible")

-- Forever's playable races (#958): the eight original races and the Skyborne, one per faction. Its client
-- data names them: the Camelot glue-screen race tags and new-player starting quests (wow-ui-source `forever`
-- branch, Blizzard_GlueParent/Camelot/GlueScreenTags.lua, Blizzard_NewPlayerExperience/Camelot/
-- Blizzard_TutorialData.lua), and CharBaseInfo (1.60.1.70374) lists exactly these ten race ids: 1-8, 95 "High
-- Order Skyborne" (Alliance) and 96 "Windshaper Skyborne" (Horde) in ChrRaces. The original eight keep their
-- Retail indexes. The Skyborne ids are deliberately left out of the id map: they keep raceIdx 0, the value every
-- revision that loads on Forever stored for them, so rolling back reads the same data; the Races tab puts a character with no
-- index on its side's row named by its race token ("Skyborne"). Any other id (a Retail-only race) is 0 too.
if ns.flavor and ns.flavor.isForever then
  API.ALLIANCE_RACES = { "Human", "Dwarf", "Night Elf", "Gnome", "Skyborne" }
  API.HORDE_RACES = { "Orc", "Undead", "Tauren", "Troll", "Skyborne" }
  raceIdToFactionIndex = {
    {1, true}, {1, false}, {2, true}, {3, true}, {2, false}, {3, false}, {4, true}, {4, false},
  }
end

---Map a WoW raceId to its compact per-faction race index and faction.
---@class Warbandeer_Characters
---@field NormalizeRaceId fun(raceId: integer): integer, boolean raceIdx (index into API.ALLIANCE_RACES/HORDE_RACES), isAlliance
function ns.NormalizeRaceId(raceId)
  local entry = raceIdToFactionIndex[raceId]
  if entry then return unpack(entry) end
  -- Forward-compat: a newly-added race the table hasn't caught up to. Derive faction from the
  -- API so login never crashes; raceIdx 0 makes callers fall back to the raw race name.
  local faction = C_CreatureInfo.GetFactionInfo(raceId)
  return 0, faction ~= nil and faction.groupTag == "Alliance"
end
