# ShadowsOfUI-DMF

## TOC
```
Interface: 120001, Category: Shadows of UI
Dependencies: LibNAddOn (no LibNUI)
No SavedVariables, no slash commands
```

Single file: `DMF.lua`. Assignment form `local ns = LibNAddOn(...)`.

**Headless Darkmoon Faire helper — no UI, no archaeology.**

### Features
- **Calendar detection** (`checkForDMF`): checks `C_Calendar` holiday textures (235446–235448) to determine if DMF is active; caches `startTime`/`endTime` for fast re-checks
- **Auto-buy**: when opening the merchant on Darkmoon Island during DMF week, automatically purchases required profession quest materials for any profession with skill ≥ 1 and quest not yet done
- **Quest auto-accept**: `QUEST_DETAIL` handler calls `AcceptQuest()` when you use a dungeon/raid/PvP drop item (Imbued Crystal, Monstrous Egg, etc.)
- **Gossip auto-complete**: `GOSSIP_SHOW` handler calls `C_GossipInfo.SelectOption()` for minigame quests you are on, have a token for, and haven't completed
- **Login alert**: prints "Darkmoon Faire is open!" on first login/reload if DMF is active

### Event lifecycle
Dynamic events (merchant, quest, gossip) are registered/unregistered based on DMF active status via `checkDMFStatus()`, called from `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, and `CALENDAR_UPDATE_EVENT_LIST`.

### Profession data
All primary and secondary professions except Archaeology. Uses `C_TradeSkillUI.GetProfessionInfoBySkillLineID` to sum skill across all expansions for primary professions; uses direct `GetProfessionInfo` values for secondary (fishing, cooking).

### Key tables
| Table | Key → Value |
|---|---|
| `ProfessionQuestData` | professionId → `{ questId, questItems? }` |
| `ProfessionTradeSkillLines` | professionId → `{ skillLineId, ... }` (11 expansions) |
| `turnInItems` | itemId → questId (10 drop items) |
| `gossipQuestIds` | gossipOptionID → questId (7 minigames) |
