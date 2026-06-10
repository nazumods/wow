local Theme      = LibNUI.Theme
local TitleFrame = LibNUI.TitleFrame
local TabFrame   = LibNUI.TabFrame
local TableFrame = LibNUI.TableFrame
local toggling   = LibNUITest.toggling

-- A deliberately loud theme so every themed token is visibly different from
-- the default dark theme. Tokens not overridden here fall back to dark.
local crimson = Theme{
  name = "crimson",
  colors = {
    window      = {0.15, 0.05, 0.05, 1},
    border      = {0.6, 0.1, 0.1, 0.8},
    titlebar    = {0.3, 0.05, 0.05, 0.9},
    tabBar      = {0.2, 0, 0, 0.6},
    tabActive   = {0.7, 0.15, 0.15, 0.9},
    tabInactive = {0.25, 0.08, 0.08, 0.8},
    header      = {1, 0.6, 0.4, 1},
    colEven     = {0.3, 0, 0, 0.4},
    colOdd      = {0.2, 0, 0, 0.3},
    rowEven     = {1, 0.3, 0.3, 0.1},
    rowOdd      = {0, 0, 0, 0},
  },
}

---@return TitleFrame
local function makeThemed()
  -- theme is passed once on the top-level window; every child widget
  -- (titlebar, tabs, table headers/rows) inherits it through `parent`
  local f = TitleFrame:new{
    name    = "LibNUITest_Theme",
    title   = "Crimson Theme",
    theme   = crimson,
    special = true,
  }
  f:Size(360, 240)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  local tabs = TabFrame:new{
    parent   = f,
    tabs     = {"Table", "Empty"},
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT"},
      BottomRight = {f, "BOTTOMRIGHT"},
    },
  }

  TableFrame:new{
    parent    = tabs:Tab(1),
    colNames  = {"Name", "Value"},
    rowNames  = {"One", "Two", "Three"},
    cellWidth = 120,
    position  = { TopLeft = {10, -10} },
    data      = {
      {{text = "Alpha"}, {text = "1"}},
      {{text = "Beta"},  {text = "2"}},
      {{text = "Gamma"}, {text = "3"}},
    },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "theme",
  name = "Theme",
  desc = "TitleFrame + TabFrame + TableFrame inheriting a custom theme",
  run  = toggling(makeThemed),
})
