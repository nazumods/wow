local TableFrame = LibNUI.TableFrame
local Button     = LibNUI.Button
local ui         = LibNUI
local window     = LibNUITest.window
local toggling   = LibNUITest.toggling

-- Composite table cells (#571): a cell that renders MULTIPLE positioned elements — an
-- icon plus its number — with a thin gold border box hugging both, as the Endeavors
-- column was originally mocked. The "Bob" row is empty ("") to exercise the
-- simple↔composite recycling path: the Re-sort button reverses the rows so that cell
-- flips between a blank cell and a composite one each press.

-- Stand-in "faction crest" icons (the real column uses baked crest TGAs).
local CREST = {
  alliance = "Interface\\Icons\\inv_misc_coin_02",
  horde    = "Interface\\Icons\\inv_misc_coin_01",
}
local GOLD  = {1, 0.82, 0, 1}
local Left  = ui.justify.Left

-- One composite Endeavors cell: crest icon on the left, its XP number to the right,
-- a 1px gold border enclosing the pair, plus a hover tooltip (handlers pass through
-- exactly as for a plain cell).
local function endeavorCell(xp, faction)
  return {
    parts = {
      { path = CREST[faction], position = { Left = {"cell", "LEFT", 4, 0}, Size = {14, 14} } },
      { text = tostring(xp), color = "muted", justifyH = Left, position = { Left = {1, "RIGHT", 3, 0} } },
    },
    border = {
      color = GOLD, thickness = 1,
      position = { TopLeft = {1, "TOPLEFT", -2, 2}, BottomRight = {2, "BOTTOMRIGHT", 2, -2} },
    },
    onEnter = function(cell)
      local tip = ui.tip
      tip:Lines("Endeavors", (faction == "horde" and "Horde" or "Alliance") .. " house")
      tip:AnchorBeside(cell)
      tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

-- Trend cell (#743): an arrow whose ROTATION and a label whose JUSTIFICATION differ per row, so
-- reversing the rows swaps both between cells. Neither field is observable without recycling —
-- a static case can't show them — and before #743 the reused part kept the previous occupant's
-- value, rendering a down arrow on an up row until a /reload.
--
-- The arrow is also positioned with the bare {x, y} offset shorthand, which the composite path
-- used to misread as a part index.
local ARROW = "Interface\\Buttons\\UI-MicroStream-Green"
local function trendCell(up)
  return {
    parts = {
      { path = ARROW, rotation = up and 0 or math.pi,
        position = { Left = {6, 0}, Size = {12, 12} } },
      { text = up and "up" or "down", color = "muted",
        justifyH = up and ui.justify.Right or Left,
        position = { Left = {1, "RIGHT", 3, 0}, Width = 30 } },
    },
  }
end

local function rows()
  return {
    { "Alice", endeavorCell(3, "alliance"), trendCell(true) },
    { "Bob",   "", "" }, -- no active endeavor → blank cell (plain, not composite)
    { "Cara",  endeavorCell(1, "horde"), trendCell(false) },
    { "Dane",  endeavorCell(5, "alliance"), trendCell(true) },
  }
end

local PAD, TITLE_H, CH, HH = 8, 38, 20, 22
local NAME_W, ENDV_W, TREND_W = 70, 66, 56

---@return TitleFrame
local function makeComposite()
  local f = window("Composite Cell", NAME_W + ENDV_W + TREND_W + PAD * 2 + 8, TITLE_H + HH + 4 * CH + PAD * 3 + 22)

  local data = rows()
  local t = TableFrame:new{
    parent       = f,
    colInfo      = {
      { name = "Name", width = NAME_W },
      { name = "Endeavors", width = ENDV_W },
      { name = "Trend", width = TREND_W },
    },
    cellWidth    = NAME_W,
    cellHeight   = CH,
    headerHeight = HH,
    data         = data,
  }
  t:SetPoint("TOPLEFT", f._widget, "TOPLEFT", PAD, -(TITLE_H))
  t:onLoad()

  -- Reverse the rows and re-render: proves cells recycle across a re-sort, and that the
  -- flipping blank/composite cell transitions cleanly in both directions.
  local reversed = false
  local btn = Button:new{
    parent     = f,
    glow       = false,
    background = "backdrop",
    position   = { TopLeft = {t, "BOTTOMLEFT", 0, -PAD}, Size = {NAME_W + ENDV_W + TREND_W, 22} },
    onClick    = function()
      reversed = not reversed
      local src, out = rows(), {}
      for i = 1, #src do out[i] = reversed and src[#src - i + 1] or src[i] end
      t.data = out
      t:update()
    end,
  }
  btn:Text("Re-sort")

  return f
end

table.insert(LibNUITest.tests, {
  key  = "composite",
  name = "Table: composite cell + border",
  desc = "Icon + number with a gold border; Re-sort exercises recycling of rotation/justify (#571, #743)",
  run  = toggling(makeComposite),
})
