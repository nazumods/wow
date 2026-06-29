---@class ShadowsOfUI_Castbar: AddOn
---@field CastBar CastBar  the cast-bar widget class (CastBar.lua)
---@field bars table<string, CastBar>  the two live bars, keyed "target" / "focus"
---@field DEFAULT_POS table<string, table>  per-unit default TOPLEFT offsets (for "Reset position")
---@field SetConfigMode fun(self: ShadowsOfUI_Castbar, on: boolean)  toggle Edit Mode placement (editmode.lua)
---@field WireEditMode fun(self: ShadowsOfUI_Castbar)  hook Blizzard Edit Mode (editmode.lua)
---@field OpenConfig fun(self: ShadowsOfUI_Castbar, bar: CastBar)  open the per-bar config popup (config.lua)
---@field AttachConfig fun(self: ShadowsOfUI_Castbar, bar: CastBar)  re-anchor the popup to a bar (config.lua)
---@field CloseConfig fun(self: ShadowsOfUI_Castbar)  close the popup + clear selection (config.lua)
local ns = LibNAddOn(...)

-- Default TOPLEFT offsets from UIParent's centre (the bar's top-left corner) before the
-- user drags a bar — the top-left equivalent of the old centred defaults at the default size.
-- Exposed on ns so the config popup's "Reset position" can restore them.
local DEFAULT_POS = {
  target = { x = -110, y = 171 },
  focus  = { x = -110, y = 135 },
}
ns.DEFAULT_POS = DEFAULT_POS

function ns:MigrateDB()
  local db = ns.db
  local v = db.version or 0
  if db.textSize == nil then db.textSize = 12 end
  if db.targetEnabled == nil then db.targetEnabled = true end
  if db.focusEnabled == nil then db.focusEnabled = true end
  if db.targetPos == nil then db.targetPos = { x = DEFAULT_POS.target.x, y = DEFAULT_POS.target.y } end
  if db.focusPos == nil then db.focusPos = { x = DEFAULT_POS.focus.x, y = DEFAULT_POS.focus.y } end

  -- v2: bars switched from CENTER-anchored to TOPLEFT-anchored (so a larger font grows
  -- down/right from a locked top-left). Convert any pre-v2 centre offset to the matching
  -- top-left offset using the bar size at the current text size, so placement is preserved.
  if v >= 1 and v < 2 then
    local w, h = ns.CastBar.dims(db.textSize)
    for _, pos in ipairs({ db.targetPos, db.focusPos }) do
      pos.x, pos.y = pos.x - w / 2, pos.y + h / 2
    end
  end

  db.version = 2
end

ns:RegisterSettings{
  { title = ns._TITLE, parent = "Shadows of UI", fields = {
    { typ = "checkbox", key = "targetEnabled", table = function(db) return db end,
      label = "Show target cast bar", default = true,
      callback = function(_, v) ns:SetBarEnabled("target", v) end },
    { typ = "checkbox", key = "focusEnabled", table = function(db) return db end,
      label = "Show focus cast bar", default = true,
      callback = function(_, v) ns:SetBarEnabled("focus", v) end },
    { typ = "slider", key = "textSize", table = function(db) return db end,
      label = "Bar text size", min = 8, max = 22, step = 1, default = 12,
      tooltip = "Font size of the spell name and cast-time text.",
      callback = function(_, v) ns:ApplyTextSize(v) end },
  } },
}

-- Live-apply settings (callbacks fire long after onLoad, so the bars exist).
---@param which string  "target" | "focus"
---@param on boolean
function ns:SetBarEnabled(which, on)
  if self.bars then self.bars[which]:SetEnabled(on) end
end

---@param size number
function ns:ApplyTextSize(size)
  if not self.bars then return end
  for _, bar in pairs(self.bars) do bar:SetTextSize(size) end
end

function ns:onLoad()
  local CastBar = self.CastBar
  self.bars = {
    target = CastBar:new{
      name = "ShadowsOfUICastBarTarget", unit = "target", events = { "PLAYER_TARGET_CHANGED" },
      enabled = self.db.targetEnabled, pos = self.db.targetPos, textSize = self.db.textSize,
    },
    focus = CastBar:new{
      name = "ShadowsOfUICastBarFocus", unit = "focus", events = { "PLAYER_FOCUS_CHANGED" },
      enabled = self.db.focusEnabled, pos = self.db.focusPos, textSize = self.db.textSize,
    },
  }
  self:WireEditMode()
  self:WireSettingsPreview()
end

-- Show both bars as static samples while our settings panel is open, so the text-size
-- slider's effect is visible immediately (otherwise nothing is on screen without a live
-- cast). DisplayCategory fires on open + every category switch; SettingsPanel.OnHide on close.
function ns:WireSettingsPreview()
  if not (SettingsPanel and SettingsPanel.DisplayCategory) then return end
  hooksecurefunc(SettingsPanel, "DisplayCategory", function(_, category)
    ns:SetPreview(category == ns.settingsCategory)
  end)
  EventRegistry:RegisterCallback("SettingsPanel.OnHide", function() ns:SetPreview(false) end, ns)
end

---@param on boolean
function ns:SetPreview(on)
  if not self.bars then return end
  for _, bar in pairs(self.bars) do bar:SetPreview(on) end
end

-- /scast        → open settings
-- /scast dump   → print current text size + per-bar state/position (dev aid)
SLASH_SUI_CASTBAR1 = "/scast"
SlashCmdList["SUI_CASTBAR"] = function(msg)
  local cmd = (msg or ""):match("^%s*(%S*)"):lower()
  if cmd == "dump" then
    local db = ns.db
    ns:Print(("text %dpx · target %s (%d, %d) · focus %s (%d, %d)"):format(
      db.textSize,
      db.targetEnabled and "on" or "off", db.targetPos.x, db.targetPos.y,
      db.focusEnabled and "on" or "off", db.focusPos.x, db.focusPos.y))
  elseif ns.settingsCategory then
    Settings.OpenToCategory(ns.settingsCategory:GetID())
  end
end
