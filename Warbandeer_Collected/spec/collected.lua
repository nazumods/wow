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

---Load the WoW-API-free outfit files into a fresh ns and return it. `ns.db` is seeded empty so the
---library has a store to write into, exactly as LibNAddOn's MigrateDB would leave it in game.
---@return table ns
function M.load()
  for name, value in pairs(SLOTS) do _G[name] = value end
  local ns = { db = { outfits = {} } }
  assert(loadfile("Warbandeer_Collected/outfitcodec.lua"))("Warbandeer_Collected", ns)
  assert(loadfile("Warbandeer_Collected/outfitlibrary.lua"))("Warbandeer_Collected", ns)
  assert(loadfile("Warbandeer_Collected/outfitfilter.lua"))("Warbandeer_Collected", ns)
  -- Qualifies for the same reason the two above do: it calls only other `ns` functions, never a C_
  -- API or a frame. Its two savers (`ns.SaveLibraryOutfit`, `ns.SaveCustomSet`) are resolved at call
  -- time, so loading it needs neither of them present — a spec stubs whichever it wants to observe.
  assert(loadfile("Warbandeer_Collected/outfitsave.lua"))("Warbandeer_Collected", ns)
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
  assert(loadfile("Warbandeer_Collected/GridShared.lua"))("Warbandeer_Collected", ns)
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
  assert(loadfile("Warbandeer_Collected/data/hidevisuals.lua"))("Warbandeer_Collected", ns)
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
  assert(loadfile("Warbandeer_Collected/ratings.lua"))("Warbandeer_Collected", ns)
  return ns
end

---Load viewsync.lua into an already-loaded `ns`. Needs no C_ stub at all — the only WoW name it
---touches is `Enum.TransmogCollectionType`, a table of constants — but it still loads separately
---because the caller supplies that table and the weapon-hand sets are built from it at load time.
---@param ns table  as returned by M.load()
---@return table ns
function M.loadViewSync(ns)
  assert(loadfile("Warbandeer_Collected/viewsync.lua"))("Warbandeer_Collected", ns)
  return ns
end

---Load the illusion + arsenal data files. Both are plain tables plus (for arsenals) a pure
---table transform, so they need no stub at all — only `ns.WeaponSources` to fold into, seeded
---empty here since the real generated data isn't loaded under busted.
---@param ns table  as returned by M.load()
---@return table ns
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
  assert(loadfile("Warbandeer_Collected/outfitshare.lua"))("Warbandeer_Collected", ns)
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

  ns.ui = { justify = { Center = "CENTER" } }
  ns.DressingRoom = { _k = { selBox = function(box) return box end } }
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

  assert(loadfile("Warbandeer_Collected/controls/TransmogFrameButtons.lua"))("Warbandeer_Collected", ns)
  env.dialogs = _G.StaticPopupDialogs
  return env
end

function M.loadWeaponData(ns)
  ns.WeaponSources = {}
  assert(loadfile("Warbandeer_Collected/data/illusions.lua"))("Warbandeer_Collected", ns)
  assert(loadfile("Warbandeer_Collected/data/arsenals.lua"))("Warbandeer_Collected", ns)
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
  assert(loadfile("Warbandeer_Collected/data/weaponsources.lua"))("Warbandeer_Collected", ns)
  assert(loadfile("Warbandeer_Collected/data/arsenals.lua"))("Warbandeer_Collected", ns)
  return ns
end

return M
