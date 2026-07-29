import { describe, expect, test } from "bun:test";
import type { EquipmentResponse } from "./transmog";

// `transmog.ts` pulls in the `config` singleton (fetchTransmog needs the region), which resolves
// process.env at import time — satisfy the required vars before importing so this file runs
// standalone, not just as part of a full-suite run that happens to prime the env first.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { buildCustomSet, realmSlug, formatTransmogReply, OUTFIT_VALUE_COUNT } =
  await import("./transmog");

// A slot with a transmog, shaped as the equipment endpoint returns it.
const mog = (
  type: string,
  id: number,
  name: string,
  second?: { id: number; name: string },
) => ({
  slot: { type },
  transmog: {
    item: { name },
    item_modified_appearance_id: id,
    ...(second
      ? { second_item: { name: second.name }, second_item_modified_appearance_id: second.id }
      : {}),
  },
});

/** A slot that is equipped but NOT transmogged — the payload simply omits `transmog`. */
const plain = (type: string) => ({ slot: { type }, transmog: undefined });

describe("buildCustomSet", () => {
  test("emits 17 values in the addon's wire order", () => {
    const { code } = buildCustomSet({
      equipped_items: [
        mog("HEAD", 101, "Helm"),
        mog("SHOULDER", 102, "Pauldrons", { id: 103, name: "Left Pauldron" }),
        mog("BACK", 104, "Cloak"),
        mog("CHEST", 105, "Robe"),
        mog("SHIRT", 106, "Shirt"),
        mog("TABARD", 107, "Tabard"),
        mog("WRIST", 108, "Bracers"),
        mog("HANDS", 109, "Gloves"),
        mog("WAIST", 110, "Belt"),
        mog("LEGS", 111, "Leggings"),
        mog("FEET", 112, "Boots"),
        mog("MAIN_HAND", 113, "Sword", { id: 114, name: "Sword Skin" }),
        mog("OFF_HAND", 115, "Shield"),
      ],
    });
    // Head, Shoulder, Shoulder2, Back, Chest, Shirt, Tabard, Wrist, Hands, Waist, Legs, Feet,
    // MainHand, MainHand2, MainHandIllusion, OffHand, OffHandIllusion
    expect(code).toBe(
      "/customset v1 101,102,103,104,105,106,107,108,109,110,111,112,113,114,0,115,0",
    );
    expect(code.split(" ")[2]!.split(",")).toHaveLength(OUTFIT_VALUE_COUNT);
  });

  test("always emits 17 values, even for a character wearing nothing", () => {
    const { code, bare, empty } = buildCustomSet({ equipped_items: [] });
    const values = code.split(" ")[2]!.split(",");
    expect(values).toHaveLength(OUTFIT_VALUE_COUNT);
    expect(values.every((v) => v === "0")).toBe(true);
    // Nothing equipped is not the same as nothing transmogged.
    expect(bare).toHaveLength(0);
    expect(empty).toHaveLength(13);
  });

  test("an equipped-but-untransmogged slot is bare; an unequipped one is empty", () => {
    // The distinction drives the reply: only `bare` leaves the look incomplete. An empty off hand
    // is what a two-hander looks like, and calling that incomplete would be wrong.
    const { code, bare, empty, named } = buildCustomSet({
      equipped_items: [mog("HEAD", 101, "Helm"), plain("CHEST")],
    });
    expect(code.startsWith("/customset v1 101,0,0,0,0,")).toBe(true);
    expect(bare).toEqual(["CHEST"]);
    expect(empty).toContain("OFF_HAND");
    expect(empty).not.toContain("CHEST");
    expect(named).toEqual([{ slot: "HEAD", name: "Helm" }]);
  });

  test("a secondary that merely echoes the primary encodes 0", () => {
    // The REST payload repeats the primary when a slot has no distinct secondary; the in-game
    // producer emits 0, and 0 is what the format means by "none". Both must agree.
    const { code } = buildCustomSet({
      equipped_items: [mog("SHOULDER", 107743, "Pauldrons", { id: 107743, name: "Pauldrons" })],
    });
    expect(code).toBe("/customset v1 0,107743,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0");
  });

  test("a genuinely distinct secondary is preserved", () => {
    const { code } = buildCustomSet({
      equipped_items: [mog("SHOULDER", 1, "Right", { id: 2, name: "Left" })],
    });
    expect(code).toBe("/customset v1 0,1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0");
  });

  test("illusion positions are always 0 — the payload carries no visual enchant", () => {
    const { code } = buildCustomSet({
      equipped_items: [mog("MAIN_HAND", 500, "Axe"), mog("OFF_HAND", 501, "Shield")],
    });
    const v = code.split(" ")[2]!.split(",");
    expect(v[14]).toBe("0"); // main-hand illusion
    expect(v[16]).toBe("0"); // off-hand illusion
    expect(v[12]).toBe("500");
    expect(v[15]).toBe("501");
  });

  test("a secondary appearance only occupies its own slot's position", () => {
    // A shoulder secondary must not bleed into the back slot that follows it.
    const { code } = buildCustomSet({
      equipped_items: [mog("SHOULDER", 1, "S", { id: 2, name: "S2" }), mog("BACK", 3, "B")],
    });
    expect(code).toBe("/customset v1 0,1,2,3,0,0,0,0,0,0,0,0,0,0,0,0,0");
  });

  test("non-transmoggable slots are ignored rather than reported as unknown", () => {
    const { unknown } = buildCustomSet({
      equipped_items: [
        mog("HEAD", 1, "Helm"),
        plain("NECK"),
        plain("FINGER_1"),
        plain("TRINKET_2"),
      ],
    });
    expect(unknown).toEqual([]);
  });

  test("an unrecognised slot type is surfaced, not swallowed", () => {
    // The slot vocabulary is the one thing here not verified against a captured response, so a
    // drift has to be visible rather than silently encoding zeros.
    const { unknown } = buildCustomSet({ equipped_items: [{ slot: { type: "SHOULDERS" } }] });
    expect(unknown).toEqual(["SHOULDERS"]);
  });

  test("tolerates a payload with no equipped_items at all", () => {
    const { code } = buildCustomSet({} as EquipmentResponse);
    expect(code.split(" ")[2]!.split(",")).toHaveLength(OUTFIT_VALUE_COUNT);
  });
});

describe("formatTransmogReply", () => {
  const full = () =>
    buildCustomSet({
      equipped_items: [mog("HEAD", 101, "Helm of Testing"), mog("CHEST", 105, "Robe of Testing")],
    });

  test("carries the pasteable code and the import target", () => {
    const out = formatTransmogReply("Testchar", "argent-dawn", full());
    expect(out).toContain("/customset v1 101,0,0,0,105,");
    expect(out).toContain("/collected outfit import");
    expect(out).toContain("**Testchar**");
    expect(out).toContain("argent-dawn");
  });

  test("names what it captured, with readable slot labels", () => {
    const out = formatTransmogReply("Testchar", "argent-dawn", full());
    expect(out).toContain("Head — Helm of Testing");
    expect(out).toContain("Chest — Robe of Testing");
  });

  test("always states the illusion and staleness caveats", () => {
    const out = formatTransmogReply("Testchar", "argent-dawn", full());
    expect(out).toContain("illusion");
    expect(out).toContain("last logout");
  });

  test("counts equipped-but-untransmogged slots, and says nothing about empty ones", () => {
    // `full()` equips only head and chest, so the other 11 wire slots are EMPTY, not untransmogged
    // — a reply that called those a gap would be telling the user their look is broken when it
    // isn't (the off hand of any two-hander).
    const out = formatTransmogReply("Testchar", "argent-dawn", full());
    expect(out).not.toContain("not transmogged");

    const withBare = buildCustomSet({
      equipped_items: [mog("HEAD", 101, "Helm"), plain("CHEST")],
    });
    const out2 = formatTransmogReply("Testchar", "argent-dawn", withBare);
    expect(out2).toContain("1 equipped slot not transmogged");
    expect(out2).toContain("Chest");
  });

  test("an all-zero result says so instead of offering an empty outfit as a success", () => {
    const out = formatTransmogReply("Testchar", "argent-dawn", buildCustomSet({ equipped_items: [] }));
    expect(out).toContain("No transmogged slots found");
    // The bare-slot line would be noise on top of that, so it's suppressed.
    expect(out).not.toContain("slots not transmogged");
  });

  test("surfaces unrecognised slot types for reporting", () => {
    const r = buildCustomSet({
      equipped_items: [mog("HEAD", 1, "Helm"), { slot: { type: "SHOULDERS" } }],
    });
    expect(formatTransmogReply("Testchar", "argent-dawn", r)).toContain("SHOULDERS");
  });
});

describe("realmSlug", () => {
  test("lowercases and hyphenates spaces", () => {
    expect(realmSlug("Argent Dawn")).toBe("argent-dawn");
  });
  test("drops apostrophes without leaving a hyphen", () => {
    expect(realmSlug("Kil'jaeden")).toBe("kiljaeden");
    expect(realmSlug("Aman'Thul")).toBe("amanthul");
  });
  test("passes an existing slug through unchanged", () => {
    expect(realmSlug("argent-dawn")).toBe("argent-dawn");
  });
  test("strips accents to their base letter", () => {
    expect(realmSlug("Éonar")).toBe("eonar");
  });
  test("trims surrounding whitespace", () => {
    expect(realmSlug("  Silvermoon  ")).toBe("silvermoon");
  });
});
