-- Test harness: loads Warbandeer_Collected's WoW-API-free modules into a fresh ns with a
-- minimal stub of the inventory-slot globals, so the /customset codec can be unit-tested
-- without the game client. Mirrors Warbandeer_Decor's spec/loader.lua. Paths are relative
-- to the AddOns root (busted's cwd).
--
-- Two files qualify outright: outfitcodec.lua and outfitlibrary.lua (the library is pure Lua over
-- `ns.db` plus the codec). `ItemUtil` is deliberately left unstubbed so the codec exercises its
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
  -- Qualifies for the same reason the two above do: it calls only other `ns` functions, never a C_
  -- API or a frame. Its two savers (`ns.SaveLibraryOutfit`, `ns.SaveCustomSet`) are resolved at call
  -- time, so loading it needs neither of them present — a spec stubs whichever it wants to observe.
  assert(loadfile("Warbandeer_Collected/outfitsave.lua"))("Warbandeer_Collected", ns)
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
