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

local FOOTER = {
  [1] = {text = "3 chars", justifyH = Left, color = {1, 1, 1, 0.6}},
  [2] = {text = "2,349,153g 88s 1c", justifyH = Right, color = {1, 0.82, 0, 1}},
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
  t:setFooter(FOOTER)      -- wide total: detached overflows, spanning clips
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
        t:setFooter(FOOTER)   -- refresh: detached re-measures the total's width
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
