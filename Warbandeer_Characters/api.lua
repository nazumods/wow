---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local sort = table.sort
local floor = math.floor
local GetServerTime = GetServerTime

---@class WarbandeerAPI
local API = ns.api

---Name of the currently logged-in character.
---@return string
function API:GetCurrentCharacter() return ns.currentPlayer end

---@param char? string
---@return Character
function API:GetCharacterData(char)
  -- todo: return a copy so it is immutable
  return ns.db.characters[char or ns.currentPlayer]
end

---Whether per-expansion profession detail has been recorded for `char` (default: current) on the
---given trade-skill line. That detail is captured only when the profession's crafting window is
---opened (TRADE_SKILL_SHOW), so a false result means the profession has never been scanned — the
---condition behind ProfsView's "Profession detail not captured" ⚠. Keyed by the parent skill line
---id (the value stamped as `frame.skillLine` on ProfessionsBook frames, and `skillID` from
---Player:GetProfessions). Note: secondary professions (Cooking/Fishing/Archaeology) never record
---expansion detail, so this is always false for them — gate callers to primary professions.
---@param char? string
---@param skillLineID integer
---@return boolean
function API:HasProfessionDetail(char, skillLineID)
  local data = self:GetCharacterData(char)
  local details = data and data.professions and data.professions.details
  local detail = details and details[skillLineID]
  return not not (detail and detail.expansions and #detail.expansions > 0)
end

---Total number of tracked characters.
---@return integer
function API:GetNumCharacters() return ns.db.numCharacters end
---Number of tracked characters at the level cap.
---@return integer
function API:GetNumMaxLevel()
  local n = 0
  for _,c in pairs(ns.db.characters) do
    if c.basic.level == ns.wow.maxLevel then n = n + 1 end
  end
  return n
end

---@class WarbandeerAPI
---@field GetAllCharacters fun(): Character[]
function API:GetAllCharacters()
  local list = {}
  for _,c in pairs(ns.db.characters) do insert(list, c) end
  return list
end

---All tracked Alliance characters (unordered).
---@return Character[]
function API:GetAllianceCharacters()
  local c = {}
  for _,t in pairs(ns.db.characters) do
    if t.isAlliance then table.insert(c, t) end
  end
  return c
end

---All tracked Horde characters (unordered).
---@return Character[]
function API:GetHordeCharacters()
  local c = {}
  for _,t in pairs(ns.db.characters) do
    if not t.isAlliance then table.insert(c, t) end
  end
  return c
end

---Warband (account) bank gold, in copper.
---@return integer
function API:GetWarbandBankGold() return (ns.db.warband and ns.db.warband.bankGold) or 0 end

---Total warband wealth (copper): warband bank + last-known gold of every character.
---@return integer
function API:GetWarbandWealth() return ns:GetWarbandWealth() end

---Gold made for the warband so far this week (copper): current wealth minus the
---week's baseline. May be negative if net wealth has dropped.
---@return integer
function API:GetWeeklyGoldMade()
  local w = ns.db.warband
  if not w or not w.week then return 0 end
  return ns:GetWarbandWealth() - w.week.baseline
end

---Closed-week wealth history (oldest first).
---@return WarbandWeekRecord[]
function API:GetWealthHistory() return (ns.db.warband and ns.db.warband.history) or {} end

---Equippable gear a character has loose in its own bags + personal bank.  Bags
---come from the per-character `gearbag` broker; the bank list is the last scan of
---that character's personal bank (empty until they've opened it).  Both lists are
---last-seen caches and may be empty.
---@param charName string?
---@return { bags: GearCandidate[], bank: GearCandidate[] }
function API:GetCharacterGearCandidates(charName)
  local name = charName or ns.currentPlayer
  local c = ns.db.characters[name]
  local bank = ns.db.bank and ns.db.bank.characters and ns.db.bank.characters[name]
  return {
    bags = (c and c.gearbag and c.gearbag.items) or {},
    bank = (bank and bank.equip) or {},
  }
end

---Equippable gear sitting in the warband (account) bank.  Last-seen; empty until
---the warband bank has been opened.
---@return GearCandidate[]
function API:GetWarbandBankGear()
  return (ns.db.bank and ns.db.bank.warband and ns.db.bank.warband.equip) or {}
end

---Active world-quest gear rewards cached for a character that could upgrade an
---equipped slot.  Captured while that character was logged in (world-quest reward
---data isn't readable for alts), last-seen.  Expired quests are dropped here on
---read, since an alt's cache can't be refreshed live.  Each entry is a
---GearCandidate plus `questID`, `title`, `zone`, `endTime`.
---@param charName string?
---@return WorldQuestReward[]
function API:GetWorldQuestRewards(charName)
  local c = ns.db.characters[charName or ns.currentPlayer]
  local list = c and c.worldquests and c.worldquests.rewards
  if not list then return {} end
  local now = GetServerTime()
  local out = {}
  for _, r in ipairs(list) do
    if not r.endTime or r.endTime > now then insert(out, r) end
  end
  return out
end

---@class ItemCountEntry
---@field name string character name
---@field classKey string PascalCase class key (for class colouring)
---@field realm string? the character's realm, set only when it differs from the current character's realm
---@field bags integer copies in the character's bags + reagent bag
---@field bank integer copies in the character's personal bank
---@field mail integer copies attached to the character's mail
---@field total integer bags + bank + mail

---@class GuildItemCount
---@field name string guild key (name, -realm if cross-realm)
---@field count integer copies in that guild bank

---@class ItemCountReport
---@field total integer grand total across every source
---@field warband integer copies in the shared warband (account) bank, counted once
---@field characters ItemCountEntry[] per-character (bags + personal bank), sorted by total desc
---@field guilds GuildItemCount[] per-guild bank, sorted by count desc

---Account-wide counts of an item across every tracked character's bags + personal
---bank, the shared warband bank, and each known guild bank.  Bag counts are live for
---the logged-in character and last-seen for alts (a character's bag map only updates
---while it's logged in); bank/guild counts are last-seen, captured when that bank was
---last opened.  Returns nil when no copies are tracked anywhere.
---@param itemID integer
---@return ItemCountReport?
function API:GetItemCounts(itemID)
  if not itemID then return nil end
  local bankStore = ns.db.bank
  local charBanks = (bankStore and bankStore.characters) or {}
  local myRealm = ns.currentData and ns.currentData.realm
  local chars, total = {}, 0
  for name, c in pairs(ns.db.characters) do
    local bags = (c.inventory and c.inventory.counts and c.inventory.counts[itemID]) or 0
    local bankData = charBanks[name]
    local bank = (bankData and bankData.items and bankData.items[itemID]) or 0
    local mail = (c.mail and c.mail.items and c.mail.items[itemID]) or 0
    local sum = bags + bank + mail
    if sum > 0 then
      insert(chars, {
        name = name,
        classKey = c.classKey,
        realm = (c.realm and c.realm ~= myRealm) and c.realm or nil,
        bags = bags, bank = bank, mail = mail, total = sum,
      })
      total = total + sum
    end
  end
  local warband = (bankStore and bankStore.warband and bankStore.warband.items and bankStore.warband.items[itemID]) or 0
  total = total + warband
  local guilds = {}
  for gname, g in pairs((bankStore and bankStore.guilds) or {}) do
    local n = g.items and g.items[itemID]
    if n and n > 0 then
      insert(guilds, { name = gname, count = n })
      total = total + n
    end
  end
  if total == 0 then return nil end
  sort(chars, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  sort(guilds, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  return { total = total, warband = warband, characters = chars, guilds = guilds }
end

---A character's last-seen mail cache (inbox count, attachment item counts, attached
---gold, and ascending absolute expiry timestamps).  Captured while that character was
---at a mailbox; nil until it has visited one.  See `MailData`.
---@param charName string?
---@return MailData?
function API:GetMail(charName)
  local c = ns.db.characters[charName or ns.currentPlayer]
  return c and c.mail or nil
end

---A character's cached faction standings, keyed by factionID (last-seen; captured each
---login + on reputation change).  nil until the character has been seen since v21.
---@param charName string?
---@return table<integer, FactionStanding>?
function API:GetReputations(charName)
  local c = ns.db.characters[charName or ns.currentPlayer]
  return c and c.reputations and c.reputations.factions or nil
end

---Every tracked character's standing with one faction, highest first.  Each entry is the
---character's `FactionStanding` plus `name`/`classKey` (for class colouring).  nil when no
---character has any standing with that faction.
---@param factionID integer
---@return { name: string, classKey: string, label: string, rank: integer, done: boolean, paragon: boolean?, accountWide: boolean? }[]?
function API:GetFactionStandings(factionID)
  if not factionID then return nil end
  local out = {}
  for name, c in pairs(ns.db.characters) do
    local f = c.reputations and c.reputations.factions and c.reputations.factions[factionID]
    if f then
      insert(out, { name = name, classKey = c.classKey, label = f.label, rank = f.rank, done = f.done, paragon = f.paragon, accountWide = f.accountWide })
    end
  end
  if #out == 0 then return nil end
  sort(out, function(a, b)
    if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
    return a.name < b.name
  end)
  return out
end

---A character's last-seen owned-auction cache (active auction count, absolute expiry
---stamps, gold tied up, bid count).  Captured while that character was at the auction
---house; nil until it has visited one.  See `AuctionData`.
---@param charName string?
---@return AuctionData?
function API:GetAuctions(charName)
  local c = ns.db.characters[charName or ns.currentPlayer]
  return c and c.auctions or nil
end

---Which tracked characters are on / have completed a quest.  Each list holds
---`{ name, classKey }` (sorted by name); nil when no character is on or has completed it.
---@param questID integer
---@return { active: { name: string, classKey: string }[], completed: { name: string, classKey: string }[] }?
function API:GetQuestStatus(questID)
  if not questID then return nil end
  local active, completed = {}, {}
  for name, c in pairs(ns.db.characters) do
    local q = c.questlog
    if q then
      local who = { name = name, classKey = c.classKey }
      if q.active and q.active[questID] then insert(active, who) end
      if ns.IsQuestCompleted(q.completed, questID) then insert(completed, who) end
    end
  end
  if #active == 0 and #completed == 0 then return nil end
  local byName = function(a, b) return a.name < b.name end
  sort(active, byName)
  sort(completed, byName)
  return { active = active, completed = completed }
end

-- Mean over a bucketed sample set (delve tiers or keystone levels): the requested bucket's own
-- samples if it has any, else every bucket's samples pooled.  Returns avg (rounded), count, and
-- whether the requested bucket's own samples were used (`bucketed`, so the caller can label the
-- scope).  Shared by durations and XP, delves and dungeons.
local function poolAvg(buckets, wanted)
  local list = wanted and buckets[wanted]
  local bucketed = list and #list > 0
  if not bucketed then
    list = {}
    for _, samples in pairs(buckets) do
      for _, s in ipairs(samples) do insert(list, s) end
    end
  end
  if #list == 0 then return nil end
  local total = 0
  for _, s in ipairs(list) do total = total + s end
  return floor(total / #list + 0.5), #list, bucketed
end

---Per-character delve completion-time stats for one delve, current character first then by name.
---`avg` is the rounded mean of recent run durations (seconds); `scope` is "T<tier>" when that
---tier has samples, else "all" (the all-tiers aggregate fallback).  `avgXp`/`xpCount` report the
---mean XP gained per run where recorded (leveling runs only; nil at/above max level).  nil when no
---tracked character has timed that delve.  Data comes from the per-character `delveTimes` cache
---(data/delvetimes.lua).
---@param delveName string the delve's display name (as shown on its map pin); normalized internally
---@param tier integer? preferred tier (e.g. 11); falls back to the all-tiers aggregate
---@return { name: string, classKey: string, avg: integer, count: integer, scope: string, avgXp: integer?, xpCount: integer? }[]?
function API:GetDelveStats(delveName, tier)
  local key = ns.NormalizeDelveKey(delveName)
  if not key then return nil end
  local me = ns.currentPlayer
  local out = {}
  for name, c in pairs(ns.db.characters) do
    local entry = c.delveTimes and c.delveTimes.runs and c.delveTimes.runs[key]
    if entry then
      local avg, count, bucketed = poolAvg(entry.tiers, tier)
      if avg then
        local avgXp, xpCount
        if entry.xps then avgXp, xpCount = poolAvg(entry.xps, tier) end
        insert(out, { name = name, classKey = c.classKey, avg = avg, count = count,
          scope = bucketed and ("T" .. tier) or "all", avgXp = avgXp, xpCount = xpCount })
      end
    end
  end
  if #out == 0 then return nil end
  sort(out, function(a, b)
    if (a.name == me) ~= (b.name == me) then return a.name == me end
    return a.name < b.name
  end)
  return out
end

---Per-character dungeon completion-time stats for one dungeon, current character first then by
---name.  Mirrors GetDelveStats.  Reads one of two axes: pass `difficultyID` for a non-keyed
---(normal/heroic/finder) run — scope is the difficulty label — else it reads the keyed Mythic+ axis
---for `level`, scope "+<level>".  Either axis falls back to its all-buckets aggregate (scope "all")
---when the requested bucket has no samples.  `avg` = rounded mean seconds; `avgXp`/`xpCount` cover
---per-run XP where recorded (leveling runs only).  nil when no tracked character has timed that
---dungeon on the requested axis.  Data comes from the `dungeonTimes` cache (data/dungeontimes.lua).
---@param dungeonName string the dungeon's display name; normalized internally
---@param level integer? preferred keystone level (keyed M+); ignored when difficultyID is given
---@param difficultyID integer? instance difficulty for a non-keyed run; selects the non-keyed axis
---@return { name: string, classKey: string, avg: integer, count: integer, scope: string, avgXp: integer?, xpCount: integer? }[]?
function API:GetDungeonStats(dungeonName, level, difficultyID)
  local key = ns.NormalizeDelveKey(dungeonName)
  if not key then return nil end
  local me = ns.currentPlayer
  local out = {}
  -- Non-keyed axis (difficulty) vs keyed axis (keystone level): pick the bucket set + scope label.
  local nonKeyed = difficultyID ~= nil
  local timeField, xpField, wanted = "tiers", "xps", level
  if nonKeyed then timeField, xpField, wanted = "diffs", "diffXps", difficultyID end
  for name, c in pairs(ns.db.characters) do
    local entry = c.dungeonTimes and c.dungeonTimes.runs and c.dungeonTimes.runs[key]
    if entry and entry[timeField] then
      local avg, count, bucketed = poolAvg(entry[timeField], wanted)
      if avg then
        local avgXp, xpCount
        if entry[xpField] then avgXp, xpCount = poolAvg(entry[xpField], wanted) end
        local scope = "all"
        if bucketed then scope = nonKeyed and ns.DungeonDifficultyLabel(difficultyID) or ("+" .. level) end
        insert(out, { name = name, classKey = c.classKey, avg = avg, count = count,
          scope = scope, avgXp = avgXp, xpCount = xpCount })
      end
    end
  end
  if #out == 0 then return nil end
  sort(out, function(a, b)
    if (a.name == me) ~= (b.name == me) then return a.name == me end
    return a.name < b.name
  end)
  return out
end

---Applied cosmetic appearance glyphs for a character's active spec: the class catalog
---(ns.AppearanceGlyphs) merged with the character's last-seen applied-glyph set for that
---spec. Per-character and per-spec; `applied` is a snapshot from when the character was
---last logged in (only the active spec's spellbook is readable). Returns nil when the class
---has no glyph catalog (Evoker). The second return is false when the active spec has never
---been scanned (so the caller can prompt to log in as that spec).
---@param charName string?
---@return { itemID: integer, label: string, glyph: integer, applied: boolean }[]?, boolean scanned
function API:GetAppliedGlyphs(charName)
  local c = self:GetCharacterData(charName)
  local list = c and ns.AppearanceGlyphs[c.classId]
  if not list then return nil, false end
  local specID = c.basic and c.basic.specialization and c.basic.specialization.id
  local applied = specID and c.glyphs and c.glyphs.applied and c.glyphs.applied[specID] or nil
  return ns.MergeGlyphStatus(list, specID, applied), applied ~= nil
end

---Account-wide barbershop appearance unlocks for a character's class (Druid Marks +
---travel-form glyphs, Warlock demon Grimoires). Unlock state is account-wide, read live via
---C_QuestLog.IsQuestFlaggedCompletedOnAccount — so it's identical for every character of the
---class and needs no per-character storage; the character only selects the class. Returns nil
---when the class has no unlock catalog (every class but Druid + Warlock).
---@param charName string?
---@return { itemID: integer, label: string, spell: integer, unlocked: boolean }[]?
function API:GetAppearanceUnlocks(charName)
  local c = self:GetCharacterData(charName)
  local list = c and ns.AppearanceUnlocks[c.classId]
  if not list then return nil end
  local done = C_QuestLog.IsQuestFlaggedCompletedOnAccount
  local out = {}
  for _, e in ipairs(list) do
    insert(out, { itemID = e.itemID, label = e.label, spell = e.spell, unlocked = done(e.quest) == true })
  end
  return out
end

---Synchronously re-fetch one broker field for the current character.
---Safe to call at any time; respects the maxLevel guard.
---@param brokerName string
---@param fieldName string
function API:RefreshCurrentCharacterField(brokerName, fieldName)
  local toon = ns.currentData
  if not toon then return end
  local broker = ns.brokers[brokerName]
  if not broker then return end
  local field = broker.fields[fieldName]
  if not field then return end
  if not (field.maxLevel and toon.basic.level < ns.wow.maxLevel) then
    toon[brokerName][fieldName] = field:get(toon, toon[brokerName][fieldName])
  end
end
