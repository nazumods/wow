local bars = require("Warbandeer_Bars.spec.bars")

describe("Warbandeer_Bars API", function()
  local ns

  before_each(function()
    ns = bars.loadApi()
    ns.db.profiles = {
      Lurias = { [62] = { spec = "Arcane" }, [63] = { spec = "Fire" } },
      Naz    = { [250] = { spec = "Blood" } },
    }
  end)

  describe("DeleteCharacter (case-insensitive forget-all)", function()
    it("removes every profile for an exact-cased character, leaving others intact", function()
      assert.is_true(ns.api:DeleteCharacter("Lurias"))
      assert.is_nil(ns.db.profiles.Lurias)
      assert.is_not_nil(ns.db.profiles.Naz)
    end)

    it("resolves a mis-cased name to the stored key and deletes it", function()
      -- The #442 bug: the raw name never matched the canonical key, so this no-oped.
      assert.is_true(ns.api:DeleteCharacter("lurias"))
      assert.is_nil(ns.db.profiles.Lurias)
    end)

    it("returns false and mutates nothing for an unknown character", function()
      assert.is_false(ns.api:DeleteCharacter("Nobody"))
      assert.is_not_nil(ns.db.profiles.Lurias)
      assert.is_not_nil(ns.db.profiles.Naz)
    end)
  end)

  describe("DeleteProfile (single spec, honest report)", function()
    it("removes one spec, reports true, and leaves the character's other specs", function()
      assert.is_true(ns.api:DeleteProfile("Lurias", 62))
      assert.is_nil(ns.db.profiles.Lurias[62])
      assert.is_not_nil(ns.db.profiles.Lurias[63])
    end)

    it("drops the character row once its last profile is forgotten", function()
      assert.is_true(ns.api:DeleteProfile("Naz", 250))
      assert.is_nil(ns.db.profiles.Naz)
    end)

    it("resolves a mis-cased name to the stored key", function()
      assert.is_true(ns.api:DeleteProfile("lurias", 62))
      assert.is_nil(ns.db.profiles.Lurias[62])
    end)

    it("returns false and mutates nothing for a spec the character never stored", function()
      -- The #584 nit: forgetting a missing spec used to report success. It must report false.
      assert.is_false(ns.api:DeleteProfile("Lurias", 999))
      assert.is_not_nil(ns.db.profiles.Lurias[62])
      assert.is_not_nil(ns.db.profiles.Lurias[63])
    end)

    it("returns false for an unknown character", function()
      assert.is_false(ns.api:DeleteProfile("Nobody", 62))
    end)
  end)
end)
