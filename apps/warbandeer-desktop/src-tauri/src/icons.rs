//! Turns the bundle's bare icon NAMES into images the webview can actually draw.
//!
//! `static-data.json` has carried names like `inv_misc_coin_01` on both its tables since it
//! landed, and a bare name is an identity the WoW client resolves internally — not a path, not
//! a FileDataID, and nothing a browser can load (nazumods/wow#842). This module closes that
//! gap for every icon-bearing surface at once rather than per column.
//!
//! The images are PACKED AT GENERATION TIME by `Tooling/update-static-data.ps1` and embedded
//! here, so resolution costs the app no network access — the property that made the data
//! bundle an `include_str!` in the first place holds unchanged. Only the ~440 icons the two
//! tables actually reference are packed, so the cost is a few hundred KB rather than the tens
//! of thousands of icons under `interface/icons/`.
//!
//! See `icons.bin`'s layout in the generator. Two distinct "no image" cases reach the UI and
//! both render the same way: a bundle entry whose `icon` is null (DB2 carries none), and a
//! name the CDN has no image for (packed as a zero-length entry so a rerun doesn't retry it).

use std::borrow::Cow;
use std::collections::HashMap;
use std::sync::OnceLock;

/// The packed icons, compiled in beside the data bundle they belong to.
const BLOB: &[u8] = include_bytes!("../data/icons.bin");

const MAGIC: &[u8] = b"WBICON1\0";

/// Scheme the webview loads icons over. Tauri serves this as `http://wbicon.localhost/<name>`
/// on Windows and `wbicon://localhost/<name>` elsewhere; the frontend builds neither by hand
/// (see `src/lib/icons.ts`).
pub const SCHEME: &str = "wbicon";

pub struct IconPack {
    /// Name -> JPEG bytes. A present-but-empty slice means "referenced by the bundle, but the
    /// source had no image under that name" — kept in the index so the generator can tell a
    /// known-dead name from one it has never tried.
    entries: HashMap<&'static str, &'static [u8]>,
}

impl IconPack {
    /// The JPEG for a bare icon name, or `None` when the name is unknown to the pack or known
    /// to have no image. Callers render both the same way, so they are deliberately not split.
    pub fn image(&self, name: &str) -> Option<&'static [u8]> {
        match self.entries.get(name) {
            Some(b) if !b.is_empty() => Some(b),
            _ => None,
        }
    }
}

fn read_u16(b: &[u8], at: usize) -> Option<u16> {
    b.get(at..at.checked_add(2)?)
        .map(|s| u16::from_le_bytes(s.try_into().expect("2-byte slice")))
}

fn read_u32(b: &[u8], at: usize) -> Option<u32> {
    b.get(at..at.checked_add(4)?)
        .map(|s| u32::from_le_bytes(s.try_into().expect("4-byte slice")))
}

/// Parse a packed blob. Split out from [`get`] the same way `staticdata::parse` is, so
/// malformed input is testable — the embedded asset is generated and CI-validated, so it
/// cannot actually fail in a shipped build.
fn parse(blob: &'static [u8]) -> Result<IconPack, String> {
    if blob.get(..MAGIC.len()) != Some(MAGIC) {
        return Err("icons.bin: not a packed icon blob (bad magic)".into());
    }
    let mut at = MAGIC.len();
    let count = read_u32(blob, at).ok_or("icons.bin: truncated header")? as usize;
    at += 4;

    let mut entries = HashMap::with_capacity(count);
    for i in 0..count {
        let name_len = read_u16(blob, at).ok_or_else(|| trunc(i))? as usize;
        at += 2;
        let name = blob
            .get(at..at.checked_add(name_len).ok_or_else(|| trunc(i))?)
            .ok_or_else(|| trunc(i))?;
        let name = std::str::from_utf8(name)
            .map_err(|e| format!("icons.bin: entry {i} has a non-utf8 name: {e}"))?;
        at += name_len;
        let offset = read_u32(blob, at).ok_or_else(|| trunc(i))? as usize;
        at += 4;
        let len = read_u32(blob, at).ok_or_else(|| trunc(i))? as usize;
        at += 4;

        let end = offset.checked_add(len).ok_or_else(|| trunc(i))?;
        let data = blob
            .get(offset..end)
            .ok_or_else(|| format!("icons.bin: '{name}' points past the end of the blob"))?;
        entries.insert(name, data);
    }
    Ok(IconPack { entries })
}

fn trunc(i: usize) -> String {
    format!("icons.bin: index is truncated at entry {i}")
}

/// The embedded pack, parsed once.
pub fn get() -> &'static IconPack {
    static PACK: OnceLock<IconPack> = OnceLock::new();
    PACK.get_or_init(|| parse(BLOB).expect("embedded icons.bin is malformed"))
}

/// Serve `<scheme>://localhost/<bare-icon-name>` out of the embedded pack.
///
/// A custom scheme rather than data URIs on the JS side: the bytes stay out of the DOM, and the
/// webview caches each icon once instead of re-parsing a base64 string per row. An unknown or
/// image-less name is a plain 404 — the frontend already has to render "no icon" for the many
/// bundle rows whose `icon` is null, so it needs no distinct signal here.
pub fn serve(request: &tauri::http::Request<Vec<u8>>) -> tauri::http::Response<Cow<'static, [u8]>> {
    serve_from(get(), request)
}

/// Serve a request out of a given pack. Split from [`serve`] the same way [`parse`] is split from
/// [`get`], so the decode-then-lookup is testable against a fixture pack — the embedded one carries
/// an image under none of its spaced names, so it cannot show the decode doing any work.
fn serve_from(
    pack: &IconPack,
    request: &tauri::http::Request<Vec<u8>>,
) -> tauri::http::Response<Cow<'static, [u8]>> {
    // Decoded, not taken raw: not every icon name is url-safe. A handful in the listfile carry
    // literal spaces ("ui_majorfaction_ vines"), which the frontend's convertFileSrc
    // percent-encodes, so an undecoded lookup would miss every one of them.
    let name = percent_encoding::percent_decode_str(request.uri().path().trim_start_matches('/'))
        .decode_utf8_lossy();
    match pack.image(&name) {
        Some(bytes) => tauri::http::Response::builder()
            .status(200)
            .header(tauri::http::header::CONTENT_TYPE, "image/jpeg")
            // The pack is compiled into the exe, so a given build's bytes for a name never
            // change; a new build is a new process with a fresh webview cache anyway.
            .header(
                tauri::http::header::CACHE_CONTROL,
                "public, max-age=31536000, immutable",
            )
            .body(Cow::Borrowed(bytes))
            .expect("static response builds"),
        None => tauri::http::Response::builder()
            .status(404)
            .body(Cow::Borrowed(&[][..]))
            .expect("static response builds"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a blob in the generator's format, so the parser is tested against the layout
    /// rather than against itself.
    fn pack(entries: &[(&str, &[u8])]) -> Vec<u8> {
        let mut out = Vec::from(MAGIC);
        out.extend_from_slice(&(entries.len() as u32).to_le_bytes());
        let mut offset = MAGIC.len() + 4;
        for (name, _) in entries {
            offset += 2 + name.len() + 8;
        }
        for (name, data) in entries {
            out.extend_from_slice(&(name.len() as u16).to_le_bytes());
            out.extend_from_slice(name.as_bytes());
            out.extend_from_slice(&(offset as u32).to_le_bytes());
            out.extend_from_slice(&(data.len() as u32).to_le_bytes());
            offset += data.len();
        }
        for (_, data) in entries {
            out.extend_from_slice(data);
        }
        out
    }

    fn leak(v: Vec<u8>) -> &'static [u8] {
        Vec::leak(v)
    }

    #[test]
    fn parses_a_packed_blob() {
        let blob = leak(pack(&[("a_icon", &[0xFF, 0xD8, 1]), ("b_icon", &[0xFF, 0xD8, 2])]));
        let p = parse(blob).expect("sample should parse");
        assert_eq!(p.entries.len(), 2);
        assert_eq!(p.image("a_icon"), Some(&[0xFF, 0xD8, 1][..]));
        assert_eq!(p.image("b_icon"), Some(&[0xFF, 0xD8, 2][..]));
    }

    #[test]
    fn zero_length_entry_is_none_not_empty() {
        // The generator's marker for "referenced, but the source has no such image". It must
        // read as absent, exactly like a bundle row whose icon is null.
        let blob = leak(pack(&[("gone", &[])]));
        let p = parse(blob).unwrap();
        assert!(p.entries.contains_key("gone"), "still indexed");
        assert_eq!(p.image("gone"), None);
    }

    #[test]
    fn unknown_and_empty_names_are_none() {
        let p = parse(leak(pack(&[("a_icon", &[0xFF, 0xD8])]))).unwrap();
        assert_eq!(p.image("nope"), None);
        assert_eq!(p.image(""), None);
    }

    #[test]
    fn bad_magic_is_an_error_not_a_panic() {
        assert!(parse(b"not a blob at all").is_err());
        assert!(parse(b"").is_err());
    }

    #[test]
    fn truncated_blob_is_an_error_not_a_panic() {
        let full = pack(&[("a_icon", &[0xFF, 0xD8, 1]), ("b_icon", &[0xFF, 0xD8, 2])]);
        // Every prefix must fail cleanly rather than index out of bounds.
        for cut in 0..full.len() {
            assert!(
                parse(leak(full[..cut].to_vec())).is_err(),
                "prefix of {cut} bytes should not parse"
            );
        }
        assert!(parse(leak(full)).is_ok(), "the whole blob still parses");
    }

    #[test]
    fn entry_pointing_past_the_blob_is_an_error() {
        let mut blob = pack(&[("a_icon", &[0xFF, 0xD8])]);
        // Overwrite the entry's length with something the data section cannot satisfy.
        let at = MAGIC.len() + 4 + 2 + "a_icon".len() + 4;
        blob[at..at + 4].copy_from_slice(&9999u32.to_le_bytes());
        assert!(parse(leak(blob)).is_err());
    }

    fn serve_path(path: &str) -> tauri::http::Response<Cow<'static, [u8]>> {
        serve_path_on(get(), path)
    }

    fn serve_path_on(
        pack: &IconPack,
        path: &str,
    ) -> tauri::http::Response<Cow<'static, [u8]>> {
        let request = tauri::http::Request::builder()
            .uri(format!("http://wbicon.localhost{path}"))
            .body(Vec::new())
            .expect("test request builds");
        serve_from(pack, &request)
    }

    #[test]
    fn serves_a_packed_icon_and_404s_the_rest() {
        let icon = get()
            .entries
            .iter()
            .find(|(_, b)| !b.is_empty())
            .map(|(n, _)| *n)
            .expect("the pack has at least one image");
        let ok = serve_path(&format!("/{icon}"));
        assert_eq!(ok.status(), 200);
        assert_eq!(ok.headers()["content-type"], "image/jpeg");
        assert!(!ok.body().is_empty());

        assert_eq!(serve_path("/no_such_icon_at_all").status(), 404);
        assert_eq!(serve_path("/").status(), 404);
    }

    #[test]
    fn serves_a_percent_encoded_name() {
        // The listfile carries names with literal spaces, which the frontend encodes as %20. A
        // FIXTURE with an image under such a name — the embedded pack has one under NONE of its
        // spaced names, so it can't show the decode doing anything — makes the decode load-bearing:
        // the encoded path resolves only because serve() turns %20 back into a space before the
        // lookup. Delete the percent_decode_str call and the raw "%20" name misses the index, 404.
        let p = parse(leak(pack(&[("ui_majorfaction_ vines", &[0xFF, 0xD8, 7])]))).unwrap();
        let got = serve_path_on(&p, "/ui_majorfaction_%20vines");
        assert_eq!(got.status(), 200, "the encoded space must resolve to the spaced entry");
        assert_eq!(got.headers()["content-type"], "image/jpeg");
        assert_eq!(got.body().as_ref(), &[0xFF, 0xD8, 7][..]);
    }

    #[test]
    fn embedded_pack_parses_and_is_populated() {
        // Guards against committing a truncated or eol-normalized asset — `* text eol=lf`
        // collapses CRLF pairs inside the packed JPEGs unless .gitattributes marks *.bin
        // binary, which silently shortens the file.
        let p = get();
        assert!(
            p.entries.len() > 300,
            "expected the packed icon set, got {}",
            p.entries.len()
        );
    }

    #[test]
    fn embedded_pack_covers_every_icon_the_bundle_references() {
        // The two artifacts are generated together from the same name set; a bundle icon with
        // no pack entry means they were committed out of step.
        let bundle = crate::staticdata::get();
        let referenced = bundle
            .currencies
            .values()
            .filter_map(|c| c.icon.as_deref())
            .chain(bundle.achievements.values().filter_map(|a| a.icon.as_deref()));
        for name in referenced {
            assert!(
                p_contains(name),
                "'{name}' is referenced by static-data.json but absent from icons.bin"
            );
        }
    }

    fn p_contains(name: &str) -> bool {
        get().entries.contains_key(name)
    }

    #[test]
    fn embedded_pack_entries_are_jpegs() {
        // Every non-empty entry must start with the JPEG SOI marker. Catches an error page or
        // a placeholder having been packed in place of an image.
        let p = get();
        let mut available = 0;
        for (name, bytes) in &p.entries {
            if bytes.is_empty() {
                continue;
            }
            available += 1;
            assert!(
                bytes.len() > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8,
                "'{name}' is not a JPEG"
            );
        }
        assert!(
            available > 300,
            "expected most icons to have an image, got {available}"
        );
    }

    #[test]
    fn embedded_pack_resolves_a_real_achievement_icon() {
        // 16585 "Loremaster of the Dragon Isles" — the same long-settled id staticdata's tests
        // pin, walked end to end: tracked id -> bundle icon name -> packed image.
        let icon = crate::staticdata::get()
            .achievement(16585)
            .and_then(|a| a.icon.as_deref())
            .expect("16585 should carry an icon name");
        assert!(
            get().image(icon).is_some(),
            "'{icon}' should resolve to a packed image"
        );
    }
}
