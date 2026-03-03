local TableFrame = LibNUI.TableFrame
local window     = LibNUITest.window
local toggling   = LibNUITest.toggling

-- Shared dataset: 3 roles × 3 combat stats
local DATA      = {
  {"2,400",  "0",      "1"},
  {"400",    "38,000", "0"},
  {"92,000", "0",      "3"},
}
local COL_NAMES = {"DPS", "HPS", "Deaths"}
local ROW_INFO  = {{name = "Tank"}, {name = "Healer"}, {name = "DPS"}}

-- Layout constants
local PAD     = 8   -- gap between tables and from the window edge
local TITLE_H = 38  -- height consumed by TitleFrame's title bar
local CW      = 70  -- cell width
local CH      = 20  -- cell height
local HH      = 22  -- column-header row height
local HW      = 55  -- row-header column width

-- -----------------------------------------------------------------------
-- 2×2 grid
--
--   top-left:     no headers
--   top-right:    column headers only
--   bottom-left:  row headers only
--   bottom-right: both headers, autosize
-- -----------------------------------------------------------------------

---@return TitleFrame
local function makeTableHeaders()
  local f = window("Table Headers", 20, 20) -- sized after onLoad

  -- Top-left: no headers
  local t1 = TableFrame:new{
    parent     = f,
    cellWidth  = CW,
    cellHeight = CH,
    data       = DATA,
  }

  -- Top-right: column headers only
  local t2 = TableFrame:new{
    parent       = f,
    colNames     = COL_NAMES,
    cellWidth    = CW,
    cellHeight   = CH,
    headerHeight = HH,
    data         = DATA,
  }

  -- Bottom-left: row headers only
  local t3 = TableFrame:new{
    parent      = f,
    rowInfo     = ROW_INFO,
    headerWidth = HW,
    cellWidth   = CW,
    cellHeight  = CH,
    data        = DATA,
  }

  -- Bottom-right: both headers, autosize
  local t4 = TableFrame:new{
    parent       = f,
    colInfo      = {{name = "DPS"}, {name = "HPS"}, {name = "Deaths"}},
    rowInfo      = ROW_INFO,
    headerWidth  = HW,
    headerHeight = HH,
    cellHeight   = CH,
    autosize     = true,
    data         = DATA,
  }

  -- Pre-compute fixed sizes for layout arithmetic
  local nCols = #COL_NAMES
  local nRows = #DATA
  local t1W   = nCols * CW            -- 210
  local t1H   = nRows * CH            -- 60
  local t2H   = HH + t1H             -- 82
  local t3W   = HW + nCols * CW      -- 265
  local t3H   = t1H                  -- 60

  local leftW = math.max(t1W, t3W)   -- width of the left column  (265)
  local row1H = math.max(t1H, t2H)   -- height of the top row      (82)

  local xL = PAD
  local xR = PAD + leftW + PAD
  local y1 = -(TITLE_H + PAD)
  local y2 = -(TITLE_H + PAD + row1H + PAD)

  t1:SetPoint("TOPLEFT", f._widget, "TOPLEFT", xL, y1)
  t2:SetPoint("TOPLEFT", f._widget, "TOPLEFT", xR, y1)
  t3:SetPoint("TOPLEFT", f._widget, "TOPLEFT", xL, y2)
  t4:SetPoint("TOPLEFT", f._widget, "TOPLEFT", xR, y2)

  t1:onLoad()
  t2:onLoad()
  t3:onLoad()
  t4:onLoad() -- autosizes t4

  local rightW = math.max(t1W, t4:Width())   -- width of the right column
  local row2H  = math.max(t3H, t4:Height())  -- height of the bottom row

  f:Size(
    PAD + leftW + PAD + rightW + PAD,
    TITLE_H + PAD + row1H + PAD + row2H + PAD
  )

  return f
end

-- -----------------------------------------------------------------------
-- Register
-- -----------------------------------------------------------------------

table.insert(LibNUITest.tests, {
  key  = "table",
  name = "Table Headers",
  desc = "2×2 grid: no headers / col only / row only / both + autosize",
  run  = toggling(makeTableHeaders),
})
