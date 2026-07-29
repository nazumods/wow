import { config } from "../config";
import { blizzardToken } from "./blizzard";
import { realmExists } from "./realm";

// Build a `/customset v1 …` outfit import string from a character's equipment, for the case the
// in-game path (#819) structurally can't reach: someone you can't inspect — offline, another
// realm, or a name pasted into chat.
//
// The equipment endpoint hands back exactly what the format encodes: each equipped item carries a
// `transmog` object with `item_modified_appearance_id` / `second_item_modified_appearance_id`,
// which ARE source ids. No id translation, no appearance lookup.

/**
 * Wire order of the `/customset v1` format, as Blizzard slot-type strings.
 *
 * **This must mirror `Warbandeer_Collected/outfitcodec.lua` exactly** — its decoder refuses any
 * value count but 17, so a layout that drifts produces a string the addon rejects outright rather
 * than one that renders slightly wrong. 13 slots, plus the shoulder and main-hand secondaries,
 * plus the two illusions.
 *
 * The Lua side indexes by `INVSLOT_*`; the REST side names slots. `SHIRT` is the API's name for
 * what the addon calls `INVSLOT_BODY`, and `HANDS` for `INVSLOT_HAND` — the two places the
 * vocabularies differ.
 */
const SLOT_ORDER = [
  "HEAD",
  "SHOULDER",
  "BACK",
  "CHEST",
  "SHIRT",
  "TABARD",
  "WRIST",
  "HANDS",
  "WAIST",
  "LEGS",
  "FEET",
  "MAIN_HAND",
  "OFF_HAND",
] as const;

/** Slots that emit a secondary appearance after their primary (shoulder, main hand). */
const SECONDARY_SLOTS = new Set<string>(["SHOULDER", "MAIN_HAND"]);
/** Slots that emit an illusion after their appearance (both weapons). */
const ILLUSION_SLOTS = new Set<string>(["MAIN_HAND", "OFF_HAND"]);

/** The decoder rejects any other count outright. */
export const OUTFIT_VALUE_COUNT = 17;

export interface EquipmentItem {
  slot?: { type?: string; name?: string };
  transmog?: {
    item?: { name?: string };
    second_item?: { name?: string };
    item_modified_appearance_id?: number;
    second_item_modified_appearance_id?: number;
  };
}

export interface EquipmentResponse {
  equipped_items?: EquipmentItem[];
}

export interface OutfitResult {
  /** The full `/customset v1 …` line, ready to paste into `/collected outfit import`. */
  code: string;
  /** Transmogged slots, in wire order, with the item name the payload supplied. */
  named: { slot: string; name: string }[];
  /**
   * Slots holding an item that simply isn't transmogged. Encoded as 0, and the look really is
   * incomplete — the character shows that item's own appearance, which the payload can't identify.
   */
  bare: string[];
  /**
   * Slots with nothing equipped at all. Also encoded as 0, but nothing is missing: a two-hander
   * leaves the off hand empty, and plenty of characters wear no shirt or tabard. Kept apart from
   * `bare` so the reply doesn't call a complete look incomplete.
   */
  empty: string[];
  /**
   * Slot types the payload contained that the wire format has no place for. Neck, rings and
   * trinkets are expected here and filtered out; anything else means the slot vocabulary has
   * drifted from what this file assumes, which is worth surfacing rather than swallowing.
   */
  unknown: string[];
}

/** Slots the character can equip that the transmog format deliberately doesn't carry. */
const NOT_TRANSMOGGABLE = new Set<string>([
  "NECK",
  "FINGER_1",
  "FINGER_2",
  "TRINKET_1",
  "TRINKET_2",
  "RANGED",
]);

/**
 * Encode an equipment payload as the `/customset v1` string.
 *
 * Pure — no network, no config — so the layout can be tested against a fixture and any drift from
 * the addon's format is caught in CI rather than in Discord.
 *
 * Two values are always 0, and that is deliberate rather than missing work:
 * - **Illusions.** The payload carries no visual-enchant field, so both illusion slots encode 0.
 *   The addon's decoder clamps illusions to 0 anyway, so nothing is lost that could be carried.
 * - **Untransmogged slots.** The `transmog` object is simply absent when a slot isn't transmogged;
 *   the visible look is then the item's own appearance, and the equipment payload gives no source
 *   id for it. Resolving one would cost an extra Game Data call per slot, so v1 emits 0 and names
 *   the gap in the reply instead of quietly shipping a partial look as if it were complete.
 */
export function buildCustomSet(equipment: EquipmentResponse): OutfitResult {
  const bySlot = new Map<string, EquipmentItem>();
  const unknown: string[] = [];
  for (const item of equipment.equipped_items ?? []) {
    const type = item.slot?.type;
    if (!type) continue;
    if ((SLOT_ORDER as readonly string[]).includes(type)) bySlot.set(type, item);
    else if (!NOT_TRANSMOGGABLE.has(type)) unknown.push(type);
  }

  const values: number[] = [];
  const named: { slot: string; name: string }[] = [];
  const bare: string[] = [];
  const empty: string[] = [];

  for (const slot of SLOT_ORDER) {
    const item = bySlot.get(slot);
    const tm = item?.transmog;
    const primary = tm?.item_modified_appearance_id ?? 0;
    values.push(primary);
    if (SECONDARY_SLOTS.has(slot)) {
      // The REST payload echoes the PRIMARY here when a slot has no distinct secondary
      // appearance, where the in-game producer (#819) emits 0 — and 0 is what this format means
      // by "no secondary". Normalising keeps the two producers emitting the same string for the
      // same look, which is the property that makes them interchangeable.
      const secondary = tm?.second_item_modified_appearance_id ?? 0;
      values.push(secondary === primary ? 0 : secondary);
    }
    if (ILLUSION_SLOTS.has(slot)) values.push(0);

    if (primary > 0) named.push({ slot, name: tm?.item?.name ?? `appearance ${primary}` });
    else if (item) bare.push(slot);
    else empty.push(slot);
  }

  return { code: `/customset v1 ${values.join(",")}`, named, bare, empty, unknown };
}

/**
 * Blizzard realm slug: lowercase, spaces and underscores to hyphens, apostrophes and accents
 * dropped. `Argent Dawn` → `argent-dawn`, `Aman'Thul` → `amanthul`, `Kil'jaeden` → `kiljaeden`.
 * A slug passed in already (`argent-dawn`) survives unchanged.
 */
export function realmSlug(realm: string): string {
  return realm
    .trim()
    .toLowerCase()
    // NFD splits an accented letter into base + combining mark; the final filter then drops the
    // mark, so `Ysondre` survives and `Éonar` becomes `eonar`. Apostrophes go before the space
    // rule so `Kil'jaeden` doesn't become `kil-jaeden`.
    .normalize("NFD")
    .replace(/['’]/g, "")
    .replace(/[\s_]+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

const SLOT_LABEL: Record<string, string> = {
  HEAD: "Head",
  SHOULDER: "Shoulder",
  BACK: "Back",
  CHEST: "Chest",
  SHIRT: "Shirt",
  TABARD: "Tabard",
  WRIST: "Wrist",
  HANDS: "Hands",
  WAIST: "Waist",
  LEGS: "Legs",
  FEET: "Feet",
  MAIN_HAND: "Main hand",
  OFF_HAND: "Off hand",
};

/**
 * The Discord reply: the pasteable string, what it captured, and — deliberately — what it didn't.
 *
 * Every caveat is stated rather than left for someone to discover by wearing the result. The
 * staleness note in particular: profile data is a logout snapshot, so the most likely person to
 * look "wrong" is the one currently online, which is exactly who you'd have just looked up.
 *
 * Pure, so the wording is testable and can't drift from what the encoder actually did.
 */
export function formatTransmogReply(character: string, realm: string, r: OutfitResult): string {
  const fence = "```";
  const lines: string[] = [
    `**${character}** — ${realm}`,
    `${fence}\n${r.code}\n${fence}`,
    "Paste into `/collected outfit import`.",
    "",
  ];

  if (r.named.length === 0) {
    lines.push(
      "⚠️ **No transmogged slots found**, so every value is 0 — the string will import as an empty outfit.",
      "That means either this character transmogs nothing, or their gear is hidden from the profile API.",
    );
  } else {
    lines.push(`**Captured ${r.named.length} slot${r.named.length === 1 ? "" : "s"}:** ` +
      r.named.map((n) => `${SLOT_LABEL[n.slot] ?? n.slot} — ${n.name}`).join(" · "));
  }

  // Only an EQUIPPED slot with no transmog leaves a gap. An empty slot — a two-hander's off hand,
  // no shirt, no tabard — encodes 0 because there is nothing there, and saying "incomplete" about
  // it would be wrong.
  if (r.bare.length > 0 && r.named.length > 0) {
    lines.push(
      `ℹ️ ${r.bare.length} equipped slot${r.bare.length === 1 ? "" : "s"} not transmogged ` +
        `(${r.bare.map((s) => SLOT_LABEL[s] ?? s).join(", ")}) — encoded as 0, so the look is incomplete.`,
    );
  }
  lines.push(
    "ℹ️ Weapon illusions aren't in the profile data, so both illusion values are 0.",
    "ℹ️ Profile data is a snapshot from the character's **last logout** — someone online right now " +
      "reports what they wore last session.",
  );
  if (r.unknown.length > 0) {
    lines.push(`⚠️ Unrecognised equipment slots: ${r.unknown.join(", ")} — please report this.`);
  }
  return lines.join("\n");
}

export class TransmogLookupError extends Error {
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message);
  }
}

/**
 * Fetch a character's equipment and encode it.
 *
 * Profile data is a **snapshot taken at logout**, so a character who is online right now reports
 * what they wore last session. Callers should say so rather than let someone debug a "wrong"
 * string that is merely stale.
 */
export async function fetchTransmog(character: string, realm: string): Promise<OutfitResult> {
  const slug = realmSlug(realm);
  const name = encodeURIComponent(character.trim().toLowerCase());
  const url =
    `https://${config.region}.api.blizzard.com/profile/wow/character/${slug}/${name}/equipment` +
    `?namespace=profile-${config.region}&locale=en_US`;

  const res = await fetch(url, { headers: { Authorization: `Bearer ${await blizzardToken()}` } });
  if (res.status === 404) {
    // Blizzard returns the same 404 for a character that doesn't exist and a realm that doesn't
    // exist (verified against the live API), so a single message would have to name both causes
    // and let the reader work it out. One of them is separable: ask about the realm directly.
    // Only on this path, so a successful lookup never pays for the extra call.
    if (!(await realmExists(slug))) {
      throw new TransmogLookupError(
        `No realm **${slug}** in ${config.region.toUpperCase()}. ` +
          `Check the realm name — it's the realm the character is *on*, spelled as in game ` +
          `(e.g. \`Argent Dawn\`).`,
        404,
      );
    }
    // The realm checked out, so this is about the character — but "never logged in" and "no such
    // character" really are indistinguishable here, so both are named rather than guessed between.
    throw new TransmogLookupError(
      `No character **${character}** on **${slug}** (${config.region.toUpperCase()}). ` +
        `Check the spelling — a character who has never logged in since the profile API last ` +
        `indexed them also 404s.`,
      404,
    );
  }
  if (!res.ok) {
    throw new TransmogLookupError(
      `Blizzard returned ${res.status} for **${character}-${slug}**.`,
      res.status,
    );
  }
  return buildCustomSet((await res.json()) as EquipmentResponse);
}
