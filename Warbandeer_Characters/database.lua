---@type Warbandeer_Characters
local ns = select(2, ...)
local gsub = string.gsub
local Player = ns.wow.Player
local UnitClassBase = UnitClassBase

---@class WarbandeerCharactersDB
---@field version integer
---@field characters table<string, Character> Character data indexed by character name
---@field numCharacters integer total number of characters
---@field warband WarbandData account-wide warband bank gold + weekly wealth tracking
---@field travelersLog TravelersLogData account-wide monthly Traveler's Log progress + rewards-waiting
---@field ui table legacy account-wide UI prefs (the wmissing copy-window font size moved to LibNUIDB.copyFontSize; kept for rollback safety)
---@field settings {combatLogging: boolean} account-wide addon settings (Settings panel)

---@class Warbandeer_Characters
---@field db WarbandeerCharactersDB

local function countCharacters(db)
  local n = 0
  for _ in pairs(db.characters) do n = n + 1 end
  return n
end

ns:registerCommand("list", "", function(self)
  ns.Print("Characters:")
  for n,_ in pairs(ns.db.characters) do
    print(n)
  end
  ns.Print("done")
end, "List all characters")

ns:registerCommand("delete", "", function(self, args)
  if not ns.db.characters[args] then
    ns.Print(args .. " not found. Use /wbc list for exact names (case-sensitive).")
    return
  end
  ns.db.characters[args] = nil
  ns.db.numCharacters = ns.db.numCharacters - 1
  -- Cached bank gear lives in the account-wide store keyed by name, so prune it
  -- here too or it would orphan (it isn't part of the per-character struct).
  if ns.db.bank and ns.db.bank.characters then ns.db.bank.characters[args] = nil end
  ns.Print(args .. " deleted.")
end, "Delete a character")

-- Explicit, user-invoked repair of stored data (per the DB-compat convention,
-- cleanup never runs automatically). Currently: recount numCharacters, which
-- pre-#47 deletes could skew by decrementing on names that didn't exist.
ns:registerCommand("cleanup", "", function(self)
  local fixed = 0
  local n = countCharacters(ns.db)
  if ns.db.numCharacters ~= n then
    ns.Print("numCharacters corrected: " .. tostring(ns.db.numCharacters) .. " -> " .. n)
    ns.db.numCharacters = n
    fixed = fixed + 1
  end
  -- Drop cached bank gear for characters no longer tracked (the account-wide
  -- bank store is keyed by name and isn't pruned when a character vanishes by
  -- means other than /wbc delete, e.g. a rename or a stale pre-existing entry).
  local banks = ns.db.bank and ns.db.bank.characters
  if banks then
    local orphans = 0
    for name in pairs(banks) do
      if not ns.db.characters[name] then banks[name] = nil; orphans = orphans + 1 end
    end
    if orphans > 0 then
      ns.Print("Removed bank gear for " .. orphans .. " untracked character(s).")
      fixed = fixed + 1
    end
  end
  if fixed == 0 then ns.Print("Nothing to clean.") end
end, "Repair stored data (recount characters)")

---@class Character
---@field name string
---@field classId string
---@field classKey string
---@field className string
---@field race string
---@field raceId string
---@field raceIdx integer
---@field isAlliance boolean
---@field realm string
---@field sex integer  UnitSex code (2=male, 3=female); refreshed each login for the active character
---@field guid string  "Player-<realmID>-<lowGUID>" UnitGUID; refreshed each login for the active character
---@field guild string?  guild name (nil when unguilded); refreshed each login and on PLAYER_GUILD_UPDATE for the active character

---@class Warbandeer_Characters
---@field MigrateDB fun(self) Migrate database to latest version
function ns:MigrateDB()
  local db = ns.db
  if db.version == 41 then return end
  if not db.characters then db.characters = {} end
  if not db.numCharacters then
    db.numCharacters = countCharacters(db)
  end
  if (db.version or 0) < 7 then
  for _,c in pairs(db.characters) do
    if not c.basic then
      c.basic = {
        level = c.level,
        specialization = {
          primary = c.specialization,
          active = c.specializationActive,
          role = c.role,
        },
        professions = {
          primary = c.prof1,
          secondary = c.prof2,
          fishing = c.fishing,
          cooking = c.cooking,
        },
      }
    end
    if not c.basic.level then c.basic.level = 1 end
    if not c.instances then
      c.instances = { locks = c.locks or {} }
    end
    c.level = nil
    c.locks = nil
    c.specialization = nil
    c.specializationActive = nil
    c.role = nil
    c.prof1 = nil
    c.prof2 = nil
    c.fishing = nil
    c.cooking = nil
  end
  db.version = 7
  end

  -- v8: account-wide warband bank gold + weekly wealth tracking (non-destructive)
  if (db.version or 0) < 8 then
    if not db.warband then db.warband = { bankGold = 0, history = {} } end
    db.version = 8
  end

  -- v9: re-derive classKey from the locale-independent class token so that
  -- characters stored on non-English clients get the correct PascalCase key.
  -- Non-destructive: keeps the existing value if classId is absent or unknown.
  if (db.version or 0) < 9 then
    for _, c in pairs(db.characters) do
      if c.classId then
        local _, _, classFile = GetClassInfo(c.classId)
        if classFile then
          c.classKey = ns.wow.ClassKeyByToken[classFile] or c.classKey
        end
      end
    end
    db.version = 9
  end

  -- v10: account-wide recipe → profession-gear cache (non-destructive).  The
  -- build stamp is left empty so data/recipegear.lua re-stamps and fills it
  -- lazily against the live client build.
  if (db.version or 0) < 10 then
    if not db.recipeGear then db.recipeGear = { build = "", recipes = {} } end
    db.version = 10
  end

  -- v11: account-wide bank profession-gear cache (non-destructive), filled
  -- lazily by data/bank.lua whenever a warband/character/guild bank is opened.
  if (db.version or 0) < 11 then
    if not db.bank then db.bank = { characters = {}, guilds = {} } end
    db.version = 11
  end

  -- v12: account-wide UI preferences table (non-destructive). Originally held
  -- the /wbc wmissing font size; that preference now lives in LibNUI's own DB
  -- (LibNUIDB.copyFontSize). This table is kept for rollback safety.
  if (db.version or 0) < 12 then
    if not db.ui then db.ui = {} end
    db.version = 12
  end

  -- v13: equippable-gear cache.
  -- Purely additive and filled lazily: the per-character `gearbag` broker records
  -- bag gear on its own, and data/bank.lua adds an `equip` list to each bank store
  -- (warband + personal) on the next bank open.  Nothing to seed — old revisions
  -- simply see empty lists until the next scan, so rollback is lossless.
  if (db.version or 0) < 13 then
    db.version = 13
  end

  -- v14: per-character world-quest gear-reward cache (non-destructive).  Filled
  -- lazily by data/worldquests.lua when a max-level character logs in and scans
  -- its active world quests; nothing to seed — old revisions simply see empty
  -- lists until the next scan, so rollback is lossless.
  if (db.version or 0) < 14 then
    db.version = 14
  end

  -- v15: per-equipped-slot empty-socket count (non-destructive).  Added to each
  -- equipment slot record by data/equipment.lua's broker at scan time; nothing to
  -- seed — old revisions simply lack the field (treated as "unknown / none") until a
  -- character next logs in and re-scans its gear, so rollback is lossless.
  if (db.version or 0) < 15 then
    db.version = 15
  end

  -- v16: per-character secondary-stats snapshot (non-destructive).  Captured by
  -- data/stats.lua's broker at scan time; nothing to seed — old revisions just lack
  -- `stats.secondary` (the Detail panel shows blanks) until the character next logs
  -- in and re-scans, so rollback is lossless.
  if (db.version or 0) < 16 then
    db.version = 16
  end

  -- v17: per-candidate item quality on cached bag/bank equippable gear (non-destructive).
  -- Stored by data/gearbag.lua + data/bank.lua at scan time so ShadowsOfUI-Upgrade's
  -- artifact gate fires for an offline alt's cold gear (GetItemQualityByID is nil for an
  -- uncached item, which let a legacy Heart of Azeroth read as a neck upgrade).  Nothing
  -- to seed — old entries just lack `quality` (the gate falls back to the live lookup)
  -- until the relevant bag/bank is next scanned, so rollback is lossless.
  if (db.version or 0) < 17 then
    db.version = 17
  end

  -- v18: per-candidate required character level on cached bag/bank equippable gear
  -- (non-destructive).  Stored by data/gearbag.lua + data/bank.lua at scan time (item
  -- warm) so a consumer's "can equip now?" gate reads consistently for an offline alt's
  -- cold gear instead of falling back to a live lookup that returns nil right after a
  -- reload.  Nothing to seed — old entries just lack `reqLevel` (the consumer falls back
  -- to the live lookup) until the relevant bag/bank is next scanned, so rollback is lossless.
  if (db.version or 0) < 18 then
    db.version = 18
  end

  -- v19: per-character bag item-count index + personal/warband/guild bank
  -- item-count maps (non-destructive).  Filled lazily — bag counts by the new
  -- `inventory` broker on BAG_UPDATE_DELAYED, bank/guild counts by data/bank.lua on
  -- the next bank open.  Nothing to seed; old revisions simply see empty counts (the
  -- warband-stock tooltip shows fewer sources) until the next scan, so rollback is
  -- lossless.
  if (db.version or 0) < 19 then
    db.version = 19
  end

  -- v20: per-character mail cache (`mail`: inbox count, attachment item counts,
  -- attached gold, absolute expiry stamps) (non-destructive).  Filled lazily by
  -- data/mail.lua whenever the character opens a mailbox; nothing to seed — old
  -- revisions simply lack it (the Summary mail column is blank and the tooltip shows
  -- no mail source) until the next mailbox visit, so rollback is lossless.
  if (db.version or 0) < 20 then
    db.version = 20
  end

  -- v21: per-character reputation cache (`reputations.factions`: factionID -> standing
  -- label/rank/done/paragon for every faction the character has a standing with)
  -- (non-destructive).  Filled lazily by data/reputations.lua each login + on reputation
  -- change; old revisions simply lack it (ShadowsOfUI-Reputations shows no standings for
  -- that character) until its next login, so rollback is lossless.
  if (db.version or 0) < 21 then
    db.version = 21
  end

  -- v22: per-character owned-auction cache (`auctions`: active count, absolute expiry
  -- stamps, gold tied up, bid count) (non-destructive).  Filled lazily by data/auctions.lua
  -- whenever the character opens the auction house; old revisions simply lack it (the
  -- Summary auctions column is blank) until the next AH visit, so rollback is lossless.
  if (db.version or 0) < 22 then
    db.version = 22
  end

  -- v23: per-character quest log (`questlog`: active-quest set + completed-quest bitmap)
  -- (non-destructive).  Filled lazily each login (and on quest events); old revisions just
  -- lack it (ShadowsOfUI-Quests shows no cross-alt status) until the next login, so rollback
  -- is lossless.  The completed bitmap is the suite's largest per-character field — a
  -- `/wbc cleanup` extension could drop it if a user wants the space back (none today).
  if (db.version or 0) < 23 then
    db.version = 23
  end

  -- v24: per-faction expansion category (`reputations.factions[*].categoryId`: the
  -- top-level reputation header's factionID, locale-proof) (non-destructive).  Stamped
  -- by data/reputations.lua's broker at scan time; nothing to seed — old entries just
  -- lack it (Warbandeer's Reputations view groups them onto the "Other" page) until the
  -- character next logs in and re-scans, so rollback is lossless.
  if (db.version or 0) < 24 then
    db.version = 24
  end

  -- v25: per-character new-mail flag (`mail.hasMail`: the minimap-envelope state, true
  -- while unread mail is waiting) (non-destructive).  Stamped by data/mail.lua on
  -- UPDATE_PENDING_MAIL (and refreshed by the inbox scan); nothing to seed — old revisions
  -- simply lack it (the Summary mail column shows no envelope) until the character next logs
  -- in, so rollback is lossless.
  if (db.version or 0) < 25 then
    db.version = 25
  end

  -- v26: per-character weekly Delver's Bounty claim (`weeklies.delversBounty`: true once
  -- the weekly delve treasure, quest 86371, has been claimed) (non-destructive).  Captured
  -- by data/weekly.lua on QUEST_TURNED_IN (and each refresh), reset weekly; nothing to seed
  -- — old revisions simply lack it (the Summary Bounty column reads as not-yet-claimed) until
  -- the character next logs in, so rollback is lossless.
  if (db.version or 0) < 26 then
    db.version = 26
  end

  -- v27: per-character delve completion-time cache (`delveTimes`: a personal rolling average of
  -- run durations per delve + tier).  Filled lazily by data/delvetimes.lua as the character
  -- completes delves; nothing to seed — old revisions simply lack it (ShadowsOfUI-Delves shows no
  -- average for that character) until it next runs a delve, so rollback is lossless.
  if (db.version or 0) < 27 then
    db.version = 27
  end

  -- v28: account-wide settings table holding the opt-in combat-logging toggle
  -- (default off).  logging.lua re-applies it each login (the client never persists
  -- combat logging across sessions).  Nothing else reads the key, so an older
  -- revision simply ignores it — rollback is lossless.
  if (db.version or 0) < 28 then
    db.settings = db.settings or {}
    if db.settings.combatLogging == nil then db.settings.combatLogging = false end
    db.version = 28
  end

  -- v29: per-character per-day played-time buckets (`playtime.byDay`: local-calendar-day
  -- "YYYY-MM-DD" -> logged-in seconds).  Filled lazily by data/playtime.lua's session
  -- accounting from this login forward; nothing to seed — old revisions simply lack it
  -- (no per-day history) until the character next logs in, so rollback is lossless.
  if (db.version or 0) < 29 then
    db.version = 29
  end

  -- v30: per-character GUID (`guid`: the "Player-<realmID>-<lowGUID>" UnitGUID string)
  -- (non-destructive).  Stamped by ns:initialize() each login for the active character;
  -- nothing to seed — old revisions simply lack it until the character next logs in, so
  -- rollback is lossless.
  if (db.version or 0) < 30 then
    db.version = 30
  end

  -- v31: per-character Mythic+ completion-time cache (`dungeonTimes`: personal rolling averages of
  -- keyed-run durations per dungeon + keystone level) plus per-run XP gains on both trackers
  -- (`delveTimes.runs.*.xps` / `dungeonTimes.runs.*.xps`, leveling runs only).  Both are additive
  -- and filled lazily by data/dungeontimes.lua / data/delvetimes.lua as the character completes
  -- runs; nothing to seed — old revisions simply lack them (no dungeon averages, no per-run XP)
  -- until the character next runs a delve/key, so rollback is lossless.
  if (db.version or 0) < 31 then
    db.version = 31
  end

  -- v32: non-keyed dungeon run-times on the existing dungeonTimes cache (`runs.*.diffs` /
  -- `.diffXps`, keyed by difficultyID — normal/heroic/etc. finder runs, recorded on
  -- LFG_COMPLETION_REWARD) plus the `active.kind` discriminator.  Additive to v31 and filled lazily
  -- by data/dungeontimes.lua; nothing to seed — an older revision simply lacks the non-keyed buckets
  -- (only keyed M+ averages) until the character next runs a finder dungeon, so rollback is lossless.
  if (db.version or 0) < 32 then
    db.version = 32
  end

  -- v33: per-character applied-glyph cache (`glyphs.applied`: a last-seen, per-spec set of the
  -- cosmetic glyph ids the character has applied to its spells).  Additive and filled lazily by
  -- data/glyphs.lua as the character logs in / applies glyphs; nothing to seed — an older revision
  -- simply lacks it (the Detail appearance card shows nothing applied) until the character is next
  -- seen, so rollback is lossless.  Account-wide barbershop unlocks are read live and never stored.
  if (db.version or 0) < 33 then
    db.version = 33
  end

  -- v34: per-character learned-unlock cache (`glyphs.unlocks`: a set of the class-unlock spell ids
  -- the character has — Druid "Tome of the Wilds", Hunter "Tomes & Tames").  Additive to the v33
  -- glyphs broker and filled lazily by data/glyphs.lua as the character logs in / learns an unlock;
  -- nothing to seed — an older revision simply lacks it (the Detail card shows nothing known) until
  -- the character is next seen, so rollback is lossless.
  if (db.version or 0) < 34 then
    db.version = 34
  end

  -- v35: per-character Hunter pet roster (`pets`: active Call-Pet slots + stabled pets, each with
  -- name/family/level/spec + stable creatureID/displayID).  Additive and filled lazily by
  -- data/pets.lua when a Hunter opens a stable master; nothing to seed — an older revision simply
  -- lacks it (the Detail Pets button reads "visit a stable") until the character next visits one,
  -- so rollback is lossless.
  if (db.version or 0) < 35 then
    db.version = 35
  end

  -- v36: per-character Warlock demon roster (`demons`: each summoned demon's last-seen name + species
  -- + npcID).  Additive and filled lazily by data/demons.lua as the Warlock summons each demon (there's
  -- no enumeration API — only the active demon is readable, so it fills in per summon); nothing to seed
  -- — an older revision simply lacks it (the Detail Demons button reads "summon your demons") until the
  -- character next summons one, so rollback is lossless.
  if (db.version or 0) < 36 then
    db.version = 36
  end

  -- v37: per-character earned-titles cache (`titles`: the `known` list of player titles the
  -- character has, plus the featured `current` title id).  Additive and filled lazily by
  -- data/titles.lua as the character logs in / earns or selects a title (only the logged-in
  -- character's titles are readable, so it's a last-seen snapshot); nothing to seed — an older
  -- revision simply lacks it (the Summary Titles column is blank for that character) until it's
  -- next seen, so rollback is lossless.
  if (db.version or 0) < 37 then
    db.version = 37
  end

  -- v38: account-wide Traveler's Log (Trading Post monthly activity) progress + rewards-
  -- waiting snapshot (`travelersLog`).  Additive and self-seeded by data/travelerslog.lua
  -- at login; nothing to seed here — an older revision simply lacks it (the Overview
  -- Traveler's Log strip stays hidden) until the next login, so rollback is lossless.
  if (db.version or 0) < 38 then
    db.version = 38
  end

  -- v39: per-character weekly profession knowledge (`professionKnowledge` broker).  Additive and
  -- self-seeded by data/professionknowledge.lua at login (and cleared each weekly reset); nothing
  -- to seed here — an older revision simply lacks it (Warbandeer's Midnight professions view shows
  -- no knowledge column for that character) until the next login, so rollback is lossless.
  if (db.version or 0) < 39 then
    db.version = 39
  end

  -- v40: account-wide housing store (`db.housing`: per-neighborhood faction + endeavor
  -- title/progress/reset + per-house level/favor) plus the per-character `housing` broker
  -- (`active`: the neighborhood each character is feeding).  Additive and self-seeded —
  -- data/housing.lua lazily creates `db.housing`, and the broker seeds each character's `housing`
  -- table; nothing to seed here, so an older revision simply lacks it (the Summary Endeavors column
  -- is blank) until it next logs in, so rollback is lossless.
  if (db.version or 0) < 40 then
    db.version = 40
  end

  -- v41: per-character owned-keystone dungeon (`weeklies.keystoneMap`: the challenge-map id of the
  -- keystone the character holds, paired with the existing `weeklies.keystone` level).  Additive and
  -- filled lazily by data/weekly.lua on CHALLENGE_MODE_COMPLETED / each refresh, reset weekly; nothing
  -- to seed — an older revision simply lacks it (the Summary M+ cell tooltip shows level-only) until
  -- the character next completes a key, so rollback is lossless.
  if (db.version or 0) < 41 then
    db.version = 41
  end
end

---@class Warbandeer_Characters
---@field currentPlayer string Name of currently active character
---@field currentData Character Data for currently active character

---@class Warbandeer_Characters
---@field initialize fun(self) Initialize character data for the current player and set up brokers
function ns:initialize()
  self.currentPlayer = Player:GetName()
  local c = self.db.characters[self.currentPlayer]
  if not c then
    -- initialize new character
    local _, classToken = UnitClassBase("player")
    local className = Player:GetClassName()
    local raceFile, raceId = Player:GetRace()
    local raceIndex, isAlliance = ns.NormalizeRaceId(raceId)
    c = {
      name = self.currentPlayer,
      classId = Player:GetClassId(),
      className = className,
      classKey = ns.wow.ClassKeyByToken[classToken] or gsub(className, " ", ""),
      isAlliance = isAlliance,
      race = raceFile,
      raceId = raceId,
      raceIdx = raceIndex,
      realm = GetRealmName()
    }
    self.db.characters[self.currentPlayer] = c
    self.db.numCharacters = self.db.numCharacters + 1
  end
  self.currentData = c
  -- Refresh each login so characters created before `sex`/`guid` existed are backfilled
  -- the next time they log in (alts not yet seen default to male at render time).
  c.sex = UnitSex("player")
  c.guid = UnitGUID("player")
  c.guild = GetGuildInfo("player")

  self:InitBrokers()
  self:InitWarband()
  self:InitTravelersLog()
  self:InitAchievements()
end

-- Guild info can read back nil at PLAYER_LOGIN (before the roster loads) and also
-- changes mid-session when the player joins or leaves a guild; keep the active
-- character's stored guild in sync as those updates arrive.
ns:registerEvent("PLAYER_GUILD_UPDATE", function()
  if ns.currentData then ns.currentData.guild = GetGuildInfo("player") end
end)

-- Missing report: guid is stamped each login by ns:initialize (DB v30); nil means the
-- character hasn't logged in since, so tools keying off it can't identify it from
-- character-list-order.txt's raw GUID fragments.
ns:RegisterMissing{
  order = 40,
  check = function(toon) if not toon.guid then return "guid" end end,
}
