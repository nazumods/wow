---@type Warbandeer_Collected
local ns = select(2, ...)
-- luacheck: no max line length
-- Generated from wago.tools weapon PTR delta (live 12.1.0.69299 vs PTR 12.1.0.69299, 2026-08-13) by tools/update-sets.ps1 -Weapons -PtrDelta.
-- Weapon/off-hand APPEARANCES on the PTR but not yet on live ("upcoming"), same source x weapon
-- type shape as weaponsources.lua. VOLATILE — regenerate on demand; not part of the weekly refresh.

---@class Warbandeer_Collected
---@field WeaponPtrSources table[] PTR-only weapon-appearance source groups (same shape as ns.WeaponSources)
---@field WeaponPtrBuild { live: string, ptr: string } the builds this delta was generated from
ns.WeaponPtrSources = {}
ns.WeaponPtrBuild = { live = "12.1.0.69299", ptr = "12.1.0.69299" }
