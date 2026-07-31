// Bare icon name -> a URL the webview can put in an <img src>.
//
// The bundle stores the identity WoW itself uses ("inv_misc_coin_01") rather than a path or a
// FileDataID, so it needs resolving before anything can draw it (nazumods/wow#842). The images
// are packed into the exe at generation time and served by src-tauri/src/icons.rs; this is the
// only place that knows the scheme's name.
import { convertFileSrc } from "@tauri-apps/api/core";

// Matches icons::SCHEME. Tauri rewrites it per platform — http://wbicon.localhost/<name> on
// Windows, wbicon://localhost/<name> elsewhere — which is exactly what convertFileSrc does, so
// the URL is never assembled by hand here.
const SCHEME = "wbicon";

/**
 * The image URL for a bare icon name, or null when there is nothing to draw.
 *
 * A large share of bundle rows carry `icon: null` (DB2 has no icon for most retired and
 * internal currencies), so null in means null out is the NORMAL case, not an error. A name
 * that resolves here can still 404 — a handful are referenced but have no image anywhere —
 * which the <img> consumer handles as the same "no icon" outcome.
 */
export function iconUrl(name: string | null | undefined): string | null {
  if (!name) return null;
  return convertFileSrc(name, SCHEME);
}
