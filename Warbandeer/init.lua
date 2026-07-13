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

-- Surface a "Changelog" button in the Warbandeer settings category, opening the
-- release history (ns.changelog, from changelog.lua) in the shared CopyWindow.
ns:RegisterChangelog()

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
  "milestones",
  "legion",
  "playtime",
  "midnightprofs",
  "bars",
  "collected",
  "reputations",
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

-- Swap every cell label's font away and back (same size/flags) to force the client
-- to re-rasterize the string. Works around the cold-session render glitch: cell
-- FontStrings in a TableFrame can rasterize blank on the first UI load of a client
-- session (never after /reload), even though text, size, visibility and font all
-- report correct. A *real* font change re-rasterizes them; a same-params SetFont is
-- a no-op. Views call this one tick after building their tables. Idempotent.
---@param tbl TableFrame
function ns.HealCellFonts(tbl)
  for _, row in pairs(tbl.cells) do
    for _, cell in pairs(row) do
      if cell.label then
        local f = cell.label:Font()
        cell.label:Font({"Fonts\\FRIZQT__.TTF", f[2], f[3]})
        cell.label:Font(f)
      end
    end
  end
end

function ns:settingChanged(key, value) --, setting
  ns.Print("setting changed", key, value)
end

---@class Warbandeer
---@field db WarbandeerDB

---@class WarbandeerDB: AddOnDatabase
---@field settings {defaultView: integer, tooltipSide: integer, summaryColumns: table<string, boolean>, consumables: table<string, boolean>, barApplyDefaults: table<string, boolean>}
---@field profIntent table<string,table<integer,string>> map of character name and skillLineID to crafter intent
---@field ignoredEnchants table<string, boolean> per-item accepted wrong-enchants, key "<itemID>:<enchantID>"

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
  if db.version < 5 then
    -- Per-item accepted wrong-enchants: ignoredEnchants["<itemID>:<enchantID>"] = true means
    -- "the (non-recommended) enchant on this specific item is fine — don't flag it." Keyed by
    -- the applied enchant too, so re-enchanting differently re-flags. Account-wide.
    db.ignoredEnchants = db.ignoredEnchants or {}
    db.version = 5
  end
  if db.version < 6 then
    -- Per-category visibility for the Detail view's Consumables box: consumables[key] = false
    -- hides that category (flask / combatPotion / food / weaponBuff / augmentRune). Absent/true
    -- = shown, so an empty table means every category visible (default).
    db.settings.consumables = db.settings.consumables or {}
    db.version = 6
  end
  if db.version < 7 then
    -- Default include-state for each Bars Apply toggle: barApplyDefaults[label] = false
    -- means that bar starts unchecked when the apply panel opens. Absent = the built-in
    -- default (every bar on except Bonus / Sky / Pet), so an empty table changes nothing.
    db.settings.barApplyDefaults = db.settings.barApplyDefaults or {}
    db.version = 7
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

-- Live-refresh the open Summary / Gear view when the warband (account) bank changes,
-- so a cross-character upgrade marker clears the moment its item is withdrawn. An item
-- pulled out of the warband bank and put on one character stops being an upgrade for
-- every *offline* alt it was suggested for (and a remaining duplicate keeps showing —
-- the data layer rebuilds db.bank.warband.equip from scratch, so a second copy is still
-- in the list). Without this, those other characters' rows stay stale until the view is
-- reopened or each alt is logged in, because the table was built before the bank rescan.
-- The data layer (Warbandeer_Characters) rebuilds the warband equip list on these same
-- events; ShadowsOfUI-Upgrade then memoizes per character for ~2s. The debounce must
-- outlast BOTH so OnBeforeShow re-reads the fresh bank list, not a cached upgrade result.
local BANK_REFRESH_DELAY = 2100  -- ms; > the data layer's bank rescan AND the upgrade ~2s memo TTL
local bankRefreshGen = 0
local WARBAND_VIEWS = { summary = true, gear = true }  -- views carrying cross-character upgrade markers
local function shownWarbandView()
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  return view and WARBAND_VIEWS[view.name] and view or nil
end
local function refreshViewOnWarbandBankChange()
  if not shownWarbandView() then return end
  bankRefreshGen = bankRefreshGen + 1
  local gen = bankRefreshGen
  ns:after(BANK_REFRESH_DELAY, function()
    if gen ~= bankRefreshGen then return end          -- superseded by a later bank change
    local view = shownWarbandView()
    if view then
      view:OnBeforeShow()
      ns.MainWindow:Fit()
    end
  end)
end

-- Live-refresh the open collected view when the sibling Collected addon finishes a
-- scan (e.g. after learning an appearance), keeping this grid in sync with the
-- standalone /collected window. The callback fires after Collected's DB is already
-- fresh, so a plain re-read suffices — no debounce needed here.
local function shownCollectedView()
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  return view and view.name == "collected" and view or nil
end
local function refreshCollectedOnScan()
  local view = shownCollectedView()
  if view then
    view:OnBeforeShow()
    ns.MainWindow:Fit()
  end
end

-- Live-refresh the open Pets panel when the Hunter rearranges pets (active↔stable, or to/from the
-- stable) or a pet's info changes (rename), so the docked panel tracks the change without a /reload.
-- The data layer (Warbandeer_Characters) rescans `toon.pets` on these same events and loads first,
-- so its handler runs before this one; the short debounce also coalesces the burst of
-- PET_STABLE_UPDATE fires as pets are dragged around.
local PETS_REFRESH_DELAY = 300  -- ms; coalesces a burst of pet moves (the data-layer rescan is synchronous)
local petsRefreshGen = 0
local function shownPetsPanel()
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  return view and view.name == "detail" and view.petsPanel or nil
end
local function refreshPetsOnChange()
  if not shownPetsPanel() then return end
  petsRefreshGen = petsRefreshGen + 1
  local gen = petsRefreshGen
  ns:after(PETS_REFRESH_DELAY, function()
    if gen ~= petsRefreshGen then return end   -- superseded by a later pet change
    local panel = shownPetsPanel()
    if panel then panel:Refresh() end          -- no-ops if the panel is toggled off
  end)
end

function ns:onLoad()
  ns:registerEvent("PLAYER_EQUIPMENT_CHANGED", refreshDetailOnGearChange)
  ns:registerEvent("PET_STABLE_UPDATE", refreshPetsOnChange)
  ns:registerEvent("PET_INFO_UPDATE", refreshPetsOnChange)
  if WarbandeerCollectedApi and WarbandeerCollectedApi.OnScanned then
    WarbandeerCollectedApi:OnScanned(refreshCollectedOnScan)
  end
  -- PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED covers a live withdrawal; BANKFRAME_CLOSED is the
  -- belt-and-suspenders final capture (the data layer rescans there too). Both coalesce into
  -- a single refresh via the generation-guarded debounce.
  ns:registerEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", refreshViewOnWarbandBankChange)
  ns:registerEvent("BANKFRAME_CLOSED", refreshViewOnWarbandBankChange)
end

function ns:onLogin()
  -- Pre-warm the calendar event list so the Summary view's Darkmoon Faire check
  -- (SummaryColumns.isDMF) has holiday data available, without relying on another
  -- addon to open the calendar first. Calendar APIs require PLAYER_ENTERING_WORLD,
  -- so this lives in onLogin rather than onLoad.
  C_Calendar.OpenCalendar()
end
