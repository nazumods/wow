---@class Warbandeer
local ns = select(2, ...)
local insert = table.insert
---@class LibNUI
local ui = ns.ui
local Left = ui.justify.Left
local Colors = ns.Colors
local Class = ns.lua.Class

---@class SummaryColumn: Class
---@field getData fun(toon:Character):any  cell data builder for a single character row
---@field getFooter? fun(toons:Character[]):any  optional footer cell data builder, given all rows
---@field key? string   stable id for the show/hide setting; nil = always-on identity column
---@field label? string display name in the "Summary Columns" settings panel
---@field colInfo table
ns.SummaryColumn = Class(nil, function(self)
  local path, coords
  if self.iconPath then
    -- explicit custom texture (e.g. the M/H crest TGAs); full image by default
    path = self.iconPath
    coords = self.iconCoords or {0, 1, 0, 1}
  elseif self.currencyID then
    local info = C_CurrencyInfo.GetCurrencyInfo(self.currencyID)
    path = info.iconFileID
    coords = {0.1, 0.9, 0.1, 0.9}
  end
  local atlas = not path and self.icon or nil
  self.colInfo = {
    name = self.name,
    width = self.width,
    justifyH = self.justifyH,
    backdrop = {color = Colors.TransparentBlack},
    padLeft = self.padLeft,
    atlas = atlas,
    -- `X and false or nil` always evaluates to nil — assign explicitly so
    -- TableCol's "centered square" branch fires for atlas icons.
    path = path,
    coords = coords,
    vertexColor = self.iconColor,
    iconOffsetX = self.iconOffsetX,
    tooltip = self.tooltip,
  }
  if atlas then self.colInfo.atlasSize = false end
end, {
  -- default options
  key = nil,         -- stable id; a column with a key is user-toggleable, nil = always-on
  label = nil,       -- settings-panel display name (for toggleable columns)
  name = nil,
  width = 20,
  justifyH = Left,
  padLeft = nil,
  icon = nil,
  iconPath = nil,   -- explicit texture path; takes precedence over currencyID/icon
  iconCoords = nil, -- optional {l,r,t,b} for iconPath (defaults to full image)
  iconColor = nil,  -- optional vertexColor tint for the header icon (e.g. white crest TGAs -> muted)
  iconOffsetX = nil, -- optional px nudge right (+) or left (-) from the icon's centered position
  currencyID = nil,
  tooltip = nil,
  getData = function() return "" end, -- function to get data for this column
  getFooter = nil, -- optional: function(toons) -> footer cell data for this column
})
local SummaryColumn = ns.SummaryColumn

-- Shared cell data reused across the summaryCol/ chunk files.
---@type table shared green check-icon cell data
ns.GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    Center = {},
    Size = {16, 16},
  },
}
---@type number[] cell color for capped/at-max values
ns.CappedColor = {1, 0.2, 0.2, 1}
---@type number[] cell color for uncapped values
ns.UncappedColor = {1, 1, 1, 1}

-- "Known zero / n-a" cell: an em-dash in the muted column-header colour. Weekly
-- currency columns (crests, field accolades, M+, caches, coffer keys) return it
-- for a max-level character that genuinely holds 0 — distinguishing it from a
-- below-max character the column doesn't apply to, which stays empty (""). The
-- upgrades column returns it for its flat n/a (no upgrades) case. Returned shared:
-- SummaryView:decorateRow copies every cell before wrapping, so it's never mutated.
-- Right-aligned to sit where each column renders its numbers.
---@type table shared muted em-dash cell for known-zero / n-a values
ns.ZeroDash = {
  text = "—",
  justifyH = ui.justify.Right,
  color = ns.theme.colors.faded,
}
---@type table ZeroDash for centered data
ns.ZeroDashC = ns.lua.maps.merge({}, ns.ZeroDash, {justifyH = ui.justify.Center})

-- Cell data for a small square icon (faction, role) that should sit centered in
-- its cell rather than stretching to fill it: a fixed 16px size leaves ~2px above
-- and below the 20px row and keeps an hPad inset from squishing the icon. Returns
-- a copy so the shared ns.icons.* table (reused by other views at full size) is
-- never mutated.
---@param icon table  a shared ns.icons.* entry (path/atlas/coords/vertexColor)
---@return table
function ns.SummaryIconCell(icon)
  return {
    path = icon.path,
    atlas = icon.atlas,
    coords = icon.coords,
    vertexColor = icon.vertexColor,
    position = { Center = {}, Size = {16, 16} },
  }
end

---@type SummaryColumn[]
ns.SummaryColumns = {}

-- The visible columns in display order: every always-on identity column (no `key`)
-- plus each toggleable column the user hasn't hidden. Visibility lives in
-- db.settings.summaryColumns[key] (missing/true = shown, false = hidden). Built
-- fresh each Summary (re)build so a settings toggle takes effect on the next render.
---@class Warbandeer
---@field VisibleSummaryColumns fun(): SummaryColumn[]
function ns.VisibleSummaryColumns()
  local shown = ns.db.settings.summaryColumns or {}
  local out = {}
  for _, c in ipairs(ns.SummaryColumns) do
    if not c.key or shown[c.key] ~= false then
      out[#out + 1] = c
    end
  end
  return out
end

-- The Darkmoon Faire holiday uses three calendar textures across its run:
-- 235448 (begins), 235447 (in progress), 235446 (ends) — match all three so the
-- column is present on the first and last days too.
local DMF_TEXTURES = {[235448] = true, [235447] = true, [235446] = true}

-- The calendar event list is loaded lazily (see ns:onLogin's OpenCalendar). Pin the
-- absolute month to the real current month before reading day events — offset 0 is
-- relative to whatever month the calendar UI last browsed to — and restore it after
-- so we never disturb an open CalendarFrame.
local isDMF = function()
  local now = C_DateAndTime.GetCurrentCalendarTime()
  now.day = now.monthDay
  local epoch = time(now)
  local savedMonth, savedYear
  if CalendarFrame and CalendarFrame:IsShown() then
    local info = C_Calendar.GetMonthInfo()
    savedMonth, savedYear = info.month, info.year
  end
  C_Calendar.SetAbsMonth(now.month, now.year)

  local found = false
  for i = 1, C_Calendar.GetNumDayEvents(0, now.monthDay) do
    local info = C_Calendar.GetHolidayInfo(0, now.monthDay, i)
    -- The calendar still lists the holiday on its final day after the faire has
    -- actually closed (~3am), so honour the event's end time, not just its presence.
    if info and DMF_TEXTURES[info.texture] then
      info.startTime.day = info.startTime.monthDay
      info.endTime.day   = info.endTime.monthDay
      if epoch >= time(info.startTime) and epoch <= time(info.endTime) then
        found = true
        break
      end
    end
  end

  if savedMonth then C_Calendar.SetAbsMonth(savedMonth, savedYear) end
  return found
end

-- Append the DMF weekly column while the faire is open. The column spec is inserted
-- into ns.SummaryColumns only once, but addCol must run for *every* table — the
-- Alliance and Horde ClassSummary frames are built separately — so the one-shot
-- guard only gates detection + spec insertion, not the per-view addCol. Detection
-- is NOT cached on a negative result: if the calendar wasn't loaded yet on the
-- first table build, a later build can still pick the faire up.
---@class Warbandeer
---@field SummaryColumnsDelayed fun(view: TableFrame)  appends the DMF column while the faire is open
---@field _dmfColumn SummaryColumn?  one-shot DMF column spec, created on first detection
ns.SummaryColumnsDelayed = function(view)
  if not ns._dmfColumn then
    if not isDMF() then return end
    ns._dmfColumn = SummaryColumn:new{
      name = "DMF",
      width = 30,
      getData = function(toon)
        return toon.weeklies and toon.weeklies.DMF and ns.GreenCheck or ""
      end,
    }
    -- Not inserted into ns.SummaryColumns (and so not user-toggleable): it's a
    -- dynamic, faire-only column appended per-table below. Keeping it out of the
    -- global list also keeps VisibleSummaryColumns + the settings panel stable.
  end
  -- shallow-copy so addCol's stored colInfo entry is never the column's shared
  -- table (the muted header color now comes from the theme)
  local info = {}
  for k, v in pairs(ns._dmfColumn.colInfo) do info[k] = v end
  view:addCol(info)
  -- keep the table's row-iteration list (self._columns) aligned with its rendered
  -- columns: the row builders walk _columns, so DMF must be appended there too
  insert(view._columns, ns._dmfColumn)
end
