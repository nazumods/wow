---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, duration = ns.lua.Class, ns.lua.strings.duration
local Frame, Label = ui.Frame, ui.Label

-- A live-updating time display: ticks on the frame's OnUpdate and re-renders only when the
-- formatted string changes (churn-free). Counts up from 0, or down from `duration` to 0
-- (firing onFinish). A Frame wrapping a Label (FontStrings can't self-tick); auto-sizes to
-- the text, so anchor it by an edge. Style via the `color`/`font` options or `:Color`.
---@class Timer: Frame
---@field format string|fun(seconds: number): string  a ns.lua.strings.duration style ("m:ss" default | "h:mm:ss" | "auto") or a formatter
---@field countdown boolean  count down from `duration` to 0 instead of up (default false)
---@field duration number    countdown start / total seconds (default 0)
---@field autoStart boolean  start ticking on construction (default false)
---@field overtime boolean   a countdown keeps running past 0 into negative time (shown "-m:ss"), recoloured `overtimeColor` (default false)
---@field overtimeColor string|table  colour applied while negative (default red)
---@field color string|table?  text colour token/rgba (forwarded to the label)
---@field onFinish fun(self: Timer)?  fired once when a countdown crosses 0 (with `overtime`, the tick continues)
---@field label Label
---@field running boolean?
---@field _elapsed number   seconds counted since the last reset
---@field _finished boolean?  guard so onFinish fires once
---@field _text string?     last rendered string (change-gate for SetText)
local Timer = Class(Frame, function(self)
  self.label = Label:new{
    parent = self, color = self.color, font = self.font, fontInfo = self.fontInfo,
    justifyH = self.justifyH, position = { Center = {} },
  }
  self._elapsed = 0

  -- Frame:onUpdate arrives in ms (see Frame); accumulate in seconds and re-render.
  self.onUpdate = function(_, ms)
    self._elapsed = self._elapsed + ms / 1000
    self:_render()
  end

  self:_render()
  if self.autoStart then self:Start() end
end, {
  type          = "Frame",
  format        = "m:ss",
  countdown     = false,
  duration      = 0,
  overtime      = false,
  overtimeColor = {0.95, 0.30, 0.30, 1},
})
ui.Timer = Timer

-- The seconds the display currently shows: elapsed when counting up; remaining (clamped at
-- 0) when counting down.
---@return number
function Timer:_seconds()
  if self.countdown then
    local s = self.duration - self._elapsed
    -- clamp at 0 for a plain countdown; let it run negative in overtime mode
    if s < 0 and not self.overtime then return 0 end
    return s
  end
  return self._elapsed
end

-- A style string ("m:ss"/"h:mm:ss"/"auto") is formatted by the shared ns.lua.strings.duration;
-- a function `format` gets the raw seconds for full control.
---@param sec number
---@return string
function Timer:_format(sec)
  local f = self.format
  if type(f) == "function" then return f(sec) end
  -- ns.lua.strings.duration formats a magnitude; the widget owns the overtime sign
  if sec < 0 then return "-" .. duration(-sec, f) end
  return duration(sec, f)
end

function Timer:_render()
  local sec = self:_seconds()
  local text = self:_format(sec)
  if text ~= self._text then
    self._text = text
    self.label:Text(text)
    self:Size(self.label:StringWidth() or 20, self.label:Height() or 12)
  end
  -- overtime owns the colour: base while ≥ 0, overtimeColor once negative
  if self.overtime then
    self.label:Color(sec < 0 and self.overtimeColor or (self.color or "text"))
  end
  -- fire onFinish once at the zero crossing; a plain countdown also stops there,
  -- an overtime one keeps ticking into the red
  if self.countdown and self.running and sec <= 0 and not self._finished then
    self._finished = true
    if not self.overtime then self:Stop() end
    if self.onFinish then self:onFinish() end
  end
end

-- Start (or resume) ticking.
---@return Timer
function Timer:Start()
  self.running = true
  self:startUpdates()
  return self
end

-- Pause ticking; the elapsed count is kept.
---@return Timer
function Timer:Stop()
  self.running = false
  self:stopUpdates()
  return self
end

-- Zero the count (back to 0:00 up, or full `duration` down) and re-render.
---@return Timer
function Timer:Reset()
  self._elapsed = 0
  self._finished = nil
  self:_render()
  return self
end

-- Get the displayed seconds, or set them (e.g. seed a run already in progress). Setting
-- doesn't start or stop the tick.
---@param sec number?
---@return number|Timer
function Timer:Value(sec)
  if sec == nil then return self:_seconds() end
  self._elapsed = self.countdown and (self.duration - sec) or sec
  self._finished = nil
  self:_render()
  return self
end

-- Set the text colour (forwards to the label).
---@param ... any  Label:Color args (token, rgba table, or channels)
---@return Timer
function Timer:Color(...)
  self.label:Color(...)
  return self
end
