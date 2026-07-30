-- Test harness: loads Warbandeer_Collected's WoW-API-free modules into a fresh ns with a
-- minimal stub of the inventory-slot globals, so the /customset codec can be unit-tested
-- without the game client. Mirrors Warbandeer_Decor's spec/loader.lua. Paths are relative
-- to the AddOns root (busted's cwd).
--
-- Three files qualify outright: outfitcodec.lua, outfitlibrary.lua (the library is pure Lua over
-- `ns.db` plus the codec) and outfitfilter.lua (the filter rule over the library's entries).
-- `ItemUtil` is deliberately left unstubbed so the codec exercises its
-- plain-table fallback (see ns.NewTransmogInfo). data/hidevisuals.lua is the one exception, loaded
-- separately over a caller-supplied API stub — see M.loadHideVisuals. Everything else in the addon
-- touches C_* or frames and stays in-game-tested.
local M = {}

-- The engine's equipment-slot constants. Real values, so a decoded list indexes the same way
-- it does in game and a wrong constant here would surface as a failing round-trip.
local SLOTS = {
  INVSLOT_HEAD = 1, INVSLOT_SHOULDER = 3, INVSLOT_BODY = 4, INVSLOT_CHEST = 5,
  INVSLOT_WAIST = 6, INVSLOT_LEGS = 7, INVSLOT_FEET = 8, INVSLOT_WRIST = 9,
  INVSLOT_HAND = 10, INVSLOT_BACK = 15, INVSLOT_MAINHAND = 16, INVSLOT_OFFHAND = 17,
  INVSLOT_TABARD = 19, INVSLOT_LAST_EQUIPPED = 19,
}

local ADDON = "Warbandeer_Collected"

---Load one of the addon's files into `ns`, handed the same two varargs WoW gives it: the addon name
---and the namespace table. Paths are relative to the addon folder (busted runs from the AddOns
---root) — the path is the only thing that ever varied across the loaders below.
---@param ns table
---@param file string  path under the addon folder, e.g. "data/arsenals.lua"
local function loadInto(ns, file)
  assert(loadfile(ADDON .. "/" .. file))(ADDON, ns)
end

---A look with one head appearance, the fixture most of these specs build on: the codec, the library
---and the filters all need a list that is non-empty and identifiable, and nothing more.
---
---Shared here because three spec files carried byte-identical copies of it.
---@param ns table  as returned by M.load()
---@param head number  the head slot's appearanceID
---@return table list
function M.lookWith(ns, head)
  local list = ns.EmptyOutfitList()
  list[INVSLOT_HEAD].appearanceID = head
  return list
end

---Load the WoW-API-free outfit files into a fresh ns and return it. `ns.db` is seeded empty so the
---library has a store to write into, exactly as LibNAddOn's MigrateDB would leave it in game.
---@return table ns
function M.load()
  for name, value in pairs(SLOTS) do _G[name] = value end
  local ns = { db = { outfits = {} } }
  loadInto(ns, "outfitcodec.lua")
  loadInto(ns, "outfitlibrary.lua")
  loadInto(ns, "outfitfilter.lua")
  -- Qualifies for the same reason the two above do: it calls only other `ns` functions, never a C_
  -- API or a frame. Its two savers (`ns.SaveLibraryOutfit`, `ns.SaveCustomSet`) are resolved at call
  -- time, so loading it needs neither of them present — a spec stubs whichever it wants to observe.
  loadInto(ns, "outfitsave.lua")
  return ns
end

---Load outfitverbs.lua into an already-loaded `ns`. Needs no stub at all: it resolves
---`ns.CustomSets` / `ns.SaveCustomSet` at CALL time rather than capturing them, so a spec installs
---whichever it wants to observe — the same arrangement that makes `outfitsave.lua` testable.
---
---It earns a spec more than most: these are the write paths for an account-wide, user-authored
---store with no undo, and the rule decides whether a push REPLACES an existing character set.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadOutfitVerbs(ns)
  loadInto(ns, "outfitverbs.lua")
  return ns
end

---Load GridShared.lua into an already-loaded `ns`, over a stub of the `ns.ui` widgets it
---destructures at load time.
---
---Only the widget NAMES have to exist: the file takes `ui.Frame`/`Texture`/`Label`/`Button` as
---upvalues when it loads, but the functions this covers — `ns.GridMatches` and
---`ns.CategoryOptions` — are pure table walks that never touch them. Everything frame-bound in
---that file (the completion cell, the dressed-cell cursor, the filter chrome) stays out of reach
---of the specs, which is why the stub can be this thin rather than a fake widget toolkit.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadGridShared(ns)
  ns.ui = ns.ui or { Frame = {}, Texture = {}, Label = {}, Button = {} }
  loadInto(ns, "GridShared.lua")
  return ns
end

---Load data/hidevisuals.lua into an already-loaded `ns`. The one file here that DOES touch the
---API, so the caller installs `Enum`, `C_TransmogCollection` and `ns.AppearanceSource` first and
---this loads over them (the file captures both C_ functions as upvalues at load time, so the stubs
---have to be in place before this call, and a re-load is what resets its per-slot cache).
---
---It earns the stub because what's worth testing is the eleven-entry slot → category map: a swapped
---entry there would silently hide the wrong slot, and nothing else in the addon would notice.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadHideVisuals(ns)
  loadInto(ns, "data/hidevisuals.lua")
  return ns
end

---Load ratings.lua into an already-loaded `ns`, with the rating tables MigrateDB seeds already on
---`ns.db` (the file itself never seeds them — in game that's init.lua's job). Needs no stub: the one
---WoW name it touches is `UnitRace`, inside `ns:PlayerRace`, which these specs don't call.
---
---It earns a spec because the wanted/rank accessors are the whole persistence contract for the
---collection's user-authored data — a flag written to the wrong table, or a `false` stored where a
---`nil` was meant, would silently mis-count a header tally or resurrect a cleared flag.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadRatings(ns)
  local db = ns.db
  db.wanted, db.rank, db.raceRank = {}, {}, {}
  db.weaponWanted, db.weaponRank = {}, {}
  db.cosmeticWanted, db.illusionWanted = {}, {}
  loadInto(ns, "ratings.lua")
  return ns
end

---Load DataViewFilters.lua into an already-loaded `ns`, over stubs of what it destructures at load
---time. Only `DataView.BuildColInfo` is exercised — the filter/sort methods it also defines drive
---frames and stay in-game-tested.
---
---It earns a loader for one invariant: **the armour grid's name column is index 2 in BOTH hosts**
---(#864). It used to be index 1 for embedded hosts and 2 in the window, and that single asymmetry was
---the source of every host branch in the grid — the index recomputed in three places, `colInfo` built
---two ways, the name cell called from two sites. A one-argument change to the name cell then had to be
---made twice, half-landed, and silently dropped the embedded host's tooltip (#865). This is the
---regression guard for the collapse, and it is pure table-building given the stubs below.
---
---`ns.icons.classes` is stubbed at three entries rather than the real thirteen: the count is irrelevant
---to the contract (the leading two columns and their order are what matter) and a fixed small number
---makes the index assertions readable.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadDataViewFilters(ns)
  -- The REAL list helpers, not a stub: `buildColInfo` is `lists.map` over the class icons and a
  -- `prepend` of the two chrome columns, so stubbing them would mean the column ORDER and INDICES this
  -- spec exists to pin came from the stub rather than from LibNAddOn. Loaded directly rather than
  -- through `loadInto`, which is scoped to this addon's folder; `lists.lua` needs only `ns.lua` to
  -- exist and is self-contained beyond that.
  ns.lua = ns.lua or {}
  assert(loadfile("LibNAddOn/lua/lists.lua"))("LibNAddOn", ns)
  ns.ui = ns.ui or {}
  ns.ui.justify = ns.ui.justify or { Center = "CENTER", Left = "LEFT", Right = "RIGHT" }
  ns.Colors = ns.Colors or { TransparentBlack = {0, 0, 0, 0} }
  ns.icons = ns.icons or {}
  ns.icons.classes = ns.icons.classes or { "atlas-1", "atlas-2", "atlas-3" }
  ns.gridCellWidth = ns.gridCellWidth or 28
  -- Captured as an upvalue at load time, so it has to exist before the file runs. Returns the class
  -- name as its FIRST value, which is the one `buildColInfo` parenthesises out for the header tooltip.
  _G.GetClassInfo = _G.GetClassInfo or function(classId) return "Class" .. classId, "CLASS" .. classId, classId end
  -- `DataView` is the table the file hangs its methods on; the real one is a Class instance, but
  -- BuildColInfo is assigned to it as a plain field so a bare table is enough.
  ns.DataView = ns.DataView or {}
  loadInto(ns, "DataViewFilters.lua")
  return ns
end

---Load DataViewData.lua over the loaders it depends on, so `ns.CollectedRows` can be called.
---
---It earns a loader for the invariant `spec/colinfo_spec.lua` cannot reach: **the row builder prepends
---exactly the chrome cells `BuildColInfo` prepends columns for**. Each half was internally consistent
---while disagreeing with the other, twice (#864) — the second time putting class 1 in the name column
---and rendering the name as "C…" in a 28px class column. A column-layout spec can't see that; only
---calling the row builder and comparing can.
---
---Composes the existing loaders rather than hand-stubbing: `loadDataViewFilters` supplies `CHROME`,
---`BuildColInfo` and `NAME_COL`; `loadGridShared` supplies `GridRowOrder`, `CompletionCell` and
---`GridNameCell`; `loadRatings` supplies `IsWanted`. What's left is the handful of names
---`DataViewData.lua` captures at load or reaches during a row build — the handlers it hangs on cells
---resolve their globals lazily and are never fired here.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadDataViewData(ns)
  M.loadDataViewFilters(ns)
  M.loadGridShared(ns)
  M.loadRatings(ns)
  ns.ui.edge = ns.ui.edge or { Top = "TOP", TopLeft = "TOPLEFT" }
  ns.ui.Texture = ns.ui.Texture or {}
  _G.tinsert = _G.tinsert or table.insert
  -- One release with an icon and one without, so the name cell's badge branch is exercised both ways.
  ns.ReleaseIcons = ns.ReleaseIcons or { [12] = "icon-midnight" }
  ns.Releases = ns.Releases or { [12] = "Midnight", [11] = "The War Within" }
  ns.db.sets = ns.db.sets or {}
  ns.Sets, ns.PtrSets = ns.Sets or {}, ns.PtrSets or {}
  -- Reached only from inside cell handlers, which these specs never fire — present so a stray call
  -- fails loudly as a nil-call rather than silently resolving to a global.
  ns.SavedCharacters = ns.SavedCharacters or function() return nil end
  ns.WantedOnlyActive = ns.WantedOnlyActive or function(view) return view._wantedOnly and not view._ptr end
  loadInto(ns, "DataViewData.lua")
  return ns
end

---Load viewsync.lua into an already-loaded `ns`. Needs no C_ stub at all — the only WoW name it
---touches is `Enum.TransmogCollectionType`, a table of constants — but it still loads separately
---because the caller supplies that table and the weapon-hand sets are built from it at load time.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadViewSync(ns)
  loadInto(ns, "viewsync.lua")
  return ns
end

---Load outfitshare.lua over a stub of the two C_TransmogCollection link functions it captures at
---load time. Only `ns.ShareableOutfit` is exercised — it takes its hide-visual resolver as an
---argument precisely so the wire-shaping rule is testable without the client.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadOutfitShare(ns)
  _G.C_TransmogCollection = _G.C_TransmogCollection or {}
  _G.C_TransmogCollection.GetCustomSetHyperlinkFromItemTransmogInfoList =
    _G.C_TransmogCollection.GetCustomSetHyperlinkFromItemTransmogInfoList or function() end
  _G.C_TransmogCollection.GetItemTransmogInfoListFromCustomSetHyperlink =
    _G.C_TransmogCollection.GetItemTransmogInfoListFromCustomSetHyperlink or function() end
  loadInto(ns, "outfitshare.lua")
  return ns
end

---Load `controls/TransmogFrameButtons.lua` over a stub of the frame furniture it names at load
---time, and return a handle for driving its two StaticPopups.
---
---The one **controls** file with a spec, and it earns one the way the two data files above do: the
---save flow it owns writes to the account-wide library, which is the only copy of a saved look, and
---#757 was a silent replacement of the wrong one. What the file does with widgets is untestable
---here and untested — `rowButton` and `build` are only reached from a real transmogrifier, so the
---stubs below need only satisfy the upvalues captured at load.
---
---`ns.LibraryOutfit` and `ns.SaveLookToBoth` are deliberately the REAL ones from M.load, so a test
---asserts on what actually landed in the store rather than on what a stub was handed. Only the
---three that reach the client are stubbed: the model list, the streaming check, and the provenance
---stamp.
---@param ns table  as returned by M.load()
---@return table env  `.model` the staged list (write it to move the model), `.shown` popups shown,
---`.printed` chat lines, `.meta` the lists `LocalOutfitMeta` was called with, `.dialogs` the
---registered `StaticPopupDialogs` entries
function M.loadTransmogButtons(ns)
  local env = { shown = {}, printed = {}, meta = {} }

  _G.StaticPopupDialogs = {}
  _G.StaticPopup_Show = function(which, data)
    env.shown[#env.shown + 1] = { which = which, data = data }
  end
  _G.SAVE, _G.CANCEL, _G.YES, _G.NO = "Save", "Cancel", "Yes", "No"
  -- The live model. `GetItemTransmogInfoList` returns nil until the model scene's actor exists,
  -- which `env.model = nil` reproduces.
  _G.TransmogFrame = {
    CharacterPreview = { GetItemTransmogInfoList = function() return env.model end },
  }

  -- No `ns.ui` / `ns.DressingRoom` stub: that file builds its widgets from `CreateFrame` +
  -- `UIPanelButtonTemplate` so they wear the GAME's chrome on the GAME's frame (#819), and nothing
  -- it names at load time comes from us any more.
  ns.registerEvent = function() end
  ns.Print = function(msg) env.printed[#env.printed + 1] = msg end
  -- outfit.lua's real one, minus the `PlayerCanCollectSource` call that decides `pending` — the
  -- filled count is the same walk over the codec's real slot order. `env.pending` forces the
  -- still-streaming branch.
  ns.OutfitIssues = function(list)
    local filled = 0
    for _, slotID in ipairs(ns.OutfitSlotOrder) do
      local info = list[slotID]
      if info and (info.appearanceID or 0) > 0 then filled = filled + 1 end
    end
    return { filled = filled, pending = env.pending or false }
  end
  -- outfitmodel.lua's stamps the player's name/class/armour off the client. Recording the list it
  -- was handed is the part a test cares about: the provenance must describe the SAVED look.
  ns.LocalOutfitMeta = function(list)
    env.meta[#env.meta + 1] = list
    return { char = "Tester-Realm" }
  end
  ns.SaveCustomSet = function() return 1 end

  loadInto(ns, "controls/TransmogFrameButtons.lua")
  env.dialogs = _G.StaticPopupDialogs
  return env
end

---Load the illusion + arsenal data files. Both are plain tables plus (for arsenals) a pure
---table transform, so they need no stub at all — only `ns.WeaponSources` to fold into, seeded
---empty here since the real generated data isn't loaded under busted.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadWeaponData(ns)
  ns.WeaponSources = {}
  loadInto(ns, "data/illusions.lua")
  loadInto(ns, "data/arsenals.lua")
  return ns
end

---Load the REAL generated `data/weaponsources.lua` and fold the shipped arsenals over it, so a spec
---can assert the #670 invariant that the generator drops no arsenal appearance. Unlike M.loadWeaponData
---(empty seed, for the transform-mechanics tests) this is the fold against production data. The
---generated file is pure Lua — `tinsert(ns.WeaponSources, {...})` literals — where `tinsert` is a WoW
---global it captures at load; stubbed here to `table.insert`.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadShippedWeapons(ns)
  _G.tinsert = _G.tinsert or table.insert
  ns.WeaponSources = {}
  loadInto(ns, "data/weaponsources.lua")
  loadInto(ns, "data/arsenals.lua")
  return ns
end

return M
