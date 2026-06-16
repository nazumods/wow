---@type Warbandeer_Collected
local ns = select(2, ...)
local GetRaceInfo = C_CreatureInfo.GetRaceInfo

-- Per race+gender creature display IDs for the dressing room. Sex keys follow
-- UnitSex: 2 = male, 3 = female.
--
-- NOTE: the dressing room now renders the body on a DRESSABLE player unit
-- (DressingRoom:Dress → Model:Unit) so the previewed set actually shows and Undress
-- works — that path renders any race textured but its gender follows the logged-in
-- char. The exact race+gender creature-display ids below (the [2]/[3] keys) are a
-- static NPC that can't wear transmog or undress, so they are NO LONGER used to
-- render the body; only each entry's `normalize` override (and the `forms` shape) is
-- consumed — sizing is otherwise automatic (see ns.NORMALIZE_AGGRESSIVENESS).
-- The ids are kept for reference and a possible future "exact gender, no dressing"
-- mode (and the dev `/collected model <id>` preview). When that path WAS active a
-- race listed here got exact race+gender selection (DressingRoom:Dress →
-- DisplayInfo); a race absent here rendered via the same unit fallback used now.
--
-- These must be PRE-BAKED display ids (a CreatureDisplayInfo whose
-- ExtendedDisplayInfoID != 0 — it carries the race+gender's own baked textures).
-- A bare ChrModel base display renders WHITE here: SetModelByCreatureDisplayID
-- only composites textures from the active player's customizations, which match
-- only the player's own race. So `Dress` renders these with customizations OFF.
--
-- Sizing is automatic: the dressing room normalizes every model toward ~human-male
-- size via engine bounding-box normalization (DressingRoom:Dress →
-- Model:Aggressiveness), tuned globally by ns.NORMALIZE_AGGRESSIVENESS — no per-race
-- size data needed. An optional `normalize` override (on the entry, or on a single
-- form) replaces that global strength for the rare model the global value handles
-- badly (e.g. Dracthyr's wide wingspan dominates the bounding box and over-shrinks the
-- body at the global value). Tune live with `/collected normalize <0..1>`.
--
-- Entry shapes:
--   single form  → { [2] = maleID, [3] = femaleID, normalize? }
--   multi form   → { forms = { { name, race?|useNativeForm?, normalize? }, ... }, selfFormOnly? }
-- The dressing room shows a form toggle when `forms` is present. A form renders either as
-- another race (`race`, e.g. Worgen's Human form → 1; works for any player) or via the
-- unit's native/altered form (`useNativeForm`, e.g. Dracthyr dragon/visage). `selfFormOnly`
-- gates the toggle to when the player is previewing their own race with an alternate form —
-- needed for the altered form (visage), which only textures for the actual race.
--
-- The [2]/[3] creature-display ids are NOT used for rendering (see the NOTE above);
-- they're kept for reference and the dev `/collected model <id>` preview. Hand-
-- maintained, VERIFY IN-GAME. The 7 allied ids are recruitment-screen showcase
-- displays (Blizzard_AlliedRacesFrameUI.lua's Actor_X_ModelID). The rest were derived
-- from DB2: base ChrModel.DisplayID → its ModelID → the first baked CreatureDisplayInfo
-- sharing that ModelID with CreatureModelScale == 1. They must be PRE-BAKED ids (see
-- the NOTE above on white renders).
---@class Warbandeer_Collected
---@field RaceModels table<number, table>  [raceID] = { [2],[3], normalize? } | { forms = {{name,race?,useNativeForm?,normalize?},...}, selfFormOnly? }
ns.RaceModels = {
  -- Allied races (recruitment-screen showcase ids, hand-verified).
  [27] = { [2] = 82708,  [3] = 82709  }, -- Nightborne
  [28] = { [2] = 82733,  [3] = 82731  }, -- Highmountain Tauren
  [31] = { [2] = 89631,  [3] = 89632  }, -- Zandalari Troll
  [35] = { [2] = 94257,  [3] = 94256  }, -- Vulpera
  [36] = { [2] = 86343,  [3] = 86342  }, -- Mag'har Orc
  [37] = { [2] = 94370,  [3] = 94371  }, -- Mechagnome
  [84] = { [2] = 121634, [3] = 121635 }, -- Earthen

  -- Core + remaining allied races: first baked display per race+gender (VERIFY/curate).
  [1]  = { [2] = 1276,  [3] = 176   }, -- Human
  [2]  = { [2] = 1139,  [3] = 1312  }, -- Orc
  [3]  = { [2] = 115,   [3] = 1286  }, -- Dwarf
  [4]  = { [2] = 1285,  [3] = 1543  }, -- Night Elf
  [5]  = { [2] = 1027,  [3] = 1029  }, -- Undead
  [6]  = { [2] = 1624,  [3] = 1905  }, -- Tauren
  [7]  = { [2] = 1832,  [3] = 1890  }, -- Gnome
  [8]  = { [2] = 1976,  [3] = 1882  }, -- Troll
  [9]  = { [2] = 6882,  [3] = 7175  }, -- Goblin
  [10] = { [2] = 10375, [3] = 15505 }, -- Blood Elf
  [11] = { [2] = 16199, [3] = 16200 }, -- Draenei
  [25] = { [2] = 39574, [3] = 39705 }, -- Pandaren
  [29] = { [2] = 80975, [3] = 80977 }, -- Void Elf
  [30] = { [2] = 76240, [3] = 76338 }, -- Lightforged Draenei
  [32] = { [2] = 78517, [3] = 77936 }, -- Kul Tiran
  [34] = { [2] = 8803,  [3] = 69941 }, -- Dark Iron Dwarf

  -- Worgen: two forms. The Human form just renders the Human race (`race = 1`) —
  -- same as previewing a Human — since the body is a dressable player unit. The
  -- Worgen form omits `race`, so it renders the selected race (22).
  [22] = { forms = {
    { name = "Worgen", [2] = 30164, [3] = 31689 },
    { name = "Human",  [2] = 1276,  [3] = 176, race = 1 },
  } },

  -- Dracthyr (52): two forms via the unit's NATIVE alternate form (useNativeForm), not a
  -- race override. The dragon (native) renders textured for everyone; the visage (altered)
  -- only composites textures for an actual Dracthyr player, so its toggle is gated by
  -- `selfFormOnly` — shown only when a Dracthyr is previewing Dracthyr. Everyone else just
  -- sees the dragon. The dragon's wide wingspan over-shrinks at the global normalize
  -- strength, so it carries a gentler per-form override; the humanoid visage sizes fine
  -- at the global value.
  [52] = { selfFormOnly = true, forms = {
    { name = "Dracthyr", useNativeForm = true,  normalize = 0.2 },  -- dragon (native; renders for all)
    { name = "Visage",   useNativeForm = false },                   -- humanoid (altered; Dracthyr players only)
  } },
}

-- Global bounding-box normalization strength for the dressing-room model (0 = natural
-- size, 1 = forced to ~human-male). 0.5 keeps races consistent while preserving some
-- racial size character; per-race `normalize` overrides it for exceptions (Dracthyr).
---@class Warbandeer_Collected
---@field NORMALIZE_AGGRESSIVENESS number
ns.NORMALIZE_AGGRESSIVENESS = 0.5

-- Selector races by faction (one id per distinct model — Pandaren/Dracthyr/Earthen
-- collapse their faction variants into the neutral group). Any id GetRaceInfo
-- doesn't recognise on this client is skipped, so newer races degrade gracefully.
local FACTIONS = {
  -- Alliance ordered (4-wide) to keep kin together:
  --   Night Elf+Void Elf | Gnome+Mechagnome
  --   Draenei+Lightforged Draenei | Dwarf+Dark Iron
  --   Human+Worgen+Kul Tiran   (the three humans, centered bottom row)
  { faction = "alliance", ids = { 4, 29, 7, 37, 11, 30, 3, 34, 1, 22, 32 } },
  -- Horde ordered (4-wide) to keep kin together (Nightborne are elves → Blood Elf):
  --   Orc+Mag'har Orc | Tauren+Highmountain Tauren
  --   Troll+Zandalari Troll | Blood Elf+Nightborne
  --   Undead+Goblin+Vulpera   (the kinless three, centered bottom row)
  { faction = "horde",    ids = { 2, 36, 6, 28, 8, 31, 10, 27, 5, 9, 35 } },
  { faction = "neutral",  ids = { 25, 52, 84 } },   -- Pandaren, Dracthyr, Earthen
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

---Ordered playable-race list for the dressing-room selector, tagged by faction.
---@class Warbandeer_Collected
---@field PlayableRaces fun(): table[]  list of { id, name, file, faction } (file = race-icon atlas suffix; faction = "alliance"|"horde"|"neutral")
ns.PlayableRaces = function()
  local out = {}
  for _, grp in ipairs(FACTIONS) do
    for _, id in ipairs(grp.ids) do
      local info = GetRaceInfo(id)
      if info and info.clientFileString and info.clientFileString ~= "" then
        local file = (ICON_ATLAS[info.clientFileString] or info.clientFileString):lower()
        out[#out + 1] = { id = id, name = info.raceName, file = file, faction = grp.faction }
      end
    end
  end
  return out
end
