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

local ROW_H  = 44
local BTN_W  = 70
local TEXT_W = 320                        -- name/description label width within a column
local PAD    = 12                         -- window inner padding
local COL_GAP = 20                        -- gap between columns
local COLS   = 2
local COL_W  = TEXT_W + 12 + BTN_W         -- one column: text block + gap + Launch button
local WIN_W  = PAD + COL_W * COLS + COL_GAP * (COLS - 1) + PAD
local ROWS_PER_COL = math.ceil(#tests / COLS)
local WIN_H  = 38 + ROWS_PER_COL * ROW_H + 12

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
    -- Column-major fill: the left column takes the first ROWS_PER_COL tests
    -- top-to-bottom, then the right column.
    local col = math.floor((i - 1) / ROWS_PER_COL)
    local row = (i - 1) % ROWS_PER_COL
    local ox  = PAD + col * (COL_W + COL_GAP)
    local rowTopY = -(38 + row * ROW_H)

    -- Test name
    LibNUI.Label:new{
      parent   = f,
      text     = test.name,
      fontObj  = "GameFontNormal",
      justifyH = LibNUI.edge.Left,
      position = {
        TopLeft = {ox, rowTopY - 5},
        Width   = TEXT_W,
      },
    }

    -- Description
    LibNUI.Label:new{
      parent   = f,
      text     = test.desc,
      fontObj  = "GameFontDisable",
      justifyH = LibNUI.edge.Left,
      position = {
        TopLeft = {ox, rowTopY - 23},
        Width   = TEXT_W,
      },
    }

    -- Launch button, at the column's right edge, centred vertically within the row
    local btnTopY = rowTopY - math.floor((ROW_H - 22) / 2)
    local runFn = test.run
    local btn = LibNUI.Frame:new{
      type     = "Button",
      template = "UIPanelButtonTemplate",
      parent   = f,
      position = {
        TopLeft = {ox + TEXT_W + 12, btnTopY},
        Width    = BTN_W,
        Height   = 22,
      },
    }
    btn:SetScript("OnClick", function() runFn() end)
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
