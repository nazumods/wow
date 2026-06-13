---@type Warbandeer_Collected
local ns = select(2, ...)
local GetRaceInfo = C_CreatureInfo.GetRaceInfo

-- Per race+gender creature display IDs for the dressing room. Sex keys follow
-- UnitSex: 2 = male, 3 = female. This is an ENHANCEMENT: a race listed here gets
-- exact race+gender selection (DressingRoom:Dress → DisplayInfo); a race absent
-- here still renders via a customRaceID-overridden player unit, but its gender
-- then follows the logged-in character.
--
-- These must be PRE-BAKED display ids (a CreatureDisplayInfo whose
-- ExtendedDisplayInfoID != 0 — it carries the race+gender's own baked textures).
-- A bare ChrModel base display renders WHITE here: SetModelByCreatureDisplayID
-- only composites textures from the active player's customizations, which match
-- only the player's own race. So `Dress` renders these with customizations OFF.
--
-- Entry shapes:
--   single form  → { [2] = maleID, [3] = femaleID }
--   multi form   → { forms = { { name, [2], [3] }, ... } }  (Worgen, Dracthyr)
-- The dressing room shows a form toggle when `forms` is present. An optional
-- `scale` (on the entry, or on a single form) corrects sizing — the borrowed
-- dressup scene renders every race through one player-sized actor, so large races
-- come out too small. `scale` is either a number (both genders) or a per-sex table
-- `{ [2] = male, [3] = female }` (omit a sex that's fine at 1). Tune live with the
-- scale slider or `/collected scale <n>`; omit entirely when 1.
--
-- Hand-maintained, VERIFY IN-GAME. The 7 allied ids are recruitment-screen
-- showcase displays (Blizzard_AlliedRacesFrameUI.lua's Actor_X_ModelID). The rest
-- were derived from DB2: base ChrModel.DisplayID → its ModelID → the first baked
-- CreatureDisplayInfo sharing that ModelID *with CreatureModelScale == 1* (so the
-- races size consistently — scaled NPC variants are skipped). Each is still a
-- specific NPC, so a pick can look odd — swap to another baked display of the same
-- model if so. `Dress` calls Undress after loading, since these arrive in the
-- NPC's gear.
---@class Warbandeer_Collected
---@field RaceModels table<number, table>  [raceID] = { [2],[3], scale? } | { forms = {{name,[2],[3],scale?},...} }
ns.RaceModels = {
  -- Allied races (recruitment-screen showcase ids, hand-verified).
  [27] = { [2] = 82708,  [3] = 82709  }, -- Nightborne
  [28] = { [2] = 82733,  [3] = 82731,  scale = { [2] = 0.60, [3] = 0.75 } }, -- Highmountain Tauren (run big)
  [31] = { [2] = 89631,  [3] = 89632,  scale = 0.85 }, -- Zandalari Troll (run big)
  [35] = { [2] = 94257,  [3] = 94256,  scale = 1.4 }, -- Vulpera (run small)
  [36] = { [2] = 86343,  [3] = 86342  }, -- Mag'har Orc
  [37] = { [2] = 94370,  [3] = 94371,  scale = 1.6 }, -- Mechagnome (run small)
  [84] = { [2] = 121634, [3] = 121635, scale = 1.3 }, -- Earthen (Dwarf, run small)

  -- Core + remaining allied races: first baked display per race+gender (VERIFY/curate).
  [1]  = { [2] = 1276,  [3] = 176,   scale = { [3] = 1.1 } }, -- Human (♀ runs small)
  [2]  = { [2] = 1139,  [3] = 1312  }, -- Orc
  [3]  = { [2] = 115,   [3] = 1286,  scale = 1.20 }, -- Dwarf (both run small)
  [4]  = { [2] = 1285,  [3] = 1543,  scale = { [2] = 0.95 } }, -- Night Elf (♂ runs big)
  [5]  = { [2] = 1027,  [3] = 1029  }, -- Undead
  [6]  = { [2] = 1624,  [3] = 1905,  scale = 0.75 }, -- Tauren (run big)
  [7]  = { [2] = 1832,  [3] = 1890,  scale = 1.5 }, -- Gnome (run small)
  [8]  = { [2] = 1976,  [3] = 1882  }, -- Troll
  [9]  = { [2] = 6882,  [3] = 7175,  scale = 1.4 }, -- Goblin (run small)
  [10] = { [2] = 10375, [3] = 15505 }, -- Blood Elf
  [11] = { [2] = 16199, [3] = 16200, scale = { [2] = 0.9 } }, -- Draenei (♂ runs big)
  [25] = { [2] = 39574, [3] = 39705 }, -- Pandaren
  [29] = { [2] = 80975, [3] = 80977, scale = { [2] = 1.1, [3] = 1.15 } }, -- Void Elf
  [30] = { [2] = 76240, [3] = 76338, scale = { [2] = 0.9 } }, -- Lightforged Draenei (♂ runs big)
  [32] = { [2] = 78517, [3] = 77936, scale = { [2] = 0.9 } }, -- Kul Tiran (♂ runs big)
  [34] = { [2] = 8803,  [3] = 69941, scale = 1.4 }, -- Dark Iron Dwarf (run small)

  -- Worgen: two forms. Human form reuses the Human (race 1) baked displays.
  [22] = { forms = {
    { name = "Worgen", [2] = 30164, [3] = 31689, scale = 0.95 },
    { name = "Human",  [2] = 1276,  [3] = 176   },
  } },

  -- Dracthyr (52): no baked display ids yet (its visage ids render white), so it
  -- still uses the textured player fallback (gender follows the char). A scale-only
  -- entry just sizes that fallback; baked ids + form toggle (visage/dragon) TBD.
  [52] = { scale = 0.7 }, -- Dracthyr (fallback render)
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

-- The race-icon atlas suffix (raceicon-<suffix>-male) doesn't always match the
-- lowercased clientFileString — override the mismatches (verified against the
-- UiTextureAtlasMember DB2). Keyed by clientFileString.
local ICON_ATLAS = {
  Scourge            = "undead",
  HighmountainTauren = "highmountain",
  ZandalariTroll     = "zandalari",
  LightforgedDraenei = "lightforged",
  EarthenDwarf       = "earthen",
}

---Ordered playable-race list for the dressing-room selector.
---@class Warbandeer_Collected
---@field PlayableRaces fun(): table[]  list of { id, name, file } (file = race-icon atlas suffix)
ns.PlayableRaces = function()
  local out = {}
  for _, id in ipairs(ORDER) do
    local info = GetRaceInfo(id)
    if info and info.clientFileString and info.clientFileString ~= "" then
      local file = (ICON_ATLAS[info.clientFileString] or info.clientFileString):lower()
      out[#out + 1] = { id = id, name = info.raceName, file = file }
    end
  end
  return out
end
