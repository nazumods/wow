local TableFrame = LibNUI.TableFrame
local Button     = LibNUI.Button
local Label      = LibNUI.Label
local window     = LibNUITest.window
local toggling   = LibNUITest.toggling
local Right      = LibNUI.justify.Right
local Left       = LibNUI.justify.Left

-- #535 detached-footer demo. Both tables autosize a right-justified "Gold" column to
-- its (narrow) per-row values and carry a much wider aggregate footer total. The top
-- table opts into `detachedFooter`, so its total is sized to its own content and
-- anchored to the column's right edge — it renders in full, overflowing left into the
-- empty footer space. The bottom table uses the default spanning footer, so the same
-- total is clamped to the narrow Gold column and clips. The button swaps the Gold data
-- (narrow ↔ wide) and re-autosizes, so you can watch each Gold column resize to its
-- data while the detached total keeps tracking the column's right edge intact.

local NARROW = { {"Alice", "92,000"}, {"Bob", "7,400"}, {"Cara", "231,000"} }
local WIDE   = { {"Alice", "9,120,000"}, {"Bob", "740,000"}, {"Cara", "2,231,000"} }

local TOTAL = {text = "2,349,153g 88s 1c", justifyH = Right, color = {1, 0.82, 0, 1}}

-- The detached table's footer leaves col 1 EMPTY on purpose. The whole claim of the demo is a wide
-- total rendering in full by overflowing left into empty footer space — and with "3 chars" sitting
-- in col 1 the total landed on top of it, so the demo contradicted its own premise and a reader
-- couldn't tell the overflow from a layout fault (#783). Not a library bug: `detachedFooter` sizes
-- the cell to its own content and anchors it to the column's right edge, which is exactly what it
-- did. The spanning table keeps col 1, where it costs nothing — that total clips to the narrow Gold
-- column rather than overflowing, which is the contrast the demo exists to show.
local FOOTER_DETACHED = { [2] = TOTAL }
local FOOTER_SPANNING = {
  [1] = {text = "3 chars", justifyH = Left, color = {1, 1, 1, 0.6}},
  [2] = TOTAL,
}

local CH, HH = 20, 22
local TITLE_H, CAP_H, GAP = 42, 16, 12

---@param parent table
---@param detached boolean
---@param y number  TOPLEFT y offset for the table
---@return TableFrame
local function buildTable(parent, detached, y)
  local t = TableFrame:new{
    parent         = parent,
    colInfo        = { {name = "Name", width = 110}, {name = "Gold", justifyH = Right} },
    cellHeight     = CH,
    headerHeight   = HH,
    autosize       = true,
    detachedFooter = detached,
    data           = NARROW,
  }
  t:SetPoint("TOPLEFT", parent._widget, "TOPLEFT", 10, y)
  t:onLoad()               -- builds rows + autosizes the Gold column to its data
  -- Wide total either way: detached overflows into the empty col 1, spanning clips to the Gold column.
  t:setFooter(detached and FOOTER_DETACHED or FOOTER_SPANNING)
  return t
end

---@return TitleFrame
local function makeFooterDemo()
  local f = window("Detached footer (#535)", 300, 320)

  Label:new{ parent = f, text = "detachedFooter = true  — total renders in full",
    position = { TopLeft = {10, -TITLE_H} }, color = {0.5, 0.9, 0.5, 1} }
  local t1 = buildTable(f, true, -(TITLE_H + CAP_H))
  local h1 = HH + #NARROW * CH + t1.footerHeight

  local cap2Y = -(TITLE_H + CAP_H + h1 + GAP)
  Label:new{ parent = f, text = "default footer — total clips to the narrow column",
    position = { TopLeft = {10, cap2Y} }, color = {0.9, 0.6, 0.5, 1} }
  local t2 = buildTable(f, false, cap2Y - CAP_H)
  local h2 = HH + #NARROW * CH + t2.footerHeight

  local btnY = cap2Y - CAP_H - h2 - GAP
  local wide = false
  local btn = Button:new{
    parent   = f,
    glow     = false,
    background = "backdrop",
    position = { TopLeft = {10, btnY}, Size = {180, 22} },
    onClick  = function()
      wide = not wide
      for _, t in ipairs({t1, t2}) do
        t.data = wide and WIDE or NARROW
        t:update()
        t:Autosize()
        -- Refresh: detached re-measures the total's width. Each table keeps its own footer shape —
        -- read back off the table rather than tracked here, so the two can't drift apart.
        t:setFooter(t.detachedFooter and FOOTER_DETACHED or FOOTER_SPANNING)
      end
    end,
  }
  btn:Text("Toggle Gold data width")

  f:Size(300, TITLE_H + CAP_H + h1 + GAP + CAP_H + h2 + GAP + 22 + 12)
  return f
end

table.insert(LibNUITest.tests, {
  key  = "tablefooter",
  name = "Table: detached footer",
  desc = "Detached vs spanning footer: a wide total over an autosized column (#535)",
  run  = toggling(makeFooterDemo),
})
