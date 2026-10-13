# Monetization

Sprechly is a **free app** plus a single **non-consumable** in-app purchase that
unlocks the AI layer (transcription is free; the IAP unlocks AI title/summary,
translation and gated extras). StoreKit 2 only — no subscriptions, no external
payment, no receipt parsing, no server validation. See CLAUDE.md §9a.

Decision (2026-06-21, for release 1.0.0): **free app + one IAP** — replaces the
earlier "paid app" idea (more downloads, users try recording and transcription
before paying for AI).

**Current price: 6,99 €. The raise to 9,99 € is deferred — decision 2026-10-05,
superseding the 2026-10-04 plan to ship it with 1.1.1.**

The earlier plan was to raise the price together with the reworked store
presence and measure the package as a new baseline. The first revenue figures
under 1.1.0 changed that:

| | Previous 30 days | 4 Sep – 3 Oct 2026 |
|---|---|---|
| Downloads | 43 | 30 (−30 %) |
| IAP purchases | 8 | 4 |
| Purchases per download | 18.6 % | 13.3 % |

Two things follow. **The funnel breaks at the top, not at the paywall** — 13 %
of downloads buying a one-time unlock is high, so the paywall is not the
problem and should not be touched. And **the two changes push the same number
in opposite directions**: the reworked listing should raise downloads and
conversion, the higher price should lower conversion. Shipped together they
plausibly cancel out, leaving a flat line that teaches nothing — and risks
discarding a listing that was in fact working.

The arithmetic is not worth that. At a held volume the raise is worth roughly
**+9 $ of proceeds per month**; break-even needs **3 of the 4 buyers to stay**.
Losing more than about 30 % of buyers to a 43 % price rise is entirely
plausible for a one-time purchase on an app with almost no ratings.

**The raise costs nothing to defer**: the price is a field in App Store
Connect and needs no build, no release and no review. Nothing couples it to
1.1.1 except the earlier decision.

**Plan:** ship 1.1.1 at 6,99 €, measure impressions, product page views,
downloads and purchases for four to six weeks, then raise the price as its own
change once the funnel has stabilised and the first ratings are in — ratings
carry a higher price, and their absence is currently the weakest point.
**Do not raise** if downloads are still falling after four weeks: that is a
reach problem, and a higher price makes it worse.

Unchanged: no subscription, free download, and the 30-second transcription
preview stays.

**The price lives in App Store Connect, not in this repository.** The app reads
it from `Product.displayPrice` (`PaywallView`), the only price in the codebase is
the local StoreKit test configuration, and there is no Fastlane/ASC automation —
so the change is a manual step, listed under "Release checklist" below.

## What to mirror in App Store Connect (manual, by Rene)

The app, the local StoreKit configuration (`Configuration/VoxStudio.storekit`)
and App Store Connect must all match. Create the IAP manually:

| Item | Value |
|---|---|
| App price | **Free** (Tier 0) |
| IAP product type | **Non-Consumable** |
| IAP product ID | `de.gcng.sprechly.ai` |
| Reference name | Sprechly AI |
| **Price** | **6,99 €** — unchanged in ASC. The raise to 9,99 € is deferred, see above. |
| Family Sharing | Recommended **On** (one-time AI unlock; nice for buyers) |
| Display name (DE) | Sprechly KI |
| Display name (EN) | Sprechly AI |
| Description (DE) | KI-Titel & Zusammenfassung, Übersetzung und Premium-Funktionen — einmalig, kein Abo, vollständig auf dem Gerät. |
| Description (EN) | AI title & summary, translation and premium features — one-time, no subscription, fully on-device. |

The product ID `de.gcng.sprechly.ai` is the single source of truth: it lives in
`StoreCatalog.aiProductID`, the `.storekit` file, and must match ASC exactly. The
capability it grants is decoupled (`Entitlement.ai`) so a future bundle
(`de.gcng.sprechly.pro`) is one line in `StoreCatalog` — see `StoreCatalog.swift`.

## The price raise, when it happens (manual, by Rene)

**Not with 1.1.1 and not with 1.2.0.** Deferred per the decision above. Nothing
in this repository changes the real price; these are the steps for the day it is
raised, as a change of its own.

| Field | Value |
|---|---|
| Product ID | `de.gcng.sprechly.ai` |
| Type | Non-Consumable |
| Price **now** | **6,99 €** |
| Price **candidate** | 9,99 € |

**Preconditions, all of them:**

- 1.1.1 is live and the reworked listing has run for **four to six weeks**
- Downloads are **no longer falling**
- The first ratings are in

1. App Store Connect → **In-App Purchases** → *Sprechly AI* → **Price Schedule**
   → set the new price (and let ASC derive the other storefronts).
2. Pick a **start date** that is clearly separated from any release, so the
   effect is attributable to the price alone.
3. The **IAP review screenshot** only needs replacing if the paywall layout
   changed — the price in it is not what is reviewed.
4. Verify on device afterwards that the paywall shows the new price — it reads
   `Product.displayPrice`, so no app update is needed for the price itself.
5. Update this file and `STORE_LISTING.md` on the same day.

**Not done here, deliberately:** no price is hard-coded, no local price logic is
introduced, and no external change was made on your behalf. The local
`Configuration/VoxStudio.storekit` carries 9.99 for *local* StoreKit testing
only; it has no effect on the App Store and is not evidence of the live price —
the device gate on 2026-10-05 read **6,99 €** from the real store.

## IAP review (required for the IAP to be approved)

- **Review screenshot** of the paywall is required per IAP. Capture `PaywallView`
  with the product + price visible (see `scripts/screenshots.sh` → `paywall`).
- **Review notes**: the IAP unlocks on-device AI; on devices without Apple
  Intelligence the AI features are marked unavailable and the paywall says so.
- **Terms of Use + Privacy** are linked in the paywall (Apple standard EULA +
  in-app privacy policy) and must also appear in the App Store listing metadata
  (EULA + privacy policy URL). See `STORE_LISTING.md`.

## Not done in code (manual in App Store Connect)

- Create the IAP product, set its price, attach the review screenshot.
- Paid Applications Agreement, banking and tax forms.
- Small Business Program enrollment (recommended — 15 % fee).
- App Review submission.

## Local & device testing

- `Configuration/VoxStudio.storekit` drives local purchases when launched from
  Xcode (Run action) and `SKTestSession` in tests. StoreKit Testing needs a
  pre-booted simulator — see docs/IOS26_NOTES.md.
- **Device builds via `devicectl` carry neither the StoreKit config nor the
  scheme env**, so the product cannot load and the real purchase cannot be
  tested there until the IAP exists in ASC. DEBUG builds are unlocked by default
  (Settings → Debug toggle) so the app is fully usable on device meanwhile.
  See memory `iap-device-testing`.
- Real end-to-end purchase: create the IAP in ASC + a Sandbox tester, then test
  on a TestFlight/release build.
