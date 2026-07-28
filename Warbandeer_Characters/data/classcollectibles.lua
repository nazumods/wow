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
--
-- **This snapshot only ever grows within a build.** Both halves are monotonic, so every scan ORs
-- against the stored one instead of replacing it (see `scanRows`). That is the invariant a future
-- maintainer needs: nothing here may be written from a live read alone, because a live read on a
-- cold login is indistinguishable from a genuine negative — and this store is account-wide, so one
-- bad login on any alt would blank the answer for the whole warband (#733).

-- Trailing-scan delay for the re-scan events (matching data/titlecatalog.lua's debounce).
local SCAN_DEBOUNCE = 1000

-- How many ITEM_DATA_LOAD_RESULT rounds a single catalog item gets before it is dropped from the
-- watch set. A real load resolves on the first; the cap is what stops an id that reports success
-- but never resolves from driving a permanent rebuild loop.
local MAX_ITEM_RETRIES = 5

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
  -- **Sticky against the stored snapshot.** Both payloads are monotonic — an account-completed
  -- quest never un-completes, a collected mount is never un-collected — so `new or previous` is the
  -- correct semantics rather than a heuristic, and it is immune to a cold read no matter which half
  -- is cold or how the timing lands. Without it, a login where the mount journal has populated but
  -- the account quest-completion payload has not writes `quests = {}` over the whole warband's
  -- answer (#733): the store is account-wide, so one bad login on any alt blanks every character.
  --
  -- Applied here rather than in ShapeClassCollectibles, which stays a pure transform. Stale keys are
  -- still handled: only ids the CURRENT catalog declares are emitted, so an id dropped from
  -- ns.AppearanceUnlocks / ns.ClassMounts still vanishes on the next scan.
  local prev = ns.db.classCollectibles or {}
  local prevQuests = prev.quests or {}
  local prevSpells = (prev.mounts and prev.mounts.spells) or {}
  local prevItems = (prev.mounts and prev.mounts.items) or {}

  local isDone = C_QuestLog.IsQuestFlaggedCompletedOnAccount
  local quests = {}
  local function addQuest(id)
    quests[#quests + 1] = { id = id, done = isDone(id) == true or prevQuests[id] == true }
  end
  for _, list in pairs(ns.AppearanceUnlocks) do
    for _, e in ipairs(list) do
      addQuest(e.quest)
      if e.startQuest then addQuest(e.startQuest) end
    end
  end

  local fromSpell, fromItem = C_MountJournal.GetMountFromSpell, C_MountJournal.GetMountFromItem
  local infoByID = C_MountJournal.GetMountInfoByID
  -- A populated journal is what makes a `false` here mean "resolved, not collected" rather than
  -- "the journal hasn't answered yet" — see the tri-state note in the header.
  local journalReady = (C_MountJournal.GetNumMounts() or 0) > 0
  local mounts = {}
  for _, roster in pairs(ns.ClassMounts) do
    for _, e in ipairs(roster) do
      local mountID = (e.spellID and fromSpell(e.spellID)) or (e.itemID and fromItem(e.itemID))
      local was = (e.spellID and prevSpells[e.spellID]) or (e.itemID and prevItems[e.itemID])
      local collected
      if was == true then
        collected = true                    -- sticky: never un-collected
      elseif mountID and journalReady then
        collected = select(11, infoByID(mountID)) == true
      elseif e.itemID then
        C_Item.RequestLoadItemDataByID(e.itemID)
      end
      -- `collected` stays nil when the id didn't resolve OR the journal isn't ready, so the entry is
      -- counted as unresolved rather than persisting a definite `false` (#733): absent ≠ false.
      mounts[#mounts + 1] = { spellID = e.spellID, itemID = e.itemID, collected = collected }
    end
  end

  return { quests = quests, mounts = mounts }
end

-- Re-scan and replace the stored snapshot.
--
-- The empty-journal bail is a cheap early-out and NOTHING MORE. It used to be the only protection
-- against a cold read blanking a good snapshot, and it never actually provided that: it tests a
-- mount quantity while the half most likely to be cold is the account QUEST payload, which it says
-- nothing about (#733). `scanRows` is sticky now, so correctness no longer rests here — this just
-- skips work that would find nothing.
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
  local attempts = {}
  local function rescan() ns:debounce("classCollectibles", SCAN_DEBOUNCE, refresh) end
  ns:registerEvent("NEW_MOUNT_ADDED", rescan)
  ns:registerEvent("QUEST_TURNED_IN", rescan)
  ns:registerEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
    -- `success` is checked for the reason data/stats.lua:90 states verbatim — "so a failed load
    -- can't drive a request/rescan loop". Without it, an id that never resolves makes every scan
    -- re-request it, which fires this event again, at roughly 1 Hz for the whole session (#733).
    if not success or not items[itemID] then return end
    -- The cap covers the other half: an id that keeps reporting success but never resolves to a
    -- mountID would otherwise loop just as hard. A handful of tries is plenty for a real load.
    attempts[itemID] = (attempts[itemID] or 0) + 1
    if attempts[itemID] > MAX_ITEM_RETRIES then items[itemID] = nil; return end
    rescan()
  end)
end
