local collected = require("Warbandeer_Collected.spec.collected")

-- Count every appearance across a WeaponSources-shaped table, so a move can be told from a
-- duplication: regrouping must not change the total, only where the entries live.
local function total(sources)
  local n = 0
  for _, src in ipairs(sources) do
    for _, list in pairs(src.types) do n = n + #list end
  end
  return n
end

-- Find a row by name (the arsenal rows are appended, so no fixed index).
local function row(sources, name)
  for _, src in ipairs(sources) do
    if src.name == name then return src end
  end
end

-- Two generated-looking rows holding the appearances an arsenal will claim, mixed in with
-- appearances that must be left exactly where they are.
local function fixture()
  return {
    { id = 1, name = "Vendor", release = 7, category = "Vendor",
      types = { [14] = { 111, 501, 222 }, [20] = { 502 }, [18] = { 333 } } },
    { id = 2, name = "Raid", release = 7, category = "Raid",
      types = { [21] = { 503 }, [23] = { 444 } } },
  }
end

describe("arsenals", function()
  local ns
  before_each(function() ns = collected.loadWeaponData(collected.load()) end)

  describe("FoldArsenals", function()
    it("moves an arsenal's appearances into a row of its own, keeping their column", function()
      local sources = fixture()
      ns.FoldArsenals(sources, {{ id = 99, name = "Arsenal", release = 7, category = "Vendor",
        visuals = { 501, 502, 503 } }})
      local arsenal = row(sources, "Arsenal")
      assert.same({ 501 }, arsenal.types[14])
      assert.same({ 502 }, arsenal.types[20])
      assert.same({ 503 }, arsenal.types[21])
    end)

    it("removes them from the rows they came from, so nothing is duplicated", function()
      local sources = fixture()
      local before = total(sources)
      ns.FoldArsenals(sources, {{ id = 99, name = "Arsenal", release = 7, category = "Vendor",
        visuals = { 501, 502, 503 } }})
      assert.equal(before, total(sources))
      assert.same({ 111, 222 }, row(sources, "Vendor").types[14])
    end)

    it("drops a type column the move emptied", function()
      local sources = fixture()
      ns.FoldArsenals(sources, {{ id = 99, name = "Arsenal", release = 7, category = "Vendor",
        visuals = { 502 } }})
      assert.is_nil(row(sources, "Vendor").types[20])
      assert.is_not_nil(row(sources, "Vendor").types[14])
    end)

    it("drops a row the move emptied entirely", function()
      local sources = fixture()
      ns.FoldArsenals(sources, {{ id = 99, name = "Arsenal", release = 7, category = "Raid",
        visuals = { 503, 444 } }})
      assert.is_nil(row(sources, "Raid"))
      assert.is_not_nil(row(sources, "Vendor"))
    end)

    -- The Warglaives of Azzinoth case: absent from the generated data entirely, so they are added
    -- under the column the manifest states rather than moved.
    it("adds an appearance the data doesn't have, under its stated column", function()
      local sources = fixture()
      local before = total(sources)
      local report = ns.FoldArsenals(sources, {{ id = 99, name = "Arsenal", release = 7,
        category = "Raid", visuals = { 900, 901 }, types = { [900] = 28, [901] = 14 } }})
      assert.equal(2, report.added)
      assert.equal(0, report.moved)
      assert.equal(before + 2, total(sources))
      assert.same({ 900 }, row(sources, "Arsenal").types[28])
      assert.same({ 901 }, row(sources, "Arsenal").types[14])
    end)

    it("counts moves and adds separately when an arsenal is a mix of both", function()
      local report = ns.FoldArsenals(fixture(), {{ id = 99, name = "Arsenal", release = 7,
        category = "Vendor", visuals = { 501, 900 }, types = { [900] = 28 } }})
      assert.equal(1, report.moved)
      assert.equal(1, report.added)
      assert.same({}, report.missing)
    end)

    -- Neither found nor given a column: it would otherwise vanish with no error at all.
    it("reports an appearance it can neither move nor place, instead of losing it", function()
      local report = ns.FoldArsenals(fixture(), {{ id = 99, name = "Arsenal", release = 7,
        category = "Vendor", visuals = { 501, 777 } }})
      assert.same({ 777 }, report.missing)
      assert.equal(1, report.moved)
    end)

    it("carries the row's identity through to the grid", function()
      local sources = fixture()
      ns.FoldArsenals(sources, {{ id = 99, name = "Arsenal", release = 7, category = "Vendor",
        obtain = "somewhere", visuals = { 501 } }})
      local arsenal = row(sources, "Arsenal")
      assert.equal(99, arsenal.id)
      assert.equal(7, arsenal.release)
      assert.equal("Vendor", arsenal.category)
      assert.equal("somewhere", arsenal.obtain)
    end)

    it("leaves the same appearances in the same columns when run twice", function()
      local manifest = {{ id = 99, name = "Arsenal", release = 7, category = "Vendor",
        visuals = { 501, 502 } }}
      local once = fixture()
      ns.FoldArsenals(once, manifest)
      local twice = fixture()
      ns.FoldArsenals(twice, manifest)
      ns.FoldArsenals(twice, manifest)
      assert.equal(total(once), total(twice))
      assert.same(row(once, "Arsenal").types, row(twice, "Arsenal").types)
      assert.same(row(once, "Vendor").types, row(twice, "Vendor").types)
    end)
  end)

  describe("the shipped manifest", function()
    it("gives every arsenal a distinct id in the 94xxxxx band", function()
      local seen = {}
      for _, a in ipairs(ns.Arsenals) do
        assert.is_nil(seen[a.id], "duplicate arsenal id " .. tostring(a.id))
        seen[a.id] = true
        assert.is_true(a.id >= 9400000 and a.id < 9500000,
          a.name .. " must not collide with the generated 92xxxxx/93xxxxx rows")
      end
    end)

    -- A stated column that isn't one of the arsenal's own appearances is dead weight, and — worse
    -- — hides the fact that the appearance it was meant to place has no column at all.
    it("only states columns for appearances it actually lists", function()
      for _, a in ipairs(ns.Arsenals) do
        local listed = {}
        for _, v in ipairs(a.visuals) do listed[v] = true end
        for visual in pairs(a.types or {}) do
          assert.is_true(listed[visual] or false,
            a.name .. " states a column for " .. visual .. ", which it doesn't list")
        end
      end
    end)

    it("names a real grid column wherever it states one", function()
      local valid = {}
      for _, t in ipairs({12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28}) do
        valid[t] = true
      end
      for _, a in ipairs(ns.Arsenals) do
        for visual, t in pairs(a.types or {}) do
          assert.is_true(valid[t] or false,
            ("%s files %d under type %s, which is not a Weapons grid column"):format(a.name, visual, tostring(t)))
        end
      end
    end)
  end)

  -- The #670 regression guard: fold the shipped arsenals over the REAL generated weapon data (not the
  -- fixtures above). The generator used to silently drop HiddenUntilCollected sources, which is why the
  -- Warglaives once needed a hand-stated column here; if it ever regresses, the dropped appearance
  -- reappears as `missing` and this fails — the check the by-hand override used to hide.
  describe("the shipped weapon data", function()
    local shipped
    before_each(function() shipped = collected.loadShippedWeapons(collected.load()) end)

    local function weaponRow(name)
      for _, s in ipairs(shipped.WeaponSources) do if s.name == name then return s end end
    end

    it("carries every appearance the shipped arsenals claim (none go missing)", function()
      assert.same({}, shipped.arsenalFoldReport.missing)
    end)

    it("emits the Warglaives of Azzinoth so the fold moves them into real columns", function()
      -- 34777 (main-hand warglaive, col 28) and 8461 (off-hand one-handed sword, col 14) — the pair
      -- #670 was filed for. Present here means the generator's HiddenUntilCollected fallback kept them;
      -- the fold then regrouped them under their own name rather than a bare "Other" row.
      local warglaives = weaponRow("The Warglaives of Azzinoth")
      assert.is_not_nil(warglaives)
      assert.same({ 34777 }, warglaives.types[28])
      assert.same({ 8461 }, warglaives.types[14])
    end)
  end)

  describe("RestrictedIllusions", function()
    it("maps each of the known class illusions to its owning class", function()
      assert.equal(4, ns.RestrictedIllusions[5364])   -- Rogue — Poisoned
      assert.equal(6, ns.RestrictedIllusions[5869])   -- Death Knight — Rune of Razorice
      for _, sourceID in ipairs({5871, 5872, 5873, 5874, 5875}) do
        assert.equal(7, ns.RestrictedIllusions[sourceID], "imbue " .. sourceID .. " belongs to the Shaman")
      end
    end)

    it("gives every restricted illusion exactly one owner", function()
      local n = 0
      for sourceID, classID in pairs(ns.RestrictedIllusions) do
        n = n + 1
        assert.equal("number", type(sourceID))
        assert.is_true(classID >= 1 and classID <= 13, "classID " .. classID .. " is not a chrClassID")
      end
      assert.equal(7, n)   -- Poisoned + Razorice + the five Shaman imbues
    end)

    -- Anything not in the map is generic, which is what lets ns.Illusions show it on every class.
    it("leaves an unknown illusion unrestricted", function()
      assert.is_nil(ns.RestrictedIllusions[1])
      assert.is_nil(ns.RestrictedIllusions[99999])
    end)
  end)
end)
