local TabFrame = LibNUI.TabFrame
local Label    = LibNUI.Label
local window   = LibNUITest.window
local toggling = LibNUITest.toggling

---@return TitleFrame
local function makeTabFrame()
  local f = window("Tab Frame", 280, 200)

  local tabs = TabFrame:new{
    parent   = f,
    tabs     = {"Overview", "Details", "Log"},
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT"},
      BottomRight = {f, "BOTTOMRIGHT"},
    },
  }

  Label:new{
    parent   = tabs:Tab(1),
    text     = "Overview tab content.",
    position = { TopLeft = {10, -10} },
  }
  Label:new{
    parent   = tabs:Tab(2),
    text     = "Details tab content.",
    position = { TopLeft = {10, -10} },
  }
  Label:new{
    parent   = tabs:Tab(3),
    text     = "Log tab content.",
    position = { TopLeft = {10, -10} },
  }

  return f
end

-- -----------------------------------------------------------------------
-- Register
-- -----------------------------------------------------------------------

table.insert(LibNUITest.tests, {
  key  = "tab",
  name = "Tab Frame",
  desc = "TabFrame with three tabs switching content panels",
  run  = toggling(makeTabFrame),
})
