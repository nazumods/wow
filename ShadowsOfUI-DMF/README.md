# ShadowsOfUI-DMF

A hands-off **Darkmoon Faire profession quest helper**. While the Faire is open it:

- **Auto-buys quest materials** when you talk to the Darkmoon Faire merchant — exactly
  the items needed for the profession turn-in quests your current character can do.
- **Guides you between quest givers** with map pins on the Faire island and a user
  waypoint in Elwynn Forest, printed to chat as you go.

Outside the Darkmoon Faire window the addon is completely dormant. There is no window,
no settings, and no saved data — it reads your quest log and profession list each
session.

`/sdmf` exists for addon development (prints NPC IDs and coordinates); you won't need
it.

## Client support

Retail only for now: the addon's TOC lists only Interface 120105, not WoW Forever's 16001.
WoW Forever's beta calendar (beta 1.60.1, build 70374), read in game on 2026-10-15, showed
no Darkmoon Faire for October or November 2026. It listed only Call to Arms: Warsong Gulch,
Stranglethorn Fishing Extravaganza, Call to Arms: Darkspear Islands, Call to Arms: Arathi
Basin and Hallow's End. To be re-checked at Forever's launch; launch-day work is tracked in
[nazumods/wow#966](https://github.com/nazumods/wow/issues/966).

## Changelog

A **Changelog** button in this addon's settings (Options → AddOns → Shadows of UI → Darkmoon Faire) opens its release history in a scrollable, copyable window.

## Dependencies

- **LibNAddOn**
