# Warbandeer_Characters (Data Layer)

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `WarbandeerCharDB` (v8) · **Commands:** `/characters`, `/wbc` · **API:** `WarbandeerApi`

Data-collection backbone for the suite. Scans the active character each login/refresh and stores everything in `WarbandeerCharDB`, exposing it to the rest of the suite through the `WarbandeerApi` global. Per-field scanning is driven by the **broker** system (`broker.lua`).

## Files

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap (assignment form) |
| `types.lua` | LuaLS aliases: `Specialization`, `SpecializationKey` |
| `broker.lua` | `Broker` class + `ns:RegisterBroker`/`InitBrokers`; reset constants `RESET_SUNDAY/DAILY/WEEKLY`; reset-boundary timestamps `ns.LAST_DAILY_RESET`/`LAST_RESET`/`LAST_SUNDAY_RESET` |
| `database.lua` | `ns:MigrateDB` (v8), `ns:initialize` (creates the per-char struct, then `InitBrokers`/`InitWarband`); `/characters list`, `/characters delete <name>`, `/characters cleanup` (recount numCharacters) |
| `main.lua` | `ns:refresh` + `ns:refreshQueue` (one **field** scanned per 100ms); `/characters refresh`, `/characters dump` |
| `login.lua` | `ns.onLogin` → `initialize()` once, then `refresh()` |
| `api.lua` | `WarbandeerApi` public methods (see below) |
| `data/basic.lua` | Broker `basic`: `level`, `specialization`, `professions` (name summary), `xp` |
| `data/currency.lua` | Broker `currency`: `RestoredCofferKey`, `gold` (`GetMoney`), `CofferKeyShard`, `Catalyst`, `HeroDawncrest`, `MythDawncrest`, `NebulousVoidcore` |
| `data/warband.lua` | Account-wide (not a broker): `db.warband` bank gold + weekly wealth. `ns:GetWarbandWealth`, `RolloverWarbandWeek`, `InitWarband`; `/wbc dump warband` |
| `data/items.lua` | Broker `items`: `bags`, `reagentBag`; `/wbc refresh items` |
| `data/professions.lua` | Broker `professions`: `details` (per-exp skill levels, spec points, learned recipes) + `gear` (tool/accessory slots). Also defines `ns.api.professionInfo` |
| `data/concentration.lua` | Broker `concentration`: `data` — Midnight concentration currency per crafting prof, keyed by parent skillLineID |
| `data/races.lua` | `API.ALLIANCE_RACES`, `API.HORDE_RACES`, `ns.NormalizeRaceId(raceId)` → `(raceIdx, isAlliance)` |
| `data/quests.lua` | Broker `quests`: `UndermineStoryMode`, `WWIRep`, `LumberAxe`, `delves` |
| `data/daily.lua` | Broker `dailies`: empty (template for future daily tracking) |
| `data/playtime.lua` | Broker `playtime`: `total` seconds + `byPatch` baseline; async via `TIME_PLAYED_MSG` |
| `data/weekly.lua` | Broker `weeklies`: `DMF`, `preMidnight`, `caches`, `vault`, `hasUnclaimedVault`, `keystone`, `dungeons`; `/wbc dump m+`, `/wbc dump vault` |
| `data/instances.lua` | Broker `instances`: `locks`; `/wbc refresh locks`, `/wbc dump locks` |
| `data/equipment.lua` | Broker `equipment`: `slots`, `ilvl`, `trackScanned`; loads item data before reading |
| `data/artifacts.lua` | Broker `artifacts`: `hidden`, `hiddenColors`, `classHall`; `/wbc dump artifact` |
| `dump.lua` | `/wbc stat` — warband-wide playtime/class statistics |
| `missing.lua` | `/wbc missing`, `/wbc missing me` — lists characters/fields with incomplete data |
| `wmissing.lua` | `/wbc wmissing` — same report rendered in a copyable scroll window |
| `debug.lua` | `/wbc debug <lua>` — runs arbitrary Lua for inspection |

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
```

Also on the API table: `ALLIANCE_RACES`, `HORDE_RACES`, `professionInfo`.
(`SettingsCategory` / `AliasSettingsCategory` are set on this same table by **Warbandeer** and **Warbandeer_Alias**, not here.)

## Per-Character Struct (`db.characters[name]`)

```lua
-- Top-level (set once at creation in initialize):
name, classId, className, classKey, race, raceId, raceIdx, isAlliance, realm
lastRefresh   -- set by refreshQueue when a full scan completes

-- Sub-tables (one per broker, populated by their fields):
basic = {
  level,
  specialization = { primary, active, role, key },
  professions    = { primary, secondary, fishing, cooking },  -- {name, skillID, ...} each
  xp             = { percent, restPercent, isResting, recordedAt }?,
}
currency = {
  RestoredCofferKey,                                   -- quantity (currency 3028)
  gold,                                                -- GetMoney(), copper
  CofferKeyShard = { quantity, capped }?,              -- weekly-reset
  Catalyst       = { quantity, max, capped }?,         -- Dawnlight Manaflux (3378), capped = bank full
  HeroDawncrest  = { quantity, earned, max, capped },
  MythDawncrest  = { quantity, earned, max, capped },
  NebulousVoidcore = { quantity, earned, max, capped }?,   -- (3418) season cap: totalEarned vs maxQuantity, grows +2/week

}
items = {
  bags = { [1..N] = {id, slots}, GoblinMiniFridge?, ArathorSatchel?, PortableRefridgerator? },
  reagentBag = { id, slots },
}
professions = {
  details = { [skillLineID] = {
    expansions = { {name, skillLevel, maxSkillLevel} }?, specPoints?,
    recipes = { [expKey] = { learned = { {id, name} }, total } }?,  -- expKey: midnight/tww/df
  } }?,
  gear = { [parentSkillLineID] = { slots = { [invSlot] = {name,link,ilvl,rarity,tier,expacID} } } }?,
}
concentration = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity,
                             rechargingAmountPerCycle, rechargingCycleDurationMS, lastUpdated } }?,
}
quests = {
  UndermineStoryMode,
  WWIRep = { complete, missing, Dornogal, Assembly, Hallowfall, Azjkahet, Undermine, Arathi, Karesh },
  LumberAxe,                                           -- has Find-Lumber tracking spell
  delves = { complete, missing, [label] = bool },
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
  slots = { Head/Neck/.../OffHand = { name, link, ilvl, track?, trackLevel? } },
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
| `basic` | level, specialization, professions, xp | `PLAYER_LEVEL_UP` (500ms), `PLAYER_XP_UPDATE`/`UPDATE_EXHAUSTION`/`PLAYER_UPDATE_RESTING` (1000ms) | — |
| `currency` | RestoredCofferKey, gold, CofferKeyShard, Catalyst, HeroDawncrest, MythDawncrest, NebulousVoidcore | `PLAYER_MONEY` (gold), `CURRENCY_DISPLAY_UPDATE` (Catalyst + NebulousVoidcore, id-filtered) | CofferKeyShard, NebulousVoidcore: `RESET_WEEKLY` |
| `items` | bags, reagentBag | — | — |
| `professions` | details, gear | `TRADE_SKILL_SHOW` (details, 0.5s C_Timer); `PLAYER_EQUIPMENT_CHANGED` (gear, 500ms + item load) | — |
| `concentration` | data | `CURRENCY_DISPLAY_UPDATE` | — |
| `quests` | UndermineStoryMode, WWIRep, LumberAxe, delves | `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `UNIT_QUEST_LOG_CHANGED`, `SPELLS_CHANGED` | — |
| `dailies` | (empty) | — | — |
| `weeklies` | DMF, preMidnight, caches, vault, hasUnclaimedVault, keystone, dungeons | `QUEST_TURNED_IN`, `WEEKLY_REWARDS_UPDATE` (1000ms), `CHALLENGE_MODE_COMPLETED` | DMF: `RESET_SUNDAY`; rest: `RESET_WEEKLY` |
| `instances` | locks | `INSTANCE_LOCK_STOP` | `RESET_WEEKLY` |
| `equipment` | slots, ilvl, trackScanned | `PLAYER_EQUIPMENT_CHANGED` (500ms + `ITEM_DATA_LOAD_RESULT`) | — |
| `artifacts` | hidden, hiddenColors, classHall | `QUEST_TURNED_IN` | — |
| `playtime` | total, byPatch | `TIME_PLAYED_MSG` (via `RequestTimePlayed()` on Init) | — |

Reset constants: `RESET_SUNDAY = 0`, `RESET_DAILY = 1`, `RESET_WEEKLY = 7`.

## How a Broker Field Works

A `Broker` (from `broker.lua`) holds a `fields` table; each field is `{ get, event?, eventDelay?, eventHandler?, eventFilter?, maxLevel?, order?, resetOn?, reset? }`.

- **`get(self, toon, currentValue)`** computes the new value; `currentValue` lets a field merge into / preserve cached data (e.g. `professions.details`, `concentration.data`).
- **`event`** (string or list) auto-registers a handler that re-runs `get` after `eventDelay` ms. Provide a custom `eventHandler` for incremental updates (e.g. `quests.WWIRep` decrements `missing` rather than re-scanning).
- **`maxLevel = true`** skips the field for sub-max-level characters (both in `refreshQueue` and `RefreshCurrentCharacterField`).
- **`resetOn` / `reset`** clear/seed the field at the matching reset boundary (`InitBrokers` walks all characters at login when a boundary has passed). Fields with `resetOn` but no `reset` are nilled.
- **`order`** sorts the scan within a broker (e.g. `basic.level` runs first so other fields can read it).

## Gotchas

- **`GetCharacterData` returns a live reference, not a copy** — mutating it writes straight into the DB. (A `--todo` in `api.lua` notes this.)
- **`refreshQueue` paces one *field* (not one broker) per 100ms** via `ns:delay` to avoid a login frame spike. `lastRefresh` is stamped only when the queue drains.
- **`professions.details` scans are window-driven and merge-preserving.** Recipes/spec points are only queryable while a trade-skill window is open; the scan captures the opened profession's ID *before* the 0.5s timer (the player may switch professions meanwhile) and per-field-nil-guards against the API returning empty during load, so partial scans never wipe good cached data.
- **`professions.gear` and `equipment.slots` pre-request item data.** WoW item APIs return nil until loaded, so both fire `RequestLoadItemData` on `PLAYER_EQUIPMENT_CHANGED` and re-`Update` from `ITEM_DATA_LOAD_RESULT` once the outstanding request count hits zero. Always merge onto cached values.
- **`playtime` bypasses the field system.** `TIME_PLAYED_MSG` is async, so the broker overrides `Init` to register its own handler and calls `RequestTimePlayed()`; `byPatch[patch]` is written only on the first login of a patch.
- **Warband wealth is account-wide, stored once at `db.warband`** (the bank is shared), not duplicated per character. `GetWarbandWealth` = `bankGold` + last-known `currency.gold` of every character. `RolloverWarbandWeek` closes elapsed weeks at the `ns.LAST_RESET` boundary, using last-seen wealth as the closing figure.
- **Evokers (classId 13) have no class hall** — `artifacts.classHall`/`hiddenColors` short-circuit for them.

## SavedVariables (`WarbandeerCharDB`)

```lua
{ version = 8, numCharacters, lastDailyReset, lastReset, lastSundayReset,
  characters = { ["Name"] = Character },
  -- account-wide warband wealth (v8); not per-character
  warband = {
    bankGold,                              -- last-known account bank gold (copper)
    week = { start, baseline },            -- open week: reset timestamp + wealth at week start
    history = { { start, ending, made } }, -- closed weeks, oldest first (made = ending − baseline)
  } }
```

`MigrateDB` (all migrations non-destructive): **v7** moves flat fields into `basic`/`instances` sub-tables and nils the old keys; **v8** seeds `warband = { bankGold = 0, history = {} }` (`week` filled lazily by `RolloverWarbandWeek` on first login).
