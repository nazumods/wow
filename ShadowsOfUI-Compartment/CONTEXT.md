# ShadowsOfUI-Compartment

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `ShadowsOfUI_CompartmentDB` (v1) · **UI:** LibNUI · **Settings:** subcategory under the shared "Shadows of UI" parent · **Slash:** `/scompartment`

Makes Blizzard's built-in `AddonCompartmentFrame` (the minimap addon-count button) movable via ALT+left-drag and replaces its count number with a custom icon.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Whole addon (assignment form). `MigrateDB` seeds `db.useIcon`. `onLoad` binds `frame = AddonCompartmentFrame`, captures `defaultPoint`, wires drag + icon, and hooks `UpdateDisplay`. File-locals: `applyPosition`/`resetPosition`/`savePosition`, `applyIcon`, `setupDrag`. Manual `SLASH_SUI_COMPARTMENT1 = "/scompartment"` (base opens settings, `reset` restores default position). |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |

## Gotchas

- **Drag is ALT-gated.** `OnDragStart` only `StartMoving()`s when `IsAltKeyDown()`, so a normal left-click still opens the DropdownButton's addon menu. `RegisterForDrag("LeftButton")` + `SetMovable`/`SetClampedToScreen`.
- **Position is stored scale-independently.** `savePosition` converts `GetLeft/GetTop` into UIParent units by `frame:GetEffectiveScale() / UIParent:GetEffectiveScale()`; `applyPosition` re-anchors `TOPLEFT → UIParent BOTTOMLEFT` and multiplies the saved offsets back by the **inverse** ratio (`UIParent / frame` effective scale) — because a `SetPoint` offset is measured in the button's own scale, not the anchor's. Both halves are needed: without the restore-side counter-conversion the button drifts by the minimap-cluster scale each drag+reload (the cluster scale is driven by the Edit-Mode minimap-size slider). `db.position == nil` means "leave Blizzard's anchor".
- **`UpdateDisplay` is hooked**, not just called once. Blizzard re-anchors/re-counts the button on `PLAYER_ENTERING_WORLD` and whenever the addon count changes; the `hooksecurefunc` reasserts our position + icon each time so they stick.
- **Icon replaces the count.** `applyIcon` shows an `OVERLAY` texture (sublevel 7, `SetTexCoord` trims the icon border) and `frame.Text:Hide()`s the number; toggling `useIcon` off hides the icon and re-shows `frame.Text`. Icon path is the file-local `ICON` constant (`inv_misc_gear_08`).
- **`defaultPoint`** is `{ frame:GetPoint() }` captured in `onLoad` before any move, so `reset` can `SetPoint(unpack(defaultPoint))` to restore Blizzard's exact anchor without naming `GameTimeFrame`.
- **No compartment func of its own** — this addon manipulates the shared frame; it does not register itself in the compartment.

## SavedVariables (`ShadowsOfUI_CompartmentDB`)

```lua
{
  useIcon  = true,            -- show the custom icon instead of the count
  position = { x = 0, y = 0 } -- UIParent-relative TOPLEFT offsets; absent = Blizzard default
}
```
`MigrateDB` only ensures `db.useIcon` exists; non-destructive.
