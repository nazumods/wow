// Number/gold formatting helpers matching the addon's presentation.

// BreakUpLargeNumbers — group digits with thousands separators (en-US, as WoW does).
export function breakUpLargeNumbers(n: number): string {
  return Math.trunc(n).toLocaleString("en-US");
}

// Copper -> gold (integer), the unit the Overview cards display.
export function copperToGold(copper: number): number {
  return Math.floor(copper / 10000);
}

export function goldText(copper: number): string {
  return breakUpLargeNumbers(copperToGold(copper)) + "g";
}

export function hoursText(seconds: number): string {
  return breakUpLargeNumbers(Math.floor(seconds / 3600)) + " hrs";
}

export function bytesText(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
