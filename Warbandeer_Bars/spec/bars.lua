-- Loads Warbandeer_Bars/tracker.lua into a fresh namespace so its WoW-API-free
-- decision logic (ns.shouldStore) can be unit-tested without the WoW client.
-- tracker.lua only touches WoW at *call* time (Snapshot/Capture → GetActionInfo,
-- the triggers → ns:after/ns:delay), and those are never invoked here; the sole
-- load-time WoW touch is the three ns:registerEvent calls, which we stub.
-- Path is relative to the AddOns root, where busted runs.
local bars = {}

---@return table ns  a fresh Warbandeer_Bars namespace with ns.shouldStore defined
function bars.load()
  local ns = { registerEvent = function() end }
  assert(loadfile("Warbandeer_Bars/tracker.lua"))("Warbandeer_Bars", ns)
  return ns
end

-- Loads api.lua into a fresh namespace so the WoW-API-free DB methods (resolveChar,
-- DeleteProfile/DeleteCharacter, the getters) can be unit-tested. api.lua's only
-- load-time WoW touch is resolving GetSpecialization, which is absent here (→ nil) and
-- never called by these tests. Tests set ns.db.profiles after loading.
---@return table ns  a fresh namespace with ns.api populated (WarbandeerBarsApi)
function bars.loadApi()
  local ns = { api = {}, db = { profiles = {} } }
  assert(loadfile("Warbandeer_Bars/api.lua"))("Warbandeer_Bars", ns)
  return ns
end

-- Loads capture.lua into a fresh namespace so the profile schema ns.Capture writes can be
-- asserted without the client. Its load-time WoW touches (Constants.MacroConsts, the
-- MAX_*_MACROS globals, C_SpecializationInfo) are all `and`/`or`-guarded, so the file loads
-- clean against bare Lua; the call-time globals come from `env`, installed as the chunk's
-- environment rather than written into _G, so the stubs stay scoped to this copy and can't
-- leak between tests. Anything env omits falls through to the real _G.
---@param env table  WoW globals the test drives (GetActionInfo, C_PetJournal, UnitName, ...)
---@return table ns  a fresh namespace with ns.Capture defined
function bars.loadCapture(env)
  local chunk = assert(loadfile("Warbandeer_Bars/capture.lua"))
  setfenv(chunk, setmetatable(env, { __index = _G }))
  -- Real bar geometry is read from live frames; the schema tests don't exercise it.
  local ns = { wow = { ReadActionBars = function() return {} end } }
  chunk("Warbandeer_Bars", ns)
  return ns
end

-- Loads restore.lua into a fresh namespace so ns.Restore can be driven out of game. Every
-- load-time WoW touch in the file (C_Spell/C_Item/C_SpellBook, Constants.MacroConsts, the
-- MAX_*_MACROS globals) is `and`/`or`-guarded, so it loads clean against bare Lua and the
-- guarded fallbacks apply. Call-time globals come from `env` via setfenv, so the stubs stay
-- scoped to this copy; anything env omits falls through to the real _G.
---@param env table  WoW globals the test drives (GetActionInfo, PickupAction, ...)
---@return table ns  a fresh namespace with ns.Restore defined; ns.printed collects ns.Print
function bars.loadRestore(env)
  local chunk = assert(loadfile("Warbandeer_Bars/restore.lua"))
  setfenv(chunk, setmetatable(env, { __index = _G }))
  local ns = { printed = {} }
  ns.Print = function(msg) ns.printed[#ns.printed + 1] = msg end
  chunk("Warbandeer_Bars", ns)
  return ns
end

-- A fake action bar for the restore specs: slot table + a one-item cursor.
--
-- Both PickupAction and PlaceAction SWAP slot and cursor, exactly as they do in game. That
-- swap is what turns "pick the action up to clear the slot" into a round-trip, so a harness
-- modelling pickup as a plain removal would not reproduce the bug this covers (#751).
---@param initial table?  { [slotID] = { type, index } } starting bar contents
---@return table bars  { slots = table, cursor = table|nil, env = table } — env holds the stubs
function bars.actionbars(initial)
  local bar = { slots = {}, cursor = nil }
  for id, action in pairs(initial or {}) do
    bar.slots[id] = { action[1], action[2] }
  end

  local function swap(id)
    bar.slots[id], bar.cursor = bar.cursor, bar.slots[id]
  end

  bar.env = {
    InCombatLockdown = function() return false end,
    GetActionInfo    = function(id)
      local a = bar.slots[id]
      if not a then return nil end
      return a[1], a[2]
    end,
    PickupAction = function(id) swap(id) end,
    PlaceAction  = function(id) swap(id) end,
    GetCursorInfo = function()
      local c = bar.cursor
      if not c then return nil end
      return c[1], c[2]
    end,
    ClearCursor = function() bar.cursor = nil end,
    -- C_SpellBook is left absent, so the spellbook passes short-circuit to empty maps and
    -- the by-index/by-name pickup fallbacks return false without touching the client.
    C_Spell = {
      PickupSpell  = function(id) bar.cursor = { "spell", id } end,
      GetSpellName = function(id) return "Spell " .. id end,
      GetSpellLink = function(id) return "[Spell " .. id .. "]" end,
    },
  }
  return bar
end

return bars
