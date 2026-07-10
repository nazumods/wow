local TableFrame = LibNUI.TableFrame
local Button     = LibNUI.Button
local window     = LibNUITest.window
local toggling   = LibNUITest.toggling

-- #445 regression + live autosize demo. The table pairs a text "Name" column with an
-- icon-only column (a colInfo entry with `path` and no `name`) — that combination used to
-- crash TableFrame:Autosize on the headerless column. The button swaps the Name column
-- between short and long values and re-runs Autosize, so you can watch the text column
-- grow/shrink to fit while the icon column keeps its fixed width.
local SHORT = {
  {"Alice", "12"},
  {"Bob",   "7"},
  {"Cara",  "23"},
}
local LONG = {
  {"Alexandria",  "12"},
  {"Bartholomew", "7"},
  {"Cassiopeia",  "23"},
}

local TABLE_TOP = 42 -- clear the title bar

---@return TitleFrame
local function makeIconAutosize()
  local f = window("Icon col + autosize", 20, 20) -- sized after layout
  local long = false

  local t = TableFrame:new{
    parent     = f,
    colInfo    = {
      {name = "Name"},
      {path = "Interface\\Icons\\inv_misc_gem_variety_01", width = 32}, -- icon-only header
    },
    cellHeight = 20,
    autosize   = true,
    data       = SHORT,
  }
  t:SetPoint("TOPLEFT", f._widget, "TOPLEFT", 8, -TABLE_TOP)
  t:onLoad() -- autosizes; before #445 this errored on the icon column's headerless label

  -- Button below the table (the table's height is autosize-invariant, so this anchor is
  -- stable — only the width changes as the Name column grows).
  local btn = Button:new{
    parent     = f,
    glow       = false,
    background = "backdrop",
    position   = { TopLeft = {t, "BOTTOMLEFT", 0, -8}, Size = {160, 22} },
    onClick    = function()
      long = not long
      t.data = long and LONG or SHORT
      t:update()
      t:Autosize()
      -- grow/shrink the window to the (re-autosized) table, keeping room for the button
      f:Size(math.max(t:Width() + 16, 176), TABLE_TOP + t:Height() + 8 + 22 + 12)
    end,
  }
  btn:Text("Toggle long names")

  f:Size(math.max(t:Width() + 16, 176), TABLE_TOP + t:Height() + 8 + 22 + 12)
  return f
end

table.insert(LibNUITest.tests, {
  key  = "tableicon",
  name = "Table: icon col + autosize",
  desc = "Regression + live autosize: icon-only column header, button re-sizes the text column (#445)",
  run  = toggling(makeIconAutosize),
})
