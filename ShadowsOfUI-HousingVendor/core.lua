---@class ShadowsOfUI_HousingVendor: AddOn
local ns = LibNAddOn(...)

-- Saved settings. Two groups: which *indicators* to draw (applied on every
-- surface) and which *surfaces* to decorate.
--   Indicators
--     countBadge — the in-storage owned count, bottom-left of the icon
--     bonusBadge — the first-acquisition House XP bonus star, top-left
--     ownedCheck — a green "you own this" check, top-left (off: the count already
--                  signals ownership; on for users who run without the count badge)
--     wantedBadge — a "wanted" star, top-right, on decor flagged wanted in
--                  Warbandeer_Decor (soft dep: never drawn when that addon is absent)
--   Surfaces (the merchant window is always decorated — no toggle)
--     bags   — decor in the Blizzard bags
--     bank   — decor in the Blizzard bank
--     bagnon — decor on Bagnon / Bagnonium bag buttons
local Defaults = {
  countBadge = true,
  bonusBadge = true,
  ownedCheck = false,
  wantedBadge = true,
  bags = true,
  bank = true,
  bagnon = true,
}

function ns:MigrateDB()
  local db = self.db
  for k, v in pairs(Defaults) do
    if db[k] == nil then db[k] = v end -- non-destructive: only add missing keys
  end
  db.version = 2
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
      { typ = "checkbox", key = "wantedBadge", default = true, name = "Wanted star",
        label = "wanted star", table = dbTable,
        tooltip = "Mark decor flagged 'wanted' in the Decor tracker (Warbandeer_Decor) with a star, top-right. Needs that addon; ignored without it." },
      { typ = "checkbox", key = "bags", default = true, name = "In bags",
        label = "in bags", table = dbTable,
        tooltip = "Show the indicators on decor in your bags (the merchant window is always decorated)." },
      { typ = "checkbox", key = "bank", default = true, name = "In bank",
        label = "in bank", table = dbTable,
        tooltip = "Show the indicators on decor in your bank." },
      { typ = "checkbox", key = "bagnon", default = true, name = "In Bagnon",
        label = "in Bagnon", table = dbTable,
        tooltip = "Show the indicators on decor in Bagnon / Bagnonium bags (if you use them)." },
    },
  },
}

-- "Changelog" button in the settings category, showing ns.changelog (changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- Decor owned-state isn't available from the housing catalog immediately after
-- login; kicking off a catalog search primes it (fires HOUSING_STORAGE_UPDATED
-- once ready, which the handler below listens for).
function ns:onLogin()
  if C_HousingCatalog and C_HousingCatalog.CreateCatalogSearcher then
    C_HousingCatalog.CreateCatalogSearcher()
  end
  -- Repaint every visible surface when a decor's wanted flag flips elsewhere (e.g. a
  -- shift-click in the /wbdecor window while a merchant is open), so the wanted marker
  -- never sits stale. Soft dep: a no-op when Warbandeer_Decor (and its API) isn't loaded.
  local wanted = _G.WarbandeerHousingDecorApi
  if wanted and wanted.OnRatingsChanged then
    wanted:OnRatingsChanged(ns.Refresh)
  end
end

-- Owned counts change on several signals, so hook all of them: buying / placing /
-- redeeming already-owned decor (HOUSING_STORAGE_UPDATED and its per-entry sibling
-- HOUSING_STORAGE_ENTRY_UPDATED), and *learning* a brand-new decor from the bags
-- (NEW_HOUSING_ITEM_ACQUIRED — a first acquisition, which the coarse storage event
-- doesn't cover). Without the acquisition event, learning one of two identical decor
-- in the bags left the other copy's overlay stale until a /reload. On any of them,
-- drop the shared decor cache so the next paint re-queries the catalog, then repaint
-- every visible surface (each refresher no-ops when its own frame is hidden).
local function refreshDecor()
  ns.WipeDecorCache()
  ns.Refresh()
end
for _, event in ipairs({
  "HOUSING_STORAGE_UPDATED",
  "HOUSING_STORAGE_ENTRY_UPDATED",
  "NEW_HOUSING_ITEM_ACQUIRED",
}) do
  ns:registerEvent(event, refreshDecor)
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
      "· first-acquisition star:", tostring(db.bonusBadge), "· owned check:", tostring(db.ownedCheck),
      "· wanted star:", tostring(db.wantedBadge))
    ns:Print("surfaces — merchant: always · bags:", tostring(db.bags),
      "· bank:", tostring(db.bank), "· bagnon:", tostring(db.bagnon))
    ns:Print("  /shvendor itemtest")
  end
end
