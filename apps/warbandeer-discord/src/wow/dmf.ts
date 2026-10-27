import { config } from "../config";

// The Darkmoon Faire opens at 00:01 realm time on the first Sunday of each
// month and runs for one week. Realm time is modeled by config.dmfTimezone.
export interface DmfWindow {
  start: Date;
  end: Date;
  // The realm-local month this faire belongs to (monthIndex is 0-based). The UTC month of
  // `start` can differ for zones east of UTC, so dedup keys must come from these.
  year: number;
  monthIndex: number;
}

const WEEK_MS = 7 * 24 * 3600 * 1000;

// Wall-clock parts of `date` as seen in timezone `tz`.
function wallClock(date: Date, tz: string) {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    hourCycle: "h23",
  });
  const p = Object.fromEntries(fmt.formatToParts(date).map((x) => [x.type, x.value]));
  return { y: +p.year!, mo: +p.month! - 1, d: +p.day!, h: +p.hour!, mi: +p.minute! };
}

// UTC instant for a wall-clock time in an IANA timezone (two-pass DST correction).
function zonedToUtc(y: number, mo: number, d: number, h: number, mi: number, tz: string): Date {
  const target = Date.UTC(y, mo, d, h, mi);
  let ts = target;
  for (let i = 0; i < 2; i++) {
    const w = wallClock(new Date(ts), tz);
    ts += target - Date.UTC(w.y, w.mo, w.d, w.h, w.mi);
  }
  return new Date(ts);
}

export function dmfWindow(
  year: number,
  monthIndex: number,
  tz: string = config.dmfTimezone,
): DmfWindow {
  // Normalize overflow (monthIndex 12 -> January of the next year).
  const first = new Date(Date.UTC(year, monthIndex, 1));
  const y = first.getUTCFullYear();
  const mo = first.getUTCMonth();
  let day = 1;
  while (new Date(Date.UTC(y, mo, day)).getUTCDay() !== 0) day++;
  const start = zonedToUtc(y, mo, day, 0, 1, tz);
  return { start, end: new Date(start.getTime() + WEEK_MS), year: y, monthIndex: mo };
}

// Dedup key for a faire: realm-local "YYYY-M" (e.g. "2026-11").
export function dmfKey(window: DmfWindow): string {
  return `${window.year}-${window.monthIndex + 1}`;
}

export function currentOrNextDmf(
  now = new Date(),
  tz: string = config.dmfTimezone,
): { active: boolean; window: DmfWindow } {
  // Pick the month by realm-local wall clock, not UTC: east of UTC the local month can
  // already have rolled over while UTC is still on the previous one.
  const local = wallClock(now, tz);
  const thisMonth = dmfWindow(local.y, local.mo, tz);
  if (now < thisMonth.start) return { active: false, window: thisMonth };
  if (now < thisMonth.end) return { active: true, window: thisMonth };
  return { active: false, window: dmfWindow(local.y, local.mo + 1, tz) };
}
