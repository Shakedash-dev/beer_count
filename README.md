# Beer Count

A minimal, offline Android app that counts beers.

One tap on a home-screen widget logs a `1/3` (333 ml) or `1/2` (500 ml).
The app shows a timeline of everything you have logged and a statistics
screen. Nothing leaves the phone. No accounts, no sync, no notifications.

Dark canvas, one amber accent, and nothing else.

## Features

**Home-screen widget**
- Two pills: `⅓` and `½`. One tap logs, no confirmation, no app launch.
- Shows today's count and volume, and resets itself at midnight.
- Never starts a Flutter engine, so a tap is instant even when the app is
  not running.

**Timeline**
- Today's count and volume in the hero block.
- Weekly goal bar, which turns red when you go over.
- Entries grouped by day, newest first. Swipe an entry left to delete it,
  with undo.

**Statistics**
- Today, this week (with the goal), and all time totals.
- Rhythm: beers per day over 30 days, per week over 12 weeks, peak hour,
  a by-weekday chart, a by-hour chart, and the last 30 days.
- Streaks: current dry streak, longest dry streak ever, current drinking
  streak, biggest single day, and weeks under goal.
- Mix: the `1/3` vs `1/2` split.
- A GitHub-style heatmap of the last 53 weeks.

**Settings**
- Weekly goal (0 turns it off), week start (Sunday or Monday).
- Export the full log as CSV or JSON through the share sheet.
- Erase everything, behind a confirmation.

## How the data is stored

Everything lives in one append-only NDJSON file in the app's private
directory:

```
/data/data/com.shakedash.beercount/files/beer_log.ndjson
```

One JSON object per line:

```json
{"id":"1758391992123-a4f1","ml":333,"at":1758391992123}
```

- `id` is `<epoch millis>-<4 hex>`, generated the same way in Dart and Kotlin.
- `ml` is the volume. `at` is epoch milliseconds; all day and week bucketing
  is done in local time when the file is read.

The widget appends to this file directly from Kotlin and keeps a three-key
`SharedPreferences` cache (`today_key`, `today_count`, `today_ml`) so it can
render without parsing anything. That cache is recomputed from the file every
time the app resumes, so it heals itself if it ever drifts. A line that cannot
be parsed is skipped, counted, and reported in Settings; the rest of the log is
unaffected.

## Build and install

Requires the Flutter SDK and an Android SDK. Tested with Flutter 3.47 /
Dart 3.13, `compileSdk 36`, `minSdk 26`.

```bash
flutter pub get
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`--split-per-abi` gives a 21 MB APK instead of the 51 MB universal one.
Any phone from the last decade is `arm64-v8a`; plain
`flutter build apk --release` produces the universal
`app-release.apk` if you would rather not care.

Then long-press the home screen → Widgets → Beer Count, and drag the
4x1 widget out. It resizes.

The first build downloads the Android NDK and CMake (~2.5 GB) even though
this app has no native code of its own - that comes from the Flutter Gradle
plugin and from `home_widget`, which pulls in Jetpack Glance. Subsequent
builds are fast.

### Signing

The release build falls back to the debug signing key, so the command above
works on a fresh clone with no setup. That is fine for sideloading onto your
own device.

For a properly signed build, create a keystore and an `android/key.properties`.
Neither is committed - both are in `.gitignore`.

```bash
keytool -genkey -v -keystore ~/beer-count.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias beercount
```

```properties
# android/key.properties
storePassword=...
keyPassword=...
keyAlias=beercount
storeFile=/absolute/path/to/beer-count.jks
```

The Gradle config picks the file up automatically if it exists.

## Development

```bash
flutter analyze   # must be clean
flutter test      # 135 tests
```

Layout:

| Path | What lives there |
|---|---|
| `lib/models/` | `Beer`, `BeerSize`, the NDJSON codec |
| `lib/data/` | log file, repository, settings, export, widget bridge |
| `lib/stats/` | pure statistics over `List<Beer>` - no IO, no Flutter |
| `lib/ui/` | screens and the hand-built charts |
| `android/app/src/main/kotlin/` | the widget provider and its log appender |
| `docs/superpowers/` | the design spec and the implementation plan |

Two rules worth knowing before changing anything:

1. **Never advance a date with `Duration(days: 1)`.** Use
   `addDays(day, n)` from `lib/stats/buckets.dart`. Israel observes DST, so a
   day is sometimes 23 or 25 hours and `Duration` lands on the wrong date.
2. **The NDJSON format and the preference keys are a cross-language
   contract.** `lib/data/beer_log_file.dart` and
   `android/.../BeerLog.kt` must agree, and every preference value is stored
   as a `String` on both sides.

Widget tests use an in-memory log store, because `testWidgets` bodies run
under `FakeAsync` where real `dart:io` futures never complete.

## Licence

MIT. See [LICENSE](LICENSE).
