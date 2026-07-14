---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local sort = table.sort
local huge = math.huge

-- Self-registering missing-data report. Each broker field declares its own completeness
-- criteria co-located with the field (a `missing` descriptor — see broker.lua's
-- MissingDescriptor), and non-broker caches register a provider via ns:RegisterMissing.
-- This file is a generic WALKER over those declarations: it no longer hardcodes one check
-- per field, so a new tracked field participates automatically (add a broker field and it's
-- covered; a field with no declaration is auto-flagged until it opts in or out, surfaced by
-- ns:AuditMissing / `/wbc missing audit`).

-- Warbandeer_Bars is optional, so its API is reached via the global. A profile captured
-- since the layout-snapshot upgrade always has bindingSet (1 or 2), so a nil there means the
-- character hasn't been re-snapshotted (logged in) since. Returns the missing-report entry,
-- or nil when the bars data is complete (or Warbandeer_Bars isn't loaded). This is the one
-- provider with no data-file home — Warbandeer_Bars is a separate, optional addon.
local function missingBars(name)
  local api = WarbandeerBarsApi
  if not (api and name) then return end
  local profiles = api:GetProfiles(name)
  if not profiles or not next(profiles) then return "bars profile" end
  local stale
  for _, profile in pairs(profiles) do
    if profile.bindingSet == nil then
      stale = stale or {}
      table.insert(stale, profile.spec or "Unknown")
    end
  end
  if not stale then return end
  table.sort(stale)
  return "bars snapshot (" .. table.concat(stale, ", ") .. ")"
end

ns:RegisterMissing{
  order = 50,
  check = function(toon) return missingBars(toon.name) end,
}

-- The merged, order-sorted completeness entries: one per broker field carrying a `missing`
-- declaration, plus every ns:RegisterMissing provider. Built once, lazily, on the first
-- report (missing.lua loads after every data file, so all brokers/providers are registered
-- by then). Each entry's `eval(toon)` returns a label, a list of labels, or nil.
local entries

local function buildEntries()
  entries = {}
  local seq = 0
  local function add(order, maxLevel, eval)
    seq = seq + 1
    insert(entries, { order = order or huge, seq = seq, maxLevel = maxLevel, eval = eval })
  end

  for _, bname in ipairs(ns.brokerOrder) do
    for fname, field in pairs(ns.brokers[bname].fields or {}) do
      local d = field.missing
      if d ~= false then
        if d == nil then
          -- Undeclared: opt-out default — a nil stored value is "missing" (respecting the
          -- field's own maxLevel gather-gate), labelled by field name. A new field is
          -- covered automatically; the audit nags until it declares a proper descriptor
          -- (or `missing = false`).
          add(huge, field.maxLevel, function(toon)
            if (toon[bname] and toon[bname][fname]) == nil then return fname end
          end)
        else
          if type(d) == "function" then d = { check = d } end
          local check, label = d.check, d.label
          add(d.order, d.maxLevel, function(toon)
            local v = toon[bname] and toon[bname][fname]
            if check then return check(toon, v) end
            if v == nil then return label end
          end)
        end
      end
    end
  end

  for _, p in ipairs(ns.missingProviders) do
    add(p.order, p.maxLevel, p.check)
  end

  -- Explicit `order` reproduces the historical per-line sequence exactly; ties (and
  -- undeclared fields, which share order = huge) fall back to registration order.
  sort(entries, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.seq < b.seq
  end)
end

-- The list of missing-data labels for one character, in report order. Evaluates every entry
-- whose maxLevel gate passes (only at the level cap), flattening each label / label-list.
---@class Warbandeer_Characters
---@field getMissingFields fun(toon: Character): string[]
function ns.getMissingFields(toon)
  if not entries then buildEntries() end
  local missing = {}
  local atMax = toon.basic and toon.basic.level == ns.wow.maxLevel
  for _, e in ipairs(entries) do
    if not (e.maxLevel and not atMax) then
      local r = e.eval(toon)
      if type(r) == "table" then
        for _, label in ipairs(r) do insert(missing, label) end
      elseif r then
        insert(missing, r)
      end
    end
  end
  return missing
end
local getMissingFields = ns.getMissingFields

---@class Warbandeer_Characters
---@field getMissingReport fun(self): string[] Report of missing character data
function ns:getMissingReport()
  local current = self.currentPlayer
  local currentLine
  local missing = {}
  for name, toon in pairs(self.db.characters) do
    local issues = getMissingFields(toon)
    if #issues > 0 then
      local line = name .. " - missing " .. table.concat(issues, ", ")
      if name == current then
        currentLine = line
      else
        table.insert(missing, line)
      end
    end
  end
  table.sort(missing)
  -- The logged-in character, when it has missing data, is pinned to the very top
  -- ahead of the alphabetically-sorted rest.
  if currentLine then
    table.insert(missing, 1, currentLine)
  end
  return missing
end

-- Broker fields with no completeness stance (neither a `missing` descriptor nor an explicit
-- `missing = false`). These are auto-flagged by the walker, so this is the forcing function
-- that keeps the report complete by construction: a clean build returns nothing.
---@class Warbandeer_Characters
---@field AuditMissing fun(self): string[] "<broker>.<field>" names lacking a completeness declaration
function ns:AuditMissing()
  local undeclared = {}
  for _, bname in ipairs(self.brokerOrder) do
    for fname, field in pairs(self.brokers[bname].fields or {}) do
      if field.missing == nil then
        insert(undeclared, bname .. "." .. fname)
      end
    end
  end
  sort(undeclared)
  return undeclared
end

ns:registerCommand("missing", "", function(self)
  local missing = self:getMissingReport()

  if #missing == 0 then
    ns.Print("All characters have complete data.")
    return
  end

  ns.Print(#missing .. " characters missing data:")
  for _, line in ipairs(missing) do
    print(line)
  end
end, "List characters missing data")

ns:registerCommand("missing", "me", function(self)
  local toon = self.currentData
  local missing = getMissingFields(toon)

  if #missing > 0 then
    ns.Print("Missing: " .. table.concat(missing, ", "))
  else
    ns.Print("No missing data.")
  end
end, "List the current character's missing data")

ns:registerCommand("missing", "audit", function(self)
  local undeclared = self:AuditMissing()
  if #undeclared == 0 then
    ns.Print("Every broker field declares a completeness stance.")
    return
  end
  ns.Print(#undeclared .. " broker field(s) with no `missing` declaration (auto-flagged by "
    .. "default — add a descriptor or `missing = false`):")
  for _, f in ipairs(undeclared) do print("  " .. f) end
end, "Audit broker fields lacking a completeness declaration (dev)")

-- Dev nudge: shortly after load, warn once if any broker field ships with no completeness
-- stance. Silent in a clean build (every field declares a descriptor or `missing = false`),
-- so users never see it — it only fires when a field is added without one, catching exactly
-- the "someone forgot to update the report" gap this system removes.
C_Timer.After(10, function()
  local undeclared = ns:AuditMissing()
  if #undeclared > 0 then
    ns.Print(("missing: %d broker field(s) undeclared for completeness (%s) — add a `missing` "
      .. "descriptor or `missing = false`; see /wbc missing audit."):format(
      #undeclared, table.concat(undeclared, ", ")))
  end
end)
