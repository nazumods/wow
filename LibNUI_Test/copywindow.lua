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

-- Titlebar-overflow fixtures (nazumods/wow#657): a body far narrower than its title.
-- Both go through the shared singleton, the path every real caller takes, so
-- `ToggleCopyWindow` already supplies the toggle behaviour `LibNUITest.toggling`
-- gives the instance-based test above.
local NARROW = table.concat({
  "12345 Alpha",
  "67890 Bravo",
  "13579 Charlie",
}, "\n")

local LONG_TITLE = "Saved transmog sets — 7/25 (a deliberately wide titlebar)"
local HUGE_TITLE = ("A title far past MAX_W that has to ellipsize rather than overlap "):rep(4)

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

table.insert(LibNUITest.tests, {
  key  = "copytitle",
  name = "Copy Window (long title)",
  desc = "Narrow body under a long title — must clear the size picker and close button",
  run  = function() LibNUI.ToggleCopyWindow(LONG_TITLE, NARROW) end,
})

table.insert(LibNUITest.tests, {
  key  = "copytitlemax",
  name = "Copy Window (over-wide title)",
  desc = "Title wider than MAX_W — must ellipsize, not overlap",
  run  = function() LibNUI.ToggleCopyWindow(HUGE_TITLE, NARROW) end,
})
