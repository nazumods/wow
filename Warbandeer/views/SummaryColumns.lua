local _, ns = ...
local insert = table.insert
local ui = ns.ui
local Left = ui.justify.Left
local Colors = ns.Colors
local Class = ns.lua.Class

---@class Warbandeer
---@field SummaryColumn fun():SummaryColumn

---@class SummaryColumn
---@field getData fun(toon:Character):any  cell data builder for a single character row
---@field getFooter? fun(toons:Character[]):any  optional footer cell data builder, given all rows
ns.SummaryColumn = Class(nil, function(self)
  local path, coords
  if self.currencyID then
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
    tooltip = self.tooltip,
  }
  if atlas then self.colInfo.atlasSize = false end
end, {
  -- default options
  name = nil,
  width = 20,
  justifyH = Left,
  padLeft = nil,
  icon = nil,
  currencyID = nil,
  tooltip = nil,
  getData = function() return "" end, -- function to get data for this column
  getFooter = nil, -- optional: function(toons) -> footer cell data for this column
})
local SummaryColumn = ns.SummaryColumn

-- Shared cell data reused across the summaryCol/ chunk files.
ns.GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    Center = {},
    Size = {16, 16},
  },
}
ns.CappedColor = {1, 0.2, 0.2, 1}
ns.UncappedColor = {1, 1, 1, 1}

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

---@class Warbandeer
---@field SummaryColumns SummaryColumn[]
ns.SummaryColumns = {}

local isDMF = function()
  local day = C_DateAndTime.GetCurrentCalendarTime().monthDay
  local numEvents = C_Calendar.GetNumDayEvents(0,day)
  for i = 1, numEvents do
    -- name, startTime, endTime, description, texture=235447
    local info = C_Calendar.GetHolidayInfo(0,day,i)
    if info and info.texture == 235447 then -- DMF texture
      return true
    end
  end
  return false
end

ns.SummaryColumnsDelayed = function(view)
  if ns._dmfChecked then return end
  ns._dmfChecked = true
  if isDMF() then
    insert(
      ns.SummaryColumns,
      SummaryColumn:new{
        name = "DMF",
        width = 30,
        getData = function(toon)
          return toon.weeklies.dmf and ns.GreenCheck or ""
        end,
      }
    )
    view:addCol(ns.SummaryColumns[#ns.SummaryColumns].colInfo)
  end
end
