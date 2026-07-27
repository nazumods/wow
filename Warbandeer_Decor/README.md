# Warbandeer: Decor

A **housing decor collection tracker** for your warband. Housing decor is collected
**account-wide** — every character shares one storage and the same houses — so this is a
single filterable catalog of every decor the game knows about, showing at a glance what
you own, what you're still missing, and what you're chasing.

Open it as a standalone window with `/housingdecor`. If you also run the main
**Warbandeer** addon, the same list appears as a **Housing Decor** tab inside it.

## The list

One row per decor entry:

- a quality-bordered **icon** and quality-colored **name**
- how many you **own** (across storage and everything placed in your houses)
- a gold **star on the icon** when a decor still grants a one-time **House XP** bonus the
  first time you acquire it (and you don't own it yet)
- a **wanted star** on the right for anything you've flagged

Hover a row to see where it comes from (its **source** text), the owned breakdown (how many
in storage vs placed), and the first-acquisition bonus.

## Filtering

- **Category** — a dropdown of every decor category, each with its subcategories indented
  beneath it (or "All decor").
- **Unowned** — show only decor you don't own yet.
- **Wanted** (gold star) — show only the decor you've flagged. The header keeps a running
  `★` count you can click to toggle this filter.
- **Search** — filter by name.

## Wanted

**Shift-click** any row to flag (or unflag) that decor as wanted. Wanted decor show a gold
star, the header keeps a running `★` count, and `/housingdecor wanted` lists them all in chat.
Wanted flags are saved account-wide.

## Usage

| Command | What it does |
|---|---|
| `/housingdecor` or `/wbdecor` | Open/close the window |
| `/housingdecor scan` | Re-scan the housing catalog |
| `/housingdecor wanted` | List the decor you've flagged as wanted |

(`/decor` is intentionally left alone — a popular decor-vendor addon already uses it.)

The addon compartment button (next to the minimap) also works: click to open,
right-click to re-scan.

## Dependencies

- **LibNAddOn**
- **LibNUI**

There is **no** `Warbandeer_Characters` dependency — decor is account-wide, so there's no
per-character data to collect.

## Upgrading from "Warbandeer: Housing Decor"

This addon used to be called **Warbandeer_HousingDecor**. If you installed that version by
unzipping it yourself, the old folder is still there — a new install lands beside it rather
than replacing it, and running both at once means two copies fighting over the same saved
data and the same slash commands.

**Delete the old `Warbandeer_HousingDecor` folder** from your `Interface/AddOns` directory.
Your wanted flags are kept: both versions save to the same place, so nothing is lost. The
addon prints a reminder in chat at login for as long as the old folder is present.

## Saved data

`WarbandeerHousingDecorDB` (account-wide): your **wanted** flags (keyed by the catalog's
stable record id) and the last collected/total counts for a quick header. The decor list
itself is re-read live from the game's housing catalog every session — never stored — so it
can't fall out of sync. The window also remembers where you last dragged it.

## Requires housing

The tracker reads the live housing catalog (`C_HousingCatalog`). On a client or account
without housing available it simply shows nothing to collect.
