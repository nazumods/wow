---@type Warbandeer_Collected
local ns = select(2, ...)
local GetRaceInfo = C_CreatureInfo.GetRaceInfo

-- Per race+gender creature display IDs for the dressing room (sex keys follow
-- UnitSex: 2 = male, 3 = female). This is an ENHANCEMENT, not a requirement: a
-- race listed here gets exact gender selection (DressingRoom:Dress → DisplayInfo);
-- a race absent here still renders correctly via a customRaceID-overridden player
-- unit, but its gender follows the logged-in character.
--
-- There is no API to derive these — they are hand-maintained, so VERIFY IN-GAME.
-- The allied-race ids below are taken from Blizzard's Allied Races recruitment UI
-- (Blizzard_AlliedRacesFrameUI.lua's Actor_X_ModelID), so they are trustworthy;
-- core-race ids are not exposed by the client UI and are intentionally left out
-- until confirmed in-game (those races fall back to the textured customRaceID path).
---@class Warbandeer_Collected
---@field RaceModels table<number, table<number, number>>  [raceID][sex] = creatureDisplayID
ns.RaceModels = {
  [27] = { [2] = 82708,  [3] = 82709  }, -- Nightborne
  [28] = { [2] = 82733,  [3] = 82731  }, -- Highmountain Tauren
  [31] = { [2] = 89631,  [3] = 89632  }, -- Zandalari Troll
  [35] = { [2] = 94257,  [3] = 94256  }, -- Vulpera
  [36] = { [2] = 86343,  [3] = 86342  }, -- Mag'har Orc
  [37] = { [2] = 94370,  [3] = 94371  }, -- Mechagnome
  [84] = { [2] = 121634, [3] = 121635 }, -- Earthen (Dwarf)
}

-- Display order for the selector, grouped Alliance → Horde → neutral. One id per
-- distinct model (Pandaren/Dracthyr/Earthen collapse their faction variants).
-- Any id GetRaceInfo doesn't recognise on this client is skipped, so newer races
-- degrade gracefully instead of erroring.
local ORDER = {
  1, 3, 4, 7, 11, 22, 29, 30, 32, 34, 37,   -- Alliance + allied
  2, 5, 6, 8, 9, 10, 27, 28, 31, 35, 36,    -- Horde + allied
  25, 52, 84,                               -- Pandaren, Dracthyr, Earthen
}

---Ordered playable-race list for the dressing-room selector.
---@class Warbandeer_Collected
---@field PlayableRaces fun(): table[]  list of { id, name, file } (file = lowercased clientFileString)
ns.PlayableRaces = function()
  local out = {}
  for _, id in ipairs(ORDER) do
    local info = GetRaceInfo(id)
    if info and info.clientFileString and info.clientFileString ~= "" then
      out[#out + 1] = { id = id, name = info.raceName, file = info.clientFileString:lower() }
    end
  end
  return out
end
