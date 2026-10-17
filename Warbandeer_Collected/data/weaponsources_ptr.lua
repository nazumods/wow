---@type Warbandeer_Collected
local ns = select(2, ...)
local tinsert = tinsert
-- luacheck: no max line length
-- Generated from wago.tools weapon PTR delta (live 12.1.5.70391 vs PTR 12.1.7.70424 [wowt], 2026-10-15) by tools/update-sets.ps1 -Weapons -PtrDelta.
-- Weapon/off-hand APPEARANCES on the PTR but not yet on live ("upcoming"), same source x weapon
-- type shape as weaponsources.lua. VOLATILE — regenerate on demand; not part of the weekly refresh.

---@class Warbandeer_Collected
---@field WeaponPtrSources table[] PTR-only weapon-appearance source groups (same shape as ns.WeaponSources)
---@field WeaponPtrBuild { live: string, ptr: string } the builds this delta was generated from
ns.WeaponPtrSources = {}
ns.WeaponPtrBuild = { live = "12.1.5.70391", ptr = "12.1.7.70424" }

tinsert(ns.WeaponPtrSources, {
  id = 9300100,
  name = "Trading Post",
  release = 0,
  category = "Trading Post",
  types = {
    [16] = { 84262 },
    [21] = { 115529, 138939, 138940, 138941, 138942 },
    [22] = { 138943, 138944, 138945, 138946 },
    [24] = { 83164 },
    [25] = { 94722 },
    [26] = { 83147 },
    [18] = { 95002 },
  },
})

tinsert(ns.WeaponPtrSources, {
  id = 9300140,
  name = "Other",
  release = 0,
  category = "Other",
  types = {
    [13] = { 83494, 93341, 104801 },
    [14] = { 93347, 109852, 114778 },
    [15] = { 109841 },
    [16] = { 83497, 104546 },
    [17] = { 115027 },
    [20] = { 104559 },
    [21] = { 93350 },
    [24] = { 83541, 109892 },
    [23] = { 83544, 93344, 114774 },
    [25] = { 83548, 109974 },
    [26] = { 93353 },
    [12] = { 109856 },
    [19] = { 109945, 115031, 135347 },
  },
})
