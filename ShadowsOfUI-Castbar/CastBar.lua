---@type ShadowsOfUI_Castbar
local ns = select(2, ...)
local ui, Class = ns.ui, ns.lua.Class
local StatusBar, Texture, Label = ui.StatusBar, ui.Texture, ui.Label
local rgba = ns.Colors.rgba
local GetTime = GetTime

-- Font path borrowed from a stock font object, so the spell-name / time-text size is
-- the only thing the user tunes (8–22px) without us shipping a font file.
local FONT_PATH = GameFontHighlightSmall:GetFont()

local PLACEHOLDER = "Interface\\Icons\\inv_misc_questionmark"

-- The bar scales with its text size so larger fonts never overflow: height = size + V_PAD,
-- width keeps the bar's proportions (height × W_PER_H). Default 12px → 22 high × 220 wide
-- (the original look); 22px → 32 × 320.
local V_PAD = 10
local W_PER_H = 10
local function dims(textSize)
  local h = textSize + V_PAD
  return h * W_PER_H, h
end

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
---@field unit string  the unit token this bar watches ("target" | "focus" | "player")
---@field changedEvent string?  PLAYER_TARGET_CHANGED | PLAYER_FOCUS_CHANGED (set via the `events` option; none for "player")
---@field pos table  the bar's saved `{x, y}` CENTER offset (a live reference into the addon DB)
---@field enabled boolean  whether the bar shows for real casts
---@field icon Texture  spell icon, inset top-left
---@field nameText Label  spell name
---@field timeText Label  remaining time
---@field _enabled boolean  internal mirror of `enabled`
---@field _editMode boolean?  true while Edit Mode placement is active (draggable sample)
---@field _preview boolean?  true while our settings panel is open (static sample, for live slider preview)
---@field _channel boolean?  true while the tracked cast is a channel
---@field _endMS number?  cast end (ms); only read when not secret (for the time text)
---@field _secretTime boolean?  true when the cast timing is a protected/secret value
---@field _sel Texture[]  the four border strips of the Edit Mode selection box
---@field _selected boolean?  true while this bar owns the open config popup (drawn highlighted)
---@field _didDrag boolean?  set on drag-start so the following click doesn't open the popup
local CastBar = Class(StatusBar, function(self)
  self._enabled = self.enabled
  self._label = ({ target = "Target Cast Bar", focus = "Focus Cast Bar", player = "Player Cast Bar" })[self.unit]

  self.icon = Texture:new{
    parent = self, layer = ui.layer.Overlay,
    position = { TopLeft = {1, -1} }, -- size set by _applySize (scales with text)
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

  self:_applySize()
  self:_buildSelection() -- Edit Mode selection box (defined in editmode.lua)

  -- Install the OnEvent → self[event] dispatcher up front. We register CAST_EVENTS manually
  -- (per-unit) below rather than via the `events`/`unitEvents` options, so we can't rely on
  -- those options to wire dispatch — the player bar passes no `events` at all.
  self:listenForEvents()
  for _, e in ipairs(CAST_EVENTS) do
    self._widget:RegisterUnitEvent(e, self.unit)
  end

  self:applyPosition()
  self:Hide()
end, {
  parent = UIParent,
  backdrop = {0, 0, 0, 0.5},
  texture = "Interface\\Buttons\\WHITE8X8", -- native fill texture, tinted via SetStatusBarColor
  textSize = 12,
})
ns.CastBar = CastBar
CastBar.dims = dims -- (textSize) → width, height; shared with MigrateDB's position conversion

-- Anchor by the bar's TOPLEFT (offset from UIParent's centre, kept in the DB so it survives
-- /reload). Top-left rather than centre so resizing for a larger font grows down/right from a
-- locked corner instead of spreading from the middle.
function CastBar:applyPosition()
  self._widget:ClearAllPoints()
  self._widget:SetPoint("TOPLEFT", UIParent, "CENTER", self.pos.x, self.pos.y)
end

-- Size the bar + icon for the current text size. CENTER-anchored, so it grows
-- symmetrically and stays put. Called at construction and on every slider change.
function CastBar:_applySize()
  local w, h = dims(self.textSize)
  self:Size(w, h)
  self.icon:Size(h - 2, h - 2)
end

-- Re-read the live cast/channel state and paint, or hide when nothing is being cast.
function CastBar:Refresh()
  if self._editMode or self._preview then return end -- a sample owns the bar (Edit Mode / settings preview)
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
  self._endMS = endMS
  -- An enemy target/focus's cast timing + interruptible flag are "secret" values (WoW's
  -- anti-automation guard): tainted addon code can't do arithmetic / boolean tests on them.
  -- We sidestep that by feeding the (possibly secret) start/end straight to the native
  -- StatusBar, which computes the fill in C — Lua never touches the protected numbers. Only
  -- the time text needs real arithmetic, so it's gated on the timing being readable.
  -- canaccessvalue is retail-only (nil elsewhere → treat as readable).
  self._secretTime = canaccessvalue ~= nil and not canaccessvalue(endMS)
  self.icon:Texture(tex)
  self.nameText:Text(text or name)
  self:applyColor(notInterruptible)
  if self._secretTime then self.timeText:Text("") end
  self._widget:SetMinMaxValues(startMS, endMS)
  self:Show()
  self:startUpdates()
  self:onUpdate(0)
end

-- Pick the fill colour for the current state (channel > shielded > normal cast). The
-- interruptible flag is secret for enemy casts, so only test it when readable.
function CastBar:applyColor(notInterruptible)
  local shielded = not self._channel
    and canaccessvalue ~= nil and canaccessvalue(notInterruptible) and notInterruptible
  local c = self._channel and CHANNEL or (shielded and SHIELDED or CAST)
  self._widget:SetStatusBarColor(c:GetRGBA())
end

-- Advance the native fill each frame; the engine clamps GetTime() against the (secret)
-- min/max, so no Lua arithmetic touches the protected times. Hiding is driven by the
-- UNIT_SPELLCAST_*_STOP events (→ Refresh), not by comparing against the secret end time.
function CastBar:onUpdate()
  self._widget:SetValue(GetTime() * 1000)
  if not self._secretTime and self._endMS then
    local remaining = (self._endMS - GetTime() * 1000) / 1000
    self.timeText:Text(("%.1f"):format(remaining < 0 and 0 or remaining))
  end
end

-- Toggle whether this bar shows at all (settings checkbox). Routes through _syncSample so
-- it also hides/shows the live sample when the panel is open (Refresh alone would no-op
-- there, since a sample owns the bar).
---@param on boolean
function CastBar:SetEnabled(on)
  self._enabled = on
  self:_syncSample()
end

-- Resize the spell-name + time text (settings slider, 8–22px).
---@param size number
function CastBar:SetTextSize(size)
  self.textSize = size
  self.nameText:Font({ FONT_PATH, size })
  self.timeText:Font({ FONT_PATH, size })
  self:_applySize()
end

-- Show the static placeholder sample while a sample source is active (Edit Mode or the
-- settings panel); otherwise hide it / return to live behaviour. Drag is armed only for Edit
-- Mode — the settings preview is look-only so the slider's effect shows.
--
-- A disabled bar stays hidden in the settings preview ("off means off") but still shows —
-- dimmed — in Edit Mode, so a hidden bar can be repositioned and re-enabled from its config
-- popup instead of being unreachable until you dig into the Settings panel.
function CastBar:_syncSample()
  if not (self._editMode or self._preview) then
    self:enableDrag(false)
    self:Alpha(1)
    self:Refresh()
    return
  end
  if not self._enabled and not self._editMode then
    self:enableDrag(false)
    self:stopUpdates()
    self:Hide()
    return
  end
  self:stopUpdates()
  self.icon:Texture(PLACEHOLDER)
  self.nameText:Text(self._label)
  self.timeText:Text("")
  self._widget:SetStatusBarColor(CAST:GetRGBA())
  self._widget:SetMinMaxValues(0, 1)
  self._widget:SetValue(0.6)
  self:Alpha(self._enabled and 1 or 0.4) -- dim the handle while the bar is hidden
  self:enableDrag(self._editMode)
  self:Show()
end

-- Edit Mode placement (draggable sample).
---@param on boolean
function CastBar:SetConfig(on)
  self._editMode = on
  self:_syncSample()
end

-- Settings-panel preview (static sample so the text-size slider shows a live result).
---@param on boolean
function CastBar:SetPreview(on)
  self._preview = on
  self:_syncSample()
end

-- Placement mode (Edit Mode only): show the selection box, left-drag to reposition (the new
-- TOPLEFT offset is written straight back into the DB-backed `pos` table), and left-click
-- (no drag) to open this bar's config popup — mirroring Blizzard's click-to-configure.
---@param on boolean
function CastBar:enableDrag(on)
  on = on and true or false -- _editMode can be nil; SetMovable rejects a non-boolean
  local w = self._widget
  w:EnableMouse(on)
  w:SetMovable(on)
  if on then
    for _, strip in ipairs(self._sel) do strip:Show() end
    self:_selectStyle(self._selected)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function() self._didDrag = true; w:StartMoving() end)
    w:SetScript("OnDragStop", function()
      w:StopMovingOrSizing()
      local ux, uy = UIParent:GetCenter()
      self.pos.x, self.pos.y = w:GetLeft() - ux, w:GetTop() - uy
      self:applyPosition()
    end)
    w:SetScript("OnMouseUp", function()
      if self._didDrag then self._didDrag = false; return end -- a drag, not a click
      ns:OpenConfig(self)
    end)
    w:SetScript("OnEnter", function() if not self._selected then self:_selectStyle(true) end end)
    w:SetScript("OnLeave", function() if not self._selected then self:_selectStyle(false) end end)
  else
    for _, strip in ipairs(self._sel) do strip:Hide() end
    w:RegisterForDrag()
    w:SetScript("OnDragStart", nil)
    w:SetScript("OnDragStop", nil)
    w:SetScript("OnMouseUp", nil)
    w:SetScript("OnEnter", nil)
    w:SetScript("OnLeave", nil)
  end
end

-- Any spellcast / unit-change event just re-reads the live state.
local function refresh(self) self:Refresh() end
for _, e in ipairs(CAST_EVENTS) do CastBar[e] = refresh end
CastBar.PLAYER_TARGET_CHANGED = refresh
CastBar.PLAYER_FOCUS_CHANGED = refresh
