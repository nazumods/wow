-- Test harness: loads Warbandeer_Collected's WoW-API-free modules into a fresh ns with a
-- minimal stub of the inventory-slot globals, so the /customset codec can be unit-tested
-- without the game client. Mirrors Warbandeer_Decor's spec/loader.lua. Paths are relative
-- to the AddOns root (busted's cwd).
--
-- Two files qualify: outfitcodec.lua and outfitlibrary.lua (the library is pure Lua over `ns.db`
-- plus the codec). Everything else in the addon touches C_* or frames and stays in-game-tested.
-- `ItemUtil` is deliberately left unstubbed so the codec exercises its plain-table fallback (see
-- ns.NewTransmogInfo).
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
  return ns
end

return M
