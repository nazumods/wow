---@type Warbandeer_Collected
local ns = select(2, ...)
-- Generated from wago.tools TransmogSet PTR delta (live 12.1.0.69299 vs PTR 12.1.0.69299, 2026-08-13) by tools/update-sets.ps1 -PtrDelta.
-- Sets present on the PTR but not yet on live ("upcoming"). VOLATILE — regenerate
-- on demand; not part of the weekly live refresh. release tags the newest expansion;
-- instance/difficulty are omitted (no lockouts for unreleased content).

---@class Warbandeer_Collected
---@field PtrSets table[] PTR-only set groups (same shape as ns.Sets)
---@field PtrBuild { live: string, ptr: string } the builds this delta was generated from
ns.PtrSets = {}
ns.PtrBuild = { live = "12.1.0.69299", ptr = "12.1.0.69299" }
