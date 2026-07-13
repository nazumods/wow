# HideStanceBar

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `HideStanceBarDB` (v1) · **UI:** LibNUI · **Settings:** subcategory under the shared "Shadows of UI" parent

Hides the Blizzard `StanceBar` per class by reparenting it onto a hidden frame. Toggled from an in-game settings panel.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Whole addon (assignment form). `MigrateDB` seeds `db.hide`; `onLoad` applies the saved state for the current class and builds the `SettingsFrame` with one toggle per supported class, nesting it under the shared "Shadows of UI" parent via `settings:RegisterSubcategory(ns:GetSettingsParent("Shadows of UI"), ns._TITLE)` (captured into `ns.settingsCategory` so a future changelog reuses this panel rather than duplicating it); file-local `update(classId, hide)` reparents `StanceBar` |

## Gotchas

- **Hiding = reparent, not just `:Hide()`.** `StanceBar` is moved onto a hidden `StanceHider` frame (created at file scope under `UIParent`); showing reparents it back to `UIParent`. Plain `:Hide()` would be reasserted by Blizzard's layout.
- **Edit Mode undoes the reparent** — applying a layout (login, layout switch, exiting the editor) re-anchors/reshows the managed `StanceBar`. `reapply()` re-hides on `EDIT_MODE_LAYOUTS_UPDATED` + a `hooksecurefunc` on `ExitEditMode`, skipping while `editModeActive` so the bar stays editable inside the editor (Exit clears the flag before hooks run).
- **Toggles are class-keyed by `classId`**, not class index — Warrior=1, Paladin=2, Rogue=4, Priest=5, Druid=11 (the stance-using classes). `update()` no-ops unless `classId == Player:GetClassId()`, so flipping another class's toggle only persists and takes effect on that class's characters.
- **Settings bind directly to `ns.db.hide`** via `AddToggleControl("…", ns.db.hide, classId)`; each control's `SettingChanged` calls `update()` for live apply.

## SavedVariables (`HideStanceBarDB`)

```lua
{ hide = { [classId] = true } }  -- absent/nil = visible
```
`MigrateDB` only ensures `db.hide` exists; non-destructive.
