---@type Warbandeer_Collected
local ns = select(2, ...)

-- The Legion class "arsenals" as Weapons-grid rows (#653).
--
-- They used to be a `kind = "arsenal"` group on `ns.Sets` — a row in the ARMOR grid under a
-- "Weapons" category (#516) — rendered through a bespoke bare-body path (since removed with the
-- second paper doll it drew on, #673). Measured in game
-- while planning #653: **21 of their 23 appearances were already in the Weapons grid**, sitting
-- anonymously inside the generated Legion → Vendor row. So the armour-grid rows were duplicating
-- appearances you could already browse, just without a name on them.
--
-- What this file does instead is REGROUP: lift each arsenal's appearances out of whichever
-- generated rows hold them into a row of their own, so an arsenal reads as an arsenal. Nothing is
-- duplicated — a moved appearance leaves its old row — so the grid's counts stay honest.
--
-- **`data/weaponsources.lua` is generated and must not be hand-edited** (`tools/update-sets.ps1
-- -Weapons` owns it wholesale), which is why this is a load-time transform over the table rather
-- than an edit to it: regenerating the data doesn't undo the regrouping.
--
-- The Warglaives of Azzinoth once needed a hand-stated `types` column here: their reissue visuals
-- (34777, 8461) were **absent from the generated data entirely**, because the generator silently
-- dropped every HiddenUntilCollected source — the flag Timewalking reissues carry (nazumods/wow#670).
-- With that fixed the generator now emits both (in an "Other" row), so the fold MOVES them like any
-- other arsenal appearance and the override is gone. A manifest `types` map is still honoured as a
-- general escape hatch for an appearance the data genuinely lacks, but no shipped arsenal needs one.

-- Ids in a band of their own — the generated rows use 92xxxxx/93xxxxx, so 94xxxxx can't collide.
-- `release = 7` (Legion) for all three: the arsenals are a Legion feature, even where the weapons
-- themselves are a Burning Crusade raid drop. `category` stays each row's HONEST source, so the
-- Weapons grid's category filter keeps meaning what it says — no new category is invented.
local ARSENALS = {
  {
    id = 9400001, name = "Armaments of the Silver Hand", release = 7, category = "Vendor",
    obtain = "Broken Shore — bought from Warmage Kath'leen for Nethershards",
    visuals = { 28592, 28593, 28594, 28596, 28597, 28598 },
  },
  {
    id = 9400002, name = "Armaments of the Ebon Blade", release = 7, category = "Vendor",
    obtain = "Broken Shore — bought from Warmage Kath'leen for Nethershards",
    -- 5 weapon shapes x 3 tints (Bloodied / Icy / Unholy).
    visuals = {
      32595, 32596, 32598, 32611, 32612, 32619,   -- one-handed swords
      32590, 32609, 32621,                        -- two-handed axes
      32593, 32603, 32605,                        -- two-handed swords
      32591, 32606, 32607,                        -- polearms
    },
  },
  {
    id = 9400003, name = "The Warglaives of Azzinoth", release = 7, category = "Raid",
    obtain = "Black Temple, Burning Crusade Timewalking — drops from Illidan Stormrage",
    -- The pair is NOT both warglaives — measured in game (`GetCategoryForItem`): the off-hand is
    -- itemized as a one-handed sword (14) carrying the original Burning Crusade appearance 8461,
    -- while the main-hand is the warglaive (28) Legion reissue 34777. The generator now emits both
    -- (#670), so the fold finds each in its real column and moves it — no hand-stated `types` needed.
    visuals = { 34777, 8461 },
  },
}

---@class Warbandeer_Collected
---@field Arsenals table[]  the manifest above, published so the fold can be re-run and tested
---@field FoldArsenals fun(sources: table[], arsenals: table[]): { moved: number, added: number, missing: number[] }
---@field arsenalFoldReport { moved: number, added: number, missing: number[] }  result of the load-time fold
ns.Arsenals = ARSENALS

---Regroup each arsenal's appearances into a row of its own, in place.
---
---Every appearance is **moved** where the generated data already has it and **added** where it
---doesn't, so the total appearance count across the table is unchanged by a move and grows only by
---the genuinely-missing ones. Rows and type columns emptied by the moves are dropped, so the grid
---never renders a row with nothing in it.
---
---Pure table work (no WoW API), and idempotent — a second run finds the visuals already in their
---arsenal rows and moves them to themselves. `missing` lists any visual that was neither found nor
---given a `types` column, which would otherwise vanish silently.
---@param sources table[]  ns.WeaponSources (mutated)
---@param arsenals table[]  the manifest above
---@return { moved: number, added: number, missing: number[] }
function ns.FoldArsenals(sources, arsenals)
  local report = { moved = 0, added = 0, missing = {} }

  for _, arsenal in ipairs(arsenals) do
    local row = { id = arsenal.id, name = arsenal.name, release = arsenal.release,
      category = arsenal.category, obtain = arsenal.obtain, types = {} }

    for _, visual in ipairs(arsenal.visuals) do
      local foundType
      for _, src in ipairs(sources) do
        if src ~= row then
          for t, list in pairs(src.types) do
            for i = #list, 1, -1 do
              if list[i] == visual then table.remove(list, i); foundType = t end
            end
          end
        end
      end
      local t = foundType or (arsenal.types and arsenal.types[visual])
      if t then
        row.types[t] = row.types[t] or {}
        table.insert(row.types[t], visual)
        if foundType then report.moved = report.moved + 1 else report.added = report.added + 1 end
      else
        report.missing[#report.missing + 1] = visual
      end
    end

    sources[#sources + 1] = row
  end

  -- Drop what the moves emptied: a type column with no appearances left renders a blank cell, and
  -- a row with no columns left renders an entirely blank row.
  for i = #sources, 1, -1 do
    local src = sources[i]
    for t, list in pairs(src.types) do
      if #list == 0 then src.types[t] = nil end
    end
    if not next(src.types) then table.remove(sources, i) end
  end

  return report
end

-- Published so a spec can assert the shipped data still carries every arsenal appearance: a non-empty
-- `missing` means the generator dropped one (the #670 regression returning) and CI fails.
ns.arsenalFoldReport = ns.FoldArsenals(ns.WeaponSources, ARSENALS)
