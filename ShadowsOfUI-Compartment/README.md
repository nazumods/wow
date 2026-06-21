# Addon Compartment

Makes Blizzard's built-in **addon compartment** button — the little counter at the
top of the minimap that lists every addon — movable, and swaps its number for a
clean icon.

## Features

- **Move it anywhere.** Hold **ALT** and left-drag the button to reposition it. A
  normal left-click still opens the addon menu, so there's nothing to lock or unlock.
  The position is remembered across reloads and sessions.
- **Custom icon.** The addon-count number is replaced with a cog icon so the button
  reads as a real minimap button instead of a bare "0". Toggle this off to go back to
  the count.

## Commands

| Command | Action |
|---|---|
| `/scompartment` | Open the settings panel |
| `/scompartment reset` | Move the button back to its default position |

## Settings

Found under **Options → AddOns → Shadows of UI → Addon Compartment**:

- **Use a custom icon (hides the addon count)** — on by default.

## Dependencies

- LibNAddOn
- LibNUI

## Saved Data

`ShadowsOfUI_CompartmentDB` (account-wide): the saved button position and the
custom-icon toggle.
