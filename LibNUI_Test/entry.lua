-- entry.lua  —  Main entry point for LibNUI_Test
--
-- Called by LibNUI as LibNUITest.run(arg).
-- arg (string|nil) : test key to launch directly, or nil/invalid to open
--                    the selector window.

---@type TestEntry[]
local tests = LibNUITest.tests

-- -----------------------------------------------------------------------
-- Selector window
-- -----------------------------------------------------------------------

local ROW_H = 44
local BTN_W = 70
local WIN_W = 440
local WIN_H = 38 + #tests * ROW_H + 12

---@type TitleFrame?
local selectorFrame

local function openSelector()
  if selectorFrame then
    selectorFrame:Toggle()
    return
  end

  local f = LibNUI.TitleFrame:new{
    name    = "LibNUITest_Selector",
    title   = "LibNUI Test Harness",
    special = true,
  }
  f:Size(WIN_W, WIN_H)
  f:SetPoint("LEFT", UIParent, "LEFT", 20, 0)
  selectorFrame = f

  for i, test in ipairs(tests) do
    local rowTopY = -(38 + (i - 1) * ROW_H)

    -- Test name
    LibNUI.Label:new{
      parent   = f,
      text     = test.name,
      fontObj  = "GameFontNormal",
      justifyH = LibNUI.edge.Left,
      position = {
        TopLeft = {10, rowTopY - 5},
        Width   = WIN_W - BTN_W - 30,
      },
    }

    -- Description
    LibNUI.Label:new{
      parent   = f,
      text     = test.desc,
      fontObj  = "GameFontDisable",
      justifyH = LibNUI.edge.Left,
      position = {
        TopLeft = {10, rowTopY - 23},
        Width   = WIN_W - BTN_W - 30,
      },
    }

    -- Launch button, centred vertically within the row
    local btnTopY = rowTopY - math.floor((ROW_H - 22) / 2)
    local runFn = test.run
    local btn = LibNUI.Button:new{
      parent  = f,
      onClick = function() runFn() end,
      position = {
        TopRight = {f, LibNUI.edge.TopRight, -10, btnTopY},
        Width    = BTN_W,
        Height   = 22,
      },
    }
    LibNUI.Label:new{
      parent   = btn,
      text     = "Launch",
      position = { Center = {} },
    }
  end
end

-- -----------------------------------------------------------------------
-- Public entry point
-- -----------------------------------------------------------------------

---@class LibNUITest
---@field run fun(arg: string?)
---@param arg string?  Test key to launch directly, or nil/invalid to open the selector window
function LibNUITest.run(arg)
  if arg then
    for _, test in ipairs(tests) do
      if test.key == arg then
        test.run()
        return
      end
    end
  end
  openSelector()
end
