import { config } from "../config";

// Blizzard resets are fixed UTC times: US daily 15:00 UTC, weekly Tuesday 15:00 UTC;
// EU daily 04:00 UTC, weekly Wednesday 04:00 UTC.
const RESETS = {
  us: { hourUtc: 15, weeklyDayUtc: 2 }, // Tuesday
  eu: { hourUtc: 4, weeklyDayUtc: 3 }, // Wednesday
} as const;

const DAY_MS = 24 * 3600 * 1000;

export function nextDailyReset(now = new Date()): Date {
  const { hourUtc } = RESETS[config.region];
  const reset = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hourUtc),
  );
  if (reset <= now) reset.setUTCDate(reset.getUTCDate() + 1);
  return reset;
}

export function nextWeeklyReset(now = new Date()): Date {
  const { hourUtc, weeklyDayUtc } = RESETS[config.region];
  const reset = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hourUtc),
  );
  const daysAhead = (weeklyDayUtc - reset.getUTCDay() + 7) % 7;
  reset.setUTCDate(reset.getUTCDate() + daysAhead);
  if (reset <= now) reset.setUTCDate(reset.getUTCDate() + 7);
  return reset;
}

export function lastWeeklyReset(now = new Date()): Date {
  return new Date(nextWeeklyReset(now).getTime() - 7 * DAY_MS);
}
