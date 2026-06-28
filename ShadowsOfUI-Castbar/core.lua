---@class ShadowsOfUI_Castbar: AddOn
---@field CastBar CastBar  the cast-bar widget class (CastBar.lua)
---@field bars table<string, CastBar>  the two live bars, keyed "target" / "focus"
---@field SetConfigMode fun(self: ShadowsOfUI_Castbar, on: boolean)  toggle Edit Mode placement (editmode.lua)
---@field WireEditMode fun(self: ShadowsOfUI_Castbar)  hook Blizzard Edit Mode (editmode.lua)
local ns = LibNAddOn(...)

-- Default CENTER offsets (UIParent) before the user drags a bar in Edit Mode.
local DEFAULT_POS = {
  target = { x = 0, y = 160 },
  focus  = { x = 0, y = 124 },
}

function ns:MigrateDB()
  local db = ns.db
  if db.textSize == nil then db.textSize = 12 end
  if db.targetEnabled == nil then db.targetEnabled = true end
  if db.focusEnabled == nil then db.focusEnabled = true end
  if db.targetPos == nil then db.targetPos = { x = DEFAULT_POS.target.x, y = DEFAULT_POS.target.y } end
  if db.focusPos == nil then db.focusPos = { x = DEFAULT_POS.focus.x, y = DEFAULT_POS.focus.y } end
  db.version = 1
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
      label = "Bar text size", min = 8, max = 18, step = 1, default = 12,
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
