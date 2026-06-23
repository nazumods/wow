# LibNUI

**Deps:** LibNAddOn · **Commands:** `/nui version`, `/nui test [key]`, `/wdebug <lua>` · **Global:** `LibNUI` (= `ns.ui` in consuming addons) · **DB:** `LibNUIDB` (v1; `copyFontSize`)

OOP UI widget library. Every widget wraps a backing WoW object (`self._widget`) and is built via `Widget:new{ ...options }`. Widgets register themselves on `ui` (e.g. `ui.Frame`, `LibNUI.Frame`). Files live at the addon root; `settings/` holds the WoW Settings-panel controls.

## Files

| File | Purpose |
|---|---|
| `globals.lua` | Creates `LibNUI`/`ns.ui`; `MigrateDB` (seeds `LibNUIDB`); registers `/nui version` and `/nui test` (loads on-demand `LibNUI_Test`) |
| `constants.lua` | Enum tables: `ui.edge`, `ui.layer`, `ui.justify`, `ui.wrap`, `ui.fonts` |
| `Theme.lua` | `ui.themes.dark` (default styling tokens) + `ui.Theme(overrides)` factory for custom themes |
| `Region.lua` | `Region` — abstract base; anchoring/size/visibility/alpha + declarative `position` system |
| `Texture.lua` | `Texture` — wraps WoW Texture (atlas, color, coords, nine-slice, runtime `Gradient`) |
| `Label.lua` | `Label` — wraps FontString; `Text`, `Color`, `JustifyH`, `StringWidth` |
| `Frame.lua` | `Frame` — core frame wrapper: events, dragging, per-frame `onUpdate`, `delay` |
| `BgFrame.lua` | `BgFrame` — Frame with auto-created backdrop Texture; `backdropColor`/`backdropTexture` |
| `Dialog.lua` | `Dialog` — DIALOG-strata frame with Blizzard title bar, Escape-to-close; `makeTitlebarDraggable` |
| `StatusBar.lua` | `StatusBar` — fill bar with backdrop/texture/orientation; `Color`, `Texture`, `SetValue` |
| `Slider.lua` | `Slider` — value slider: themed track + draggable gold thumb, `min`/`max`/`step`/`orientation`, `OnChange(value, userInput)`; `Value` getter/setter, `MinMax` |
| `Model.lua` | `Model` — `ModelScene`-backed 3D viewer (borrows dressup scene 596 for camera + a skinnable player actor); `DisplayInfo(id, useCustomizations?)`/`Unit(token, customRaceID?, useNativeForm?)`/`TryOn`/`Undress`/`Dress`/`Outfit`/`Aggressiveness`/`Scale`/`Spin`. `Unit`'s `useNativeForm` (default true) toggles the unit's native vs altered form (Worgen human, Dracthyr visage) — only effective when the unit itself has one. `DisplayInfo` defaults customizations **off** (a baked display carries its own textures; on only matches the player's own race). One player-sized actor renders every model, so races at natural size are inconsistent: `Aggressiveness(n)` (0 = natural, **default**; 1 = forced to ~human-male) drives Blizzard's bounding-box normalization (`SetNormalizedScaleAggressiveness` + `SetRequestedScale`, `effectiveScale = requestedScale * 1/maxBoundingBoxScale` via `UpdateScale`); `Scale(n)` is the user multiplier on top (= `requestedScale`). **Left-drag = actor yaw (rotate, with release inertia), right-drag = camera pan, wheel = camera zoom.** Yaw lives on the actor (so re-skins keep the framing); pan/zoom live on the borrowed scene's `OrbitCamera` (`GetActiveCamera()`): leftX mode set to `NOTHING`, rightX/rightY = `PAN_HORIZONTAL`/`PAN_VERTICAL`, wheel = `ZOOM`, and min/max zoom widened from the scene's tight 6–10 to `minZoom`/`maxZoom` (2/16) so the wheel has travel. Our `OnUpdate`/`OnMouse*` `SetScript`s replace the template's, so they forward to the mixin (`w:OnMouseDown/Up/Wheel`, `w:OnUpdate(elapsed)`) to keep the camera stepping (pan + zoom are eased by the `OrbitCamera`'s own `DeltaLerp` interpolation, default amount `.15`); only `LeftButton` arms the actor-yaw drag. **Rotation inertia:** since the yaw is on the actor (not routed through the eased camera), the drag tracks a throw speed (`_yawVel`, rad/sec, `DeltaLerp`-smoothed by `spinTracking` so placing the model precisely doesn't fling it) and, on release, keeps rotating and glides to a stop via the same engine `DeltaLerp` decay (`spinFriction`, ~1s) down to a `SPIN_CUTOFF` snap; a fresh grab zeroes the velocity. `Spin(v)` reads/sets the live velocity for a programmatic showcase spin (or `Spin(0)` to halt). `ResetView()` restores the load defaults — yaw back to `facing` (zeroing any spin), the captured `_naturalZoom` distance, and pan offsets (`_cam.panningXOffset/panningYOffset`) to 0; the user `Scale` multiplier is left untouched. The dragged yaw and remembered `Outfit` (a sourceID list, empty = undressed) are re-applied via a `SetOnModelLoadedCallback` after each async model load (which would otherwise reset the actor to its baked default), so the angle and worn transmog never snap back. Scale (`_applyScale`) is instead **re-asserted every frame** in `OnUpdate` — a cold first load resets the actor scale *after* the load-callback/backstop fire, so polling is the only reliable way to keep the size correction (idempotent, corrects within a frame). Use `Outfit` rather than one-shot `TryOn`/`Undress` across a re-skin. A scene actor skins arbitrary races correctly where a bare `DressUpModel` renders them white |
| `Button.lua` | `Button` — interactive button: glow, keybind label, item/spell/toy tooltip, `onClick` |
| `MinimapButton.lua` | `MinimapButton` — draggable minimap-edge button: shape-aware positioning (`GetMinimapShape`), drag-to-move with persisted angle, ADD-blend highlight, optional Blizzard ring/background, optional addon-compartment entry; `Shown`/`Angle`/`Icon` |
| `SecureButton.lua` | `SecureButton` — `SecureActionButtonTemplate` for casting spells/toys in combat |
| `CheckButton.lua` | `CheckButton` — toggle checkbox; `Checked`, `OnToggle` |
| `AutoWidget.lua` | `AutoWidget` — standalone factory that builds a Button, Texture, or Label from options |
| `EditBox.lua` | `EditBox` — text input; `Text`, `CursorPosition`, `HighlightText`, `Font` (`{path,size[,flags]}` tuple getter/setter) |
| `ScrollFrame.lua` | `ScrollFrame` — scrollable container; `Child`, `VerticalScroll` (get/set offset, clamped to range — for scroll-into-view) |
| `CleanFrame.lua` | `CleanFrame` — styled dark frame with tooltip border (base for windows) |
| `Cell.lua` | `Cell` — table cell (Frame); renders as Label or Texture, reused across re-sorts via `update`. Label cell-data keys: `text`, `color`, `justifyH`, `font` (font-object name), `fontInfo` (`{path,size}` tuple, re-applied on reuse) |
| `TableCol.lua` | `TableCol` — column header (BgFrame); content surfaced as `header.label`/`header.texture` |
| `TableRow.lua` | `TableRow` — row header strip (BgFrame) |
| `TableFrame.lua` | `TableFrame` — full data grid (headers + cells); `set`, `addCol`/`addRow`, `update`, `setFooter` |
| `TitleFrame.lua` | `TitleFrame` — windowed CleanFrame with title bar, icon, close button; `Title`; `RememberPosition(store)` — opt-in drag-position persistence: restores the saved point from `store` and writes `{ point, relPoint, x, y }` back on drag-stop (hooks both drag paths — the body `OnDragStop` + the title bar's `OnMouseUp`), so a DB-backed `store` survives `/reload`/relog instead of re-centering |
| `CopyWindow.lua` | `CopyWindow` — reusable copyable scroll window (TitleFrame + ScrollFrame + multiline EditBox + titlebar font-size picker); `Display(title, text)`. Shared singleton via `ui.ShowCopyWindow(title, text)`; `ui.ToggleCopyWindow(title, text)` closes it if already open on the same title (caches `_title`), else shows — for slash commands that should toggle. Font size persists in `LibNUIDB.copyFontSize` |
| `TabFrame.lua` | `TabFrame` — tabbed container; `Select`, `Tab`, `Selected` |
| `Tooltip.lua` | `Tooltip` — custom tooltip with line pooling + scrolling menus; singleton `ui.tip` |
| `settings/SettingsFrame.lua` | `SettingsFrame` — WoW Settings panel container; `AddControl`, `Register(Sub)category` |
| `settings/TextSetting.lua` | `TextSetting` — label + EditBox bound to `table[field]` |
| `settings/ToggleSetting.lua` | `ToggleSetting` — label + CheckButton bound to `table[field]` |
| `debug.lua` | `/wdebug <lua>` — eval arbitrary Lua (expression or statement) and show the dump/print output in `ui.ShowCopyWindow`. Registered as a raw slash (`SLASH_WDEBUG1`), not via the `/nui` dispatcher, so the whole arg string is the code |

## Class Hierarchy

```
Region
 ├─ Texture
 ├─ Label
 └─ Frame
     ├─ BgFrame
     │   ├─ TableCol
     │   └─ TableRow
     ├─ Dialog
     ├─ StatusBar
     ├─ Slider
     ├─ Model
     ├─ Button
     │   ├─ SecureButton
     │   └─ CheckButton
     ├─ MinimapButton
     ├─ EditBox
     ├─ ScrollFrame
     ├─ Cell
     ├─ TabFrame
     ├─ SettingsFrame
     ├─ TextSetting
     ├─ ToggleSetting
     └─ CleanFrame
         ├─ TitleFrame
         │   └─ CopyWindow
         └─ Tooltip
AutoWidget — standalone factory (no parent class)
```

## Constants

| Enum | Values |
|---|---|
| `ui.edge` | `Top`, `Center`, `TopLeft`, `TopRight`, `Bottom`, `BottomLeft`, `BottomRight`, `Left`, `Right` |
| `ui.layer` | `Background`, `Border`, `Artwork`, `Overlay`, `Highlight` |
| `ui.justify` | `Left`, `Center`, `Right`, `Top`, `Middle`, `Bottom` |
| `ui.media` | shared texture paths bundled in `LibNUI/media/` (full-path strings, reachable from any LibNUI-dependent addon): `unresolved` (red ⊗ marker for empty/not-applicable slots) |
| `ui.wrap` | `Clamp`, `Repeat`, `Mirror` |
| `ui.fonts` | `GameFontHighlight`, `GameFontHighlightSmall`, `SystemFont_Med2` |

## Themes

All built-in widget styling lives in `ui.themes.dark` as named tokens (`colors`, `fonts`, `textures`). Widgets resolve their styling defaults against the **active theme**: the `theme` constructor option, inherited from the parent widget chain, falling back to `ui.themes.dark`. Pass a theme once on a top-level window and every child widget created with `parent = <widget>` inherits it.

```lua
local myTheme = ui.Theme{               -- unlisted tokens fall back to dark
  colors = { window = {0.05, 0.05, 0.06, 1}, header = {1, 0.6, 0.4, 1} },
  fonts  = { title = {path, 16}, header = {path, 11}, body = {path, 13} },
}
local win = ui.TitleFrame:new{ title = "Mine", theme = myTheme }
```

- **Color tokens**: `window`, `border`, `titlebar`, `backdrop`, `tooltip`, `text`, `header`, `muted`, `icon`, `iconHover`, `closeHover`, `tabBar`, `tabActive`, `tabInactive`, `colEven`/`colOdd`, `rowEven`/`rowOdd`, `footer`, `divider`.
- **Font slots** (fontInfo `{path, size}` tuples; absent = Blizzard font objects as before): `title` (TitleFrame), `header` (table row/col headers), `body` (default Label font).
- **Texture slots**: `titleIcon`, `closeIcon` (TitleFrame).
- **Token strings as colors**: any color option (`background`, `color`, `activeColor`, cell `data.color`, …) and `Label:Color`/`Texture:Color`/`Texture:SetVertexColor` accept a token name string (e.g. `background = "window"`), resolved against the widget's active theme.
- `Region:Theme()` returns the active theme; `Region:ThemeColor(c)` resolves a token-or-table.
- Always build custom themes via `ui.Theme{}` (raw tables miss the dark fallback metatables).

## Region (base class)

Constructor resolves `theme` (own option → parent widget's theme), calls subclass `CreateWidget()`, then applies `position` and `alpha`.

| Method | Description |
|---|---|
| `Parent(p)` | Set parent (auto-unwraps `_widget`) |
| `Position(tbl)` | Apply declarative position table |
| `SetPoint(point, target?, edge?, x?, y?)` | Anchor (auto-unwraps target) |
| `All()` / `ClearAllPoints()` | `SetAllPoints` / clear |
| `Center/Top/TopLeft/TopRight/Bottom/BottomLeft/BottomRight/Left/Right(...)` | Shorthand anchors |
| `Size(x?, y?)` · `Width(w?)` · `Height(h?)` | Getter/setter |
| `Show()` · `Hide()` · `SetShown(b)` · `Toggle()` | Visibility |
| `Alpha(a?)` | Getter/setter |

### `position` table

```lua
position = {
    TopLeft = { parent, "BOTTOMLEFT", x, y },  -- table → unpacked as method args
    Width   = 200,                              -- scalar → single arg
    All     = true,                             -- true → no args
    Hide    = false,                            -- false → key skipped
}
```
Any key matching a method on the instance is valid; tables are unpacked, scalars passed directly, `false` skipped.

## Constructor options (per widget)

| Widget | Key options |
|---|---|
| `Texture` | `parent`, `name`, `layer`, `template`, `atlas`, `atlasSize`, `rotation`, `color`, `vertexColor`, `blendMode`, `gradient`, `path`, `coords` |
| `Label` | `parent`, `name`, `layer` (`Artwork`), `font` (`GameFontHighlight`), `fontObj`, `fontInfo`, `text`, `color`, `justifyH`, `justifyV`, `wordWrap` |
| `Frame` | `type` (`"Frame"`), `name`, `parent`, `template`, `strata`, `clamped`, `scale`, `level`, `special`, `background`, `drag`, `dragTarget`, `scripts`, `events`, `unitEvents` |
| `BgFrame` | inherits Frame; default backdrop `{color={0,0,0,0.8}}` |
| `Dialog` | inherits Frame; `title`, `titleColor` |
| `StatusBar` | `backdrop`, `fill` (`{color,gradient,blend}`), `color`, `texture` (string or `{...,coords}`), `orientation`, `min`, `max` |
| `Slider` | inherits Frame (`type = "Slider"`); `min` (0), `max` (1), `step`, `value`, `orientation` (`"HORIZONTAL"`), `thickness` (4), `OnChange(value, userInput)` |
| `Model` | inherits Frame (`type = "ModelScene"`, `template = "ModelSceneMixinTemplate"`); `rotateSpeed` (0.01 rad/px), `facing`, `minZoom`/`maxZoom` (2/16, camera zoom range), `spinFriction` (0.05, inertia decay), `spinTracking` (0.5, throw-speed follow) |
| `Button` | `normal` (`{texture,coords}`), `onClick`, `bindLeftClick`, `kbLabel`, `glow` (true), `itemID`, `tooltip`, `OnChange`, `OnClick` |
| `MinimapButton` | inherits Frame (`type="Button"`, parents to `Minimap`); `icon`, `iconFillsButton`, `db` (`{angle,hide}` store), `defaultAngle` (225), `radius` (8), `tooltip` (string[] or fn), `onClick(self, mouseButton)`, `compartment` (`{text, icon?, onClick}`). Methods: `Shown`, `Angle`, `Icon`. Build it at/after `PLAYER_LOGIN` |
| `SecureButton` | `actions` — list of `{type, target, spell, toy}` |
| `CheckButton` | `text`, `OnToggle` |
| `AutoWidget` | `parent`, `onClick`, `path`, `atlas`, `atlasSize`, `coords`, `vertexColor`, `position`, `label`, `font`, `color`, `justifyH` |
| `EditBox` | `fontObj`, `autoFocus`, `text`, `cursorPosition` |
| `CleanFrame` | `parent` (`UIParent`), `clamped` (true), `strata` (`MEDIUM`), `background` (`{0.114,0.141,0.165,1}`) |
| `TitleFrame` | inherits CleanFrame; `title`, `drag` (true) |
| `CopyWindow` | inherits TitleFrame; no options needed (defaults: centered, height 380, `special`). `Display(title, text)` shows + sizes + highlights; prefer the `ui.ShowCopyWindow` singleton |
| `TabFrame` | `tabs` (string[]), `tabHeight` (24), `tabWidth` (80), `activeColor`, `inactiveColor`, `onSelect` |
| `Tooltip` | inherits CleanFrame; `lines`, `maxHeight` (clips into scrollable viewport); `strata` (`DIALOG`), `background` (`{0,0,0,0.7}`), `inset` (3) |
| `SettingsFrame` | `heading` (`{text,fontObj,color}`), `headingText` |
| `TextSetting` / `ToggleSetting` | `label`, `table`, `field`, (`editor`), `SettingChanged` |

### `Button` tooltip / `AutoWidget` dispatch

```lua
tooltip = { _widget, owner, point, itemId, toyId, spellId, mountSpellId }
```
`AutoWidget`: `onClick` set → Button; `path`/`atlas` set → Texture; otherwise → Label.

## TableFrame

Constructor options: `colNames`, `rowNames`, `colInfo`, `rowInfo`, `numCols`, `numRows`, `cellWidth` (100), `cellHeight` (20), `headerWidth`, `headerHeight`, `headerFont`, `colHeaderFont`, `rowHeaderFont`, `padding` (2), `autosize`, `backdrop`, `colBackdrop`, `data`, `GetData`, `footerHeight`, `footerBackdrop`.

Sub-fields: `self.cols` (TableCol[]), `self.rows` (TableRow[]), `self.cells` (Cell[][]), `self.rowArea` (Frame), `self.footerRow` / `self.footerCells` (lazy).

Methods: `onLoad()`, `row(n)`, `col(n)`, `set(row, col, element)`, `addCol(info)`, `addRow(info)`, `update()`, `setFooter(data)`.

- `colInfo` fields: `name`, `width`, `atlas`, `atlasSize`, `padding`, `padLeft`, `justifyH`, `color`, `backdrop`, `autosize`, `tooltip` (string or string[], shown on header hover via `ui.tip`).
- `rowInfo` fields: `name`, `height`, `atlas`, `atlasSize`, `justifyH`, `color`, `backdrop`.
- `setFooter(data)`: lazily builds a footer TableRow pinned below `rowArea`; `data` keyed by column index (columns absent render no footer cell). Re-callable to refresh.

## TitleFrame / TabFrame sub-fields

- **TitleFrame**: `self.titlebar` (Frame) → `.title` (Label), `.icon` (Frame with `.icon` Texture); `self.closeButton` (Frame with `.icon` Texture). `Title(text)` setter; `RememberPosition(store)` persists the dragged point into `store` (`{ point, relPoint, x, y }`, anchored to UIParent), restoring it immediately and re-saving on drag-stop.
- **TabFrame**: `self.tabBar`, `self.content`, `self._tabs` (button Frame[]), `self._panels` (Frame[]), `self._selected`.

## Tooltip

Methods: `ClearLines()`, `AddLine(text, r?, g?, b?, a?)`, `AnchorTo(frame, anchor, dx?, dy?)`, `ShowForCharacter(toon, position)`, `MaxWidth(w)` (pass `nil` to clear — deviates from the getter pattern since `nil` is a meaningful set value).

Singleton `ui.tip`. Helpers: `ui.ShowCharacterTooltip(toon, frame, position)`, `ui.HideCharacterTooltip()`.

## Gotchas

- **TableFrame `offsetX`/`offsetY` are baked in at construction** from whether `rowNames`/`colNames` are non-nil (`offsetX = rowNames ~= nil and headerWidth or 0`). For dynamic tables built with `addRow`/`addCol`, pass `rowNames = {}` / `colNames = {}` or row data overlaps the headers.
- **`Frame:onUpdate(elapsed)` receives milliseconds**, not seconds (Frame multiplies WoW's seconds by 1000). `Frame:delay(ms, fn)` likewise takes ms.
- **`special = true`** registers the frame in `_G` and `UISpecialFrames` (Escape closes it) — only for top-level windows. `Dialog` does this unconditionally.
- **`SecureButton`**: never call `SetAttribute` during combat (taint).
- **`Cell` is reused across re-sorts** — `Cell:Label()`/`update` re-applies `justifyH` every time, because a cell that previously held left-aligned data must reset when new data is right-aligned. When a `getData` returns a *shared* table, decorate a shallow copy before adding hover/click handlers, or wrappers chain across every row sharing the object.
- **`events` option** is a list of event names; the Frame's `OnEvent` dispatches to `self[eventName](self, ...)`.
- **Addon-local controls register on the addon's `ns`, never on `ui`/`LibNUI`** — only LibNUI's own widgets belong on the shared global; polluting it can clobber LibNUI symbols for every other addon.
