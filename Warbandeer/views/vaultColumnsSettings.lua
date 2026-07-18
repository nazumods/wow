---@type Warbandeer
local ns = select(2, ...)

-- Build one checkbox per toggleable Great Vault column (those carrying a `key`; the always-on
-- crest / Character / Lvl identity columns have none and are skipped). ns.VaultColumns is fully
-- populated by VaultColumns.lua (loaded earlier in the .toc), so the list is complete here.
local fields = {}
for _, c in ipairs(ns.VaultColumns) do
  if c.key then
    fields[#fields + 1] = {
      name = c.label,
      typ = "checkbox",
      default = true,
      -- Ensure-and-persist the backing table: MigrateDB only creates it on the v8 bump, so a DB
      -- already at the current version but missing the table would otherwise hand Settings a nil
      -- variableTbl. Mirrors VisibleVaultColumns' `or {}` and summaryColumnsSettings.
      table = function(db)
        db.settings.vaultColumns = db.settings.vaultColumns or {}
        return db.settings.vaultColumns
      end,
      key = c.key,
      label = c.label,
      tooltip = "Show the " .. c.label .. " column in the Great Vault view",
      -- value is committed to db.settings.vaultColumns before this fires
      callback = function() ns.RefreshVaultColumns() end,
    }
  end
end

-- Nest a "Great Vault Columns" subcategory under the existing Warbandeer panel so the checkboxes
-- don't crowd the main page. A second RegisterSettings call is safe: getParent("Warbandeer")
-- reuses the category init.lua already created (like the Summary Columns subcategory).
if #fields > 0 then
  ns:RegisterSettings{
    {
      parent = "Warbandeer",
      title = "Great Vault Columns",
      fields = fields,
    },
  }
end
