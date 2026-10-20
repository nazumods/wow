---@type Warbandeer_Collected
local ns = select(2, ...)

-- WoW: Forever has no PTR, so the Retail weapon PTR delta loaded before this file (weaponsources_ptr.lua,
-- generated against Retail's live and PTR builds) describes nothing that client will get. Empty it there,
-- as data/sets_forever.lua does for the armour delta, so the PTR toggle shows no Retail "upcoming" weapons
-- and no Retail PTR build string. Loaded right after weaponsources_ptr.lua and before api.lua; inert on
-- Retail. Hand-written (unlike the generated data files around it). Spec'd in spec/forever_spec.lua.
if not (ns.flavor and ns.flavor.isForever) then return end
ns.WeaponPtrSources = {}
ns.WeaponPtrBuild = nil
