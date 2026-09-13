# Pocket Paludarium — Google Play + AdMob setup

| Field | Value |
| --- | --- |
| Play package | `com.grapegames.pocketpaludarium` |
| Debug package | `com.grapegames.pocketpaludarium.debug` |
| Export preset | `Android Play` (AAB, arm64-v8a, gradle build) |
| Godot | 4.7.1-stable (pinned by `android/.build_version`) |
| Store listing copy and art | [`store/LISTING.md`](../store/LISTING.md) |

## Ads: Google test units by default

The bottom banner ships wired to **Google's official test banner**
`ca-app-pub-3940256099942544/6300978111` and test app ID
`ca-app-pub-3940256099942544~3347511713`. That is deliberate: internal and
closed testing must never click a live unit, and Google treats it as invalid
traffic if you do.

Two switches control it, and **both** must change to go live:

1. `ADMOB_USE_TEST_UNITS: "false"` in
   [`.github/workflows/deploy-android.yml`](../.github/workflows/deploy-android.yml),
   which lands as `use_google_test_units` in the generated `config/admob.json`.
2. Real values in the `ADMOB_ANDROID_APP_ID` and `ADMOB_ANDROID_BANNER_UNIT_ID`
   repository secrets.

While `use_google_test_units` is true,
[`autoload/ad_bar_service.gd`](../autoload/ad_bar_service.gd) returns the test
unit regardless of what the config file says, so a stray production id in a
local `config/admob.json` cannot leak into a test build.

### How the bar is laid out

`AdBarService` is an autoload that owns a `CanvasLayer` overlay and the native
`AdView`. The game reserves room for it by shrinking its 720×1280 stage
uniformly (`scripts/main.gd`, `_apply_ad_reserve`), so no button ever sits under
the banner; the letterbox gutters are painted with the project's clear colour.
The service re-anchors on rotation, window resize, and when the soft keyboard
opens or closes.

To eyeball the shrunken layout on desktop, where no real banner loads:

```bash
CAPTURE_AD_RESERVE=160 godot --path . --resolution 720x1280 tests/capture.tscn
```

## GitHub secrets (required for deploy)

Repo → Settings → Secrets and variables → Actions → **Secrets**:

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Release keystore file, base64-encoded |
| `KEY_ALIAS` | Keystore alias |
| `KEYSTORE_PASSWORD` | Keystore password (ASCII only) |
| `SERVICE_ACCOUNT_JSON` | Play Developer API service account JSON |
| `ADMOB_ANDROID_APP_ID` | AdMob App ID (`ca-app-pub-…~…`) |
| `ADMOB_ANDROID_BANNER_UNIT_ID` | AdMob banner unit (`ca-app-pub-…/…`) |

This app signs with the shared Grapegames upload key (alias `grapegames`), the
same one peregrine uses; Play App Signing is per-app, so one upload key can cover
several games. To encode it for the secret:

```bash
base64 -w0 ~/release-grapegames.keystore | gh secret set ANDROID_KEYSTORE_BASE64
```

Note these must be **repository** secrets. Organization secrets do not reach a
private repo on the current plan — they arrive empty and the deploy fails at the
"Decode release keystore" guard.

Keep the keystore somewhere safe and out of the repo — losing it means you
can never update the app under the same package name. `.gitignore` already
blocks `*.keystore`, `*.jks`, and `*service-account*.json`.

## Workflows

| Workflow | Trigger | Does |
| --- | --- | --- |
| [`ci.yml`](../.github/workflows/ci.yml) | pull request, manual | Imports the project and runs `tests/test_runner.gd` |
| [`deploy-android.yml`](../.github/workflows/deploy-android.yml) | push to `main`/`master`, manual | Builds the signed AAB and uploads it to the Play **Closed testing** track (`alpha`) |

The deploy job stamps `versionCode` from `github.run_number` and `versionName`
as `1.<run_number>`, validates the built AAB's manifest with Google's official
Bundletool, and only then uploads. It publishes no GitHub Actions artifact — the
AAB goes straight to Play.

CI uploads straight to **Closed testing**. `tracks: alpha` in
`deploy-android.yml` is the Play API name for the default Closed testing track;
if you created a *custom* closed track, put its own name there instead or the
upload fails with a track-not-found error.

versionCode 1 was published to the internal track by the first run and stays
there. Play rejects a second upload of the same versionCode, so promote an
existing build rather than re-uploading it — and note that a release with no
bundle attached fails with "This release does not add or remove any app
bundles".

## Play Console checklist

- [x] Create the app (`com.grapegames.pocketpaludarium`), Game → Simulation
- [x] Play Console → Users and permissions → invite the Play API service account
- [x] First CI upload (versionCode 1) landed on internal — no manual upload needed
- [ ] Closed testing → testers list + share the opt-in link
- [ ] Store listing from [`store/LISTING.md`](../store/LISTING.md) (copy + art)
- [ ] App content → Privacy policy URL
- [ ] App content → **Ads: contains ads = yes**
- [ ] App content → Data safety (advertising ID; see `store/LISTING.md`)
- [ ] App content → Content rating questionnaire
- [ ] Store settings → **Website** = `https://patguettler.github.io`
- [ ] Target audience = Everyone

Skip Play Integrity unless you adopt it deliberately.

## `app-ads.txt`

AdMob authorises a publisher from a file on the **developer website** listed in
the Play listing, not from this repo:

```
https://patguettler.github.io/app-ads.txt
```

Until the listing carries that Website field, AdMob reports "No app-ads.txt file
found" and limits serving. After the listing is live: AdMob → the app → **Add
store** → Google Play → matching package name, then AdMob → **app-ads.txt** →
**Check for updates** (can take 24 hours).

## Local export

```bash
./scripts/ci/godot-export-android.sh                 # AAB + debug APK
SKIP_DEBUG_APK=1 ./scripts/ci/godot-export-android.sh  # AAB only
```

The script downloads Godot and the export templates, unzips `android_source.zip`
into `android/build/` (headless Godot will not install the template on its own),
fetches the AdMob Android binaries into `addons/admob/android/bin/`, writes
`config/admob.json`, applies the R8 / 16 KB-page gradle overlay from
`android/play-release.gradle`, exports, and validates the manifest. It restores
`export_presets.cfg` and `project.godot` on exit, so a local run leaves no diff.

It needs `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) and a JDK 17. Release signing
comes from the usual Godot env vars:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$HOME/release-grapegames.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=grapegames
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=…
```

`android/.build_version` must match `GODOT_VERSION`; the script hard-fails if
they drift. Godot 4.7.1 pins Android Gradle Plugin 8.6.1 — do not bump that to
AGP 9 independently, it breaks the export template.
