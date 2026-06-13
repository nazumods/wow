local CopyWindow = LibNUI.CopyWindow
local toggling   = LibNUITest.toggling

local SAMPLE = table.concat({
  "CopyWindow sample output:",
  "  a short line",
  "  a noticeably longer line so the window has to widen to fit the content",
  "  { nested = true, count = 3 }",
  "",
  "Use the titlebar A-size picker to change the font; the size persists.",
}, "\n")

---@return CopyWindow
local function makeCopyWindow()
  local f = CopyWindow:new{}
  f:Display("CopyWindow", SAMPLE)
  return f
end

-- -----------------------------------------------------------------------
-- Register
-- -----------------------------------------------------------------------

table.insert(LibNUITest.tests, {
  key  = "copywindow",
  name = "Copy Window",
  desc = "Copyable scroll window with a titlebar font-size picker",
  run  = toggling(makeCopyWindow),
})
