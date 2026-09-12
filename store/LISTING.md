# Pocket Paludarium — Google Play store listing

Paste these fields into Play Console → Grow → Store presence → Main store listing.
Character limits are Google's; the counts in brackets are the current copy.

## App name (30 max)

```
Pocket Paludarium
```

[17]

## Short description (80 max)

```
Tend a gentle axolotl in a glowing pond. Feed, decorate, and grow a quiet bond.
```

[79]

## Full description (4000 max)

```
A calm little pond that lives in your pocket.

Pocket Paludarium gives you one axolotl to look after — no timers to beat, no
streaks to lose, nothing to miss if you put it down for a week. Name your pet,
keep the water clear, and watch a small personality settle in.

TEND ONE PET
Fullness, happiness, and water quality each drift gently over time. Feed a
snack, clean the pond, or share a slow pet to bring them back up. Time away is
capped at eight hours, so coming back after a long break is a soft landing
rather than a mess to clean up.

EARN AND DECORATE
Care and play earn pearls. Spend them in the Ripple Shop on plants, stones,
cozy logs, and cosmetics, then place each piece anywhere in the tank — tap a
placed item to put it back in your inventory. A Gentle Filter slows water
decay; a Pearl Bubbler lifts happiness and sends real bubbles up the glass.

A PET WITH MOODS
Your axolotl swims, gets curious, hides in the log to peek out at you, naps
under the decor you placed for it, and celebrates when your bond runs deep.
Bond is permanent — it only ever goes up — and each title you reach unlocks a
new way for your pet to behave.

THREE LITTLE WISHES A DAY
Every day brings three small, achievable wishes — serve a snack, place a cozy
decor, share a gentle pet. Each one pays pearls and bonus bond. Miss a day and
nothing is lost.

TWO GENTLE MINIGAMES
Bubble Pop is thirty seconds of tapping rising bubbles for a combo. Food Catch
is forty-five seconds of steering your axolotl to catch falling snacks and dodge
debris. Both pay out in clear reward tiers, and neither one can be failed.

MADE TO BE KIND
- Portrait, one-handed, and playable with sound off.
- Reduced motion and large touch target options in Settings.
- Progress saves instantly and locally on your device, with automatic backup
  recovery — no account, no sign-in, no cloud.
- Hand-painted storybook art and soft synthesized tones.

Pocket Paludarium is supported by a single small banner ad at the bottom of the
screen. There are no in-app purchases and no paid currency.
```

[2054]

## Categorisation

| Field | Value |
| --- | --- |
| App or game | Game |
| Category | Simulation |
| Tags | Casual, Pet, Relaxing |
| Contains ads | **Yes** (a bottom banner via Google AdMob) |
| In-app purchases | No |
| Target audience | Everyone — the AdMob request is configured `max_ad_content_rating: G` |

## Graphics

| Asset | File | Spec |
| --- | --- | --- |
| App icon | `store/play_icon_512.png` | 512×512 PNG |
| Feature graphic | `store/feature_graphic_1024x500.png` | 1024×500 PNG |
| Phone screenshots | `store/phone/01..06_*.png` | 1080×1920 PNG, 6 supplied (Play needs 2–8) |

All of it is regenerated from the committed art and live in-game captures:

```bash
godot --path . --resolution 720x1280 tests/capture.tscn
python3 scripts/tools/generate_store_assets.py
```

Play policy forbids screenshots that show ads, so the captures are taken without
the banner reserve. `CAPTURE_AD_RESERVE=160` re-captures *with* the reserve for
layout QA — those images are for you, not for the listing.

A 7-inch and 10-inch tablet screenshot set is still outstanding; Play only
requires them if you opt the app into tablet form factors.

## Contact and policy links

| Field | Value |
| --- | --- |
| Website | `https://patguettler.github.io` |
| Privacy policy | `https://patguettler.github.io/privacy-policy.html` |
| Data deletion | `https://patguettler.github.io/privacy-policy.html#data-deletion` |

The Website field is also what lets AdMob find `app-ads.txt`; see
[`docs/PLAY_ANDROID.md`](../docs/PLAY_ANDROID.md).

## Data safety answers

The game itself collects and transmits nothing — saves are a local JSON file in
`user://`. The AdMob banner SDK does collect data, so the Data safety form must
say so:

- Collected: **Device or other IDs** (advertising ID), shared with third parties,
  for **Advertising or marketing**. Not user-controllable, not deletable on
  request beyond the OS-level ad ID reset.
- Also disclose approximate location / diagnostics only if you later enable an
  AdMob feature that gathers them; the default banner request does not.
- Data is encrypted in transit.
- Declare the Advertising ID permission in the Play Console permissions form.
