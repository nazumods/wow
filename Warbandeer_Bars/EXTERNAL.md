[**Part of Nazuraki's WoW AddOn Suite**](https://github.com/nazumods/wow) — free & open source on GitHub.

![Warbandeer_Bars](https://raw.githubusercontent.com/nazumods/wow/main/Warbandeer_Bars/logo.png)

# Warbandeer: Bars

**A headless data layer — there's no window.** Warbandeer_Bars quietly captures every character's action bars, keybinds, macros, pet bar, and equipment-set outfits — one profile per character **and** spec — in the background, so you never have to remember to "save the layout" again.

It's the backbone that powers **Warbandeer**'s Bars view: preview any character/spec's setup and copy it onto the character you're playing, with per-bar toggles and macro re-creation so a cross-character import actually works. On its own it just collects and stores; install [Warbandeer](https://github.com/nazumods/wow/tree/main/Warbandeer) to browse and apply the profiles.

Profiles are captured at natural session boundaries (login, spec change, logout/reload) — never on a per-click basis — so it stays completely out of your way.

## Dependencies

- **LibNAddOn** — the only requirement (truly headless: no LibNUI, no other addon needed). Installs automatically.

## Developers

Warbandeer_Bars exposes a `WarbandeerBarsApi` for any addon to build on. See the [README on GitHub](https://github.com/nazumods/wow/tree/main/Warbandeer_Bars).

## Found a bug / Have a suggestion?

Warbandeer_Bars is developed in the open as part of **[Nazuraki's WoW AddOn Suite](https://github.com/nazumods/wow)**. Please report bugs and request features on the **[GitHub issue tracker](https://github.com/nazumods/wow/issues)**.
