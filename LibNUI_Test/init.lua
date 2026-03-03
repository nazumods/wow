---@class TestEntry
---@field key  string  Short identifier passed as the argument to LibNUITest.run
---@field name string  Human-readable display name shown in the selector window
---@field desc string  One-line description shown beneath the name in the selector window
---@field run  fun()   Toggle-aware launcher: creates the window on first call, toggles it thereafter

---@class LibNUITest
---@field tests    TestEntry[]
LibNUITest = {}

---@type TestEntry[]
LibNUITest.tests = {}

-- -----------------------------------------------------------------------
-- Shared helpers available to all test files
-- -----------------------------------------------------------------------

---@class LibNUITest
---@field window   fun(title: string, width: number, height: number): TitleFrame
---@param  title  string
---@param  width  number
---@param  height number
---@return TitleFrame
function LibNUITest.window(title, width, height)
  local f = LibNUI.TitleFrame:new{
    name    = "LibNUITest_" .. title:gsub("%s+", ""),
    title   = title,
    special = true,
  }
  f:Size(width, height)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  return f
end

---@class LibNUITest
---@field toggling fun(makeFn: fun(): TitleFrame): fun()
---@param  makeFn fun(): TitleFrame  Factory that creates and returns the test window
---@return fun()                      Toggle-aware launcher closure
function LibNUITest.toggling(makeFn)
  local w
  return function()
    if w then w:Toggle(); return end
    w = makeFn()
  end
end
