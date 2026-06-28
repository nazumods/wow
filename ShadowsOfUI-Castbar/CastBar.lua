---@type ShadowsOfUI_Castbar
local ns = select(2, ...)
local ui, Class = ns.ui, ns.lua.Class
local StatusBar, Texture, Label = ui.StatusBar, ui.Texture, ui.Label
local rgba = ns.Colors.rgba
local GetTime = GetTime
local unpack = unpack

-- Font path borrowed from a stock font object, so the spell-name / time-text size is
-- the only thing the user tunes (8–18px) without us shipping a font file.
local FONT_PATH = GameFontHighlightSmall:GetFont()

local WIDTH, HEIGHT = 220, 22
local PLACEHOLDER = "Interface\\Icons\\inv_misc_questionmark"

-- Fill colours by cast state.
local CAST     = rgba(255, 200, 80, 0.9)  -- normal, interruptible cast
local SHIELDED = rgba(150, 150, 150, 0.9) -- non-interruptible (greyed)
local CHANNEL  = rgba(120, 200, 120, 0.9) -- channelled spell

-- Spellcast events, registered per-unit via RegisterUnitEvent so each bar only wakes
-- for its own unit ("target" / "focus" follow whatever is currently targeted/focused).
local CAST_EVENTS = {
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

---@class CastBar: StatusBar
---@field unit string  the unit token this bar watches ("target" | "focus")
---@field changedEvent string  PLAYER_TARGET_CHANGED | PLAYER_FOCUS_CHANGED (set via the `events` option)
---@field pos table  the bar's saved `{x, y}` CENTER offset (a live reference into the addon DB)
---@field enabled boolean  whether the bar shows for real casts
---@field icon Texture  spell icon, inset top-left
---@field nameText Label  spell name
---@field timeText Label  remaining time
---@field _enabled boolean  internal mirror of `enabled`
---@field _config boolean?  true while Edit Mode placement is active
---@field _channel boolean?  true while the tracked cast is a channel
---@field _startMS number?  cast start (ms)
---@field _endMS number?  cast end (ms)
local CastBar = Class(StatusBar, function(self)
  self:Size(WIDTH, HEIGHT)
  self._enabled = self.enabled
  self._label = self.unit == "focus" and "Focus Cast Bar" or "Target Cast Bar"

  self.icon = Texture:new{
    parent = self, layer = ui.layer.Overlay,
    position = { TopLeft = {1, -1}, Width = HEIGHT - 2, Height = HEIGHT - 2 },
  }
  self.icon:Coords(0.08, 0.92, 0.08, 0.92) -- trim the icon's built-in border

  self.nameText = Label:new{
    parent = self, layer = ui.layer.Overlay, color = {1, 1, 1},
    fontInfo = { FONT_PATH, self.textSize }, justifyH = ui.justify.Left, wordWrap = false,
    position = { Left = {self.icon, ui.edge.Right, 4, 0}, Right = {self, ui.edge.Right, -36, 0} },
  }
  self.timeText = Label:new{
    parent = self, layer = ui.layer.Overlay, color = {0.9, 0.9, 0.9},
    fontInfo = { FONT_PATH, self.textSize }, justifyH = ui.justify.Right,
    position = { Right = {self, ui.edge.Right, -3, 0} },
  }

  -- Darkened top edge, matching the XP / GCD bars.
  self.edge = Texture:new{
    parent = self, layer = ui.layer.Overlay, blendMode = "BLEND",
    gradient = { "VERTICAL", rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.5) },
    position = { TopLeft = {}, BottomRight = {self, ui.edge.TopRight, 0, -3} },
  }

  for _, e in ipairs(CAST_EVENTS) do
    self._widget:RegisterUnitEvent(e, self.unit)
  end

  self:applyPosition()
  self:Hide()
end, {
  parent = UIParent,
  backdrop = {0, 0, 0, 0.5},
  fill = { color = {1, 1, 1} },
  textSize = 12,
})
ns.CastBar = CastBar

-- Anchor by CENTER to UIParent using the saved offset (kept in the DB so it survives /reload).
function CastBar:applyPosition()
  self._widget:ClearAllPoints()
  self._widget:SetPoint("CENTER", UIParent, "CENTER", self.pos.x, self.pos.y)
end

-- Re-read the live cast/channel state and paint, or hide when nothing is being cast.
function CastBar:Refresh()
  if self._config then return end -- placement sample owns the bar while Edit Mode is open
  if not self._enabled then self:Hide(); self:stopUpdates(); return end

  local unit = self.unit
  local name, text, tex, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
  local channel = false
  if not name then
    name, text, tex, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
    channel = name ~= nil
  end
  if not name then self:Hide(); self:stopUpdates(); return end

  self._channel = channel
  self._startMS, self._endMS = startMS, endMS
  self.icon:Texture(tex)
  self.nameText:Text(text or name)
  self:applyColor(notInterruptible)
  self:Show()
  self:startUpdates()
  self:onUpdate(0)
end

-- Pick the fill colour for the current state (channel > shielded > normal cast).
function CastBar:applyColor(notInterruptible)
  local c = self._channel and CHANNEL or (notInterruptible and SHIELDED or CAST)
  self.fill:Color(unpack(c))
end

function CastBar:onUpdate()
  local s, e = self._startMS, self._endMS
  if not s then self:stopUpdates(); return end
  local now = GetTime() * 1000
  if now >= e then self:Hide(); self:stopUpdates(); return end
  local pct = (now - s) / (e - s)
  if self._channel then pct = 1 - pct end
  if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
  self.fill:Width(self:Width() * pct)
  self.timeText:Text(("%.1f"):format((e - now) / 1000))
end

-- Toggle whether this bar shows for real casts (settings checkbox).
---@param on boolean
function CastBar:SetEnabled(on)
  self._enabled = on
  self:Refresh()
end

-- Resize the spell-name + time text (settings slider, 8–18px).
---@param size number
function CastBar:SetTextSize(size)
  self.nameText:Font({ FONT_PATH, size })
  self.timeText:Font({ FONT_PATH, size })
end

-- Enter/leave Edit Mode placement: show a static draggable sample, or return to live.
---@param on boolean
function CastBar:SetConfig(on)
  self._config = on
  if on then
    self:stopUpdates()
    self.icon:Texture(PLACEHOLDER)
    self.nameText:Text(self._label)
    self.timeText:Text("")
    self.fill:Color(unpack(CAST))
    self.fill:Width(self:Width() * 0.6)
    self:enableDrag(true)
    self:Show()
  else
    self:enableDrag(false)
    self:Refresh()
  end
end

-- Left-drag to reposition (only armed while in placement mode); the new CENTER offset
-- is written straight back into the DB-backed `pos` table.
---@param on boolean
function CastBar:enableDrag(on)
  local w = self._widget
  w:EnableMouse(on)
  w:SetMovable(on)
  if on then
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function() w:StartMoving() end)
    w:SetScript("OnDragStop", function()
      w:StopMovingOrSizing()
      local cx, cy = w:GetCenter()
      local ux, uy = UIParent:GetCenter()
      self.pos.x, self.pos.y = cx - ux, cy - uy
      self:applyPosition()
    end)
  else
    w:RegisterForDrag()
    w:SetScript("OnDragStart", nil)
    w:SetScript("OnDragStop", nil)
  end
end

-- Any spellcast / unit-change event just re-reads the live state.
local function refresh(self) self:Refresh() end
for _, e in ipairs(CAST_EVENTS) do CastBar[e] = refresh end
CastBar.PLAYER_TARGET_CHANGED = refresh
CastBar.PLAYER_FOCUS_CHANGED = refresh
