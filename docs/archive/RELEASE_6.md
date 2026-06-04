# Release 6 — Cosmetics expansion (archived)

**Status:** Retired 2026-06-04. Active release tracking: [`../RELEASE_9.md`](../RELEASE_9.md).

---

Ship **8 board themes**, **8 avatar orbs**, and **8 initial styles** in the Shop, plus groundwork for future bundle IAP.

## What shipped in this build

| Category | Count | New in R6 |
|----------|------:|----------:|
| Themes | 8 | Sunset, Frost, Void |
| Avatars | 8 | Lime, Coral, Violet, Ice, Rose |
| Initials | 8 | Neon, Outline, Shadow, Chrome, Arcade |

Starter items remain free (`theme_neon_default`, `avatar_orb_cyan`, `initial_skin_classic`).

### Theme IDs

- `theme_neon_sunset` — 400 coins, epic  
- `theme_neon_frost` — 400 coins, epic  
- `theme_neon_void` — 500 coins, legendary  

### Avatar IDs

- `avatar_orb_lime` — 180  
- `avatar_orb_coral` — 200  
- `avatar_orb_violet` — 280  
- `avatar_orb_ice` — 320  
- `avatar_orb_rose` — 400  

### Initial skin IDs

- `initial_skin_neon` — 180  
- `initial_skin_outline` — 220  
- `initial_skin_shadow` — 260  
- `initial_skin_chrome` — 340  
- `initial_skin_arcade` — 400  

Initial styles apply on **Profile** and **Home** (when display name is not a long auto-generated id).

### Shop UX

- **BUY** on Themes / Avatars / Initials is disabled when `coins < price` (price shown in red); matches Boosts tab behavior.

## Future: cosmetic bundles (not in shop UI yet)

`CatalogBundle` entries exist in `mock_catalog_repository.dart` with `enabled: false`:

| Bundle ID | Contents | Planned price |
|-----------|----------|---------------|
| `bundle_starter_rival` | Sunset + Rose + Neon initial | 850 coins |
| `bundle_ice_queen` | Frost + Ice + Chrome initial | 950 coins |
| `bundle_void_master` | Void + Violet + Arcade initial | 1100 coins |

**Later implementation checklist**

1. Add `purchaseBundle(bundleId)` on `ProfileRepository` (atomic coin debit + grant all `itemIds`).  
2. Shop tab “Bundles” — only list `bundles.where((b) => b.enabled)`.  
3. Optional IAP: `iapProductId` per bundle + restore.  
4. Analytics: `cosmetic_bundle_purchase`, `cosmetic_bundle_view`.  
5. Remote catalog: move `MockCatalogRepository` → Firestore/config when ready.

## Pre-release QA (historical)

- [ ] Buy and equip each **new theme** — board, home, shop colors update app-wide.  
- [ ] Buy and equip each **new orb** — home + profile show correct color.  
- [ ] Buy and equip each **new initial** — profile + home letter style changes for real names.
- [ ] Cosmetic **BUY** disabled when coins insufficient; enabled after earning enough.  
- [ ] Existing profiles: only owned starters until they purchase new items.  
- [ ] Coin balance cannot go negative on purchase failures.  
- [ ] Shop grid scrolls smoothly with 8 items per tab (2 columns).  

## Store / growth (R6)

- Screenshot: Shop **Themes** tab showing Sunset / Frost / Void swatches.  
- Screenshot: **Avatars** with orb previews.  
- Release note line: *“8 new neon looks — themes, orbs, and initial styles in the Shop.”*  
