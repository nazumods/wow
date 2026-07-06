# ShadowsOfUI-DMF

**Deps:** LibNAddOn · **SavedVars:** none · **Commands:** `/sdmf` (dev coords) · **UI:** none (no LibNUI)

Headless Darkmoon Faire helper. While the faire is open it auto-buys profession quest materials at the merchant and guides you between the profession quest givers via a map waypoint + world-map pins. Single file, assignment-form init (`local ns = LibNAddOn(...)`).

## Files

| File | Purpose |
|---|---|
| `DMF.lua` | Everything: DMF calendar detection, profession-skill tally, merchant auto-buy, waypoint/map-pin guidance, event wiring, `/sdmf` |

## Behavior

- **DMF detection** (`checkForDMF`) — reads `C_Calendar` holiday textures (235448 begin / 235447 mid / 235446 end) for today; caches `startTime`/`endTime` so subsequent checks skip the calendar scan until the window lapses. `checkDMFStatus` enters/leaves DMF mode (registers/unregisters the merchant + quest events) and refreshes guidance. Driven by `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, and `CALENDAR_UPDATE_EVENT_LIST`.
- **Profession tally** (`updateProfessions`) — for each known profession sums per-expansion `skillLevel`/`maxSkillLevel` via `C_TradeSkillUI.GetProfessionInfoBySkillLineID`; falls back to `GetProfessionInfo` when the trade-skill book hasn't loaded. Refreshed on `SKILL_LINES_CHANGED` / `TRADE_SKILL_LIST_UPDATE` and at login.
- **Auto-buy** (`autoBuyItems`) — on opening a merchant during DMF, buys the shortfall of each `questItems` entry for any profession with `skillLevel >= 1` whose quest isn't completed. Buys in max-stack chunks then a remainder, clamping to vendor stock and available money. Spend-safety guard: skips a merchant slot whose `maxStack` is 0/nil (the stack loop would otherwise spin forever on `BuyMerchantItem(j, 0)`) or that `hasExtendedCost` (the gold-only price check can't gauge a currency/token cost).
- **Guidance** — `updateWaypoint` sets a user waypoint to the first quest giver in `WaypointOrder[mapId]` with an incomplete quest (Elwynn only; `SetUserWaypoint` is unsupported on the DMF island). `refreshMapPins` draws clickable QuestGiver pins on the world map canvas for the same NPCs. Both refresh on `QUEST_ACCEPTED` / `QUEST_TURNED_IN` and on world-map show/`MapChanged`.
- **Login alert** — first `CALENDAR_UPDATE_EVENT_LIST` after login prints "Darkmoon Faire is open!" if active (gated by `calendarNotified`).
- **`/sdmf`** — dev helper: prints the mouseover/target NPC id and player map coords to populate `QuestGiverNpcs` / `NpcPositions`.

## Key tables

| Table | Key → Value | Notes |
|---|---|---|
| `ProfessionQuestData` | professionId → `{ questId, questItems? }` | 13 professions (no Archaeology); only entries with `questItems` are auto-bought |
| `ProfessionTradeSkillLines` | professionId → `{ skillLineId × 11 }` | per-expansion lines, summed for total skill |
| `QuestGiverNpcs` | npcId → `{ questId, ... }` | DMF-island givers + 2 Elwynn vendors |
| `NpcPositions` | npcId → `{ mapId, x, y, label }` | normalized 0–1 coords for waypoint/pins |
| `WaypointOrder` | mapId → `{ npcId, ... }` | ordered visit sequence (37 Elwynn, 407 DMF island) |

## Gotchas

- **Auto-buy is debounced via `lockAutoBuy`.** Set on merchant show, runs `autoBuyItems` next frame (`C_Timer.After(0)`), and is only cleared by `BAG_UPDATE_DELAYED` (also next frame) — this prevents the buy loop re-firing on its own bag updates. Cleared on leaving DMF.
- **Calendar scan is non-destructive.** `checkForDMF` saves/restores the open `CalendarFrame`'s month (`SetAbsMonth`) so opening the calendar to detect DMF doesn't leave the user's calendar on the wrong month.
- **Calendar dates need `day = monthDay`.** `C_Calendar` time tables expose `monthDay`, not `day`, which `time()` requires — assigned before every `time()` call.
- **Waypoints only work in Elwynn.** `C_Map.SetUserWaypoint` is unsupported on Darkmoon Island (map 407); the island relies on map pins only.
- **Merchant info has a dual API path.** Price/stack/availability read `C_MerchantFrame.GetItemInfo` when present, else fall back to `GetMerchantItemInfo` selects.
