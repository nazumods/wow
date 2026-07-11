---@class ShadowsOfUI_HousingVendor: AddOn
local ns = LibNAddOn(...)

-- Saved settings. Each overlay indicator is independently toggleable; the module
-- has a single surface (the merchant window), so there is no per-surface switch.
--   countBadge — the in-storage owned count, bottom-left of the icon
--   bonusBadge — the first-acquisition House XP bonus star, top-right
--   ownedCheck — a green "you own this" check, top-left (off: the count already
--                signals ownership; on for users who run without the count badge)
local Defaults = {
  countBadge = true,
  bonusBadge = true,
  ownedCheck = false,
}

function ns:MigrateDB()
  local db = self.db
  for k, v in pairs(Defaults) do
    if db[k] == nil then db[k] = v end -- non-destructive: only add missing keys
  end
  db.version = 1
end

-- Re-render every currently-visible surface. Surfaces register a refresher here so
-- a settings change takes effect immediately on anything already on screen.
ns._refreshers = {}
function ns.AddRefresher(fn)
  table.insert(ns._refreshers, fn)
end
function ns.Refresh()
  for _, fn in ipairs(ns._refreshers) do fn() end
end

function ns:settingChanged()
  ns.Refresh()
end

local function dbTable(db) return db end
ns:RegisterSettings{
  {
    title = ns._TITLE,
    parent = "Shadows of UI",
    fields = {
      { typ = "checkbox", key = "countBadge", default = true, name = "Storage count",
        label = "storage count", table = dbTable,
        tooltip = "Overlay the number you have in storage on owned decor at a vendor." },
      { typ = "checkbox", key = "bonusBadge", default = true, name = "First-acquisition star",
        label = "first-acquisition star", table = dbTable,
        tooltip = "Mark decor that grants a one-time House XP bonus the first time you get it (and that you don't own yet) with a gold star." },
      { typ = "checkbox", key = "ownedCheck", default = false, name = "Owned check",
        label = "owned check", table = dbTable,
        tooltip = "Add a green check to decor you already own. The storage count already implies ownership, so this is off by default." },
    },
  },
}

-- "Changelog" button in the settings category, showing ns.changelog (changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- Decor owned-state isn't available from the housing catalog immediately after
-- login; kicking off a catalog search primes it (fires HOUSING_STORAGE_UPDATED
-- once ready, which the merchant surface listens for).
function ns:onLogin()
  if C_HousingCatalog and C_HousingCatalog.CreateCatalogSearcher then
    C_HousingCatalog.CreateCatalogSearcher()
  end
end

-- ─── /shvendor ────────────────────────────────────────────────────────────────
-- no arg      — print status
-- itemtest    — dump normalized decor info for the item under the cursor (dev aid)

local function itemtest()
  local _, link = GameTooltip:GetItem()
  if not link then return ns:Print("No item under the cursor.") end
  ns:Print(link)
  local d = ns.DecorEntryFor(link)
  if not d then return ns:Print("  not housing decor (or catalog not ready).") end
  ns:Print(("  owned:%s stored:%d total:%d bonus:%d bonusAvailable:%s"):format(
    tostring(d.owned), d.stored, d.total, d.bonus, tostring(d.bonusAvailable)))
end

SLASH_SUI_HVENDOR1 = "/shvendor"
SlashCmdList["SUI_HVENDOR"] = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$"):lower()
  if msg == "itemtest" then
    itemtest()
  else
    local db = ns.db
    ns:Print("indicators — storage count:", tostring(db.countBadge),
      "· first-acquisition star:", tostring(db.bonusBadge), "· owned check:", tostring(db.ownedCheck))
    ns:Print("  /shvendor itemtest")
  end
end
