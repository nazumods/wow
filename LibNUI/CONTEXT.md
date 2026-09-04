# LibNUI

**Deps:** LibNAddOn · **Commands:** `/nui version`, `/nui test [key]`, `/wdebug <lua>` · **Global:** `LibNUI` (= `ns.ui` in consuming addons) · **DB:** `LibNUIDB` (v1; `copyFontSize`)

OOP UI widget library. Every widget wraps a backing WoW object (`self._widget`) and is built via `Widget:new{ ...options }`. Widgets register themselves on `ui` (e.g. `ui.Frame`, `LibNUI.Frame`). Files live at the addon root; `settings/` holds the WoW Settings-panel controls.

## Files

| File | Purpose |
|---|---|
| `globals.lua` | Creates `LibNUI`/`ns.ui`; `MigrateDB` (seeds `LibNUIDB`); registers `/nui version` and `/nui test` (loads on-demand `LibNUI_Test`) |
| `constants.lua` | Enum tables: `ui.edge`, `ui.layer`, `ui.justify`, `ui.wrap`, `ui.fonts` |
| `Theme.lua` | `ui.themes.dark` (default styling tokens) + `ui.Theme(overrides)` factory for custom themes. **Runtime swaps:** `theme:Apply{colors/fonts/textures}` merges tokens **in place** (widgets built afterwards style themselves with the new values automatically — construction resolves from the same tables) and re-runs every repaint registered via `Region:Themed(fn)`. Custom themes fall back to dark via `__index`, so a dark-level Apply shows through custom themes that didn't override that token. **Font preload (#718):** `ui.Theme()` and a font-carrying `Apply` call `Theme:_preload()`, which parks one alpha-0 throwaway FontString per distinct TTF path on a session-lived holder frame. A FontString built while its file is still loading renders BLANK forever — text set, rect correct, `SetFont` successful, no glyph run — and only the first requester of each file survives, so the throwaway takes that hit at addon-load time instead of a real caption. Holder is alpha-0, not hidden: a region on a hidden frame is never laid out and so never builds the glyph run that makes the file resident |
| `Region.lua` | `Region` — abstract base; anchoring/size/visibility/alpha + declarative `position` system. Also the **hairline pixel snapping** (#782): `Pixels(units)` snaps a UI-unit length to the nearest whole number of physical pixels, floored at one, via `PixelUtil.GetNearestPixelSize(units, effectiveScale, 1)`, `PixelWidth`/`PixelHeight` set a dimension with it, `Inset(units)` anchors TopLeft/BottomRight inset by it (the framed-box rim). Snapped lengths are held in a weak-keyed table and re-derived on `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED`. **Sizes only** — a run of exactly N whole pixels covers N pixels wherever it starts, so offsets need no snapping |
| `Texture.lua` | `Texture` — wraps WoW Texture (atlas, color, coords, nine-slice, runtime `Gradient`, `Rotation`, `BlendMode`, `DrawLayer(layer, sublevel?)`) |
| `Label.lua` | `Label` — wraps FontString; `Text`, `Color`, `JustifyH`, `JustifyV`, `WordWrap`, `StringWidth`, `UnboundedWidth`. `tooltip` option (string\|string[]) overlays an invisible hit-rect frame (FontStrings can't take mouse) showing the lines via `ui.tip:Lines` + `AnchorBeside`. `DrawLayer(layer, sublevel?)` for sub-layer stacking |
| `Frame.lua` | `Frame` — core frame wrapper: events, dragging, per-frame `onUpdate`, `delay`; `SetScript`/`RemoveScript`, `EnableKeyboard`/`SetPropagateKeyboardInput` (receive keys + consume vs pass through — e.g. trap Esc; `SetPropagateKeyboardInput` no-ops in combat lockdown, taint-safe since 10.1.5) |
| `BgFrame.lua` | `BgFrame` — Frame with auto-created backdrop Texture; `backdropColor`/`backdropTexture` |
| `Dialog.lua` | `Dialog` — DIALOG-strata frame with Blizzard title bar, Escape-to-close; `makeTitlebarDraggable` |
| `StatusBar.lua` | `StatusBar` — fill bar with backdrop/texture/orientation; `Color`, `Texture`, `SetValue` |
| `Slider.lua` | `Slider` — value slider: themed track + draggable gold thumb, `min`/`max`/`step`/`orientation`, `OnChange(value, userInput)`; `Value` getter/setter, `MinMax`. Optional `label` (muted caption above the left end) + `valueFormat(v)→string` (live accent readout above the right end) — both float above the track, adding no layout height |
| `RingSelector.lua` | `RingSelector` — OPie-style radial selector. Lays `items` (`{name, path/atlas, rotation?, title?}`) out as glyphs clockwise from the top; an `OnUpdate` reads `GetCursorPosition()` (scaled, vs the frame's `GetCenter`) and highlights the slice the cursor *aims toward* (`hiColor`, others `restColor`), showing its `title` in the center; inside `deadZone` nothing is aimed. `Selected()` → aimed name; `Commit()` fires `onSelect(name)` (called on key-release by a consumer, or on click in the test). Pure insecure UI, taint-free. Reuses the IconStrip glyph pattern; consumer feeds it the view metadata |
| `Button.lua` | `Button` — interactive button: glow, keybind label, item/spell/toy tooltip, `onClick`. `ConfirmFlash(text?, ms?)` — transient feedback: swaps the text (default "Done!") and restores after `ms` (1500); re-flashing keeps the first-captured original |
| `MinimapButton.lua` | `MinimapButton` — draggable minimap-edge button: shape-aware positioning (`GetMinimapShape`), drag-to-move with persisted angle, ADD-blend highlight, optional Blizzard ring/background, `ShowContextMenu`; `Shown`/`Angle`/`Icon`. (Addon-compartment entries stay declarative via the `.toc`, not here) |
| `SecureButton.lua` | `SecureButton` — `SecureActionButtonTemplate` for casting spells/toys in combat |
| `CheckButton.lua` | `CheckButton` — toggle checkbox; `Checked`, `OnToggle` |
| `RadioGroup.lua` | `RadioGroup` — vertical stack of mutually-exclusive `CheckButton` rows (single-select companion to CheckButton). `{ key, label }` options; picking one checks it and clears the rest (re-clicking the selected keeps it); `Select(key)` re-points without firing, `onSelect(self, key)` fires only on a *changed* user pick. Mirrors FilterDropdown's key/label + Select/onSelect contract |
| `AutoWidget.lua` | `AutoWidget` — standalone factory that builds a Button, Texture, or Label from options |
| `EditBox.lua` | `EditBox` — text input; `Text`, `CursorPosition`, `HighlightText`, `Font` (`{path,size[,flags]}` tuple getter/setter), `Placeholder(text)`. **`placeholder`** shows a muted prompt while the box is empty (`placeholderColor`, `placeholderInset` `{left, right}`; parented to the EditBox itself, not any framing box, so it sits on exactly the edge the typed text lands on). Shown whenever empty, focused or not. Kept in step **without taking `OnTextChanged` from the caller**: the constructor wraps whatever handler was supplied, since the Frame dispatcher calls `self.OnTextChanged` — and `Text()` syncs it too, so a **programmatic** set is reflected as well as typing (the hand-rolled copies this replaces only updated from their own `OnTextChanged`, so setting text in code left the prompt drawn over it). A caller reaching past the class to `_widget:SetScript("OnTextChanged", …)` clobbers it, as it does every dispatched script |
| `ScrollFrame.lua` | `ScrollFrame` — scrollable container; `onScroll(self, offset)` option fires on every offset change (hooked on the widget's own `OnVerticalScroll`, so thumb/wheel/`EnsureVisible`/engine all reach it — a viewport-bound consumer can't miss one); `Child`, `VerticalScroll` (get/set offset, clamped to range — for scroll-into-view), `Refresh()` (recompute the scroll range via `UpdateScrollChildRect` after the child's content extent changed, then re-clamp the offset — call after the child grows/shrinks so it can't overscroll into empty space. **The range tracks the child's content extent (its shown sub-frames), NOT its set height** — so a caller that shrinks the scroll child must *hide* the frames it leaves below, e.g. `TableFrame:ResizeRows` hides rows+cells beyond the visible count; otherwise `UpdateScrollChildRect` still measures the old extent and the range stays full), `Scrolls()` (whether the content overflows the viewport — the single range truth `_syncScrollbar` reads, so a consumer reserving a scrollbar gutter can gate it on this and stay in lockstep with the bar's own show/hide), `EnsureVisible(top, height)` (scroll the **minimum** distance that brings a band into view, and none at all if it already is — `top` measured from the top of the scroll CHILD, the space a list already has for its rows at `(i-1) * rowHeight`. Minimum-distance rather than centring on purpose: arrowing down a list should nudge the view one row, not jump the target to mid-viewport each press. Clamping is `VerticalScroll`'s, so a band past the end settles at the bottom. Both Collected grids had a copy, and a consuming addon carried a third as a version-skew fallback). Opt-in `scrollbar = true` swaps the Blizzard bar for a themed **auto-hiding** `Slider` scrollbar (gutter on the inner right edge, mousewheel-synced, hidden when content fits); only that path overrides the frame's wheel/range scripts, so default consumers are untouched |
| `Timer.lua` | `Timer` — live-updating time display (Frame + Label): ticks on the frame's OnUpdate, re-rendering only when the formatted string changes. Counts up from 0 or down from `duration` to 0 (fires `onFinish`); `format` = a `ns.lua.strings.duration` style (`"m:ss"`/`"h:mm:ss"`/`"auto"`) or a `fun(sec)->string`. `Start`/`Stop`/`Reset`, `Value` (get displayed secs / seed), `Color`. Auto-sizes to the text |
| `SectionHeader.lua` | `SectionHeader` — titled section separator: an accent heading + a 1px divider rule underneath, plus an optional right-aligned muted `summary` slot on the heading row. Sizes its own height from the heading; anchor it with a fixed width (Left+Right, or a Width) so the rule/summary have an edge. `Text`/`Summary` getters/setters. The single most-repeated panel-layout construct in the source addon |
| `VirtualList.lua` | `VirtualList` — pooled, variable-height, mixed-row-type list (the complement to TableFrame's fixed grid). Owns a themed-scrollbar `ScrollFrame` + content child; per-**type** row pools; `SetItems(items)` stacks one row per item via a `yCur` cursor (anchored to the child, no sibling chaining), reusing rows and hiding the surplus, then sizes the child + `Refresh`es the scroll range. Rows anchor left+right → reflow on resize. **Not windowed** (a frame per item). Single-type: `createRow`/`updateRow`; multi-type: `rowTypes` map + `typeOf(item)`. `Content()` is the parent for row builders. `emptyText` shows a muted centred placeholder when the item list is empty |
| `Accordion.lua` | `Accordion` — collapsible sections composed on a `VirtualList`: built-in clickable header rows (accent caret + title, hover highlight) whose child rows (consumer's `createRow`/`updateRow`) appear only while expanded. Header click → `Toggle(key)` rebuilds the flattened item list. `SetSections`, `Toggle`/`Expand`/`Collapse`/`IsExpanded`, `onToggle(self, key, expanded)`; expansion state keyed by `section.key` (survives `SetSections`) |
| `StatTile.lua` | `StatTile` — bordered "KPI" box: big centred value (default `GameFontHighlightLarge`) + small muted subtitle, 1px border whose colour expresses state; optional `tooltip` lines via `ui.tip`. `Value`/`Subtitle` getters/setters; `Colors{value,subtitle,border,fill}` one-call restyle. FilterDropdown's bordered idiom (border texture + fill inset 1px) |
| `LabeledValue.lua` | `LabeledValue` — one "label: value" stat field: optional icon + muted caption + accent value to its right. `Value` getter/setter for live updates |
| `IconListItem.lua` | `IconListItem` — media list row: icon (or `•` bullet when none) + title with optional muted `kind` suffix + wrapped subtitle; row hover shows `itemID`'s real item tooltip (GameTooltip) or custom `tooltip` lines (`ui.tip`, opened on the `tooltipAnchor` side — a `"<tipCorner>/<rowCorner>"` key from the module-level `TIP_ANCHORS` map, default `"LL/UR"` up-right; a right-docked list passes e.g. `"LR/LL"` so the tip opens leftward instead of flying off-screen). `Set(data)` re-points the whole row for pooled reuse (the VirtualList updateRow path). Anchor with a width so the subtitle wraps |
| `Badge.lua` | `Badge` — inline status pill: short coloured text on a subtle fill, auto-sized to the text (`_fit` on `Text` set); optional `tooltip` legend. For "[B]"-style markers beside a name |
| `TextLink.lua` | `TextLink` — text-only hyperlink: accent label, brightens to `text` colour on hover, `onClick`; auto-sizes to its text (`Text(v)` re-fits). For About-panel links / inline actions where a full Button is too heavy |
| `SortableHeaderRow.lua` | `SortableHeaderRow` — standalone clickable column-header strip for lists **not** built on TableFrame (e.g. above a VirtualList; TableFrame has its own opt-in sortable columns). `columns` = `{key,label,width,justifyH?,descFirst?}[]`; click selects a column (ascending, or `descFirst`), re-click flips; active column renders accent + arrow texture. `onSort(self,key,desc)` fires on user clicks; `Sort(key?,desc?)` gets/sets silently |
| `BarsPreview.lua` | `BarsPreview` — read-only action-bar layout preview: renders a captured profile as a **condensed map of its real on-screen topography** from the per-profile `barLayout` (via `ns.wow.ReadActionBars()`, which now carries each bar's screen `x`/`y`). **Normal bars** (a fixed screen home) are placed by coordinate-compressing their screen X→columns and Y→rows — empty space removed but left→right / top→bottom order and each bar's real H/V orientation preserved (falls back to a stacked column when a profile predates `barLayout`). **Stance/Sky pages** (they replace Bar 1, so have no fixed home) + the **pet** stay in a separate gold-outlined group below. Consumer-agnostic: icon/name **resolvers** (`resolveIcon/resolveName/resolvePetIcon/resolvePetName`), styling colours as options, optional `editLayoutFor(profile)` orientation fallback. Programmatic class-agnostic **stance detection** (a page is a stance bar only when it replaces Bar 1 via `barLayout.mainPage`, or is an inactive page); empty stance pages hidden. `Set(profile)`, `HighlightBar(bar, on)`. Shared by Warbandeer's Bars preview and ABM |
| `BorderBox.lua` | `BorderBox` — thin rectangular outline (Frame): four edge Textures two-point-anchored to the frame's corners (stretch on resize), transparent interior. `thickness` (UI units snapped to whole pixels, default 1), `color` (token/rgba, default `border`); `Color(c)`/`Thickness(t)`. Edges size via `Region:PixelWidth`/`PixelHeight`, so a 1px border is a whole pixel and not the ~0.97 of one that made its left edge vanish (#782). Reusable outline primitive — used by `Cell`'s composite border (BarsPreview still hand-rolls the same 4-edge pattern in `_stanceOutline`, now snapped too — worth collapsing onto `BorderBox`) |
| `CleanFrame.lua` | `CleanFrame` — styled dark frame with tooltip border (base for windows); `BorderColor(c)` recolours the border at runtime (accent-bordered panels) |
| `Cell.lua` | `Cell` — table cell (Frame); renders as Label or Texture, reused across re-sorts via `update`. Label cell-data keys: `text`, `color`, `justifyH`, `font` (font-object name), `fontInfo` (`{path,size}` tuple, re-applied on reuse). **Composite mode**: cell-data with a `parts` array renders multiple positioned Texture/Label children (`{...opts, position}[]`) plus an optional `border` (`{color, thickness, position}`, a `BorderBox`). Anchor targets in a part/border `position` resolve symbolically — `"cell"` → the cell, integer `N` → part `N` (parts anchor earlier parts only); scalar keys (Size/Width) pass through. Reconciled in place across re-sorts (reuse-on-kind-match, transitions cleanly to/from plain/empty). Reuse re-applies every part field, resetting an omitted one to its neutral value (rotation 0, `BLEND`, full coords/vertexColor, Left/Middle justify, wrap on, `"text"` colour) so it can't inherit the previous occupant's — `fontInfo` is the deliberate exception. A part index in a `position` must be followed by an edge string; a bare `{x, y}` is an offset, not an index. Going composite empties **and** hides the single `.label`, so `Autosize` measures it as zero — still give the column a fixed `width` |
| `TableCol.lua` | `TableCol` — column header (BgFrame); content surfaced as `header.label`/`header.texture`. `sortable` makes the header a clickable Button reporting to `onHeaderClick` (+ reserves room for an up/down arrow); `SetSortState(active, desc)` styles it (active = accent + arrow, inactive = muted) — driven by TableFrame's sort state |
| `TableRow.lua` | `TableRow` — row header strip (BgFrame). `Highlighted(b)` — active-row marker: lazy translucent overlay (`highlight` token) stacked at OVERLAY sublevel 1 above BgFrame's backdrop, with the header label lifted to sublevel 2 while active (BgFrame draws its backdrop over ARTWORK text) so the text stays legible on the gold; striping untouched |
| `TableFrame.lua` | `TableFrame` — full data grid (headers + cells); `set`, `addCol`/`addRow`, `update`, `setFooter`. `ResizeRows(n)` shows exactly `n` rows: sets the row-area height **and hides rows `n+1…` plus their cells** (cells parent to the row area, not the row), so a hosting `ScrollFrame`'s range — driven by the child's content extent — collapses to the visible rows instead of overscrolling into the blanked dead rows |
| `TitleFrame.lua` | `TitleFrame` — windowed CleanFrame with title bar, icon, close button; `Title`; `RememberPosition(store)` — opt-in drag-position persistence: restores the saved point from `store` and writes `{ point, relPoint, x, y }` back on drag-stop (hooks both drag paths — the body `OnDragStop` + the title bar's `OnMouseUp`), so a DB-backed `store` survives `/reload`/relog instead of re-centering; **`SavePosition()`** is the write half on its own, public because a window can also be moved by a drag this class never sees — `Frame:setDragTarget` lets another frame's titlebar `StartMoving` this one, touching neither hooked script, so the owner of such a drag calls this when it ends (#764) |
| `CopyWindow.lua` | `CopyWindow` — reusable copyable scroll window (TitleFrame + ScrollFrame + multiline EditBox + titlebar font-size picker); `Display(title, text)`. Shared singleton via `ui.ShowCopyWindow(title, text)`; `ui.ToggleCopyWindow(title, text)` closes it if already open on the same title (caches `_title`), else shows — for slash commands that should toggle. **`DIALOG` strata** so it floats above the HIGH-strata Blizzard Settings panel (e.g. when opened from LibNAddOn's changelog viewer). Font size persists in `LibNUIDB.copyFontSize` |
| `Notification.lua` | `Notification` — movable, Escape-closable notification card (TitleFrame subclass): accent title strip + close X, optional `icon`, wrapped `body`, optional "don't show again" checkbox, and a dismiss button. `:Notify()` shows it (resets the checkbox, arms the optional `duration` auto-hide via `C_Timer.NewTimer`); the close X, dismiss button, and Escape share one `_dismiss` path (`onDismiss`). `special = true` by default → **pass a unique `name`**. `width`/`height` (360/170) are intrinsic options (survive a caller `position`). Ports EverythingDelves' reminder-toast pattern; subsumes a version-gated "what's new" popup |
| `TabFrame.lua` | `TabFrame` — tabbed container; `Select`, `Tab`, `Selected`. `autosize = true` sizes each tab to its label text (+`tabPadding`, 24) instead of the fixed `tabWidth` |
| `SegmentedToggle.lua` | `SegmentedToggle` — horizontal row of captioned segments in one framed box, at most one lit; `{ key, label }` options, `Select(key)` (no `onSelect`), `Selected()`, `onSelect(self, key)` on a click — fired on **every** click including the lit segment, since what a mode switch drives is normally idempotent. **`Select(nil)` lights none**, the state a switch shows when its subject belongs to neither mode (this is why it isn't a `RadioGroup`, which has no "none", and isn't a `TabFrame`, which owns the panels it switches). Segments take the widest caption's width + `padding` (24), so the frame's width is an outcome — read it back with `Width()` to lay out beside it. **The constructor's width is a FLOOR, not the answer:** `_layout()` measures via `UnboundedWidth`, which reports 0 until the font is resident and the frame has been laid out — untrue when the toggle is built inside a window still being assembled, which used to bake that zero in permanently (blank captions in a box collapsed to padding width). It now re-runs on first `OnShow` when the constructor measurement came back unmeasured, then fires **`onResize(self)`** so a host that positioned against the old width can re-place it (both Collected hosts do, via `_applyStripX`). The lit rim is a `BorderBox` (whole physical pixels, #782); `activeColor` defaults to the theme's `gold`, falling back to `header`. Hosts the Armor\|Weapons switch in both Collected windows (#816) |
| `Tooltip.lua` | `Tooltip` — custom tooltip with line pooling + scrolling menus; singleton `ui.tip`. `Lines(title, ...)` one-call fill (clear + accent title + body lines, chainable); `AnchorBeside(frame, dx?, dy?)` side-flip anchor — prefers the frame's right, flips left when the tooltip's width would pass the screen edge (call after content is set; effective-scale-normalised) |
| `FilterDropdown.lua` | `FilterDropdown` — select control: labelled button (left-aligned text + right chevron Texture, flipped while open) that drops an **attached option panel** of `{ key, label, enabled? }` options (disabled = greyed/inert; the panel swallows their clicks). The panel hangs flush under the button's left edge, is never narrower than the button (`menuWidth` = minimum; widens to fit the longest option), and option labels share the button label's x-inset so text aligns exactly; on open the current selection renders gold (`header` token). Picking fires `onSelect(self, key)` and updates the button label. `Select(key)` re-points it without firing; `SetOptions(options, selected?)` replaces the option list and re-lays the menu (the panel is built once at construction; `_buildMenu` builds the frame + scripts, `_layoutMenu` **pools** the option rows so a swap reuses frames and leaks none, re-parenting them across the flat↔scroll transition and hiding the surplus), selecting the given key if valid else the surviving key else the first — for a dropdown repointed at a subject with a different option set (e.g. the weapon look-builder re-scoping per class). `width`; `bordered` draws a framed background + 1px border (matches toggle buttons; the panel is always framed). A long list (taller than `maxMenuHeight`, default 400px — e.g. a full category taxonomy) caps the panel and **scrolls** it (wraps the rows in a themed `ScrollFrame`, re-opening at the top); shorter menus keep the flat, direct-child layout unchanged. Menu closes on **Esc** (captured + consumed, so a parent window stays open), on **any click outside** (`GLOBAL_MOUSE_DOWN`, registered only while open), and **when the dropdown/its view hides** (the panel parents to UIParent to escape clipping ancestors, so an `OnHide` hook takes it down); **at most one menu is open at a time** (module-level registry). Used for titlebar/strip filters (Collected expansion+category, Overview/Reputations/Crafting pickers) |
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
     ├─ BorderBox
     ├─ Cell
     ├─ TabFrame
     ├─ SegmentedToggle
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
| `All()` / `ClearAllPoints()` | `SetAllPoints(GetParent())` / clear — the target is passed **explicitly**, not left to `SetAllPoints()`'s implicit-parent form, and read from `GetParent()` rather than `self.parent` (which `Region:Parent` doesn't keep in sync). Same anchor, stated outright; see nazumods/wow#718, where `All = true` regions — and only those — drew nothing at first paint after a login |
| `Center/Top/TopLeft/TopRight/Bottom/BottomLeft/BottomRight/Left/Right(...)` | Shorthand anchors |
| `Size(x?, y?)` · `Width(w?)` · `Height(h?)` | Getter/setter |
| `Pixels(units)` | A UI-unit length snapped to the **nearest** whole number of physical pixels, floored at one (`minPixels = 1`), returned in UI units. Not a pixel count — `Pixels(1)` keeps a border's apparent weight at every resolution rather than thinning it on high-DPI |
| `PixelWidth(u)` · `PixelHeight(u)` | Set one dimension through `Pixels`. For anything thin enough to vanish: border edges, dividers, rules |
| `Inset(u)` | Anchor TopLeft/BottomRight to the parent inset by `Pixels(u)` — the framed-box idiom (a fill over a slightly larger rect, the difference showing as a rim), whose rim has the same exposure as a hairline texture |
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
| `Button` | `normal` (`{texture,coords}`), `onClick`, `bindLeftClick`, `kbLabel`, `glow` (true), `glowAlpha` (1 — softens the hover glow without removing it; `glow = false` remains the only way to suppress it outright, and a button with no glow reads as disabled), `itemID`, `tooltip`, `OnChange`, `OnClick` |
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
| `IconListItem` | inherits Frame; `icon` (nil → bullet), `title`, `kind`, `subtitle`, `titleColor` (`"text"`), `subtitleColor` (`"muted"`), `iconSize` (20), `height` (32, intrinsic), `itemID` (real item tooltip) / `tooltip` (custom lines), `tooltipAnchor` (which way `tooltip` opens; a `TIP_ANCHORS` corner-pair key, default `"LL/UR"`). Methods: `Set(data)` (pooled-reuse re-point) |
| `Badge` | inherits Frame; `text`, `color` (`"header"`), `fill` (`"backdrop"`), `tooltip`; auto-sizes to text. Methods: `Text` (re-fits) |
| `TextLink` | inherits Frame (`type="Button"`); `text`, `color` (`"header"`), `hoverColor` (`"text"`), `onClick(self)`; auto-sizes. Methods: `Text` (re-fits) |
| `SortableHeaderRow` | inherits Frame; `columns` (`{key,label,width,justifyH?,descFirst?}[]`), `sortKey`/`sortDesc` (initial), `height` (20), `gap` (2), `onSort(self,key,desc)`. Methods: `Sort(key?,desc?)` (get/set, no fire) |
| `BarsPreview` | inherits Frame; slot resolvers `resolveIcon(slot,macroMap)→tex`, `resolveName(slot,macroMap)→str?`, `resolvePetIcon(slot)→tex`, `resolvePetName(slot)→str?`; `editLayoutFor(profile)→{[sys]=info}?` (optional orientation fallback); colours `rowColor` (`{1,1,1,0.05}`), `highlightColor` (`{0.9,0.8,0.5,0.15}`), `labelColor` (`"muted"`), `stanceColor` (`{1,0.82,0,0.35}`); `labelFontInfo` (`{path,size}`). Methods: `Set(profile)`, `HighlightBar(profileBar, on)` |
| `AutoWidget` | `parent`, `onClick`, `path`, `atlas`, `atlasSize`, `coords`, `vertexColor`, `position`, `label`, `font`, `color`, `justifyH` |
| `EditBox` | `multiline`, `fontObj`, `autoFocus`, `text`, `cursorPosition`, `template` (`"InputBoxTemplate"`), `placeholder`, `placeholderColor` (`"muted"`), `placeholderInset` (`{6,-4}`). Methods: `Placeholder(text)` |
| `CleanFrame` | `parent` (`UIParent`), `clamped` (true), `strata` (`MEDIUM`), `background` (`{0.114,0.141,0.165,1}`) |
| `TitleFrame` | inherits CleanFrame; `title`, `drag` (true) |
| `CopyWindow` | inherits TitleFrame; no options needed (defaults: centered, height 380, `special`). `Display(title, text)` shows + sizes + highlights; prefer the `ui.ShowCopyWindow` singleton. `_relayout` widths to the wider of the body (`_maxLineWidth`) and the title (`titlebar.title:UnboundedWidth()` + `TITLE_CHROME_W`, the 33px title inset + picker + close button + gaps), clamped to `MIN_W`/`MAX_W`; `_createPicker` also right-anchors the inherited title label to the picker so a title past `MAX_W` ellipsizes instead of drawing over the controls (#657) |
| `Notification` | inherits TitleFrame; **`name` (required — `special`)**, `title`, `body`, `icon`, `dismiss` (`"Dismiss"`, false to omit), `dontShowAgain` (false), `dontShowText`, `duration` (auto-hide secs), `onDismiss(self)`, `onDontShowAgain(self, checked)`; defaults `strata="DIALOG"`, `Center` 360×170. Methods: `Notify()`, `Body(text)` |
| `TabFrame` | `tabs` (string[]), `tabHeight` (24), `tabWidth` (80), `autosize` (false; text-measured widths + `tabPadding` 24), `activeColor`, `inactiveColor`, `onSelect` |
| `SegmentedToggle` | `options` (`{key,label}[]`), `selected` (initial key; nil lights none), `height` (20), `padding` (24), `activeColor` (`"gold"` → `"header"`), `inactiveColor`, `fillColor`, `textColor` (`"text"`), `font` (defaults to the theme's `caps` slot at 10), `onSelect(self, key)`. Methods: `Select(key)`, `Selected()`. Width is computed, not passed |
| `Tooltip` | inherits CleanFrame; `lines`, `maxHeight` (clips into scrollable viewport); `strata` (`DIALOG`), `background` (`{0,0,0,0.7}`), `inset` (3) |
| `SettingsFrame` | `heading` (`{text,fontObj,color}`), `headingText` |
| `TextSetting` / `ToggleSetting` | `label`, `table`, `field`, (`editor`), `SettingChanged` |

### `Button` tooltip / `AutoWidget` dispatch

```lua
tooltip = { _widget, owner, point, itemId, toyId, spellId, mountSpellId }
```
`AutoWidget`: `onClick` set → Button; `path`/`atlas` set → Texture; otherwise → Label.

## TableFrame

Constructor options: `colNames`, `rowNames`, `colInfo`, `rowInfo`, `numCols`, `numRows`, `cellWidth` (100), `cellHeight` (20), `headerWidth`, `headerHeight`, `headerFont`, `colHeaderFont`, `rowHeaderFont`, `padding` (2), `rowHeaderGap` (8 — the autosized row-header-to-first-column gap, kept separate from `padding` so widening it doesn't also pad every column; falls back to `padding`), `autosize`, `backdrop`, `colBackdrop`, `data`, `GetData`, `footerHeight`, `footerBackdrop`, `detachedFooter`, `virtual` (false), `overscan` (3), `onRebind`.

**Viewport virtualisation (`virtual = true`, #843).** A static table builds a cell frame per (row, column) of `data` regardless of what fits on screen — 473 rows in a 23-row viewport meant 6,622 cells to show ~5%, and the frame count drove creation, the engine's layout pass *and* `UpdateScrollChildRect`'s content walk. Virtual mode keeps `ceil(viewportH / cellHeight) + 2 * overscan` row frames and re-binds them to a sliding window of `data` on scroll (`_rebind`, early-outs unless the window moved; one re-anchor + one `Cell:update` per resident cell, no frame creation). The row area still spans **every** data row, so the scroll range and a consumer's offset maths are unchanged — but the **table frame itself takes the viewport's height, not the dataset's**: it isn't scrolled, and the column frames anchor their `Bottom` to it, so sizing it to the data stretches every column backdrop thousands of pixels past the viewport and paints them down the screen as vertical bands. Wire it with `grid:BindViewport(scroll)` **before** the data lands (the resident count comes from the viewport's height); it chains onto any existing `ScrollFrame.onScroll` rather than replacing it. `update()` and `ResizeRows` both branch — `ResizeRows` is a no-op, since a resident row index is a viewport slot rather than a data row. **`onRebind(self, first, last)` fires after each real bind** (#843 marks fix): `_rebind` refreshes each cell's own content via `Cell:update`, but an overlay a consumer draws ON TOP of a cell keyed by that cell's row — Collected's wanted-★ and rank-pip are the case — isn't cell data, so after the window slides it sits on the wrong row; `onRebind` is the signal to re-derive those from the now-resident cells. `first`/`last` are the DATA indices resident (slot `k` holds row `first + k - 1`, `last` clamped to `#data` since the final window can be shorter than the pool) so an overlay keyed by row POSITION needn't infer the window from cell content or read the private `_top`. Fires only when the window actually moved (after the early-out), so it's as cheap to handle as `_rebind` is to run — but it DOES fire on the initial bind from `update()`, so one registration covers build and scroll alike. A static table never fires it: a consumer supporting both modes applies overlays in `update()` and re-applies in `onRebind`, which the initial fire makes idempotent rather than doubled. **`RefreshViewport()` re-sizes the pool to the viewport's current height and re-binds** — required because the resident count is derived from the viewport at `update()` time, while a host that refits its scroll height from the row count (Collected's `_fitToGrid`, every filter change) changes it *after*: filter down to a few rows and back and the pool is still sized for the small viewport, leaving empty space below the data that the table can't detect. Idempotent, and a no-op when static. **Constraints:** uniform row height only (the map is `floor(offset / cellHeight)`); `Autosize` measures only resident rows, so a column sized from cell text would resize while scrolling — size it from the data or fix its width; **no row headers and no footer, both now ENFORCED with `error`** rather than left to mis-render (populated `rowNames` raises at construction — empty `{}` stays legal as the dynamic-table idiom; `setFooter` raises on a virtual table). Those two fail silently *and misleadingly* otherwise — headers would follow the viewport and name the wrong rows, reading as a data bug, and a footer anchored to the dataset's bottom simply looks missing. Exercised by `/nui test tablevirtual`, which builds 500×12 both ways, reports time + frame count, and stamps a data-keyed overlay on every fifth row to prove `onRebind` re-derives it (reporting a slot↔index mismatch in the readout rather than asserting, since it runs on the scroll path).

Sub-fields: `self.cols` (TableCol[]), `self.rows` (TableRow[]), `self.cells` (Cell[][]), `self.rowArea` (Frame), `self.footerRow` / `self.footerCells` (lazy).

Methods: `onLoad()`, `row(n)`, `col(n)`, `set(row, col, element)`, `addCol(info)`, `addRow(info)`, `update()`, `setFooter(data)`, `detachedFooterPosition(colN, justifyH)`, `Sort(key?, desc?)`.

- `colInfo` fields: `name`, `width`, `atlas`, `atlasSize`, `padding`, `padLeft`, `justifyH`, `color`, `backdrop`, `autosize`, `tooltip` (string or string[], shown on header hover via `ui.tip`), `sortable`/`sortKey`/`descFirst` (see below).
- `rowInfo` fields: `name`, `height`, `atlas`, `atlasSize`, `justifyH`, `color`, `backdrop`.
- `setFooter(data)`: lazily builds a footer TableRow pinned below `rowArea`; `data` keyed by column index (columns absent render no footer cell). Re-callable to refresh. Default footer cells span their column (via `cellPosition`), so a column can't shrink below its aggregate total. Opt into **`detachedFooter = true`** to decouple: each footer cell is sized to its own content and anchored to its column's bottom by the single edge matching its `justifyH` (right→`BottomRight`, left→`BottomLeft`, center→`Bottom`) via `detachedFooterPosition`, so a data column can `autosize` below its (wider) total while the total overflows into the empty footer space beside it. The column bottom coincides with the footer band (columns span to the table bottom), so the edge anchor lands the cell in the footer row while tracking its column horizontally. Fixed-width columns render identically in both modes. Consumed by Warbandeer's `ClassSummary`.
- **Sortable columns (opt-in):** `colInfo[i].sortable = true` makes that `TableCol` header clickable (with `sortKey` = stable id defaulting to the column index, `descFirst` = descending-first for numeric columns). `onSort(self, key, desc)` fires on a user click; the frame owns the header UI + active-sort state (`_sortKey`/`_sortDesc`/`_sortCols`, `_clickSort` flip-on-reclick, `_refreshSortHeaders`), **the consumer owns the comparator + repaint** (sort your own data, call `update()`). `Sort(key?, desc?)` reads/sets the active sort without firing `onSort`. The active header renders accent + up/down arrow (via `TableCol:SetSortState`), others rest muted — same contract as `SortableHeaderRow`. TableFrame never permutes `self.data`, so index-parallel consumer state stays aligned.

## TitleFrame / TabFrame sub-fields

- **TitleFrame**: `self.titlebar` (Frame) → `.title` (Label, inset 33px from the left, `wordWrap = false` so a width-bounded title ellipsizes rather than wrapping out of the 30px bar), `.icon` (Frame with `.icon` Texture); `self.closeButton` (Frame with `.icon` Texture). `Title(text)` setter; `RememberPosition(store)` persists the dragged point into `store` (`{ point, relPoint, x, y }`, anchored to UIParent), restoring it immediately and re-saving on drag-stop; `SavePosition()` performs that write on demand for drags routed through `setDragTarget`, which bypass both hooks.
- **TabFrame**: `self.tabBar`, `self.content`, `self._tabs` (button Frame[]), `self._panels` (Frame[]), `self._selected`.

## Tooltip

Methods: `ClearLines()`, `AddLine(text, r?, g?, b?, a?)`, `Lines(title, ...)`, `AnchorTo(frame, anchor, dx?, dy?)`, `AnchorBeside(frame, dx?, dy?)`, `ShowForCharacter(toon, position)`, `MaxWidth(w)` (pass `nil` to clear — deviates from the getter pattern since `nil` is a meaningful set value).

Singleton `ui.tip`. Helpers: `ui.ShowCharacterTooltip(toon, frame, position)`, `ui.HideCharacterTooltip()`.

## Gotchas

- **TableFrame `offsetX`/`offsetY` are baked in at construction** from whether `rowNames`/`colNames` are non-nil (`offsetX = rowNames ~= nil and headerWidth or 0`). For dynamic tables built with `addRow`/`addCol`, pass `rowNames = {}` / `colNames = {}` or row data overlaps the headers.
- **`Region:Position` ACCUMULATES anchors — it never clears.** It just dispatches each key to the matching `Region` method (`TopLeft` → `SetPoint`), and `SetPoint` is additive. So a *second* `Position` call re-anchoring with a **different** point leaves the previous anchor in force and the widget lands where neither call asked; re-anchoring with the **same** point replaces that anchor, which is why the bug hides until someone switches `TopLeft` → `Left`. Call `ClearAllPoints()` before re-positioning (`FilterDropdown:_row` does this for its pooled rows). Only affects re-positioning — the constructor's `position` runs once on a fresh widget.
- **`Frame:onUpdate(elapsed)` receives milliseconds**, not seconds (Frame multiplies WoW's seconds by 1000). `Frame:delay(ms, fn)` likewise takes ms.
- **`special = true`** registers the frame in `_G` and `UISpecialFrames` (Escape closes it) — only for top-level windows. `Dialog` does this unconditionally.
- **`SecureButton`**: never call `SetAttribute` during combat (taint).
- **`Cell` is reused across re-sorts** — `Cell:Label()`/`update` re-applies `justifyH` every time, because a cell that previously held left-aligned data must reset when new data is right-aligned. When a `getData` returns a *shared* table, decorate a shallow copy before adding hover/click handlers, or wrappers chain across every row sharing the object.
- **Sortable TableFrame never permutes `self.data` itself** — it fires `onSort(self, key, desc)` and lets the consumer sort. This is deliberate: a consumer that holds **index-parallel state** (row → object maps, per-row closures capturing the row index) must re-sort its source array and rebuild those rows *together*, or clicks desync. Don't reach for a hypothetical "TableFrame sorts its own rows" mode when index-parallel state exists — use `onSort`.
- **`events` option** is a list of event names; the Frame's `OnEvent` dispatches to `self[eventName](self, ...)`.
- **Addon-local controls register on the addon's `ns`, never on `ui`/`LibNUI`** — only LibNUI's own widgets belong on the shared global; polluting it can clobber LibNUI symbols for every other addon.
- **A 1-unit line is NOT one pixel** (#782). `physicalPixelsPerUnit = effectiveScale / (768 / physicalScreenHeight)` — 1 at exactly one `uiScale` per resolution (`768 / height`) and a fraction either side, so a `Width(1)` edge is a coin toss on hardware we don't control. Just under 1 the phase drifts only ~0.03px per unit, so the misses land on a **fixed stripe every ~34 units** and every widget on one loses the same edge every time (which is why it reads as a broken widget, not as rounding); well under 1 — a small window, or `uiScale` at its 0.64 floor — a third of all positions drop. Size hairlines with `PixelWidth`/`PixelHeight`/`Inset`, never raw `Width`/`Height`. Sizes are enough; offsets need no snapping of their own. `thickness = 2` was never *invisible* but did render 1px at ~6% of positions, so snapping firms it up rather than changing it. **Verification: a clean pass at one resolution proves nothing about another**, and at a pixel-perfect `uiScale` even unsnapped code looks right — `/nui test hairlines` prints the pixels-per-unit it is running at, so check it somewhere that figure is not 1.000.
