# Warbandeer_Characters

Data collection backbone. Populates `WarbandeerApi` global.

## TOC
```
Interface: 120001, Dependencies: LibNAddOn, LibNUI
SavedVariables: WarbandeerCharDB (version 8)
X-NUI-COMMANDS: /characters, /wbc
X-NUI-API: WarbandeerApi, X-NUI-UI: LibNUI
```

## Files

| File | Purpose |
|---|---|
| `init.lua` | LibNAddOn assignment form bootstrap |
| `types.lua` | LuaLS aliases for `Specialization`, `SpecializationKey` |
| `broker.lua` | `Broker` class, `RegisterBroker`, `InitBrokers`, reset constants |
| `database.lua` | `MigrateDB` (v6), `initialize`, `/characters list/delete` |
| `main.lua` | `refresh`, `refreshQueue` (one broker per 100ms), `/characters refresh/dump` |
| `login.lua` | `onLogin` → `initialize()` then `refresh()` |
| `api.lua` | `WarbandeerApi` public methods |
| `data/basic.lua` | Broker: level, specialization, professions |
| `data/currency.lua` | Broker: `RestoredCofferKey` (currency 3028), per-char `gold` (`GetMoney`), Coffer/Dawncrest currencies |
| `data/warband.lua` | Account-wide (not a broker): `db.warband` bank gold + weekly wealth tracking. `GetWarbandWealth`, `RolloverWarbandWeek`, `InitWarband`, `/wbc dump warband` |
| `data/items.lua` | Broker: bag inventory |
| `data/professions.lua` | Broker: per-expansion skill levels, spec points, per-expansion learned recipes (ids+names). Also `ns.api.professionInfo` |
| `data/concentration.lua` | Broker: `data` — Midnight concentration currency per crafting prof (qty/max/recharge), keyed by parent skillLineID |
| `data/races.lua` | Race tables, `NormalizeRaceId()` |
| `data/quests.lua` | Broker: `UndermineStoryMode`, `WWIRep`, `delves` |
| `data/daily.lua` | Broker: (empty) |
| `data/playtime.lua` | Broker: `total` seconds, `byPatch` baseline per WoW version |
| `data/weekly.lua` | Broker: `DMF`, `preMidnight`, `caches`, `vault` |
| `data/instances.lua` | Broker: `locks` (instance lockouts) |
| `data/equipment.lua` | Broker: `slots`, `ilvl` |
| `data/artifacts.lua` | Broker: `hidden`, `hiddenColors`, `classHall` |
| `data/reputation.lua` | Broker: `legion` (9 Legion faction standings) |
| `dump.lua` | `stat` command — warband-wide playtime/class statistics |
| `missing.lua` | `missing` command — lists characters missing data (gold, playtime, profession detail, recipe capture, …) |

## WarbandeerApi Methods

```lua
WarbandeerApi:GetCurrentCharacter()       → string
WarbandeerApi:GetCharacterData(char?)     → Character
WarbandeerApi:GetNumCharacters()          → integer
WarbandeerApi:GetNumMaxLevel()            → integer
WarbandeerApi:GetAllCharacters()          → Character[]
WarbandeerApi:GetAllianceCharacters()     → Character[]
WarbandeerApi:GetHordeCharacters()        → Character[]
WarbandeerApi:GetWarbandBankGold()        → integer (copper)
WarbandeerApi:GetWarbandWealth()          → integer (copper, bank + all char gold)
WarbandeerApi:GetWeeklyGoldMade()         → integer (copper, current wealth − week baseline)
WarbandeerApi:GetWealthHistory()          → WarbandWeekRecord[]  (closed weeks, oldest first)
```

Also on API table: `ALLIANCE_RACES`, `HORDE_RACES`, `professionInfo`, `SettingsCategory`, `AliasSettingsCategory`

## Character Struct

```lua
-- Top-level (set at creation):
name, classId, className, classKey, race, raceId, raceIdx, isAlliance, realm

-- Sub-tables (populated by brokers):
basic = {
  level, specialization = { primary, active, role, key },
  professions = { primary, secondary, fishing, cooking },
}
currency = { RestoredCofferKey }
items = {
  bags = { [1..N] = {id, slots}, GoblinMiniFridge?, ArathorSatchel?, PortableRefridgerator? },
  reagentBag = { id, slots },
}
professions = {
  details = { [skillLineID] = {
    expansions = { {name, skillLevel, maxSkillLevel} }, specPoints?,
    recipes = { [expKey] = { learned = { {id, name} }, total } }?,  -- expKey: midnight/tww/df
  } },
}
concentration = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity,
                             rechargingAmountPerCycle, rechargingCycleDurationMS, lastUpdated } },
}
quests = {
  UndermineStoryMode,
  WWIRep = { complete, missing, Dornogal, Assembly, Hallowfall, Azjkahet, Undermine, Arathi, Karesh },
  delves = { complete, missing, [label] = bool },
}
dailies = {}
weeklies = {
  DMF,
  preMidnight = { eight, three },
  caches,
  vault = { rewards, counts, best, bestN }?,
}
instances = {
  locks = { [instanceID] = { [difficultyID] = { name, total, progress, reset, extended, isRaid } } },
}
equipment = {
  slots = { Head/Neck/Shoulder/.../OffHand = { name, link, ilvl, track?, trackLevel? } },
  ilvl,
}
artifacts = {
  hidden = { [SpecKey] = bool },
  hiddenColors = { wq = {progress, goal}, dungeon = {}, kills = {} },
  classHall,
}
reputation = {
  legion = { [factionID] = { name, done, current, max } },
}
playtime = {
  total,    -- total /played in seconds
  byPatch = { ["12.0.5"] = baseSeconds, ... }, -- /played at first login per patch
}
```

## Broker Definitions

| Broker | Fields | Events | Resets |
|---|---|---|---|
| `basic` | level, specialization, professions | `PLAYER_LEVEL_UP` (500ms delay) | — |
| `currency` | RestoredCofferKey | — | — |
| `items` | bags, reagentBag | — | — |
| `professions` | details (expansions, specPoints, per-exp recipes) | `TRADE_SKILL_SHOW` (500ms C_Timer) | — |
| `concentration` | data (per-prof Midnight concentration currency) | `CURRENCY_DISPLAY_UPDATE` | — |
| `quests` | UndermineStoryMode, WWIRep, delves | `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `UNIT_QUEST_LOG_CHANGED` | — |
| `dailies` | (empty) | — | — |
| `weeklies` | DMF, preMidnight, caches, vault | `QUEST_TURNED_IN`, `WEEKLY_REWARDS_UPDATE` (1000ms delay) | DMF: `RESET_SUNDAY`, others: `RESET_WEEKLY` |
| `instances` | locks | `INSTANCE_LOCK_STOP` | `RESET_WEEKLY` |
| `equipment` | slots, ilvl | `PLAYER_EQUIPMENT_CHANGED` (500ms delay + item load) | — |
| `artifacts` | hidden, hiddenColors, classHall | `QUEST_TURNED_IN` | — |
| `reputation` | legion | — | — |
| `playtime` | total, byPatch | `TIME_PLAYED_MSG` (via `GetTimePlayed()` on Init) | — |

Reset constants: `RESET_SUNDAY=0`, `RESET_DAILY=1`, `RESET_WEEKLY=7`

## SavedVariables (`WarbandeerCharDB`)

```lua
{ version, numCharacters, lastDailyReset, lastReset, lastSundayReset,
  characters = { ["Name"] = Character },
  -- account-wide warband wealth (v8); not per-character (warband bank is shared)
  warband = {
    bankGold,                              -- last-known account bank gold (copper)
    week = { start, baseline },            -- open week: reset timestamp + wealth at week start
    history = { { start, ending, made } }, -- closed weeks, oldest first (made = ending − baseline)
  } }
```

`MigrateDB` v8 seeds `warband = { bankGold = 0, history = {} }` (non-destructive); `week`
is filled lazily by `RolloverWarbandWeek` on first login. Wealth = `bankGold` + the
last-known `currency.gold` of every character; `RolloverWarbandWeek` closes elapsed weeks
at the `ns.LAST_RESET` boundary (exposed from `broker.lua`).
