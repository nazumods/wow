import { config } from "../config";

// The Darkmoon Faire opens at 00:01 realm time on the first Sunday of each
// month and runs for one week. Realm time is modeled by config.dmfTimezone.
export interface DmfWindow {
  start: Date;
  end: Date;
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

export function dmfWindow(year: number, monthIndex: number): DmfWindow {
  let day = 1;
  while (new Date(Date.UTC(year, monthIndex, day)).getUTCDay() !== 0) day++;
  const start = zonedToUtc(year, monthIndex, day, 0, 1, config.dmfTimezone);
  return { start, end: new Date(start.getTime() + WEEK_MS) };
}

export function currentOrNextDmf(now = new Date()): { active: boolean; window: DmfWindow } {
  const thisMonth = dmfWindow(now.getUTCFullYear(), now.getUTCMonth());
  if (now < thisMonth.start) return { active: false, window: thisMonth };
  if (now < thisMonth.end) return { active: true, window: thisMonth };
  return { active: false, window: dmfWindow(now.getUTCFullYear(), now.getUTCMonth() + 1) };
}
