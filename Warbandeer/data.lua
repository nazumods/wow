---@type Warbandeer
local ns = select(2, ...)

---@class Warbandeer
---@field data table                          static data + profession/concentration helpers
---@field factionIcon table<boolean, table>   cell icon spec by isAlliance (path/coords/vertexColor)
---@field gearSlots string[]                  canonical gear-slot draw order
---@field gearSlotIcon table<string, table>   cell icon spec by gear-slot name (path/coords)
ns.data = {}

-- Custom Warbandeer faction art (white TGAs under icons/, tinted at draw time).
-- Defined here rather than in the shared LibNAddOn icon set, which only re-exports
-- WoW globals. Indexed by isAlliance; tints mirror the legacy AllianceLight/HordeLight.
local FACTION_ICONS = "Interface\\AddOns\\Warbandeer\\icons\\"
ns.factionIcon = {
  [true]  = {path = FACTION_ICONS.."alliance.tga", coords = {0, 1, 0, 1}, vertexColor = {0.400, 0.733, 1.000}},
  [false] = {path = FACTION_ICONS.."horde.tga",    coords = {0, 1, 0, 1}, vertexColor = {1.000, 0.125, 0.125}},
}

-- Ready for Midnight
local gearTiers = {
  explorer = 207,
  adventurer = 220,
  veteran = 233,
  champion = 246,
  hero = 259,
  mythic = 272,
}

ns.data.gearTiers = gearTiers

-- Canonical gear-slot draw order, shared by the Gear table, the Detail panel, and
-- the Summary iLvl tooltip. Mirrors the paper-doll layout; Shirt/Tabard are omitted.
ns.gearSlots = {
  "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand",
}

-- Gear-slot art: one 1024x1024 atlas (icons/gearslots.tga), a 4x4 grid of 256px
-- cells in this reading order. Each spec is {path, coords} so it drops straight
-- into a LibNUI Texture/Cell (same shape as factionIcon). The 14 distinct icons
-- cover all 16 gearSlots: Finger1/2 share the ring cell and Trinket1/2 share the
-- trinket cell. Cell -> normalized texcoords are derived, not hand-typed.
local GEAR_ATLAS = FACTION_ICONS.."gearslots.tga"
local ATLAS_COLS, ATLAS_ROWS = 4, 4
local atlasCells = {
  "Head", "Shoulder", "Back", "Neck", "Chest", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Ring", "Trinket", "MainHand", "OffHand",
}
-- gearSlots whose art is not a 1:1 named cell point at the cell that holds it.
local cellAlias = { Finger1 = "Ring", Finger2 = "Ring", Trinket1 = "Trinket", Trinket2 = "Trinket" }

local cellCoords = {}
for i, name in ipairs(atlasCells) do
  local col, row = (i - 1) % ATLAS_COLS, math.floor((i - 1) / ATLAS_COLS)
  cellCoords[name] = { col / ATLAS_COLS, (col + 1) / ATLAS_COLS, row / ATLAS_ROWS, (row + 1) / ATLAS_ROWS }
end

ns.gearSlotIcon = {}
for _, slot in ipairs(ns.gearSlots) do
  ns.gearSlotIcon[slot] = { path = GEAR_ATLAS, coords = cellCoords[cellAlias[slot] or slot] }
end

---@class ColorMixin
---@field WrapTextInColorCode fun(self: ColorMixin, ilvl: any): string

---@class Warbandeer
---@field IlvlColorObj fun(iLvl: number): ColorMixin
-- ColorMixin for an item level, by gear tier. Thresholds are by ilvl, not upgrade
-- track, by design: gear maxed on a lower track counts as the tier its ilvl reaches
-- (e.g. a fully upgraded Hero item at 272+ reads as mythic gold).
---@param ilvl number
---@return ColorMixin
function ns.IlvlColorObj(ilvl)
  if ilvl >= gearTiers.mythic then return ITEM_ARTIFACT_COLOR -- muted gold (#e6cc80)
  elseif ilvl >= gearTiers.hero then return ITEM_LEGENDARY_COLOR
  elseif ilvl >= gearTiers.champion then return ITEM_EPIC_COLOR
  elseif ilvl >= gearTiers.veteran then return ITEM_SUPERIOR_COLOR
  elseif ilvl >= gearTiers.adventurer then return ITEM_GOOD_COLOR
  elseif ilvl >= gearTiers.explorer then return ITEM_STANDARD_COLOR
  else return ITEM_POOR_COLOR
  end
end

---@class Warbandeer
---@field IlvlColor fun(ilvl: number): string
-- The ilvl wrapped in its tier's color escape code.
---@param ilvl number
---@return string
function ns.IlvlColor(ilvl)
  return ns.IlvlColorObj(ilvl):WrapTextInColorCode(ilvl)
end

---@class Warbandeer
---@field ilvlOf fun(t: Character): number
-- Safe ilvl accessor for sort comparators: fresh alts may not have had an
-- equipment pass yet, so equipment or equipment.ilvl can be nil.
---@param t Character
---@return number
function ns.ilvlOf(t) return t.equipment and t.equipment.ilvl or 0 end

-- Upgrade-track tier colors for the per-slot ilvl breakdown lines: the track
-- letter + level is wrapped in its tier color. Keyed by full track name.
local trackColors = {
  Explorer   = ITEM_STANDARD_COLOR,
  Adventurer = ITEM_GOOD_COLOR,
  Veteran    = ITEM_SUPERIOR_COLOR,
  Champion   = ITEM_EPIC_COLOR,
  Hero       = ITEM_LEGENDARY_COLOR,
  Mythic     = ITEM_ARTIFACT_COLOR, -- muted gold (#e6cc80)
}

---@class Warbandeer
---@field IlvlTooltipLines fun(t: Character): string[]
-- Per-slot item-level breakdown lines ("Head 272 (M3)", ...) in gearSlots draw
-- order, each ilvl tier-colored with the upgrade-track letter+level suffix. Drives
-- the hover tooltip on both the Summary iLvl column and the Overview ilvl cell.
---@param t Character
---@return string[]
function ns.IlvlTooltipLines(t)
  local lines = {}
  if not t.equipment then return lines end
  for _, slotName in ipairs(ns.gearSlots) do
    local slot = t.equipment.slots and t.equipment.slots[slotName]
    if slot then
      local suffix = ""
      if slot.track and slot.trackLevel and slot.trackLevel > 0 then
        local letter = slot.track:sub(1, 1)
        local color  = trackColors[slot.track]
        suffix = " (" .. (color and color:WrapTextInColorCode(letter) or letter) .. slot.trackLevel .. ")"
      end
      table.insert(lines, slotName .. " " .. ns.IlvlColor(slot.ilvl) .. suffix)
    end
  end
  return lines
end

---@class Warbandeer
---@field byLevelIlvl fun(a: Character, b: Character): boolean
-- Standard sort: descending level, then descending ilvl, then ascending name.
---@param a Character
---@param b Character
---@return boolean
function ns.byLevelIlvl(a, b)
  if a.basic.level ~= b.basic.level then return a.basic.level > b.basic.level end
  local ai, bi = ns.ilvlOf(a), ns.ilvlOf(b)
  if ai ~= bi then return ai > bi end
  return a.name < b.name
end

-- Bar colors for factions the API exposes no color for (Delves, Prey, the
-- Silvermoon Court minor factions, Slayer's Duellum, Valeera). Values match the
-- palette the Plumber addon uses so the overview reads consistently. {r,g,b} 0..1.
ns.data.factionColors = {
  [2710] = {206/255, 164/255,  56/255}, -- Silvermoon Court
  [2711] = {155/255, 173/255, 204/255}, -- Magisters
  [2712] = {206/255, 159/255, 159/255}, -- Blood Knights
  [2713] = {145/255, 181/255, 128/255}, -- Farstriders
  [2714] = {206/255, 164/255,  56/255}, -- Shades of the Row
  [2742] = {215/255, 160/255,  65/255}, -- Delves: Season 1
  [2744] = {242/255, 141/255, 152/255}, -- Valeera Sanguinar
  [2764] = {246/255, 138/255, 162/255}, -- Prey: Season 1
  [2770] = { 56/255, 184/255, 255/255}, -- Slayer's Duellum
}

-- doesn't seem a good way to get this via the api
-- except to crawl the discovered factions by expanding/collapsing what's shown in the standard rep window
-- which would need to be saved in db, at which point why not just hardcode it from wago:
-- https://wago.tools/db2/Faction?filter%5BExpansion%5D=10&page=1
local minorFactions = {}
local minorFactionMaxStanding = {}
-- 2600 = { -- Severed Threads
minorFactions[2600] = {
  2601, -- weaver
  2605, -- general
  2607, -- vizier
}
minorFactionMaxStanding[2600] = 20000
-- cartels of undermine
minorFactions[2653] = {
  2669, -- darkfuse solutions
  2671, -- venture company
  2673, -- bilgewater cartel
  2675, -- blackwater cartel
  2677, -- steamwheedle cartel
}
minorFactionMaxStanding[2653] = 42000

-- Midnight
minorFactions[2742] = {2744}                          -- Delves S1: Valeera Sanguinar (friendship reputation, level 1-60)
minorFactions[2764] = {2770}                          -- Prey S1: Slayer's Duellum (likely friendship rep)
minorFactions[2710] = {2711, 2712, 2713, 2714}        -- Silvermoon Court: Magisters, Blood Knights, Farstriders, Shades of the Row
minorFactionMaxStanding[2710] = 42000

minorFactionMaxStanding[2170] = 42000 -- Argussian Reach
minorFactionMaxStanding[2045] = 42000 -- Armies of Legionfall
minorFactionMaxStanding[2165] = 42000 -- Army of the Light
minorFactionMaxStanding[1900] = 42000 -- Court of Farondis
minorFactionMaxStanding[1883] = 42000 -- Dreamweavers
minorFactionMaxStanding[1828] = 42000 -- Highmountain Tribe
minorFactionMaxStanding[1859] = 42000 -- The Nightfallen
minorFactionMaxStanding[1894] = 42000 -- The Wardens
minorFactionMaxStanding[1948] = 42000 -- Valarjar

ns.data.minorFactions = minorFactions
ns.data.minorFactionMaxStanding = minorFactionMaxStanding

-- ─── Profession helpers ───────────────────────────────────────────────────────
local insert, sort = table.insert, table.sort

-- Concentration fill estimate, shared by the Midnight Profs and Crafting views.
-- Concentration recharges passively; the stored snapshot is projected forward to now.
-- Returns currentQuantity, maxQuantity, isEstimate.
---@param entry table  stored concentration snapshot (quantity/maxQuantity/recharge fields)
---@return number currentQuantity
---@return number maxQuantity
---@return boolean isEstimate
function ns.data.EstimateConcentration(entry)
  local cycleMs  = entry.rechargingCycleDurationMS or 0
  local cycleAmt = entry.rechargingAmountPerCycle  or 0
  if cycleMs == 0 or cycleAmt == 0 then
    return entry.quantity, entry.maxQuantity, false
  end
  local elapsed = GetServerTime() - (entry.lastUpdated or 0)
  local gained  = math.floor(elapsed / (cycleMs / 1000)) * cycleAmt
  return math.min(entry.maxQuantity, entry.quantity + gained), entry.maxQuantity, gained > 0
end

local PROF_SLOTS = { "primary", "secondary", "fishing", "cooking" }

-- Returns a character's profession object for a parent skill line ID, or nil.
---@param toon Character
---@param skillLineID number
---@return table?
function ns.data.FindProf(toon, skillLineID)
  local profs = toon.basic and toon.basic.professions
  if not profs then return nil end
  for _, slot in ipairs(PROF_SLOTS) do
    local p = profs[slot]
    if p and p.skillID == skillLineID then return p end
  end
  return nil
end

-- User-assigned intent for a character's profession: "main" | "secondary" | "gatherer" | nil.
---@param charName string
---@param skillLineID number
---@return string?
function ns.data.GetProfIntent(charName, skillLineID)
  local intents = ns.db and ns.db.profIntent
  local forChar = intents and intents[charName]
  return forChar and forChar[skillLineID] or nil
end

-- Assign (or clear, when intent is nil) a character's profession intent.
-- Persisted to WarbandeerDB.profIntent[charName][skillLineID].
---@param charName string
---@param skillLineID number
---@param intent string?  "main" | "secondary" | "gatherer", or nil to clear
function ns.data.SetProfIntent(charName, skillLineID, intent)
  local db = ns.db
  db.profIntent = db.profIntent or {}
  local forChar = db.profIntent[charName]
  if not forChar then
    forChar = {}
    db.profIntent[charName] = forChar
  end
  forChar[skillLineID] = intent
end

local INTENT_ORDER = { main = 1, secondary = 2, gatherer = 3 }

-- Every toon that has the given profession, with intent + skill, for tooltip display.
-- Sorted main -> secondary -> gatherer -> unset, then by skill descending.
---@param skillLineID number
---@param toons Character[]
---@return {toon:Character, intent:string?, skill:integer}[]
function ns.data.GetProfToons(skillLineID, toons)
  local list = {}
  for _, toon in ipairs(toons) do
    local p = ns.data.FindProf(toon, skillLineID)
    if p then
      insert(list, {
        toon   = toon,
        intent = ns.data.GetProfIntent(toon.name, skillLineID),
        skill  = p.skillLevel or 0,
      })
    end
  end
  sort(list, function(a, b)
    local ra, rb = INTENT_ORDER[a.intent] or 4, INTENT_ORDER[b.intent] or 4
    if ra ~= rb then return ra < rb end
    return a.skill > b.skill
  end)
  return list
end

-- The designated crafter for a profession: the toon flagged "main", else the
-- highest-skill toon that has it. Returns toon, isFlaggedMain (toon may be nil).
---@param skillLineID number
---@param toons Character[]
---@return Character? toon
---@return boolean isFlaggedMain
function ns.data.GetMainCrafter(skillLineID, toons)
  local best, bestSkill
  for _, toon in ipairs(toons) do
    local p = ns.data.FindProf(toon, skillLineID)
    if p then
      if ns.data.GetProfIntent(toon.name, skillLineID) == "main" then
        return toon, true
      end
      local s = p.skillLevel or 0
      if not best or s > bestSkill then best, bestSkill = toon, s end
    end
  end
  return best, false
end
