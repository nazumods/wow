---@type Warbandeer_Characters
local ns = select(2, ...)
local GetBuildInfo = GetBuildInfo
local GetServerTime = GetServerTime
local ipairs, pairs, select = ipairs, pairs, select

-- Account-wide **class-collectible ownership** snapshot: the two oracles Detail's appearance cards
-- resolve LIVE each render, frozen into the DB so an offline reader can answer them too.
--
--  * appearance-unlock quest flags (C_QuestLog.IsQuestFlaggedCompletedOnAccount) behind
--    ns.AppearanceUnlocks — Druid Marks / travel-form glyphs, Warlock Grimoires + green fire
--  * class-mount `isCollected` (C_MountJournal) behind ns.ClassMounts
--
-- Per-character applied glyphs (`glyphs.applied`) and learned class unlocks (`glyphs.unlocks`) are
-- already persisted by data/glyphs.lua; these two are not, so the offline app can't tell which
-- appearance unlocks the warband owns. Neither is offloadable to static game data: QuestV2 knows a
-- quest exists but never who completed it, and Mount.db2 gives a mount's identity, not ownership
-- (the only external answer is Blizzard's account collections endpoint, which needs an OAuth client
-- secret no distributed binary can ship) — see #636.
--
-- Account-wide, not per character: both answers are identical for every character (the character
-- only selects which class roster to show), so this lives once at `db.classCollectibles` — the
-- data/titlecatalog.lua pattern — and BOTH catalogs are walked for EVERY class, not just the
-- logged-in one. The live getters (api.lua's GetAppearanceUnlocks / GetClassMounts) keep reading
-- the client directly; in game that's always right, and this snapshot is purely for the reader
-- that has no client.
--
-- Unlocks are keyed by QUEST id rather than one bool per catalog entry, because a progressive row
-- (green fire) needs `startQuest` answered as well as `quest` to pick which itemID to surface — a
-- per-entry bool throws that half away. The quest-keyed set reproduces GetAppearanceUnlocks exactly.
--
-- Mount ownership is TRI-STATE: `true` collected, `false` resolved-but-not-collected, and ABSENT
-- when the id didn't resolve to a mountID this scan. GetMountFromItem returns nil for an item whose
-- data hasn't loaded, so a cold first-login scan must record "unknown", never a false negative.

-- Trailing-scan delay for the re-scan events (matching data/titlecatalog.lua's debounce).
local SCAN_DEBOUNCE = 1000

---@class ClassCollectibleMounts
---@field spells table<integer, boolean>  spell-keyed catalog entry -> collected; absent = unresolved
---@field items table<integer, boolean>   item-keyed catalog entry -> collected; absent = unresolved

---@class ClassCollectibles
---@field build string  client build number the scan came from (GetBuildInfo's 2nd return)
---@field scannedAt integer  server time of the scan
---@field scannedBy string  name of the character that scanned (any character reads the same answers)
---@field quests table<integer, true>  account-completed quest ids from the AppearanceUnlocks catalog
---@field mounts ClassCollectibleMounts  class-mount ownership, split by which id the catalog keys on
---@field questCount integer  entries in `quests`
---@field mountCount integer  class mounts the account has collected
---@field mountUnresolved integer  catalog mounts whose id didn't resolve to a mountID this scan

---@class WarbandeerCharactersDB
---@field classCollectibles ClassCollectibles?  account-wide unlock/collected state; nil until first login after this shipped

-- Pure shaper (WoW-API-free, unit-tested): scan rows -> the stored snapshot. A quest row is
-- `{ id, done }` and only a completed one is written (absent = not completed, so an untouched
-- account doesn't serialise a key per quest). A mount row is `{ spellID?, itemID?, collected? }`,
-- filed under `spells` when it carries a spellID (matching GetClassMounts' resolution order) and
-- `items` otherwise; `collected == nil` means the id didn't resolve, so nothing is written and only
-- `mountUnresolved` counts it. First row for an id wins. The returned tables are fresh every call,
-- so an id a later scan no longer reports simply vanishes — there are no stale keys to clean up.
---@param rows { quests: { id: integer, done: boolean? }[]?, mounts: { spellID: integer?, itemID: integer?, collected: boolean? }[]? }?
---@param meta { build: string?, scannedAt: integer?, scannedBy: string? }?
---@return ClassCollectibles
function ns.ShapeClassCollectibles(rows, meta)
  rows = rows or {}
  local quests, questCount = {}, 0
  for _, r in ipairs(rows.quests or {}) do
    if r.id and r.done and quests[r.id] == nil then
      quests[r.id] = true
      questCount = questCount + 1
    end
  end

  local mounts = { spells = {}, items = {} }
  local seen = { spells = {}, items = {} }
  local mountCount, unresolved = 0, 0
  for _, r in ipairs(rows.mounts or {}) do
    local kind = r.spellID and "spells" or (r.itemID and "items" or nil)
    local key = r.spellID or r.itemID
    if kind and not seen[kind][key] then
      seen[kind][key] = true
      if r.collected == nil then
        unresolved = unresolved + 1
      else
        mounts[kind][key] = r.collected == true
        if r.collected then mountCount = mountCount + 1 end
      end
    end
  end

  meta = meta or {}
  return {
    build = meta.build, scannedAt = meta.scannedAt, scannedBy = meta.scannedBy,
    quests = quests, mounts = mounts,
    questCount = questCount, mountCount = mountCount, mountUnresolved = unresolved,
  }
end

-- The live client scan, walking both catalogs for every class. Quest rows cover a progressive
-- unlock's `startQuest` alongside its `quest` (see the header). A mount row leaves `collected` nil
-- when the id doesn't resolve and re-requests the cold item, so ITEM_DATA_LOAD_RESULT re-scans it.
local function scanRows()
  local isDone = C_QuestLog.IsQuestFlaggedCompletedOnAccount
  local quests = {}
  for _, list in pairs(ns.AppearanceUnlocks) do
    for _, e in ipairs(list) do
      quests[#quests + 1] = { id = e.quest, done = isDone(e.quest) == true }
      if e.startQuest then
        quests[#quests + 1] = { id = e.startQuest, done = isDone(e.startQuest) == true }
      end
    end
  end

  local fromSpell, fromItem = C_MountJournal.GetMountFromSpell, C_MountJournal.GetMountFromItem
  local infoByID = C_MountJournal.GetMountInfoByID
  local mounts = {}
  for _, roster in pairs(ns.ClassMounts) do
    for _, e in ipairs(roster) do
      local mountID = (e.spellID and fromSpell(e.spellID)) or (e.itemID and fromItem(e.itemID))
      local collected
      if mountID then
        collected = select(11, infoByID(mountID)) == true
      elseif e.itemID then
        C_Item.RequestLoadItemDataByID(e.itemID)
      end
      mounts[#mounts + 1] = { spellID = e.spellID, itemID = e.itemID, collected = collected }
    end
  end

  return { quests = quests, mounts = mounts }
end

-- Re-scan and replace the stored snapshot. Bails keeping the last snapshot while the mount journal
-- reports no mounts at all (pre-data login), so a cold read never blanks a good snapshot.
local function refresh()
  if (C_MountJournal.GetNumMounts() or 0) == 0 then return end
  local _, build = GetBuildInfo()
  ns.db.classCollectibles = ns.ShapeClassCollectibles(scanRows(), {
    build = build,
    scannedAt = GetServerTime(),
    scannedBy = ns.currentPlayer,
  })
end

-- Every itemID the class-mount catalog keys on, so the ITEM_DATA_LOAD_RESULT hook only re-scans for
-- an item this snapshot cares about (the event fires for every item the whole UI loads).
local function catalogItems()
  local set = {}
  for _, roster in pairs(ns.ClassMounts) do
    for _, e in ipairs(roster) do
      if e.itemID then set[e.itemID] = true end
    end
  end
  return set
end

---Login-time setup: take a fresh scan, then re-scan whenever an answer can change — a newly
---collected mount (NEW_MOUNT_ADDED), a turned-in quest (QUEST_TURNED_IN), or a catalog item's data
---finally arriving (ITEM_DATA_LOAD_RESULT, which is what clears a mount left `unresolved` by the
---first login scan). All three share one trailing scan, debounced so a burst collapses.
---@class Warbandeer_Characters
---@field InitClassCollectibles fun()
function ns:InitClassCollectibles()
  refresh()
  local items = catalogItems()
  local function rescan() ns:debounce("classCollectibles", SCAN_DEBOUNCE, refresh) end
  ns:registerEvent("NEW_MOUNT_ADDED", rescan)
  ns:registerEvent("QUEST_TURNED_IN", rescan)
  ns:registerEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID)
    if items[itemID] then rescan() end
  end)
end
