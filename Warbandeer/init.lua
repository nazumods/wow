---@class Warbandeer: AddOn
local ns = LibNAddOn(...)

local Views = {"Overview", "Races", "Summary", "Gear", "Detail", "Roles", "Professions"}

-- Parallel view-key list: index i in Views maps to the view name ns.viewKeys[i].
-- Kept adjacent so the two lists stay in sync. Used by MainWindow to resolve
-- db.settings.defaultView (a 1-based index) to an actual view name.
ns.viewKeys = {"overview", "races", "summary", "gear", "detail", "roles", "profs"}

-- Index → side for the character-tooltip anchor (see CharacterTooltip.lua).
ns.TOOLTIP_SIDES = {"Left", "Right"}

ns:RegisterSettings{
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
      {
        name = "Tooltip Side",
        typ = "dropdown",
        default = 1,
        table = function(db) return db.settings end,
        key = "tooltipSide",
        label = "tooltip side",
        tooltip = "Which side of the hovered cell the character tooltip appears on",
        options = ns.TOOLTIP_SIDES,
      },
    },
  },
}

ns.views = {}

-- Order of views in the selector dropdown (by view `.name`).  Single source of
-- truth for selector ordering; any registered view not listed here falls to the
-- end (sorted by title).  Keep new views in their intended slot.
ns.viewOrder = {
  "overview",
  "summary",
  "detail",
  "gear",
  "roles",
  "races",
  "profs",
  "crafting",
  "midnight",
  "legion",
  "playtime",
  "midnightprofs",
  "bars",
  "collected",
}

-- https://wowpedia.fandom.com/wiki/Category:HOWTOs
-- addon compartment, settings scroll templates: https://warcraft.wiki.gg/wiki/Patch_10.1.0/API_changes
-- settings changes: https://warcraft.wiki.gg/wiki/Patch_11.0.2/API_changes

-- https://wowpedia.fandom.com/wiki/Create_a_WoW_AddOn_in_15_Minutes#Options_Panel

local Generate, Map, Select = ns.lua.lists.generate, ns.lua.maps.map, ns.lua.Select
local GetClassInfo, GetClassColor = GetClassInfo, C_ClassColor.GetClassColor

-- class colors: https://wowpedia.fandom.com/wiki/Class_colors

ns.CLASSES = Generate(
  function(i)
    local n, id = GetClassInfo(i)
    local c = GetClassColor(id)
    return {name = n, id = id, color = c}
  end,
  GetNumClasses()
)
ns.CLASS_NAMES = Map(ns.CLASSES, Select("name"))

function ns:settingChanged(key, value) --, setting
  ns.Print("setting changed", key, value)
end

---@class Warbandeer
---@field db WarbandeerDB

---@class WarbandeerDB: AddOnDatabase
---@field settings {defaultView: integer, tooltipSide: integer, summaryColumns: table<string, boolean>}
---@field profIntent table<string,table<integer,string>> map of character name and skillLineID to crafter intent

function ns:MigrateDB()
  local db = self.db
  if not db.version then
    db.settings = {}
    db.settings.defaultView = 1
    db.version = 1
  end
  if db.version < 2 then
    -- Per-character, per-profession crafting intent: profIntent[charName][skillLineID]
    -- = "main" | "secondary" | "gatherer". Editor lives in a later session.
    db.profIntent = db.profIntent or {}
    db.version = 2
  end
  if db.version < 3 then
    -- Character-tooltip anchor side (index into ns.TOOLTIP_SIDES): 1=Left, 2=Right.
    db.settings.tooltipSide = db.settings.tooltipSide or 1
    db.version = 3
  end
  if db.version < 4 then
    -- Per-column Summary visibility: summaryColumns[columnKey] = false hides it.
    -- Absent/true = shown, so an empty table means every column visible (default).
    db.settings.summaryColumns = db.settings.summaryColumns or {}
    db.version = 4
  end
end

-- Live-refresh the open Detail view when the logged-in character's equipment changes,
-- so a suggestion clears the instant the gear it's about does. The Suggested box's
-- faction-quartermaster entries come from a fixed bundled list (unlike held/world-quest
-- ones, they never drop out of an inventory cache), so they're gated *only* by the
-- equipped-ilvl comparison — without this, a piece you just equipped keeps showing as
-- "buy it" until you reopen the view, because the box was populated before the data
-- layer rescanned your gear. The equipment broker rescans on PLAYER_EQUIPMENT_CHANGED
-- (asynchronously, as item data loads), so debounce long enough to read fresh data.
local DETAIL_REFRESH_DELAY = 750  -- ms; must outlast the equipment broker's rescan
local refreshGen = 0
local function isDetailShownForCurrentChar()
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  return view and view.name == "detail" and view._char == ns.api:GetCharacterData() and view or nil
end
local function refreshDetailOnGearChange()
  if not isDetailShownForCurrentChar() then return end
  refreshGen = refreshGen + 1
  local gen = refreshGen
  ns:after(DETAIL_REFRESH_DELAY, function()
    if gen ~= refreshGen then return end          -- superseded by a later gear change
    local view = isDetailShownForCurrentChar()
    if view then
      view:OnBeforeShow()
      ns.MainWindow:Fit()
    end
  end)
end

function ns:onLoad()
  ns:registerEvent("PLAYER_EQUIPMENT_CHANGED", refreshDetailOnGearChange)
end

function ns:onLogin()
  -- Pre-warm the calendar event list so the Summary view's Darkmoon Faire check
  -- (SummaryColumns.isDMF) has holiday data available, without relying on another
  -- addon to open the calendar first. Calendar APIs require PLAYER_ENTERING_WORLD,
  -- so this lives in onLogin rather than onLoad.
  C_Calendar.OpenCalendar()
end
