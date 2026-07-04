# Mouselook Toggle

Adds a keybind that toggles **mouselook** on and off: while active, the camera
follows your mouse movements without holding the right mouse button. Press the
key again, or right-click, to get your cursor back.

While the toggle is on, the (hidden) cursor is centered on screen at a
configurable height and a crosshair reticle marks it — that's exactly where
`@cursor` macros will land, action-combat style.

The reticle also fades in during ordinary **held** mouselook (right-click
camera dragging), after a short delay so quick camera flicks don't flash it.
There it marks the frozen cursor position `@cursor` macros target. This can be
turned off in settings.

## Setup

Bind a key under **Options → Gameplay → Keybindings → Shadows of UI → Toggle
mouselook**. The addon does nothing until you bind a key.

## Settings

Under **Options → AddOns → Shadows of UI → Mouselook Toggle**:

| Setting | Default | Effect |
|---|---|---|
| Reticle height (% of screen) | 50 | Screen height the cursor and reticle are centered at while the toggle is on (50 = dead center, higher = further up) |
| Show reticle during held mouselook | On | Also show the reticle while mouselooking via right-click hold |

## Saved data

`MouselookToggleDB` (account-wide): the two settings above.

## Dependencies

- LibNAddOn
