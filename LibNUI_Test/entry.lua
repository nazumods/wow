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
    local nameLabel = f._widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", f._widget, "TOPLEFT", 10, rowTopY - 5)
    nameLabel:SetSize(WIN_W - BTN_W - 30, 18)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText(test.name)

    -- Description
    local descLabel = f._widget:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    descLabel:SetPoint("TOPLEFT", f._widget, "TOPLEFT", 10, rowTopY - 23)
    descLabel:SetSize(WIN_W - BTN_W - 30, 16)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetText(test.desc)

    -- Launch button, centred vertically within the row
    local btnTopY = rowTopY - math.floor((ROW_H - 22) / 2)
    local btn = CreateFrame("Button", "LibNUITest_Btn_" .. test.key, f._widget, "UIPanelButtonTemplate")
    btn:SetSize(BTN_W, 22)
    btn:SetPoint("TOPRIGHT", f._widget, "TOPRIGHT", -10, btnTopY)
    btn:SetText("Launch")
    local runFn = test.run
    btn:SetScript("OnClick", function() runFn() end)
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
