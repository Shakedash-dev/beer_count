# Beer Count

A minimal, offline Android app that counts beers.

One tap on a home-screen widget logs a `1/3` (333 ml) or `1/2` (500 ml).
The app shows a timeline of everything you have logged and a statistics
screen. Nothing leaves the phone. No accounts, no sync, no notifications.

Dark canvas, one amber accent, and nothing else.

## Features

**Home-screen widget**
- Two pills: `⅓` and `½`. One tap logs, no confirmation, no app launch.
- The tap animates: the count pops, the pill you hit fills amber, and the
  sub-line flashes `+333 ML` before settling back to the running total.
- Never starts a Flutter engine, so a tap is instant even when the app is
  not running.

**The journey**
- The timeline is a dotted path running left to right through time, with
  every beer a waypoint on it. Days are stations along the way; the path
  ends at `NOW`.
- Opens scrolled to the present, and walks itself back there when you log.
- A newly logged beer pops onto the path.
- Tap any waypoint to see it and delete it, with undo. That is the fix for
  a beer you logged by accident.

**Statistics** — seven diagrams, not seven numbers.
- **This week**: an arc gauge sweeping toward your goal, red once past it.
- **Last 30 days**: a smoothed area curve with the peak day marked.
- **By hour**: a 24-spoke clock face. Midnight at the top, your peak hour lit.
- **By weekday**: a radar polygon, so the shape of your week is the point.
- **Streaks**: a 60-day ribbon where dry runs and benders are visible as runs.
- **Mix**: a donut of `1/3` against `1/2`.
- **Year**: a heatmap of the last 53 weeks, with month labels and a legend.

Everything animates in on build and every chart is hand-drawn with
`CustomPainter` — no charting dependency, so the palette is exact and the
APK stays small.

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
flutter test      # 148 tests
```

Layout:

| Path | What lives there |
|---|---|
| `lib/models/` | `Beer`, `BeerSize`, the NDJSON codec |
| `lib/data/` | log file, repository, settings, export, widget bridge |
| `lib/stats/` | pure statistics over `List<Beer>` - no IO, no Flutter |
| `lib/ui/` | screens, the journey timeline and the charts |
| `lib/ui/widgets/charts/` | every diagram, each one a `CustomPainter` |
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

3. **The widget's animation is a scripted sequence, not an animator.**
   `RemoteViews` cannot run one, so `BeerWidgetProvider` calls `goAsync()`
   and posts a handful of delayed frames that change the text size, the pill
   drawable and the sub-line. Keep the whole sequence well under the ten
   seconds a broadcast receiver is given.

The journey lays its waypoints out eagerly in a single `Stack`, so it shows
the most recent `maxWaypoints` (150) beers and marks the rest as "N more".
The full history is still in the heatmap and the export.

Widget tests use an in-memory log store, because `testWidgets` bodies run
under `FakeAsync` where real `dart:io` futures never complete.

## Licence

MIT. See [LICENSE](LICENSE).
