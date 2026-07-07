---@type Warbandeer
local ns = select(2, ...)

-- Friendlier settings labels than the terse toggle captions the apply panel shows
-- ("1", "C1", "Bonus"). Numbered bars and class pages are derived; the three
-- special bars are named explicitly.
local SPECIAL = { Bonus = "Bonus Bar", Sky = "Skyriding Bar", Pet = "Pet Bar" }
local function settingName(label)
  if SPECIAL[label] then return SPECIAL[label] end
  if label:match("^C%d$") then return "Class Page " .. label:sub(2) end
  return "Action Bar " .. label
end

-- One checkbox per Bars Apply toggle, setting whether that bar is pre-checked when
-- the apply panel opens for a new profile. Default mirrors the built-in state
-- (`not def.off`), so the box matches the panel until the user changes it. The value
-- is read in BarsApply.lua's toggle init, so a change takes effect the next time the
-- apply panel is built (a fresh session / reload).
local fields = {}
for _, def in ipairs(ns.BarApplyToggles) do
  local name = settingName(def.label)
  fields[#fields + 1] = {
    name = def.label,
    typ = "checkbox",
    default = not def.off,
    -- Ensure-and-persist the backing table: MigrateDB only creates it on the v7 bump,
    -- so a DB already current but missing the table would hand Settings a nil tbl.
    table = function(db)
      db.settings.barApplyDefaults = db.settings.barApplyDefaults or {}
      return db.settings.barApplyDefaults
    end,
    key = def.label,
    label = name,
    tooltip = "Include the " .. name .. " by default when the Bars Apply panel opens.",
  }
end

-- Nest a "Bar Apply Defaults" subcategory under the existing Warbandeer panel.
ns:RegisterSettings{
  {
    parent = "Warbandeer",
    title = "Bar Apply Defaults",
    fields = fields,
  },
}
