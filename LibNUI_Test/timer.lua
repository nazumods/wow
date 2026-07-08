local Timer    = LibNUI.Timer
local Label    = LibNUI.Label
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- Three modes: count up (ticks from 0:00 live), a plain countdown (0:10 → 0:00 then flips
-- green + "done!" via onFinish and stops), and an overtime countdown (0:05 → 0:00, then keeps
-- running into negative time — "-0:01", "-0:02" … — recoloured red).
---@return TitleFrame
local function makeTimer()
  local f = window("Timer", 240, 180)

  Label:new{ parent = f, text = "Count up", color = "muted",
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 16, -20} } }
  Timer:new{ parent = f, color = "header", autoStart = true,
    position = { TopRight = {f, "TOPRIGHT", -20, -40} } }

  Label:new{ parent = f, text = "Countdown", color = "muted",
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 16, -52} } }
  Timer:new{
    parent = f, color = "header", countdown = true, duration = 10, autoStart = true,
    onFinish = function(self) self:Color{0.4, 0.85, 0.4, 1}; self.label:Text("done!") end,
    position = { TopRight = {f, "TOPRIGHT", -20, -72} },
  }

  Label:new{ parent = f, text = "Overtime", color = "muted",
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 16, -84} } }
  Timer:new{
    parent = f, color = "header", countdown = true, overtime = true, duration = 5, autoStart = true,
    position = { TopRight = {f, "TOPRIGHT", -20, -104} },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "timer",
  name = "Timer",
  desc = "Count-up, countdown (onFinish), and overtime (negative + red) timers",
  run  = toggling(makeTimer),
})
