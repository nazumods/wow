//! The per-character currency table. Mirrors the currency columns of the in-game Summary view
//! (`Warbandeer/views/summaryCol/{crests,catalyst,voidcore,manacrystal,dundun,cofferKey,
//! fieldaccolade,unalloyedabundance,gold}.lua`) as one grid: a row per character, a column per
//! currency the broker persists (nazumods/wow#884).
//!
//! Everything except the column ORDER is data-driven. Column names and icons come from the
//! bundled `CurrencyTypes` extract, joined through `currencyFields` — the broker's field-name →
//! currency-id map, which is the only thing that connects a save's `toon.currency.HeroDawncrest`
//! to the bundle's `"3345"`. Nothing here hand-maintains a currency list.

use crate::model::{CharDb, Character, CurrencyValue, GOLD_FIELD};
use crate::staticdata::StaticData;
use serde::Serialize;

/// Column order, mirroring the order the in-game view loads its currency columns in
/// (`Warbandeer.toc`), with gold last as it is there.
///
/// This is the app's own presentation, exactly as `EXPANSION_ORDER` is — the bundle emits ids
/// only, no order and no labels. A broker field the bundle knows but this list doesn't is
/// APPENDED rather than dropped, so adding a currency to the addon surfaces a column here
/// instead of silently vanishing.
const CURRENCY_ORDER: [&str; 10] = [
    "HeroDawncrest",
    "MythDawncrest",
    "Catalyst",
    "NebulousVoidcore",
    "UntaintedManaCrystal",
    "ShardOfDundun",
    "RestoredCofferKey",
    "CofferKeyShard",
    "FieldAccolade",
    "UnalloyedAbundance",
];

/// How a column's quantities render. Carried on the column — like each in-game column's own
/// `getData` formatter — so the frontend never needs to know which field is which.
#[derive(Serialize, PartialEq, Eq, Clone, Copy, Debug)]
#[serde(rename_all = "lowercase")]
pub enum ColumnFormat {
    /// `GetMoney()` copper: formatted as gold, and a zero is real money information, not the
    /// captured-nothing a count's em-dash marks.
    Money,
    /// An ordinary currency amount.
    Count,
}

/// App-shipped stand-in icons, by currency id, for the headers the packed set can never carry.
/// Keyed by id rather than by DB2's icon-name string because the id is stable and lint-gated
/// (`currency.id` in lint-stale-ids.ps1) while the art name regenerates weekly — a re-art would
/// silently orphan a name-keyed entry. The `wb:` names resolve in the frontend's own asset map
/// (`lib/icons.ts`), never through the `wbicon` scheme.
fn standin_icon(id: u32) -> Option<&'static str> {
    match id {
        // Untainted Mana-Crystals: DB2's icon name carries a literal space and the CDN has no
        // image under any spelling of it (#883) — the app ships the addon's own TGA instead.
        3356 => Some("wb:manacrystal"),
        _ => None,
    }
}

/// One column: a broker field joined to its bundled display metadata.
#[derive(Serialize, PartialEq, Debug)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyColumn {
    /// The broker field name — also the key the frontend uses for `{#each}`.
    pub field: String,
    /// The currency's real name from DB2, so no labels are hand-maintained here. Falls back to
    /// the field name if the bundle can't resolve it, keeping the skew visible rather than blank.
    pub name: String,
    /// Bare icon name for `iconUrl()` — or a `wb:`-prefixed app asset. `None` when DB2 carries
    /// no icon; the frontend reserves the box either way.
    pub icon: Option<String>,
    pub format: ColumnFormat,
}

/// One character's value for one column.
///
/// `quantity: None` means NEVER CAPTURED, which is normal rather than an error and renders
/// differently from a captured zero: `GetCurrencyInfo` returns nil for an undiscovered
/// currency, and the broker skips its max-level-only fields entirely for a levelling character.
#[derive(Serialize, Default, PartialEq, Debug)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyCell {
    pub quantity: Option<f64>,
    pub earned: f64,
    pub max: f64,
    pub weekly_max: f64,
    pub capped: bool,
}

/// One character's row, cells parallel to [`Currencies::columns`].
#[derive(Serialize, PartialEq, Debug)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyRow {
    /// Unique by construction — `db.characters` is keyed by it — so it is also the row key.
    pub name: String,
    pub class_key: String,
    pub level: i64,
    pub cells: Vec<CurrencyCell>,
}

#[derive(Serialize, PartialEq, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Currencies {
    pub columns: Vec<CurrencyColumn>,
    pub rows: Vec<CurrencyRow>,
}

/// The columns to render: [`CURRENCY_ORDER`] first, then anything else the bundle maps, sorted
/// by name so the tail is stable. Gold is appended last, as the in-game view places it.
fn build_columns(bundle: &StaticData) -> Vec<CurrencyColumn> {
    let mut extra: Vec<&str> = bundle
        .currency_fields
        .keys()
        .map(String::as_str)
        .filter(|f| !CURRENCY_ORDER.contains(f))
        .collect();
    extra.sort_unstable();

    let mut columns: Vec<CurrencyColumn> = CURRENCY_ORDER
        .iter()
        .copied()
        .chain(extra)
        // A name in CURRENCY_ORDER that the bundle no longer maps is dropped: the broker
        // retired the field, so there is no data and no metadata for a column of it.
        .filter_map(|field| {
            let id = bundle.currency_field(field)?;
            let meta = bundle.currency(id);
            Some(CurrencyColumn {
                field: field.to_string(),
                name: meta.map_or_else(|| field.to_string(), |m| m.name.clone()),
                icon: standin_icon(id)
                    .map(str::to_string)
                    .or_else(|| meta.and_then(|m| m.icon.clone())),
                format: ColumnFormat::Count,
            })
        })
        .collect();

    // Gold has no currency id — it is `GetMoney()` copper — so it joins nothing and brings its
    // own icon, an app asset like the stand-ins above.
    columns.push(CurrencyColumn {
        field: GOLD_FIELD.to_string(),
        name: "Gold".to_string(),
        icon: Some("wb:gold".to_string()),
        format: ColumnFormat::Money,
    });
    columns
}

/// Normalise one persisted value into a cell, across every shape the broker writes.
fn cell_of(value: Option<&CurrencyValue>) -> CurrencyCell {
    match value {
        None => CurrencyCell::default(),
        // A bare number: the four scalar fields, and a legacy NebulousVoidcore from before it
        // became a table. Neither carries caps, so a scalar is never "capped".
        Some(CurrencyValue::Scalar(n)) => CurrencyCell {
            quantity: Some(*n),
            ..Default::default()
        },
        Some(CurrencyValue::Table(t)) => CurrencyCell {
            quantity: Some(t.quantity),
            earned: t.earned,
            max: t.max,
            weekly_max: t.weekly_max,
            capped: t.capped,
        },
    }
}

fn row_of(name: &str, c: &Character, columns: &[CurrencyColumn]) -> CurrencyRow {
    // One map, many lookups.
    let cur = c.currency.as_ref();
    CurrencyRow {
        name: name.to_string(),
        class_key: c.class_key.clone().unwrap_or_default(),
        level: c.basic.level as i64,
        cells: columns
            .iter()
            .map(|col| cell_of(cur.and_then(|cur| cur.fields.get(&col.field))))
            .collect(),
    }
}

/// Build the whole grid. Rows are ordered the way the in-game Summary view's default sort is —
/// level desc, then ilvl desc, then name — using the same comparison the Overview's top-alt
/// list does.
pub fn build(db: &CharDb) -> Currencies {
    let columns = build_columns(crate::staticdata::get());
    let mut named: Vec<(&String, &Character)> = db.characters.iter().collect();
    named.sort_by(|(an, a), (bn, b)| crate::overview::cmp_by_level_ilvl(a, an, b, bn));
    let rows = named
        .into_iter()
        .map(|(name, c)| row_of(name, c, &columns))
        .collect();
    Currencies { columns, rows }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Basic, Currency, CurrencyTable, Equipment};
    use std::collections::HashMap;

    fn scalar(n: f64) -> CurrencyValue {
        CurrencyValue::Scalar(n)
    }

    fn character(level: f64, ilvl: f64, currency: Option<Currency>) -> Character {
        Character {
            class_key: Some("Mage".into()),
            basic: Basic {
                level,
                ..Default::default()
            },
            equipment: Some(Equipment { ilvl: Some(ilvl) }),
            currency,
            ..Default::default()
        }
    }

    fn currency(entries: &[(&str, CurrencyValue)]) -> Currency {
        Currency {
            fields: entries
                .iter()
                .map(|(k, v)| ((*k).to_string(), v.clone()))
                .collect(),
        }
    }

    fn db_of(chars: Vec<(&str, Character)>) -> CharDb {
        CharDb {
            characters: chars
                .into_iter()
                .map(|(n, c)| (n.to_string(), c))
                .collect(),
            ..Default::default()
        }
    }

    fn cell<'a>(cs: &'a Currencies, row: usize, field: &str) -> &'a CurrencyCell {
        let i = cs
            .columns
            .iter()
            .position(|c| c.field == field)
            .expect("column");
        &cs.rows[row].cells[i]
    }

    /// The four table shapes the broker writes differ only in which cap keys they carry, so one
    /// all-defaulted struct has to absorb all of them — a missing key must read as 0, not fail.
    #[test]
    fn every_table_shape_deserializes() {
        let cases = [
            // {quantity, max, capped} — Catalyst
            r#"{"quantity": 4, "max": 6, "capped": false}"#,
            // {quantity, earned, max, capped} — the dawncrests
            r#"{"quantity": 90, "earned": 90, "max": 90, "capped": true}"#,
            // {quantity, earned, weeklyMax, capped} — CofferKeyShard
            r#"{"quantity": 120, "earned": 120, "weeklyMax": 600, "capped": false}"#,
            // {quantity, earned, max, weeklyMax, capped} — ShardOfDundun
            r#"{"quantity": 8, "earned": 3, "max": 8, "weeklyMax": 8, "capped": true}"#,
        ];
        for json in cases {
            let v: CurrencyValue = serde_json::from_str(json).expect("shape should deserialize");
            assert!(
                matches!(v, CurrencyValue::Table(_)),
                "{json} should be a table, not a scalar"
            );
            assert!(cell_of(Some(&v)).quantity.is_some());
        }
        let t: CurrencyTable = serde_json::from_str(cases[0]).unwrap();
        assert_eq!(t.weekly_max, 0.0, "an absent cap key reads as 0");
    }

    /// The hazard #884 calls out: NebulousVoidcore predates the table shape and real saves can
    /// still hold it as a plain number. A reader that assumes a table breaks on those.
    #[test]
    fn a_legacy_bare_number_reads_as_a_quantity() {
        let v: CurrencyValue = serde_json::from_str("7").expect("a bare number is valid");
        let c = cell_of(Some(&v));
        assert_eq!(c.quantity, Some(7.0));
        assert!(!c.capped, "a scalar carries no caps, so it is never capped");
    }

    /// "Never captured" and "captured as zero" are different renders — blank vs. an em-dash —
    /// so they must not collapse into the same cell.
    #[test]
    fn absent_is_none_not_zero() {
        assert_eq!(cell_of(None).quantity, None);
        assert_eq!(cell_of(Some(&scalar(0.0))).quantity, Some(0.0));
    }

    /// A character the broker has never run for has no `currency` table at all. That is a row
    /// of blanks, not a dropped character — the grid still has to account for them.
    #[test]
    fn a_character_with_no_currency_table_yields_a_full_blank_row() {
        let cs = build(&db_of(vec![("Nocurrency", character(80.0, 600.0, None))]));
        assert_eq!(cs.rows.len(), 1);
        assert_eq!(cs.rows[0].cells.len(), cs.columns.len());
        assert!(cs.rows[0].cells.iter().all(|c| c.quantity.is_none()));
    }

    #[test]
    fn columns_follow_the_declared_order_and_end_with_gold() {
        let cs = build(&CharDb::default());
        let fields: Vec<&str> = cs.columns.iter().map(|c| c.field.as_str()).collect();
        let expected: Vec<&str> = CURRENCY_ORDER
            .iter()
            .copied()
            .filter(|f| crate::staticdata::get().currency_field(f).is_some())
            .collect();
        assert_eq!(&fields[..expected.len()], &expected[..]);
        assert_eq!(fields.last(), Some(&GOLD_FIELD));
        assert_eq!(cs.columns.last().unwrap().format, ColumnFormat::Money);
    }

    /// The whole point of sourcing the field list from the bundle: a currency added to the
    /// broker must produce a column without anyone editing CURRENCY_ORDER.
    #[test]
    fn a_field_missing_from_the_order_const_is_appended_not_dropped() {
        let mapped: Vec<&String> = crate::staticdata::get().currency_fields.keys().collect();
        let cs = build(&CharDb::default());
        for field in mapped {
            assert!(
                cs.columns.iter().any(|c| &c.field == field),
                "{field} is mapped by the bundle but has no column"
            );
        }
        // Gold is the one money-formatted column, and it brings its own icon.
        let money: Vec<_> = cs
            .columns
            .iter()
            .filter(|c| c.format == ColumnFormat::Money)
            .collect();
        assert_eq!(money.len(), 1);
        assert_eq!(money[0].field, GOLD_FIELD);
        assert_eq!(money[0].icon.as_deref(), Some("wb:gold"));
    }

    /// The stand-in mechanism: 3356's DB2 icon name is unrenderable (a literal space, no CDN
    /// image — #883), so its column must carry the app-owned `wb:` name instead of whatever
    /// the bundle regenerated this week.
    #[test]
    fn the_mana_crystal_column_carries_the_app_stand_in() {
        let cs = build(&CharDb::default());
        let col = cs
            .columns
            .iter()
            .find(|c| c.field == "UntaintedManaCrystal")
            .expect("the broker still maps UntaintedManaCrystal");
        assert_eq!(col.icon.as_deref(), Some("wb:manacrystal"));
    }

    /// Every currency column has to arrive with real metadata, or the tab renders a header with
    /// no name and no icon — the bundle/broker skew this join exists to make visible.
    #[test]
    fn every_currency_column_resolves_a_name() {
        let cs = build(&CharDb::default());
        for col in cs.columns.iter().filter(|c| c.format == ColumnFormat::Count) {
            assert_ne!(
                col.name, col.field,
                "{} fell back to its field name — the bundle didn't resolve it",
                col.field
            );
        }
    }

    #[test]
    fn rows_sort_by_level_then_ilvl_then_name() {
        let cs = build(&db_of(vec![
            ("Bravo", character(80.0, 600.0, None)),
            ("Alpha", character(80.0, 600.0, None)),
            ("Highest", character(80.0, 640.0, None)),
            ("Levelling", character(42.0, 300.0, None)),
        ]));
        let names: Vec<&str> = cs.rows.iter().map(|r| r.name.as_str()).collect();
        assert_eq!(names, vec!["Highest", "Alpha", "Bravo", "Levelling"]);
    }

    /// End to end over the mixed shapes one real character holds at once.
    #[test]
    fn cells_line_up_with_their_columns() {
        let mut fields: HashMap<String, CurrencyValue> = HashMap::new();
        fields.insert("gold".into(), scalar(12_345_678.0));
        fields.insert("RestoredCofferKey".into(), scalar(3.0));
        fields.insert("NebulousVoidcore".into(), scalar(5.0)); // legacy bare number
        fields.insert(
            "HeroDawncrest".into(),
            CurrencyValue::Table(CurrencyTable {
                quantity: 90.0,
                earned: 90.0,
                max: 90.0,
                capped: true,
                ..Default::default()
            }),
        );
        let cs = build(&db_of(vec![(
            "Mixed",
            character(80.0, 640.0, Some(Currency { fields })),
        )]));

        assert_eq!(cell(&cs, 0, "gold").quantity, Some(12_345_678.0));
        assert_eq!(cell(&cs, 0, "RestoredCofferKey").quantity, Some(3.0));
        assert_eq!(cell(&cs, 0, "NebulousVoidcore").quantity, Some(5.0));
        let hero = cell(&cs, 0, "HeroDawncrest");
        assert_eq!(hero.quantity, Some(90.0));
        assert!(hero.capped);
        assert_eq!(hero.max, 90.0);
        // Untouched by this character, so blank rather than zero.
        assert_eq!(cell(&cs, 0, "ShardOfDundun").quantity, None);
    }

    /// The gold column stays the money field: it must not be joined through currencyFields and
    /// end up rendered as a count.
    #[test]
    fn gold_is_a_column_but_never_a_currency() {
        let cs = build(&db_of(vec![(
            "Rich",
            character(80.0, 600.0, Some(currency(&[("gold", scalar(999.0))]))),
        )]));
        assert_eq!(cell(&cs, 0, "gold").quantity, Some(999.0));
        assert_eq!(crate::staticdata::get().currency_field(GOLD_FIELD), None);
    }
}
