# Shadows of UI: QuestXP

Shows **what percentage of a level** a quest's XP reward is worth, right next to the XP reward
in the quest log.

Open your quest log (the world map) and select a quest that awards XP: next to the XP number in
the "You will receive" rewards section, you'll see a muted `(3%)` — how much of your current
level that reward is worth.

`/squestxp` prints the computed percentage for the currently selected quest — a testing/debug aid.

## Dependencies

- **LibNAddOn**

## Notes

- The percentage is relative to the XP needed for your **current** level, not how much XP you
  have left to level — so it stays a stable measure of a quest's "worth" no matter how much XP
  you've already banked this level.
- Nothing is shown for quests that award no XP (reputation/currency-only rewards) or once you've
  reached max level.
- Only the quest log's map-based Details pane is affected — the small always-on-screen quest
  tracker is untouched.
- There is no window and no saved data of its own.
