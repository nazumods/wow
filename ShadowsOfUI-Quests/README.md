# ShadowsOfUI-Quests

Tells you **which of your other characters are on — or have already completed — a quest**, so
you can see at a glance who still needs it.

Open your quest log (the world map) and hover a quest: the tooltip gains a cross-alt block —

- **Also on this quest:** the other characters currently questing on it, and
- **Completed by:** the characters that have already finished it.

Your own character is left off (you can see your own quest log), and the block only appears
when another character is actually on or has completed the quest.

`/squests <questID>` prints the same status to chat — a testing aid and a quick lookup.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — provides the per-character quest data this addon reads (active
  quests and completed-quest history, captured automatically each login).
- **Warbandeer** *(optional)* — not required; listed only for sensible load order.

## Notes

- Status is **last-seen**: a character's quests refresh while it's logged in, so a freshly
  installed setup fills in as you log each alt in once. (`/wbc missing` lists characters not
  yet captured.)
- Completed-quest history is the **largest** thing the suite stores per character (it tracks
  every quest you've ever finished, packed compactly) — expected for this feature, but worth
  knowing if you watch your SavedVariables size.
- There is no window and no saved data of its own — it reads Warbandeer_Characters' cache.
