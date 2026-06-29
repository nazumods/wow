---@type Warbandeer
local ns = select(2, ...)

-- One checkbox per recommended-consumable category (flask, combat potion, food, weapon buff,
-- augment rune), letting the user hide categories from the Detail view's Consumables box.
-- Consumables come only from ClassCodex via ShadowsOfUI-Upgrade, so this subcategory is
-- registered only when that addon is loaded — mirroring the gated Up/Ench/Gem Summary columns.
local api = ShadowsOfUI_UpgradeApi
if not (api and api.RecommendedConsumables and ns.ConsumableCats) then return end

-- Re-render the open Detail view so a toggle takes effect immediately.
local function refreshDetail()
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  if view and view.name == "detail" then view:OnBeforeShow(); ns.MainWindow:Fit() end
end

local fields = {}
for _, cat in ipairs(ns.ConsumableCats) do
  fields[#fields + 1] = {
    name = cat.label,
    typ = "checkbox",
    default = true,
    -- Ensure-and-persist the backing table (MigrateDB only creates it on a version bump),
    -- mirroring summaryColumnsSettings + the box's own `or {}` read.
    table = function(db)
      db.settings.consumables = db.settings.consumables or {}
      return db.settings.consumables
    end,
    key = cat.key,
    label = cat.label,
    tooltip = "Show the " .. cat.label .. " recommendation in the Detail view's Consumables box",
    callback = refreshDetail,
  }
end

-- Nest a "Consumables" subcategory under the existing Warbandeer panel (getParent reuses the
-- category init.lua created), like the Summary Columns subcategory.
ns:RegisterSettings{
  {
    parent = "Warbandeer",
    title = "Consumables",
    fields = fields,
  },
}
