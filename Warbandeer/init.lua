local ADDON_NAME, ns = ...
-- luacheck: globals LibNAddOn LibNUI WarbandeerApi

local Views = {"Overview", "Races", "Summary", "Gear", "Detail", "Roles", "Professions"}

LibNAddOn{
  name = ADDON_NAME,
  addOn = ns,
  settings = {
    {
      title = "Warbandeer",
      fields = {
        {
          name = "Default View",
          typ = "dropdown",
          default = 1,
          table = function(db) return db.settings end,
          key = "defaultView",
          label = "default view",
          tooltip = "View to open by default",
          options = Views,
        },
      },
    },
  },
}

ns.views = {}

-- https://wowpedia.fandom.com/wiki/Category:HOWTOs
-- addon compartment, settings scroll templates: https://warcraft.wiki.gg/wiki/Patch_10.1.0/API_changes
-- settings changes: https://warcraft.wiki.gg/wiki/Patch_11.0.2/API_changes

-- https://wowpedia.fandom.com/wiki/Create_a_WoW_AddOn_in_15_Minutes#Options_Panel

local unpack, Generate, Map, Select = unpack, ns.lua.lists.generate, ns.lua.maps.map, ns.lua.Select
local GetClassInfo, GetClassColor = GetClassInfo, C_ClassColor.GetClassColor

-- class colors: https://wowpedia.fandom.com/wiki/Class_colors

ns.ALLIANCE_RACES = {
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
}

ns.HORDE_RACES = {
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
}

ns.CLASSES = Generate(
  function(i)
    local n, id = GetClassInfo(i)
    local c = GetClassColor(id)
    return {name = n, id = id, color = c}
  end,
  GetNumClasses()
)
ns.CLASS_NAMES = Map(ns.CLASSES, Select("name"))

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

function ns.NormalizeRaceId(raceId)
  return unpack(raceIdToFactionIndex[raceId])
end

function ns:settingChanged(key, value) --, setting
  ns.Print("setting changed", key, value)
end

function ns:MigrateDB()
  local db = self.db
  if not db.version then
    db.settings = {}
    db.settings.defaultView = 1
    db.version = 1
  end
end

function ns:onLoad(self)
  ns.api.SettingsCategory = ns.settingsCategory
end
