// Sort helpers for the character-select order list — ported from the standalone
// WarbandeerCharacterSort app's SortMode/CharacterSorter. Unresolved characters (no
// matching Warbandeer record) always sort to the end regardless of mode, since there's
// nothing meaningful to sort them by until the owning character next logs in.
import type { OrderLine, ResolvedCharacter } from "./types";

export type SortMode =
  | "alphaAsc"
  | "alphaDesc"
  | "levelDesc"
  | "levelAsc"
  | "classRole"
  | "profession"
  | "memory";

// English gathering professions — a crafting profession always outranks these as a
// character's sort identity. (Assumes an English client, same as the Tank/Healer/DPS
// role mapping the backend already applies.)
const GATHERING = new Set(["Herbalism", "Mining", "Skinning"]);

export function isGathering(profession: string): boolean {
  return GATHERING.has(profession);
}

/** True when the character has two crafting professions and the user must pick which
 * one is the sort identity — there's no automatic priority between two crafts. */
export function isAmbiguous(c: ResolvedCharacter): boolean {
  return (
    c.profession1 !== "" &&
    c.profession2 !== "" &&
    !isGathering(c.profession1) &&
    !isGathering(c.profession2)
  );
}

function isUnresolved(c: ResolvedCharacter): boolean {
  return c.classId === 0;
}

const collator = new Intl.Collator(undefined, { sensitivity: "base" });
const cmpName = (a: ResolvedCharacter, b: ResolvedCharacter) => collator.compare(a.name, b.name);

/** A character's professions ordered by sort priority, ignoring slot order: a
 * user-remembered primary wins, then crafting outranks gathering, then alphabetical.
 * Empty slots sort after real names so a lone profession is always "first". */
function ordered(
  c: ResolvedCharacter,
  professionPrimary: ReadonlyMap<string, string>,
): [string, string] {
  const a = c.profession1;
  const b = c.profession2;
  if (a === "") return [b, a];
  if (b === "") return [a, b];

  const primary = professionPrimary.get(c.realmGuid);
  if (primary !== undefined) {
    if (collator.compare(primary, a) === 0) return [a, b];
    if (collator.compare(primary, b) === 0) return [b, a];
  }

  const aGathers = isGathering(a);
  const bGathers = isGathering(b);
  if (aGathers !== bGathers) return aGathers ? [b, a] : [a, b];

  return collator.compare(a, b) <= 0 ? [a, b] : [b, a];
}

export function applySort(
  characters: readonly ResolvedCharacter[],
  mode: SortMode,
  professionPrimary: ReadonlyMap<string, string> = new Map(),
): ResolvedCharacter[] {
  const resolved = characters.filter((c) => !isUnresolved(c));
  const unresolved = [...characters.filter(isUnresolved)].sort((a, b) =>
    a.realmGuid < b.realmGuid ? -1 : a.realmGuid > b.realmGuid ? 1 : 0,
  );

  let sorted: ResolvedCharacter[];
  switch (mode) {
    case "alphaAsc":
      sorted = [...resolved].sort(cmpName);
      break;
    case "alphaDesc":
      sorted = [...resolved].sort((a, b) => -cmpName(a, b));
      break;
    case "levelDesc":
      sorted = [...resolved].sort((a, b) => b.level - a.level || cmpName(a, b));
      break;
    case "levelAsc":
      sorted = [...resolved].sort((a, b) => a.level - b.level || cmpName(a, b));
      break;
    case "classRole":
      sorted = [...resolved].sort(
        (a, b) => collator.compare(a.className, b.className) || cmpName(a, b),
      );
      break;
    case "profession":
      // Slot order is just learn order, so group by profession regardless of slot.
      // Profession-less characters go after those with one.
      sorted = [...resolved].sort((a, b) => {
        const [aFirst, aSecond] = ordered(a, professionPrimary);
        const [bFirst, bSecond] = ordered(b, professionPrimary);
        return (
          (aFirst === "" ? 1 : 0) - (bFirst === "" ? 1 : 0) ||
          collator.compare(aFirst, bFirst) ||
          collator.compare(aSecond, bSecond) ||
          cmpName(a, b)
        );
      });
      break;
    default:
      sorted = [...resolved];
      break;
  }

  return [...sorted, ...unresolved];
}

/** Applies `sortFn` only to the characters not in `locked` (by realmGuid); every locked
 * character is left in its current slot untouched — sorts "go around" a lock rather than
 * moving it. Works with any of the sort functions above, including `applyRememberedOrder`,
 * since it only ever calls `sortFn` with the unlocked subset. */
export function applyLocked(
  characters: readonly ResolvedCharacter[],
  locked: ReadonlySet<string>,
  sortFn: (unlocked: ResolvedCharacter[]) => ResolvedCharacter[],
): ResolvedCharacter[] {
  const isLocked = characters.map((c) => locked.has(c.realmGuid));
  const sortedUnlocked = sortFn(characters.filter((c) => !locked.has(c.realmGuid)));
  let cursor = 0;
  return characters.map((c, i) => (isLocked[i] ? c : sortedUnlocked[cursor++]));
}

export interface AssignedSlot {
  position: number;
  /** The character at this position, or `null` for a locked-empty-slot reservation. */
  c: ResolvedCharacter | null;
}

/** Assigns sequential position numbers to `characters`, reserving one for each locked-gap
 * rank (a rank is "this many characters precede it" — the same rank a locked character's
 * array index preserves through a sort, but for a slot with nothing in it). Used both to
 * build what gets written to disk (a `null` slot is simply omitted, leaving its number
 * permanently vacant) and to drive the "Slot #" display once anything is locked — with an
 * empty `lockedGapRanks`, this just numbers `characters` 1..N with no gaps, same as before
 * locking existed. */
export function assignPositions(
  characters: readonly ResolvedCharacter[],
  lockedGapRanks: ReadonlySet<number>,
): AssignedSlot[] {
  const result: AssignedSlot[] = [];
  let position = 1;
  for (let rank = 0; rank <= characters.length; rank++) {
    if (lockedGapRanks.has(rank)) {
      result.push({ position, c: null });
      position++;
    }
    if (rank < characters.length) {
      result.push({ position, c: characters[rank] });
      position++;
    }
  }
  return result;
}

/** Reorders `characters` to match a previously remembered order (by realmGuid). A
 * character not present in the memory — created since it was last remembered — keeps its
 * current relative position, appended after every remembered one, rather than being
 * dropped or shuffled to an arbitrary spot. */
export function applyRememberedOrder(
  characters: readonly ResolvedCharacter[],
  remembered: readonly OrderLine[],
): ResolvedCharacter[] {
  const index = new Map(remembered.map((r, i) => [r.realmGuid, i]));
  const known = characters.filter((c) => index.has(c.realmGuid));
  const unknown = characters.filter((c) => !index.has(c.realmGuid));
  known.sort((a, b) => index.get(a.realmGuid)! - index.get(b.realmGuid)!);
  return [...known, ...unknown];
}

// --- Remembered profession-sort choices (localStorage — the webview already has a
// persistent profile, so no need for a Rust-side %APPDATA% file like the standalone
// WPF app needed). Keyed by realmGuid; discarded (and re-asked) if the profession pair
// changes, same as the standalone app's SortPreferences.ValidPrimaryFor. ---

interface StoredChoice {
  profession1: string;
  profession2: string;
  primary: string;
}

const STORAGE_KEY = "warbandeer-desktop:profession-primary:v1";

function loadChoices(): Record<string, StoredChoice> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function saveChoices(choices: Record<string, StoredChoice>) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(choices));
}

/** The remembered primary for this character, or undefined if none/stale (profession
 * pair changed since the choice was recorded). */
export function validPrimaryFor(realmGuid: string, prof1: string, prof2: string): string | undefined {
  const choice = loadChoices()[realmGuid];
  if (!choice) return undefined;
  const samePair =
    (choice.profession1 === prof1 && choice.profession2 === prof2) ||
    (choice.profession1 === prof2 && choice.profession2 === prof1);
  return samePair ? choice.primary : undefined;
}

export function rememberPrimary(realmGuid: string, prof1: string, prof2: string, primary: string) {
  const choices = loadChoices();
  choices[realmGuid] = { profession1: prof1, profession2: prof2, primary };
  saveChoices(choices);
}

/** Build the professionPrimary map `applySort`'s profession mode needs, from every
 * ambiguous character's remembered (or just-answered) choice. */
export function professionPrimaryMap(characters: readonly ResolvedCharacter[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const c of characters) {
    if (!isAmbiguous(c)) continue;
    const primary = validPrimaryFor(c.realmGuid, c.profession1, c.profession2);
    if (primary) map.set(c.realmGuid, primary);
  }
  return map;
}
