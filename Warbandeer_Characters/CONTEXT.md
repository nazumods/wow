# Warbandeer_Characters (Data Layer)

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `WarbandeerCharDB` (v19) · **Commands:** `/characters`, `/wbc` · **API:** `WarbandeerApi`

Data-collection backbone for the suite. Scans the active character each login/refresh and stores everything in `WarbandeerCharDB`, exposing it to the rest of the suite through the `WarbandeerApi` global. Per-field scanning is driven by the **broker** system (`broker.lua`).

## Files

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap (assignment form) |
| `types.lua` | LuaLS aliases: `Specialization`, `SpecializationKey` |
| `broker.lua` | `Broker` class + `ns:RegisterBroker`/`InitBrokers`; reset constants `RESET_SUNDAY/DAILY/WEEKLY`; reset-boundary timestamps `ns.LAST_DAILY_RESET`/`LAST_RESET`/`LAST_SUNDAY_RESET` |
| `database.lua` | `ns:MigrateDB` (v18), `ns:initialize` (creates the per-char struct, then `InitBrokers`/`InitWarband`); `/characters list`, `/characters delete <name>` (also prunes the character's cached bank gear), `/characters cleanup` (recount numCharacters + drop bank gear for untracked characters) |
| `main.lua` | `ns:refresh` + `ns:refreshQueue` (one **field** scanned per 100ms); `/characters refresh`, `/characters dump` |
| `login.lua` | `ns.onLogin` → `initialize()` once, then `refresh()` |
| `api.lua` | `WarbandeerApi` public methods (see below) |
| `data/basic.lua` | Broker `basic`: `level`, `specialization`, `professions` (name summary), `xp` |
| `data/currency.lua` | Broker `currency`: `RestoredCofferKey`, `gold` (`GetMoney`), `CofferKeyShard`, `Catalyst`, `HeroDawncrest`, `MythDawncrest`, `NebulousVoidcore`, `UntaintedManaCrystal` |
| `data/warband.lua` | Account-wide (not a broker): `db.warband` bank gold + weekly wealth. `ns:GetWarbandWealth`, `RolloverWarbandWeek`, `InitWarband`; `/wbc dump warband` |
| `data/bank.lua` | Account-wide (not a broker): `db.bank` profession-gear cache for the warband bank, each character's bank, and guild banks. Also records each store's equippable gear (`equip` = `GearCandidate[]`) for the warband + personal banks (not guild). Scanned on bank/guild-bank open (warband+character via `C_Bank`/`C_Container`, guild via the classic API). Each store also records `items` (v19) — a full `{[itemID]=count}` map of *everything* in that bank (not just prof gear), accumulated in the same slot loop via `addCount`; drives `WarbandeerApi:GetItemCounts` (warband-stock tooltip). The warband bank's map is account-wide (stored once). **Load-then-rescan** for the `equip` ilvls: a fresh bank-open scan reads many slots cold, so `addEquip` falls back to the link's ilvl (never nil — a nil ilvl makes the upgrade finder drop the item, recommending a worse already-loaded piece first) and flags the slot; `scanPersonalBanks` requests a load and `scheduleBankRescan` re-scans (gen-guarded, `MAX_BANK_RESCANS`×`BANK_RESCAN_DELAY`, gated on the bank still open) until every slot reports its real scaled ilvl — mirrors `data/equipment.lua`. `WarbandeerApi:GetBankProfGear(skillID)`; `/wbc dump bankgear`. A character with no `db.bank.characters[name]` entry is flagged "bank contents" by `missing.lua` |
| `data/items.lua` | Broker `items`: `bags`, `reagentBag`; `/wbc refresh items` |
| `data/inventory.lua` | Broker `inventory`: `counts` — `{[itemID]=qty}` summed across the active character's bags + reagent bag (container IDs 0..NUM_BAG_SLOTS+1 via `C_Container`). Rescanned on `BAG_UPDATE_DELAYED` (500ms). Last-seen per character (only refreshable while logged in). Consumed by `WarbandeerApi:GetItemCounts` → ShadowsOfUI-WarbandInventory's stock tooltip. A character with no `inventory.counts` (not seen since v19) is flagged "bag contents" by `missing.lua` |
| `data/mail.lua` | Event-driven mail scanner (not a broker): on `MAIL_INBOX_UPDATE`, scans the open inbox into `db.characters[name].mail` = `{ scannedAt, count, expiries[] (absolute server-time stamps, asc), items {[itemID]=qty}, money }` — `daysLeft` is stored as an absolute expiry so it stays correct as the cache ages. Last-seen (inbox only readable at a mailbox). Also `ns:WarnExpiringMail` (login chat warning for mail within `ns.MAIL_WARN_DAYS` = 3 days, called from `login.lua` after a 6s delay). Feeds the `Mail` source of `GetItemCounts` + Warbandeer's Summary `mail` column. A character with no `mail` is flagged "mail" by `missing.lua` |
| `data/gearbag.lua` | Broker `gearbag`: `items` — the active character's equippable bag gear (`GearCandidate[]`) for the upgrade finder (ShadowsOfUI-Upgrade). Filtered via `WarbandeerApi:ClassifyGearItem`; rescanned on `BAG_UPDATE_DELAYED` (a cold slot falls back to the link's ilvl rather than a nil that would drop the candidate; the scaled value refreshes on the next bag update) |
| `data/professions.lua` | Broker `professions`: `details` (per-exp skill levels, spec points, learned recipes) + `gear` (tool/accessory slots). Also defines `ns.api.professionInfo`; scans pre-resolve current-exp recipes into the recipe-gear cache and capture each prof-gear recipe's reachable crafting `quality`/`qualityConc` (via `GetCraftingOperationInfo`) |
| `data/recipegear.lua` | Account-wide `db.recipeGear` cache (recipe → prof-gear output: itemID/rarity/equipLoc/target skillID), build-stamped; `WarbandeerApi:ResolveRecipeOutput`, `WarbandeerApi:ClassifyProfGearItem` (item → prof skillID/equipLoc, shared with the bank scanner), `WarbandeerApi:ClassifyGearItem` (item → equippable equipLoc/classID/subClassID, shared by `gearbag`/`bank`) |
| `data/concentration.lua` | Broker `concentration`: `data` — Midnight concentration currency per crafting prof, keyed by parent skillLineID |
| `data/artisancurrency.lua` | Broker `artisanCurrency`: `data` — current-expansion artisan crafting currency (Midnight's per-profession "Artisan's … Moxie", every prof incl. gathering), keyed by parent skillLineID. Consumed by ShadowsOfUI-Artisan |
| `data/races.lua` | `API.ALLIANCE_RACES`, `API.HORDE_RACES`, `ns.NormalizeRaceId(raceId)` → `(raceIdx, isAlliance)` |
| `data/quests.lua` | Broker `quests`: `UndermineStoryMode`, `WWIRep`, `LumberAxe`, `delves` |
| `data/worldquests.lua` | Broker `worldquests`: `rewards` — the logged-in character's active world-quest **gear** rewards that could upgrade an equipped slot, cached per-character (last-seen; reward data is only readable for the active char). Not max-level-gated — some WQs are available before the cap. Each entry is a `GearCandidate` + `{questID, title, zone, endTime}`. Scans the current expansion's WQ continent zones (`WQ_CONTINENTS` → `GetMapChildrenInfo`), keeps only equippable gear (`API:ClassifyGearItem`), gated by an ilvl ceiling (no scan when every slot ≥ `WQ_ILVL_CEILING` 220). Debounced on `QUEST_LOG_UPDATE`/`ZONE_CHANGED_NEW_AREA`; since reward data loads async, a scan that finds quests before their rewards are ready preloads them and schedules a bounded retry (`RefreshCurrentCharacterField`), keeping the last-seen list instead of caching empty. `WarbandeerApi:GetWorldQuestRewards`; `/wbc dump wq`. The upgrade *evaluation* lives in ShadowsOfUI-Upgrade (consumes the raw cache) |
| `data/daily.lua` | Broker `dailies`: empty (template for future daily tracking) |
| `data/playtime.lua` | Broker `playtime`: `total` seconds + `byPatch` baseline; async via `TIME_PLAYED_MSG` |
| `data/weekly.lua` | Broker `weeklies`: `DMF`, `preMidnight`, `caches`, `vault`, `hasUnclaimedVault`, `keystone`, `dungeons`; `/wbc dump m+`, `/wbc dump vault` |
| `data/instances.lua` | Broker `instances`: `locks`; `/wbc refresh locks`, `/wbc dump locks` |
| `data/equipment.lua` | Broker `equipment`: `slots`, `ilvl`, `trackScanned`, `socketScanned` (marker set once gear is scanned with the GetItemGemID socket count — `missing.lua` flags "gem socket data" for alts last scanned before that fix); loads item data before reading. Each slot also records `emptySockets` (v15) — `emptySocketCount(link)` = `C_Item.GetItemNumSockets` minus the sockets that hold a gem (`C_Item.GetItemGemID` per socket, mirroring Blizzard's paperdoll socket display). **Not** the `GetItemStats` `EMPTY_SOCKET_*` keys: the Midnight Gem Manager applies gems outside the stat block, so a gemmed item still reports those keys and would falsely read as needing a gem. Captured here while the item is loaded so it persists + reads warband-wide. Each slot also records `enchant` — the applied permanent-enchant **name** read from the live tooltip (`C_TooltipInfo.GetInventoryItem` → the `ENCHANTED_TOOLTIP_LINE` "Enchanted: %s" line, trailing quality-tier atlas markup stripped), e.g. "Enchant Helm - Rune of Avoidance"; nil when unenchanted. Same "Enchant <Slot> - <X>" form as the recommendations, so ShadowsOfUI-Upgrade can flag a WRONG enchant warband-wide |
| `data/stats.lua` | Broker `stats`: `secondary` (v16) — `{ crit, haste, mastery, versatility }`, each `{ pct, rating }` (effective % + gear combat rating) from the live `GetCritChance`/`GetHaste`/`GetMasteryEffect`/`GetCombatRatingBonus` + `GetCombatRating` APIs (logged-in char only), so it's a last-seen snapshot read warband-wide. `mastery` also carries its active-spec passive `spell` id (`GetSpecializationMasterySpells`), letting Detail name the mastery + show its spec-specific effect. Refreshes on `COMBAT_RATING_UPDATE`. Drives Warbandeer's Detail stat grid. **Secret values:** these APIs can return WoW "secret" numbers (tainted addon code can't do arithmetic on them); each is passed through `safe()` (`canaccessvalue` guard, retail-only) and stored as **nil** when secret, so the snapshot is always safe to read + serialize (Detail's delta/radar math would otherwise taint) |
| `data/artifacts.lua` | Broker `artifacts`: `hidden`, `hiddenColors`, `classHall`; `/wbc dump artifact` |
| `dump.lua` | `/wbc stat` — warband-wide playtime/class statistics |
| `missing.lua` | `/wbc missing`, `/wbc missing me` — lists characters/fields with incomplete data |
| `wmissing.lua` | `/wbc wmissing` — same report rendered in a copyable scroll window via the shared `ui.ToggleCopyWindow` (LibNUI's `CopyWindow`), so re-running the command closes the window; window/picker logic no longer lives here |

## WarbandeerApi Methods

```lua
WarbandeerApi:GetCurrentCharacter()       → string
WarbandeerApi:GetCharacterData(char?)     → Character   -- live ref, NOT a copy (mutable)
WarbandeerApi:GetNumCharacters()          → integer
WarbandeerApi:GetNumMaxLevel()            → integer
WarbandeerApi:GetAllCharacters()          → Character[]
WarbandeerApi:GetAllianceCharacters()     → Character[]
WarbandeerApi:GetHordeCharacters()        → Character[]
WarbandeerApi:GetWarbandBankGold()        → integer (copper)
WarbandeerApi:GetWarbandWealth()          → integer (copper, bank + all char gold)
WarbandeerApi:GetWeeklyGoldMade()         → integer (copper, current wealth − week baseline; may be negative)
WarbandeerApi:GetWealthHistory()          → WarbandWeekRecord[]  (closed weeks, oldest first)
WarbandeerApi:RefreshCurrentCharacterField(broker, field)  -- synchronous single-field re-scan
WarbandeerApi:ResolveRecipeOutput(recipeID) → RecipeGearInfo|false|nil
    -- what prof gear a recipe crafts ({itemID, rarity, equipLoc, skillID}),
    -- from the account-wide cache; false = not prof gear, nil = item not in
    -- the client cache yet (load requested — retry later)
WarbandeerApi:ClassifyProfGearItem(itemID)  → skillID?, equipLoc?
    -- static class/subclass test: parent prof skillLineID + INVTYPE the item is
    -- gear for, or nil if not profession gear (synchronous, no item load)
WarbandeerApi:GetBankProfGear(skillID)     → BankGearEntry[]
    -- prof gear for a profession cached across every opened bank — warband,
    -- character, and guild ({itemID, equipLoc, rarity, count, source,
    -- sourceType}); source is a display label, sourceType ∈ warband/character/
    -- guild; empty until a bank is opened
WarbandeerApi:ClassifyGearItem(itemID)     → equipLoc?, classID?, subClassID?
    -- static test: equippable armour/weapon filling a real slot (nil for
    -- cosmetics/non-gear); synchronous, shared by the gearbag + bank scanners
WarbandeerApi:GetCharacterGearCandidates(char?) → { bags: GearCandidate[], bank: GearCandidate[] }
    -- a character's loose equippable gear: its bags (gearbag broker) + its
    -- personal bank (last bank scan).  The "held for them" pool; last-seen
WarbandeerApi:GetWarbandBankGear()         → GearCandidate[]
    -- equippable gear in the warband (account) bank; the shared "better
    -- elsewhere" pool; empty until the warband bank has been opened
WarbandeerApi:GetMail(char?)               → MailData?
    -- a character's last-seen mail cache { scannedAt, count, expiries[], items, money };
    -- nil until it has visited a mailbox
WarbandeerApi:GetItemCounts(itemID)        → ItemCountReport?
    -- account-wide counts of an item: { total, warband, characters =
    -- {{name, classKey, realm?, bags, bank, mail, total}} (sorted total desc), guilds =
    -- {{name, count}} }.  realm is set only when it differs from the current
    -- character's realm (cross-realm note).  Per-char = bags (inventory broker) + personal bank + mail
    -- (db.bank.characters[name].items); warband = db.bank.warband.items (once);
    -- guilds = db.bank.guilds[*].items.  All last-seen; nil when nothing is held
WarbandeerApi:GetWorldQuestRewards(char?)  → WorldQuestReward[]
    -- a character's cached active world-quest gear rewards (GearCandidate +
    -- {questID, title, zone, mapID, endTime}); captured while that char was logged in,
    -- last-seen.  Expired quests (endTime passed) are dropped on read.  Consumed
    -- by ShadowsOfUI-Upgrade's WorldQuestUpgrades; empty until the char has scanned
```

`GearCandidate` = `{ link, itemID, ilvl?, equipLoc, classID, subClassID, quality?, reqLevel? }` (ilvl is the
**effective** (context-scaled) level via `C_Item.GetCurrentItemLevel(ItemLocation)`, captured when
warm; recompute from `link` if nil). `quality` (v17, Enum.ItemQuality) is captured at scan time so the
upgrade finder's artifact gate fires even when the candidate is later read for an offline alt with the
item cold (`GetItemQualityByID` is nil for an uncached item); absent on entries cached before v17. `reqLevel`
(v18) is the required character level, also captured at scan time (item warm) so a consumer's "can equip
now?" gate reads consistently for an offline alt's cold gear instead of falling back to a live (cold, →nil)
`GetItemInfo` lookup; absent on entries cached before v18. Effective, not the link's unscaled `GetDetailedItemLevelInfo`,
so it matches how `equipment.slots` measures equipped ilvl — else a downscaled item over-reports and
the upgrade finder fakes a huge gain.

Also on the API table: `ALLIANCE_RACES`, `HORDE_RACES`, `professionInfo`.
(`AliasSettingsCategory` is set on this same table by **Warbandeer_Alias**, not here. Settings-panel nesting now goes through LibNAddOn's shared parent registry — `ns:GetSettingsParent("Warbandeer")` — rather than a published `SettingsCategory` field.)

## Per-Character Struct (`db.characters[name]`)

```lua
-- Top-level (set once at creation in initialize):
name, classId, className, classKey, race, raceId, raceIdx, isAlliance, realm
sex           -- UnitSex code (2=male, 3=female); refreshed each login for the active char (alts seen before this field default to male at render time)
lastRefresh   -- set by refreshQueue when a full scan completes

-- Sub-tables (one per broker, populated by their fields):
basic = {
  level,
  specialization = { primary, active, role, key, id },  -- active = PLAYED spec, primary = LOOT spec; role/key/id follow the played (active) spec; id = numeric spec ID (locale-independent; v13)
  professions    = { primary, secondary, fishing, cooking },  -- {name, skillID, ...} each
  xp             = { percent, restPercent, isResting, recordedAt }?,
}
stats = {                                              -- v16
  secondary = { crit, haste, mastery, versatility },   -- each { pct, rating }; mastery also { spell } (active-spec passive id)
}
currency = {
  RestoredCofferKey,                                   -- quantity (currency 3028)
  gold,                                                -- GetMoney(), copper
  CofferKeyShard = { quantity, capped }?,              -- weekly-reset
  Catalyst       = { quantity, max, capped }?,         -- Dawnlight Manaflux (3378), capped = bank full
  HeroDawncrest  = { quantity, earned, max, capped },
  MythDawncrest  = { quantity, earned, max, capped },
  NebulousVoidcore = { quantity, earned, max, capped }?,   -- (3418) season cap: totalEarned vs maxQuantity, grows +2/week
  UntaintedManaCrystal = { quantity, earned, max, capped }?, -- (3356) weekly-earn cap 250 (hard cap 1000); RESET_WEEKLY
}
items = {
  bags = { [1..N] = {id, slots}, GoblinMiniFridge?, ArathorSatchel?, PortableRefridgerator? },
  reagentBag = { id, slots },
}
inventory = {                                          -- v19
  counts = { [itemID] = qty }?,                        -- every item in bags + reagent bag, summed; last-seen
}
mail = {                                                -- v20; last-seen, scanned at a mailbox
  scannedAt, count,
  expiries = { absExpiryTs, ... },                     -- absolute server-time stamps, ascending (one per mail)
  items    = { [itemID] = qty },                       -- attached items, summed
  money,                                               -- attached gold, copper
}?
gearbag = {
  items = { {link, itemID, ilvl?, equipLoc, classID, subClassID} }?,  -- equippable bag gear (v13)
}
professions = {
  details = { [skillLineID] = {
    expansions = { {name, skillLevel, maxSkillLevel} }?, specPoints?,
    recipes = { [expKey] = { learned = { {id, name, quality?, qualityConc?} }, total } }?,
                                                         -- expKey: midnight/tww/df; quality/qualityConc
                                                         -- = crafting tier reachable now w/o and w/ concentration
                                                         -- (current-exp prof-gear recipes only)
  } }?,
  gear = { [parentSkillLineID] = { slots = { [invSlot] = {name,link,ilvl,rarity,tier,expacID} } } }?,
}
concentration = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity,
                             rechargingAmountPerCycle, rechargingCycleDurationMS, lastUpdated } }?,
}
artisanCurrency = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity, lastUpdated } }?,
                                                       -- current-expansion artisan crafting currency per crafting prof
}
quests = {
  UndermineStoryMode,
  WWIRep = { complete, missing, Dornogal, Assembly, Hallowfall, Azjkahet, Undermine, Arathi, Karesh },
  LumberAxe,                                           -- has Find-Lumber tracking spell
  delves = { complete, missing, [label] = bool },
}
worldquests = {                                        -- v14
  rewards = { {                                        -- GearCandidate + quest metadata
    link, itemID, ilvl, equipLoc, classID, subClassID, -- GearCandidate fields
    questID, title, zone, mapID, endTime,              -- source quest + zone uiMapID + expiry (server time)
  } }?,
}
dailies = {}
weeklies = {
  DMF,                                                 -- RESET_SUNDAY
  preMidnight = { eight, three },
  caches,                                              -- count
  vault = VaultRewards?, hasUnclaimedVault,
  keystone?,                                           -- owned keystone level
  dungeons = { done, max }?,                           -- M+ runs + vault threshold
}
instances = {
  locks = { [instanceID] = { [difficultyID] = { name, total, progress, reset, extended, isRaid } } },
}
equipment = {
  slots = { Head/Neck/.../OffHand = { name, link, ilvl, track?, trackLevel?, equipLoc, classID, subClassID, emptySockets, enchant? } },  -- emptySockets (v15): count of unfilled gem sockets, via GetItemNumSockets − gemmed sockets (GetItemGemID); NOT GetItemStats EMPTY_SOCKET_* (stale under the Midnight Gem Manager). enchant: applied permanent-enchant NAME ("Enchant Helm - Rune of Avoidance") read from the live tooltip's "Enchanted:" line at scan time (trailing quality-tier atlas stripped); nil if unenchanted/un-rescanned. Lets ShadowsOfUI-Upgrade flag a WRONG enchant warband-wide
  ilvl, trackScanned,
}
artifacts = {
  hidden       = { [SpecKey] = bool },
  hiddenColors = { wq = {progress, goal}, dungeon = {...}, kills = {...} },
  classHall,
}
playtime = {
  total,                                               -- total /played in seconds
  byPatch = { ["12.0.5"] = baseSeconds, ... },         -- /played at first login per patch
}
```

## Broker Definitions

| Broker | Fields | Events | Resets |
|---|---|---|---|
| `basic` | level, specialization, professions, xp | `PLAYER_LEVEL_UP` (500ms), `PLAYER_SPECIALIZATION_CHANGED` (specialization), `PLAYER_XP_UPDATE`/`UPDATE_EXHAUSTION`/`PLAYER_UPDATE_RESTING` (1000ms) | — |
| `currency` | RestoredCofferKey, gold, CofferKeyShard, Catalyst, HeroDawncrest, MythDawncrest, NebulousVoidcore, UntaintedManaCrystal | `PLAYER_MONEY` (gold), `CURRENCY_DISPLAY_UPDATE` (Catalyst + NebulousVoidcore, id-filtered) | CofferKeyShard, NebulousVoidcore, UntaintedManaCrystal: `RESET_WEEKLY` |
| `items` | bags, reagentBag | — | — |
| `inventory` | counts | `BAG_UPDATE_DELAYED` (500ms) | — |
| `gearbag` | items | `BAG_UPDATE_DELAYED` (500ms) | — |
| `professions` | details, gear | `TRADE_SKILL_SHOW` (details, 0.5s C_Timer); `PLAYER_EQUIPMENT_CHANGED` (gear, 500ms + item load) | — |
| `concentration` | data | `CURRENCY_DISPLAY_UPDATE` | — |
| `artisanCurrency` | data | `CURRENCY_DISPLAY_UPDATE` | — |
| `quests` | UndermineStoryMode, WWIRep, LumberAxe, delves | `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `UNIT_QUEST_LOG_CHANGED`, `SPELLS_CHANGED` | — |
| `worldquests` | rewards | `QUEST_LOG_UPDATE`, `ZONE_CHANGED_NEW_AREA` (debounced; retries while reward data loads) | — |
| `dailies` | (empty) | — | — |
| `weeklies` | DMF, preMidnight, caches, vault, hasUnclaimedVault, keystone, dungeons | `QUEST_TURNED_IN`, `WEEKLY_REWARDS_UPDATE` (1000ms), `CHALLENGE_MODE_COMPLETED` | DMF: `RESET_SUNDAY`; rest: `RESET_WEEKLY` |
| `instances` | locks | `INSTANCE_LOCK_STOP` | `RESET_WEEKLY` |
| `equipment` | slots, ilvl, trackScanned | `PLAYER_EQUIPMENT_CHANGED` (`ITEM_DATA_LOAD_RESULT` + bounded fallback re-scan) | — |
| `stats` | secondary (crit/haste/mastery/versatility {pct,rating}) | `COMBAT_RATING_UPDATE` | — |
| `artifacts` | hidden, hiddenColors, classHall | `QUEST_TURNED_IN` | — |
| `playtime` | total, byPatch | `TIME_PLAYED_MSG` (via `RequestTimePlayed()` on Init) | — |

Reset constants: `RESET_SUNDAY = 0`, `RESET_DAILY = 1`, `RESET_WEEKLY = 7`.

## How a Broker Field Works

A `Broker` (from `broker.lua`) holds a `fields` table; each field is `{ get, event?, eventDelay?, eventHandler?, eventFilter?, maxLevel?, order?, resetOn?, reset? }`.

- **`get(self, toon, currentValue)`** computes the new value; `currentValue` lets a field merge into / preserve cached data (e.g. `professions.details`, `concentration.data`).
- **`event`** (string or list) auto-registers a handler that re-runs `get` after `eventDelay` ms. Provide a custom `eventHandler` for incremental updates (e.g. `quests.WWIRep` decrements `missing` rather than re-scanning).
- **`maxLevel = true`** skips the field for sub-max-level characters (both in `refreshQueue` and `RefreshCurrentCharacterField`).
- **`resetOn` / `reset`** clear/seed the field at the matching reset boundary (`InitBrokers` walks all characters at login when a boundary has passed). Fields with `resetOn` but no `reset` are nilled. The daily/weekly anchors are recomputed per login from the seconds-until APIs and can jitter by a second, so a reset only fires when the anchor advanced by more than `RESET_SLACK` (12h). The **Sunday** anchor (`RESET_SUNDAY`, used by `weeklies.DMF`) is derived from the epoch alone (`GetServerTime()` → UTC day-of-week math), never from `GetCurrentCalendarTime()` — that call returns a zeroed struct (`weekday=0`) when the calendar isn't warm yet at addon-load, which turned the old formula's `-(weekday-1)*day` into `+1 day` and pushed the anchor into the future, firing a spurious Sunday reset that wiped every character's DMF flag. The epoch-only anchor needs no calendar API, so it's always valid and identical across all realms/timezones. `InitBrokers` also clamps a stored future Sunday anchor (left by the old bug) back down without resetting, so the next genuine boundary still fires on schedule.
- **`order`** sorts the scan within a broker (e.g. `basic.level` runs first so other fields can read it).

## Gotchas

- **`GetCharacterData` returns a live reference, not a copy** — mutating it writes straight into the DB. (A `--todo` in `api.lua` notes this.)
- **`refreshQueue` paces one *field* (not one broker) per 100ms** via `ns:delay` to avoid a login frame spike. `lastRefresh` is stamped only when the queue drains. **Each field's `get` is `pcall`-isolated**: `ns:delay` clears its `OnUpdate` before invoking the tick, so an unguarded throw inside a `get` (e.g. a currency `GetCurrencyInfo(id).quantity` where the currency is undiscovered → nil index) would skip the chain re-arm and silently strand every field *after* the failing one (and never stamp `lastRefresh`). The `pcall` keeps the cached value on error and continues, so one bad field can't halt the whole refresh.
- **Per-recipe crafting `quality`/`qualityConc` is a conservative skill-floor estimate.** Captured with empty reagents (`GetCraftingOperationInfo(id, {}, nil, false/true)`), so it's the worst-case tier the character reaches on skill alone — better mats only improve on it. Per-character and window-driven like the rest of `details`, so it stays nil until the character reopens that profession window.
- **`professions.details` scans are window-driven and merge-preserving.** Recipes/spec points are only queryable while a trade-skill window is open; the scan captures the opened profession's ID *before* the 0.5s timer (the player may switch professions meanwhile) and per-field-nil-guards against the API returning empty during load, so partial scans never wipe good cached data.
- **`professions.gear` and `equipment.slots` pre-request item data.** WoW item APIs return nil until loaded, so both fire `RequestLoadItemData` on `PLAYER_EQUIPMENT_CHANGED` and re-`Update` from `ITEM_DATA_LOAD_RESULT` once the outstanding request count hits zero. Always merge onto cached values (their `get` preserves a slot whose item isn't loaded yet rather than dropping it). **`ITEM_DATA_LOAD_RESULT` does NOT fire for an item whose data is already cached** (the common case: equipping straight from your bags), which strands the pending set and leaves the cache showing the pre-swap gear until the next reload/refresh. Both `equipment.slots` and `professions.gear` guard this with a bounded generation-guarded fallback re-scan (`scheduleFallback`, `FALLBACK_DELAY`×`MAX_FALLBACKS`, gated by an `anyUnloaded()` slot check); whichever of the event-path Update or the fallback lands first refreshes the cache, the other is idempotent.
- **`playtime` bypasses the field system.** `TIME_PLAYED_MSG` is async, so the broker overrides `Init` to register its own handler and calls `RequestTimePlayed()`; `byPatch[patch]` is written only on the first login of a patch.
- **Warband wealth is account-wide, stored once at `db.warband`** (the bank is shared), not duplicated per character. `GetWarbandWealth` = `bankGold` + last-known `currency.gold` of every character. `RolloverWarbandWeek` closes elapsed weeks at the `ns.LAST_RESET` boundary, using last-seen wealth as the closing figure.
- **Evokers (classId 13) have no class hall** — `artifacts.classHall`/`hiddenColors` short-circuit for them.
- **World-quest scanning is bundled-continent, any level.** `data/worldquests.lua`'s `WQ_CONTINENTS` is the current expansion's WQ continent map ID(s) (expanded to zone children at scan time, so all zones are covered regardless of where the player stands); **update it each expansion**. Not max-level-gated — some WQs reward gear before the cap. Reward data is only readable for the logged-in character, so alts keep their last-seen cache (expired entries dropped on read by `endTime`). `WQ_ILVL_CEILING` (220) skips the map walk for fully-geared characters (the only level-related guard). The reward ilvl is the value scaled to the character that scanned it, so it's only ever compared against that same character's slots.

## SavedVariables (`WarbandeerCharDB`)

```lua
{ version = 18, numCharacters, lastDailyReset, lastReset, lastSundayReset,
  characters = { ["Name"] = Character },
  -- account-wide warband wealth (v8); not per-character
  warband = {
    bankGold,                              -- last-known account bank gold (copper)
    week = { start, baseline },            -- open week: reset timestamp + wealth at week start
    history = { { start, ending, made } }, -- closed weeks, oldest first (made = ending − baseline)
  },
  -- account-wide recipe → prof-gear cache (v10); static game data, wiped on client build change
  recipeGear = {
    build,                                 -- "version-buildNum" the cache was resolved against
    recipes = { [recipeID] = { itemID, rarity, equipLoc, skillID } | false },
  },
  -- account-wide bank gear cache (v11; equippable `equip` lists added v13; full
  -- `items` count maps added v19); last-seen, scanned on bank open.  prof-gear
  -- entries: { itemID, skillID, equipLoc, rarity, count }; equip entries (warband +
  -- personal banks only): GearCandidate; items: { [itemID] = count } over everything
  bank = {
    warband    = { scannedAt, gear = {...}, equip = {...}, items = {...} },   -- shared account bank
    characters = { ["Name"]      = { scannedAt, gear = {...}, equip = {...}, items = {...} } },
    guilds     = { ["GuildName"] = { scannedAt, gear = {...}, items = {...} } },  -- no equip (not an upgrade source)
  },
  -- account-wide UI preferences (v12); now legacy/unused — the wmissing copy-
  -- window font size moved to LibNUI's own DB (LibNUIDB.copyFontSize). Kept per
  -- the non-destructive policy; left in place for rollback safety.
  ui = { wmissingFontSize } }                              -- legacy (stale)
```

`MigrateDB` (all migrations non-destructive): **v7** moves flat fields into `basic`/`instances` sub-tables and nils the old keys; **v8** seeds `warband = { bankGold = 0, history = {} }` (`week` filled lazily by `RolloverWarbandWeek` on first login); **v9** re-derives `classKey` from the locale-independent class token; **v10** seeds `recipeGear = { build = "", recipes = {} }` (re-stamped and filled lazily by `data/recipegear.lua`); **v11** seeds `bank = { characters = {}, guilds = {} }` (warband filled lazily; all populated by `data/bank.lua` on bank open); **v12** seeds `ui = {}` (account-wide UI prefs; originally held `wmissingFontSize`, now legacy — the copy-window font size moved to `LibNUIDB.copyFontSize`, this table left in place for rollback safety). **v13** is a version bump only — the equippable-gear cache (`bank.*.equip`, per-char `gearbag.items`, `basic.specialization.id`) is purely additive and filled lazily, so older revisions just see empty lists. **v14** is a version bump only — the per-character world-quest reward cache (`worldquests.rewards`) is additive and filled lazily on the next scan, so rollback is lossless. **v15** is a version bump only — the per-slot `equipment.slots.*.emptySockets` count is additive and filled lazily on the next equipment scan, so older revisions just lack the field (treated as none) and rollback is lossless. **v16** is a version bump only — the `stats.secondary` snapshot is additive and filled lazily on the next scan, so older revisions just lack it (the Detail grid shows blanks) and rollback is lossless. **v17** is a version bump only — the per-candidate `quality` (Enum.ItemQuality) on cached bag/bank equippable gear is additive and filled lazily on the next bag/bank scan, so older entries just lack it (the upgrade addon's artifact gate falls back to the live `GetItemQualityByID` lookup) and rollback is lossless. **v18** is a version bump only — the per-candidate `reqLevel` (required character level) on cached bag/bank equippable gear is additive and filled lazily on the next bag/bank scan, so older entries just lack it (the consumer's level gate falls back to the live `GetItemInfo` lookup) and rollback is lossless. **v19** is a version bump only — the per-character bag count index (`inventory.counts`) and the per-bank `items` count maps (`bank.*.items`) are additive and filled lazily (bag counts on the next `BAG_UPDATE_DELAYED`, bank counts on the next bank open), so older revisions just see empty counts (the warband-stock tooltip shows fewer sources) and rollback is lossless. **v20** is a version bump only — the per-character `mail` cache is additive and filled lazily on the next mailbox visit, so older revisions just lack it (the Summary mail column is blank, the tooltip shows no mail source) and rollback is lossless.
