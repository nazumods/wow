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
end)
