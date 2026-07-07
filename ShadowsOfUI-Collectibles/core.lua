---@class ShadowsOfUI_Collectibles: AddOn
local ns = LibNAddOn(...)

-- Preset known-item tints (0–1 rgb), indexed to match the settings dropdown below.
local PRESETS = {
  { 1, 0, 0 },       -- Red
  { 0, 1, 0 },       -- Green
  { 0, 0, 1 },       -- Blue
  { 1, 1, 0 },       -- Yellow
  { 0, 1, 1 },       -- Cyan
  { 1, 0, 1 },       -- Purple
  { 0.5, 0.5, 0.5 }, -- Gray
}
local COLOR_OPTIONS = { "Red", "Green", "Blue", "Yellow", "Cyan", "Purple", "Gray" }

-- Fixed green tint for items that are still collectible (not yet owned/learned).
ns.UncollectedColor = { 0, 1, 0 }

-- Saved settings. `r`/`g`/`b` is the authoritative known-item tint (the dropdown
-- writes a preset into it; /scollect custom writes an arbitrary colour). Each
-- surface is independently toggleable.
local Defaults = {
  r = 1, g = 0, b = 0,
  knownColor = 1, -- Red, matches r/g/b above
  monochrome = false,
  markUncollected = true,
  merchant = true,
  auctionHouse = true,
}

function ns:MigrateDB()
  local db = self.db
  for k, v in pairs(Defaults) do
    if db[k] == nil then db[k] = v end -- non-destructive: only add missing keys
  end
  db.version = 1
end

-- The current known-item tint, and whether known icons should be desaturated.
function ns.KnownColor()
  local db = ns.db
  return db.r, db.g, db.b
end

-- Re-tag every currently-visible surface. Surfaces register a refresher here so a
-- settings change takes effect immediately on anything already on screen.
ns._refreshers = {}
function ns.AddRefresher(fn)
  table.insert(ns._refreshers, fn)
end
function ns.Refresh()
  for _, fn in ipairs(ns._refreshers) do fn() end
end

-- Applying the colour preset only when the dropdown itself changed keeps a custom
-- colour (set via /scollect custom) from being clobbered by unrelated toggles.
function ns:settingChanged(key)
  if key == "knownColor" then
    local p = PRESETS[ns.db.knownColor]
    if p then ns.db.r, ns.db.g, ns.db.b = p[1], p[2], p[3] end
  end
  ns.Refresh()
end

local function dbTable(db) return db end
ns:RegisterSettings{
  {
    title = ns._TITLE,
    parent = "Shadows of UI",
    fields = {
      { typ = "dropdown", key = "knownColor", default = 1, options = COLOR_OPTIONS,
        name = "Known-item tint", label = "known-item tint", table = dbTable,
        tooltip = "Colour used to tint items you (or your alts) already know. Use /scollect custom for any colour." },
      { typ = "checkbox", key = "monochrome", default = false, name = "Desaturate known",
        label = "desaturate known", table = dbTable,
        tooltip = "Also grey out the icons of already-known items." },
      { typ = "checkbox", key = "markUncollected", default = true, name = "Mark collectible",
        label = "mark collectible", table = dbTable,
        tooltip = "Tint still-collectible items (recipes/toys/mounts/pets you don't have yet) green." },
      { typ = "checkbox", key = "merchant", default = true, name = "Vendor",
        label = "vendor", table = dbTable, tooltip = "Tint on the merchant window." },
      { typ = "checkbox", key = "auctionHouse", default = true, name = "Auction House",
        label = "auction house", table = dbTable, tooltip = "Tint on the Auction House browse list." },
    },
  },
}

-- "Changelog" button in the settings category, showing ns.changelog (changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- ─── /scollect ──────────────────────────────────────────────────────────────
-- no arg     — print status
-- custom     — open the colour picker for a custom known-item tint
-- itemtest   — dump IsKnown/IsCollectible for the item under the cursor (dev aid)

local function hex(r, g, b)
  return ("%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function openColorPicker()
  local db = ns.db
  local function apply()
    db.r, db.g, db.b = ColorPickerFrame:GetColorRGB()
    RunNextFrame(function()
      if not ColorPickerFrame:IsShown() then
        ns:Print("Custom tint set to |cff" .. hex(db.r, db.g, db.b) .. "this colour|r.")
      end
    end)
    ns.Refresh()
  end
  local function cancel()
    db.r, db.g, db.b = ColorPickerFrame:GetPreviousValues()
    ns.Refresh()
  end
  ColorPickerFrame:SetupColorPickerAndShow{
    r = db.r, g = db.g, b = db.b, hasOpacity = false,
    swatchFunc = apply, cancelFunc = cancel,
  }
end

local function itemtest()
  local _, link = GameTooltip:GetItem()
  if not link then return ns:Print("No item under the cursor.") end
  ns:Print(link)
  ns:Print("  IsKnown:", tostring(ns.IsKnown(link)), "· IsCollectible:", tostring(ns.IsCollectible(link)))
end

SLASH_SUI_COLLECT1 = "/scollect"
SlashCmdList["SUI_COLLECT"] = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$"):lower()
  if msg == "custom" then
    openColorPicker()
  elseif msg == "itemtest" then
    itemtest()
  else
    local db = ns.db
    ns:Print("Known tint |cff" .. hex(db.r, db.g, db.b) .. "this|r · desaturate:", tostring(db.monochrome),
      "· mark collectible:", tostring(db.markUncollected))
    ns:Print("  surfaces — vendor:", tostring(db.merchant), "AH:", tostring(db.auctionHouse))
    ns:Print("  /scollect custom | /scollect itemtest")
  end
end
