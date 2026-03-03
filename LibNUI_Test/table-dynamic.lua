local TableFrame = LibNUI.TableFrame
local window     = LibNUITest.window
local toggling   = LibNUITest.toggling

-- -----------------------------------------------------------------------
-- Dynamic addRow / addCol
--   Tests: starting from empty, building structure with addRow/addCol,
--   then populating with update()
-- -----------------------------------------------------------------------

---@return TitleFrame
local function makeDynamic()
  local f = window("Dynamic Table", 320, 180)

  local t = TableFrame:new{
    parent       = f,
    cellWidth    = 90,
    cellHeight   = 20,
    headerHeight = 22,
    -- non-nil so offsets are computed correctly before addRow/addCol are called
    rowNames     = {},
    headerWidth  = 70,
    colNames     = {},
  }
  t:SetPoint("TOPLEFT", f._widget, "TOPLEFT", 8, -38)

  -- build structure dynamically
  t:addCol{name = "Item",     width = 140}
  t:addCol{name = "Count",    width = 70,  justifyH = "RIGHT"}
  t:addCol{name = "Equipped", width = 80,  justifyH = "CENTER"}

  t:addRow{name = "Weapons"}
  t:addRow{name = "Armor"}
  t:addRow{name = "Trinkets"}

  t.data = {
    {"Thunderfury",    "1", "Yes"},
    {"Sulfuras",       "1", "No"},
    {"Eye of Sulfuras","2", "Yes"},
  }
  t:update()
  f:Size(t:Width() + 16, t:Height() + 46)

  return f
end

-- -----------------------------------------------------------------------
-- Register
-- -----------------------------------------------------------------------

table.insert(LibNUITest.tests, {
  key  = "table-dynamic",
  name = "Dynamic Table",
  desc = "addCol/addRow from empty, then update() to populate",
  run  = toggling(makeDynamic),
})
