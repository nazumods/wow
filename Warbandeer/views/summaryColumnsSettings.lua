---@type Warbandeer
local ns = select(2, ...)

-- Build one checkbox per toggleable Summary column (those carrying a `key`; the
-- always-on identity columns have none and are skipped). Runs after every
-- summaryCol/*.lua has populated ns.SummaryColumns, so the list is complete here —
-- including only the gated Up/Ench/Gem columns when ShadowsOfUI-Upgrade is loaded.
local fields = {}
for _, c in ipairs(ns.SummaryColumns) do
  if c.key then
    fields[#fields + 1] = {
      name = c.label,
      typ = "checkbox",
      default = true,
      -- Ensure-and-persist the backing table: MigrateDB only creates it on a version
      -- bump (DB v4), so a DB already at the current version but missing the table
      -- would otherwise hand Settings a nil variableTbl. Mirrors VisibleSummaryColumns' `or {}`.
      table = function(db)
        db.settings.summaryColumns = db.settings.summaryColumns or {}
        return db.settings.summaryColumns
      end,
      key = c.key,
      label = c.label,
      tooltip = "Show the " .. c.label .. " column in the Summary view",
      -- value is committed to db.settings.summaryColumns before this fires
      callback = function() ns.RefreshSummaryColumns() end,
    }
  end
end

-- Nest a "Summary Columns" subcategory under the existing Warbandeer panel so the
-- checkboxes don't crowd the main page. A second RegisterSettings call is safe:
-- getParent("Warbandeer") reuses the category init.lua already created.
if #fields > 0 then
  ns:RegisterSettings{
    {
      parent = "Warbandeer",
      title = "Summary Columns",
      fields = fields,
    },
  }
end
