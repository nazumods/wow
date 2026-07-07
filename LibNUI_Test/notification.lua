local Notification = LibNUI.Notification
local toggling     = LibNUITest.toggling

-- A full notification card: icon + wrapped body + "don't show again" checkbox + dismiss.
-- The dismiss button, the close X, and Escape all print via onDismiss; toggling the
-- checkbox prints via onDontShowAgain. Re-run /nui test notification to toggle it.
---@return Notification
local function makeNotification()
  local n = Notification:new{
    name          = "LibNUITest_Notification",
    title         = "Reminder",
    body          = "Don't forget to use your Trovehunter's Bounty before finishing this "
                 .. "delve! This body text wraps within the card so long messages stay legible.",
    icon          = 1064187,
    dontShowAgain = true,
    onDismiss = function()
      print("|cFF88CCFF[LibNUITest]|r Notification dismissed")
    end,
    onDontShowAgain = function(_, checked)
      print("|cFF88CCFF[LibNUITest]|r don't-show-again = " .. tostring(checked))
    end,
  }
  n:Notify()
  return n
end

table.insert(LibNUITest.tests, {
  key  = "notification",
  name = "Notification",
  desc = "Dismissible card: icon + wrapped body + don't-show-again + dismiss",
  run  = toggling(makeNotification),
})
