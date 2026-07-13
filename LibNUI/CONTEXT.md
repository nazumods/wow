# LibNUI

**Deps:** LibNAddOn · **Commands:** `/nui version`, `/nui test [key]`, `/wdebug <lua>` · **Global:** `LibNUI` (= `ns.ui` in consuming addons) · **DB:** `LibNUIDB` (v1; `copyFontSize`)

OOP UI widget library. Every widget wraps a backing WoW object (`self._widget`) and is built via `Widget:new{ ...options }`. Widgets register themselves on `ui` (e.g. `ui.Frame`, `LibNUI.Frame`). Files live at the addon root; `settings/` holds the WoW Settings-panel controls.

## Files

| File | Purpose |
|---|---|
| `globals.lua` | Creates `LibNUI`/`ns.ui`; `MigrateDB` (seeds `LibNUIDB`); registers `/nui version` and `/nui test` (loads on-demand `LibNUI_Test`) |
| `constants.lua` | Enum tables: `ui.edge`, `ui.layer`, `ui.justify`, `ui.wrap`, `ui.fonts` |
| `Theme.lua` | `ui.themes.dark` (default styling tokens) + `ui.Theme(overrides)` factory for custom themes. **Runtime swaps:** `theme:Apply{colors/fonts/textures}` merges tokens **in place** (widgets built afterwards style themselves with the new values automatically — construction resolves from the same tables) and re-runs every repaint registered via `Region:Themed(fn)`. Custom themes fall back to dark via `__index`, so a dark-level Apply shows through custom themes that didn't override that token |
| `Region.lua` | `Region` — abstract base; anchoring/size/visibility/alpha + declarative `position` system |
| `Texture.lua` | `Texture` — wraps WoW Texture (atlas, color, coords, nine-slice, runtime `Gradient`, `Rotation`, `DrawLayer(layer, sublevel?)`) |
| `Label.lua` | `Label` — wraps FontString; `Text`, `Color`, `JustifyH`, `StringWidth`, `UnboundedWidth`. `tooltip` option (string\|string[]) overlays an invisible hit-rect frame (FontStrings can't take mouse) showing the lines via `ui.tip:Lines` + `AnchorBeside`. `DrawLayer(layer, sublevel?)` for sub-layer stacking |
| `Frame.lua` | `Frame` — core frame wrapper: events, dragging, per-frame `onUpdate`, `delay`; `SetScript`/`RemoveScript`, `EnableKeyboard`/`SetPropagateKeyboardInput` (receive keys + consume vs pass through — e.g. trap Esc) |
| `BgFrame.lua` | `BgFrame` — Frame with auto-created backdrop Texture; `backdropColor`/`backdropTexture` |
| `Dialog.lua` | `Dialog` — DIALOG-strata frame with Blizzard title bar, Escape-to-close; `makeTitlebarDraggable` |
| `StatusBar.lua` | `StatusBar` — fill bar with backdrop/texture/orientation; `Color`, `Texture`, `SetValue` |
| `Slider.lua` | `Slider` — value slider: themed track + draggable gold thumb, `min`/`max`/`step`/`orientation`, `OnChange(value, userInput)`; `Value` getter/setter, `MinMax`. Optional `label` (muted caption above the left end) + `valueFormat(v)→string` (live accent readout above the right end) — both float above the track, adding no layout height |
| `Model.lua` | `Model` — `ModelScene`-backed 3D viewer (borrows dressup scene 596 for camera + a skinnable player actor); `DisplayInfo(id, useCustomizations?)`/`Unit(token, customRaceID?, useNativeForm?)`/`TryOn`/`Undress`/`Dress`/`Outfit`/`Aggressiveness`/`Scale`/`Spin`. `Unit`'s `useNativeForm` (default true) toggles the unit's native vs altered form (Worgen human, Dracthyr visage) — only effective when the unit itself has one. `DisplayInfo` defaults customizations **off** (a baked display carries its own textures; on only matches the player's own race). One player-sized actor renders every model, so races at natural size are inconsistent: `Aggressiveness(n)` (0 = natural, **default**; 1 = forced to ~human-male) drives Blizzard's bounding-box normalization (`SetNormalizedScaleAggressiveness` + `SetRequestedScale`, `effectiveScale = requestedScale * 1/maxBoundingBoxScale` via `UpdateScale`); `Scale(n)` is the user multiplier on top (= `requestedScale`). **Left-drag = actor yaw (rotate, with release inertia), right-drag = camera pan, wheel = camera zoom.** Yaw lives on the actor (so re-skins keep the framing); pan/zoom live on the borrowed scene's `OrbitCamera` (`GetActiveCamera()`): leftX mode set to `NOTHING`, rightX/rightY = `PAN_HORIZONTAL`/`PAN_VERTICAL`, wheel = `ZOOM`, and min/max zoom widened from the scene's tight 6–10 to `minZoom`/`maxZoom` (2/16) so the wheel has travel. Our `OnUpdate`/`OnMouse*` `SetScript`s replace the template's, so they forward to the mixin (`w:OnMouseDown/Up/Wheel`, `w:OnUpdate(elapsed)`) to keep the camera stepping (pan + zoom are eased by the `OrbitCamera`'s own `DeltaLerp` interpolation, default amount `.15`); only `LeftButton` arms the actor-yaw drag. **Rotation inertia:** since the yaw is on the actor (not routed through the eased camera), the drag tracks a throw speed (`_yawVel`, rad/sec, `DeltaLerp`-smoothed by `spinTracking` so placing the model precisely doesn't fling it) and, on release, keeps rotating and glides to a stop via the same engine `DeltaLerp` decay (`spinFriction`, ~1s) down to a `SPIN_CUTOFF` snap; a fresh grab zeroes the velocity. `Spin(v)` reads/sets the live velocity for a programmatic showcase spin (or `Spin(0)` to halt). `ResetView()` restores the load defaults — yaw back to `facing` (zeroing any spin), the captured `_naturalZoom` distance, and pan offsets (`_cam.panningXOffset/panningYOffset`) to 0; the user `Scale` multiplier is left untouched. The dragged yaw and remembered `Outfit` (a sourceID list, empty = undressed) are re-applied via a `SetOnModelLoadedCallback` after each async model load (which would otherwise reset the actor to its baked default), so the angle and worn transmog never snap back. Scale (`_applyScale`) is instead **re-asserted every frame** in `OnUpdate` — a cold first load resets the actor scale *after* the load-callback/backstop fire, so polling is the only reliable way to keep the size correction (idempotent, corrects within a frame). Use `Outfit` rather than one-shot `TryOn`/`Undress` across a re-skin. A scene actor skins arbitrary races correctly where a bare `DressUpModel` renders them white |
| `RingSelector.lua` | `RingSelector` — OPie-style radial selector. Lays `items` (`{name, path/atlas, rotation?, title?}`) out as glyphs clockwise from the top; an `OnUpdate` reads `GetCursorPosition()` (scaled, vs the frame's `GetCenter`) and highlights the slice the cursor *aims toward* (`hiColor`, others `restColor`), showing its `title` in the center; inside `deadZone` nothing is aimed. `Selected()` → aimed name; `Commit()` fires `onSelect(name)` (called on key-release by a consumer, or on click in the test). Pure insecure UI, taint-free. Reuses the IconStrip glyph pattern; consumer feeds it the view metadata |
| `Button.lua` | `Button` — interactive button: glow, keybind label, item/spell/toy tooltip, `onClick`. `ConfirmFlash(text?, ms?)` — transient feedback: swaps the text (default "Done!") and restores after `ms` (1500); re-flashing keeps the first-captured original |
| `MinimapButton.lua` | `MinimapButton` — draggable minimap-edge button: shape-aware positioning (`GetMinimapShape`), drag-to-move with persisted angle, ADD-blend highlight, optional Blizzard ring/background, `ShowContextMenu`; `Shown`/`Angle`/`Icon`. (Addon-compartment entries stay declarative via the `.toc`, not here) |
| `SecureButton.lua` | `SecureButton` — `SecureActionButtonTemplate` for casting spells/toys in combat |
| `CheckButton.lua` | `CheckButton` — toggle checkbox; `Checked`, `OnToggle` |
| `RadioGroup.lua` | `RadioGroup` — vertical stack of mutually-exclusive `CheckButton` rows (single-select companion to CheckButton). `{ key, label }` options; picking one checks it and clears the rest (re-clicking the selected keeps it); `Select(key)` re-points without firing, `onSelect(self, key)` fires only on a *changed* user pick. Mirrors FilterDropdown's key/label + Select/onSelect contract |
| `AutoWidget.lua` | `AutoWidget` — standalone factory that builds a Button, Texture, or Label from options |
| `EditBox.lua` | `EditBox` — text input; `Text`, `CursorPosition`, `HighlightText`, `Font` (`{path,size[,flags]}` tuple getter/setter) |
| `ScrollFrame.lua` | `ScrollFrame` — scrollable container; `Child`, `VerticalScroll` (get/set offset, clamped to range — for scroll-into-view), `Refresh()` (recompute the scroll range via `UpdateScrollChildRect` after the child's content extent changed, then re-clamp the offset — call after the child grows/shrinks so it can't overscroll into empty space. **The range tracks the child's content extent (its shown sub-frames), NOT its set height** — so a caller that shrinks the scroll child must *hide* the frames it leaves below, e.g. `TableFrame:ResizeRows` hides rows+cells beyond the visible count; otherwise `UpdateScrollChildRect` still measures the old extent and the range stays full). Opt-in `scrollbar = true` swaps the Blizzard bar for a themed **auto-hiding** `Slider` scrollbar (gutter on the inner right edge, mousewheel-synced, hidden when content fits); only that path overrides the frame's wheel/range scripts, so default consumers are untouched |
| `Timer.lua` | `Timer` — live-updating time display (Frame + Label): ticks on the frame's OnUpdate, re-rendering only when the formatted string changes. Counts up from 0 or down from `duration` to 0 (fires `onFinish`); `format` = a `ns.lua.strings.duration` style (`"m:ss"`/`"h:mm:ss"`/`"auto"`) or a `fun(sec)->string`. `Start`/`Stop`/`Reset`, `Value` (get displayed secs / seed), `Color`. Auto-sizes to the text |
| `SectionHeader.lua` | `SectionHeader` — titled section separator: an accent heading + a 1px divider rule underneath, plus an optional right-aligned muted `summary` slot on the heading row. Sizes its own height from the heading; anchor it with a fixed width (Left+Right, or a Width) so the rule/summary have an edge. `Text`/`Summary` getters/setters. The single most-repeated panel-layout construct in the source addon |
| `VirtualList.lua` | `VirtualList` — pooled, variable-height, mixed-row-type list (the complement to TableFrame's fixed grid). Owns a themed-scrollbar `ScrollFrame` + content child; per-**type** row pools; `SetItems(items)` stacks one row per item via a `yCur` cursor (anchored to the child, no sibling chaining), reusing rows and hiding the surplus, then sizes the child + `Refresh`es the scroll range. Rows anchor left+right → reflow on resize. **Not windowed** (a frame per item). Single-type: `createRow`/`updateRow`; multi-type: `rowTypes` map + `typeOf(item)`. `Content()` is the parent for row builders. `emptyText` shows a muted centred placeholder when the item list is empty |
| `Accordion.lua` | `Accordion` — collapsible sections composed on a `VirtualList`: built-in clickable header rows (accent caret + title, hover highlight) whose child rows (consumer's `createRow`/`updateRow`) appear only while expanded. Header click → `Toggle(key)` rebuilds the flattened item list. `SetSections`, `Toggle`/`Expand`/`Collapse`/`IsExpanded`, `onToggle(self, key, expanded)`; expansion state keyed by `section.key` (survives `SetSections`) |
| `StatTile.lua` | `StatTile` — bordered "KPI" box: big centred value (default `GameFontHighlightLarge`) + small muted subtitle, 1px border whose colour expresses state; optional `tooltip` lines via `ui.tip`. `Value`/`Subtitle` getters/setters; `Colors{value,subtitle,border,fill}` one-call restyle. FilterDropdown's bordered idiom (border texture + fill inset 1px) |
| `LabeledValue.lua` | `LabeledValue` — one "label: value" stat field: optional icon + muted caption + accent value to its right. `Value` getter/setter for live updates |
| `IconListItem.lua` | `IconListItem` — media list row: icon (or `•` bullet when none) + title with optional muted `kind` suffix + wrapped subtitle; row hover shows `itemID`'s real item tooltip (GameTooltip) or custom `tooltip` lines (`ui.tip`). `Set(data)` re-points the whole row for pooled reuse (the VirtualList updateRow path). Anchor with a width so the subtitle wraps |
| `Badge.lua` | `Badge` — inline status pill: short coloured text on a subtle fill, auto-sized to the text (`_fit` on `Text` set); optional `tooltip` legend. For "[B]"-style markers beside a name |
| `TextLink.lua` | `TextLink` — text-only hyperlink: accent label, brightens to `text` colour on hover, `onClick`; auto-sizes to its text (`Text(v)` re-fits). For About-panel links / inline actions where a full Button is too heavy |
| `SortableHeaderRow.lua` | `SortableHeaderRow` — standalone clickable column-header strip for lists **not** built on TableFrame (e.g. above a VirtualList; TableFrame has its own opt-in sortable columns). `columns` = `{key,label,width,justifyH?,descFirst?}[]`; click selects a column (ascending, or `descFirst`), re-click flips; active column renders accent + arrow texture. `onSort(self,key,desc)` fires on user clicks; `Sort(key?,desc?)` gets/sets silently |
| `BarsPreview.lua` | `BarsPreview` — read-only action-bar layout preview: renders a captured profile as a **condensed map of its real on-screen topography** from the per-profile `barLayout` (via `ns.wow.ReadActionBars()`, which now carries each bar's screen `x`/`y`). **Normal bars** (a fixed screen home) are placed by coordinate-compressing their screen X→columns and Y→rows — empty space removed but left→right / top→bottom order and each bar's real H/V orientation preserved (falls back to a stacked column when a profile predates `barLayout`). **Stance/Sky pages** (they replace Bar 1, so have no fixed home) + the **pet** stay in a separate gold-outlined group below. Consumer-agnostic: icon/name **resolvers** (`resolveIcon/resolveName/resolvePetIcon/resolvePetName`), styling colours as options, optional `editLayoutFor(profile)` orientation fallback. Programmatic class-agnostic **stance detection** (a page is a stance bar only when it replaces Bar 1 via `barLayout.mainPage`, or is an inactive page); empty stance pages hidden. `Set(profile)`, `HighlightBar(bar, on)`. Shared by Warbandeer's Bars preview and ABM |
| `CleanFrame.lua` | `CleanFrame` — styled dark frame with tooltip border (base for windows); `BorderColor(c)` recolours the border at runtime (accent-bordered panels) |
| `Cell.lua` | `Cell` — table cell (Frame); renders as Label or Texture, reused across re-sorts via `update`. Label cell-data keys: `text`, `color`, `justifyH`, `font` (font-object name), `fontInfo` (`{path,size}` tuple, re-applied on reuse) |
| `TableCol.lua` | `TableCol` — column header (BgFrame); content surfaced as `header.label`/`header.texture`. `sortable` makes the header a clickable Button reporting to `onHeaderClick` (+ reserves room for an up/down arrow); `SetSortState(active, desc)` styles it (active = accent + arrow, inactive = muted) — driven by TableFrame's sort state |
| `TableRow.lua` | `TableRow` — row header strip (BgFrame). `Highlighted(b)` — active-row marker: lazy translucent overlay (`highlight` token) stacked at OVERLAY sublevel 1 above BgFrame's backdrop, with the header label lifted to sublevel 2 while active (BgFrame draws its backdrop over ARTWORK text) so the text stays legible on the gold; striping untouched |
| `TableFrame.lua` | `TableFrame` — full data grid (headers + cells); `set`, `addCol`/`addRow`, `update`, `setFooter`. `ResizeRows(n)` shows exactly `n` rows: sets the row-area height **and hides rows `n+1…` plus their cells** (cells parent to the row area, not the row), so a hosting `ScrollFrame`'s range — driven by the child's content extent — collapses to the visible rows instead of overscrolling into the blanked dead rows |
| `TitleFrame.lua` | `TitleFrame` — windowed CleanFrame with title bar, icon, close button; `Title`; `RememberPosition(store)` — opt-in drag-position persistence: restores the saved point from `store` and writes `{ point, relPoint, x, y }` back on drag-stop (hooks both drag paths — the body `OnDragStop` + the title bar's `OnMouseUp`), so a DB-backed `store` survives `/reload`/relog instead of re-centering |
| `CopyWindow.lua` | `CopyWindow` — reusable copyable scroll window (TitleFrame + ScrollFrame + multiline EditBox + titlebar font-size picker); `Display(title, text)`. Shared singleton via `ui.ShowCopyWindow(title, text)`; `ui.ToggleCopyWindow(title, text)` closes it if already open on the same title (caches `_title`), else shows — for slash commands that should toggle. **`DIALOG` strata** so it floats above the HIGH-strata Blizzard Settings panel (e.g. when opened from LibNAddOn's changelog viewer). Font size persists in `LibNUIDB.copyFontSize` |
| `Notification.lua` | `Notification` — movable, Escape-closable notification card (TitleFrame subclass): accent title strip + close X, optional `icon`, wrapped `body`, optional "don't show again" checkbox, and a dismiss button. `:Notify()` shows it (resets the checkbox, arms the optional `duration` auto-hide via `C_Timer.NewTimer`); the close X, dismiss button, and Escape share one `_dismiss` path (`onDismiss`). `special = true` by default → **pass a unique `name`**. `width`/`height` (360/170) are intrinsic options (survive a caller `position`). Ports EverythingDelves' reminder-toast pattern; subsumes a version-gated "what's new" popup |
| `TabFrame.lua` | `TabFrame` — tabbed container; `Select`, `Tab`, `Selected`. `autosize = true` sizes each tab to its label text (+`tabPadding`, 24) instead of the fixed `tabWidth` |
| `Tooltip.lua` | `Tooltip` — custom tooltip with line pooling + scrolling menus; singleton `ui.tip`. `Lines(title, ...)` one-call fill (clear + accent title + body lines, chainable); `AnchorBeside(frame, dx?, dy?)` side-flip anchor — prefers the frame's right, flips left when the tooltip's width would pass the screen edge (call after content is set; effective-scale-normalised) |
| `FilterDropdown.lua` | `FilterDropdown` — select control: labelled button (left-aligned text + right chevron Texture, flipped while open) that drops an **attached option panel** of `{ key, label, enabled? }` options (disabled = greyed/inert; the panel swallows their clicks). The panel hangs flush under the button's left edge, is never narrower than the button (`menuWidth` = minimum; widens to fit the longest option), and option labels share the button label's x-inset so text aligns exactly; on open the current selection renders gold (`header` token). Picking fires `onSelect(self, key)` and updates the button label. `Select(key)` re-points it without firing. `width`; `bordered` draws a framed background + 1px border (matches toggle buttons; the panel is always framed). Menu closes on **Esc** (captured + consumed, so a parent window stays open), on **any click outside** (`GLOBAL_MOUSE_DOWN`, registered only while open), and **when the dropdown/its view hides** (the panel parents to UIParent to escape clipping ancestors, so an `OnHide` hook takes it down); **at most one menu is open at a time** (module-level registry). Used for titlebar/strip filters (Collected expansion+category, Overview/Reputations/Crafting pickers) |
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
     ├─ RingSelector
     ├─ Button
     │   ├─ SecureButton
     │   └─ CheckButton
     ├─ RadioGroup
     ├─ MinimapButton
     ├─ EditBox
     ├─ ScrollFrame
     ├─ SectionHeader
     ├─ Timer
     ├─ VirtualList
     ├─ Accordion
     ├─ StatTile
     ├─ LabeledValue
     ├─ IconListItem
     ├─ Badge
     ├─ TextLink
     ├─ SortableHeaderRow
     ├─ BarsPreview
     ├─ Cell
     ├─ TabFrame
     ├─ FilterDropdown
     ├─ SettingsFrame
     ├─ TextSetting
     ├─ ToggleSetting
     └─ CleanFrame
         ├─ TitleFrame
         │   ├─ CopyWindow
         │   └─ Notification
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

- **Color tokens**: `window`, `border`, `titlebar`, `backdrop`, `tooltip`, `text`, `header`, `muted`, `icon`, `iconHover`, `closeHover`, `tabBar`, `tabActive`, `tabInactive`, `colEven`/`colOdd`, `rowEven`/`rowOdd`, `footer`, `divider`, `highlight`.
- **Font slots** (fontInfo `{path, size}` tuples; absent = Blizzard font objects as before): `title` (TitleFrame), `header` (table row/col headers), `body` (default Label font).
- **Texture slots**: `titleIcon`, `closeIcon` (TitleFrame).
- **Token strings as colors**: any color option (`background`, `color`, `activeColor`, cell `data.color`, …) and `Label:Color`/`Texture:Color`/`Texture:SetVertexColor` accept a token name string (e.g. `background = "window"`), resolved against the widget's active theme.
- `Region:Theme()` returns the active theme; `Region:ThemeColor(c)` resolves a token-or-table.
- Always build custom themes via `ui.Theme{}` (raw tables miss the dark fallback metatables).
- **Runtime swaps**: `theme:Apply{ colors = { header = {...} } }` merges tokens **in place** and re-runs repaints registered via `Region:Themed(fn)` (`fn(self, theme)` runs immediately + after every Apply — re-pull token styling there, e.g. `self.title:Color("header")`). Registration is **permanent**: register once at construction, never per refresh (pooled rows register when built). Widgets without a custom theme register on the shared dark theme — a `ui.themes.dark:Apply` repaints across every LibNUI-based addon; scope user-facing accent pickers to a custom theme instead.

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
| `IsMouseOver()` | Cursor within the region's hit rect |
| `Themed(fn)` | Register `fn(self, theme)` against the active theme: runs now + after every `theme:Apply` (see **Themes**) |

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
| `Label` | `parent`, `name`, `layer` (`Artwork`), `font` (`GameFontHighlight`), `fontObj`, `fontInfo`, `text`, `color`, `justifyH`, `justifyV`, `wordWrap`, `tooltip` (hover lines via hit-rect) |
| `Frame` | `type` (`"Frame"`), `name`, `parent`, `template`, `strata`, `clamped`, `scale`, `level`, `special`, `background`, `drag`, `dragTarget`, `scripts`, `events`, `unitEvents` |
| `BgFrame` | inherits Frame; default backdrop `{color={0,0,0,0.8}}` |
| `Dialog` | inherits Frame; `title`, `titleColor` |
| `StatusBar` | `backdrop`, `fill` (`{color,gradient,blend}`), `color`, `texture` (string or `{...,coords}`), `orientation`, `min`, `max` |
| `Slider` | inherits Frame (`type = "Slider"`); `min` (0), `max` (1), `step`, `value`, `orientation` (`"HORIZONTAL"`), `thickness` (4), `OnChange(value, userInput)`, `label` (caption), `valueFormat(v)→string` (live readout) |
| `Model` | inherits Frame (`type = "ModelScene"`, `template = "ModelSceneMixinTemplate"`); `rotateSpeed` (0.01 rad/px), `facing`, `minZoom`/`maxZoom` (2/16, camera zoom range), `spinFriction` (0.05, inertia decay), `spinTracking` (0.5, throw-speed follow) |
| `Button` | `normal` (`{texture,coords}`), `onClick`, `bindLeftClick`, `kbLabel`, `glow` (true), `itemID`, `tooltip`, `OnChange`, `OnClick` |
| `MinimapButton` | inherits Frame (`type="Button"`, parents to `Minimap`); `icon`, `iconFillsButton`, `db` (`{angle,hide}` store), `defaultAngle` (225), `radius` (8), `tooltip` (string[] or fn), `onClick(self, mouseButton)`. Methods: `Shown`, `Angle`, `Icon`, `ShowContextMenu(generator)`. Build it at/after `PLAYER_LOGIN` |
| `SecureButton` | `actions` — list of `{type, target, spell, toy}` |
| `CheckButton` | `text`, `OnToggle` |
| `RadioGroup` | inherits Frame; `options` (`{key,label}[]`), `selected` (initial key), `header` (optional heading), `spacing` (32), `width` (180), `onSelect(self, key)`. Methods: `Select(key)` (get/set, no fire) |
| `Timer` | inherits Frame; `format` (`ns.lua.strings.duration` style `"m:ss"`\|`"h:mm:ss"`\|`"auto"`, or a `fun(sec)->string`), `countdown` (false), `duration` (0), `autoStart` (false), `overtime` (false; countdown runs past 0 into negative + `overtimeColor` red), `color`, `onFinish(self)` (fires once at the 0 crossing). Methods: `Start`/`Stop`/`Reset`, `Value(sec?)` (get displayed secs / seed), `Color(...)` |
| `SectionHeader` | inherits Frame; `text`, `summary` (optional right-aligned), `titleColor` (`"header"`), `dividerColor` (`"header"`), `fontInfo`, `underline` (true), `gap` (5). Anchor with a fixed width. Methods: `Text`, `Summary` |
| `VirtualList` | inherits Frame; `spacing` (2), `padding` (4), `rowHeight` (20), `scrollbar` (true), `items`; single-type `createRow(list)→Frame` + `updateRow(list,row,item,i)→height?`, or multi-type `rowTypes` (`{name={create,update}}`) + `typeOf(item,i)→name` (default `item.type`). Methods: `SetItems(items)`, `Content()`, `Refresh()`, `EmptyText(text?)` (get/set the empty-state placeholder, updating the live label — for a list reused across contexts with a per-subject hint), `Row(index)` (live pooled row showing item `index`, for selectable lists), `ScrollToItem(index)` (minimal scroll-into-view) |
| `Accordion` | inherits Frame; `sections` (`{key,title,rows,expanded?}[]`), `spacing` (2), `padding` (4), `headerHeight` (24), `rowHeight` (20), `headerColor` (`"header"`), `scrollbar` (true), `createRow(acc)→Frame`, `updateRow(acc,row,rowData,section)→height?`, `onToggle(acc,key,expanded)`. Methods: `SetSections`, `Toggle`/`Expand`/`Collapse`/`IsExpanded(key)`, `Content()` |
| `StatTile` | inherits Frame; `value`, `subtitle`, `valueColor` (`"text"`), `subtitleColor` (`"muted"`), `borderColor` (`"divider"`), `fill` (`"backdrop"`), `valueFont` (`"GameFontHighlightLarge"`), `tooltip` (string\|string[]), `width`/`height` (64/40 — **intrinsic size options**, not position defaults, so a caller's `position` can't zero them). Methods: `Value`, `Subtitle`, `Colors{...}` |
| `LabeledValue` | inherits Frame; `label`, `value`, `icon`, `labelColor` (`"muted"`), `valueColor` (`"header"`), `iconSize` (16), `gap` (4), `height` (16, intrinsic). Methods: `Value` |
| `IconListItem` | inherits Frame; `icon` (nil → bullet), `title`, `kind`, `subtitle`, `titleColor` (`"text"`), `subtitleColor` (`"muted"`), `iconSize` (20), `height` (32, intrinsic), `itemID` (real item tooltip) / `tooltip` (custom lines). Methods: `Set(data)` (pooled-reuse re-point) |
| `Badge` | inherits Frame; `text`, `color` (`"header"`), `fill` (`"backdrop"`), `tooltip`; auto-sizes to text. Methods: `Text` (re-fits) |
| `TextLink` | inherits Frame (`type="Button"`); `text`, `color` (`"header"`), `hoverColor` (`"text"`), `onClick(self)`; auto-sizes. Methods: `Text` (re-fits) |
| `SortableHeaderRow` | inherits Frame; `columns` (`{key,label,width,justifyH?,descFirst?}[]`), `sortKey`/`sortDesc` (initial), `height` (20), `gap` (2), `onSort(self,key,desc)`. Methods: `Sort(key?,desc?)` (get/set, no fire) |
| `BarsPreview` | inherits Frame; slot resolvers `resolveIcon(slot,macroMap)→tex`, `resolveName(slot,macroMap)→str?`, `resolvePetIcon(slot)→tex`, `resolvePetName(slot)→str?`; `editLayoutFor(profile)→{[sys]=info}?` (optional orientation fallback); colours `rowColor` (`{1,1,1,0.05}`), `highlightColor` (`{0.9,0.8,0.5,0.15}`), `labelColor` (`"muted"`), `stanceColor` (`{1,0.82,0,0.35}`); `labelFontInfo` (`{path,size}`). Methods: `Set(profile)`, `HighlightBar(profileBar, on)` |
| `AutoWidget` | `parent`, `onClick`, `path`, `atlas`, `atlasSize`, `coords`, `vertexColor`, `position`, `label`, `font`, `color`, `justifyH` |
| `EditBox` | `fontObj`, `autoFocus`, `text`, `cursorPosition` |
| `CleanFrame` | `parent` (`UIParent`), `clamped` (true), `strata` (`MEDIUM`), `background` (`{0.114,0.141,0.165,1}`) |
| `TitleFrame` | inherits CleanFrame; `title`, `drag` (true) |
| `CopyWindow` | inherits TitleFrame; no options needed (defaults: centered, height 380, `special`). `Display(title, text)` shows + sizes + highlights; prefer the `ui.ShowCopyWindow` singleton |
| `Notification` | inherits TitleFrame; **`name` (required — `special`)**, `title`, `body`, `icon`, `dismiss` (`"Dismiss"`, false to omit), `dontShowAgain` (false), `dontShowText`, `duration` (auto-hide secs), `onDismiss(self)`, `onDontShowAgain(self, checked)`; defaults `strata="DIALOG"`, `Center` 360×170. Methods: `Notify()`, `Body(text)` |
| `TabFrame` | `tabs` (string[]), `tabHeight` (24), `tabWidth` (80), `autosize` (false; text-measured widths + `tabPadding` 24), `activeColor`, `inactiveColor`, `onSelect` |
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

Methods: `onLoad()`, `row(n)`, `col(n)`, `set(row, col, element)`, `addCol(info)`, `addRow(info)`, `update()`, `setFooter(data)`, `Sort(key?, desc?)`.

- `colInfo` fields: `name`, `width`, `atlas`, `atlasSize`, `padding`, `padLeft`, `justifyH`, `color`, `backdrop`, `autosize`, `tooltip` (string or string[], shown on header hover via `ui.tip`), `sortable`/`sortKey`/`descFirst` (see below).
- `rowInfo` fields: `name`, `height`, `atlas`, `atlasSize`, `justifyH`, `color`, `backdrop`.
- `setFooter(data)`: lazily builds a footer TableRow pinned below `rowArea`; `data` keyed by column index (columns absent render no footer cell). Re-callable to refresh.
- **Sortable columns (opt-in):** `colInfo[i].sortable = true` makes that `TableCol` header clickable (with `sortKey` = stable id defaulting to the column index, `descFirst` = descending-first for numeric columns). `onSort(self, key, desc)` fires on a user click; the frame owns the header UI + active-sort state (`_sortKey`/`_sortDesc`/`_sortCols`, `_clickSort` flip-on-reclick, `_refreshSortHeaders`), **the consumer owns the comparator + repaint** (sort your own data, call `update()`). `Sort(key?, desc?)` reads/sets the active sort without firing `onSort`. The active header renders accent + up/down arrow (via `TableCol:SetSortState`), others rest muted — same contract as `SortableHeaderRow`. TableFrame never permutes `self.data`, so index-parallel consumer state stays aligned.

## TitleFrame / TabFrame sub-fields

- **TitleFrame**: `self.titlebar` (Frame) → `.title` (Label), `.icon` (Frame with `.icon` Texture); `self.closeButton` (Frame with `.icon` Texture). `Title(text)` setter; `RememberPosition(store)` persists the dragged point into `store` (`{ point, relPoint, x, y }`, anchored to UIParent), restoring it immediately and re-saving on drag-stop.
- **TabFrame**: `self.tabBar`, `self.content`, `self._tabs` (button Frame[]), `self._panels` (Frame[]), `self._selected`.

## Tooltip

Methods: `ClearLines()`, `AddLine(text, r?, g?, b?, a?)`, `Lines(title, ...)`, `AnchorTo(frame, anchor, dx?, dy?)`, `AnchorBeside(frame, dx?, dy?)`, `ShowForCharacter(toon, position)`, `MaxWidth(w)` (pass `nil` to clear — deviates from the getter pattern since `nil` is a meaningful set value).

Singleton `ui.tip`. Helpers: `ui.ShowCharacterTooltip(toon, frame, position)`, `ui.HideCharacterTooltip()`.

## Gotchas

- **TableFrame `offsetX`/`offsetY` are baked in at construction** from whether `rowNames`/`colNames` are non-nil (`offsetX = rowNames ~= nil and headerWidth or 0`). For dynamic tables built with `addRow`/`addCol`, pass `rowNames = {}` / `colNames = {}` or row data overlaps the headers.
- **`Frame:onUpdate(elapsed)` receives milliseconds**, not seconds (Frame multiplies WoW's seconds by 1000). `Frame:delay(ms, fn)` likewise takes ms.
- **`special = true`** registers the frame in `_G` and `UISpecialFrames` (Escape closes it) — only for top-level windows. `Dialog` does this unconditionally.
- **`SecureButton`**: never call `SetAttribute` during combat (taint).
- **`Cell` is reused across re-sorts** — `Cell:Label()`/`update` re-applies `justifyH` every time, because a cell that previously held left-aligned data must reset when new data is right-aligned. When a `getData` returns a *shared* table, decorate a shallow copy before adding hover/click handlers, or wrappers chain across every row sharing the object.
- **Sortable TableFrame never permutes `self.data` itself** — it fires `onSort(self, key, desc)` and lets the consumer sort. This is deliberate: a consumer that holds **index-parallel state** (row → object maps, per-row closures capturing the row index) must re-sort its source array and rebuild those rows *together*, or clicks desync. Don't reach for a hypothetical "TableFrame sorts its own rows" mode when index-parallel state exists — use `onSort`.
- **`events` option** is a list of event names; the Frame's `OnEvent` dispatches to `self[eventName](self, ...)`.
- **Addon-local controls register on the addon's `ns`, never on `ui`/`LibNUI`** — only LibNUI's own widgets belong on the shared global; polluting it can clobber LibNUI symbols for every other addon.
