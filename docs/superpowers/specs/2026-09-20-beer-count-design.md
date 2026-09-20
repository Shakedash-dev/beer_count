# Beer Count - Design

Date: 2026-09-20
Status: approved (scope locked by owner; no further design questions)

## 1. Purpose

A personal, offline-only Android app to count beers with near-zero friction,
and to look at the resulting history.

Two things matter:

1. **Logging must cost one tap from the home screen.** No app launch, no
   confirmation dialog, no sync.
2. **The history must be worth looking at.** A timeline and a statistics
   screen that are actually nice to read.

Non-goals: accounts, cloud sync, social features, Play Store distribution,
iOS, notifications, health advice.

## 2. Locked product decisions

| Decision | Value |
|---|---|
| Entry payload | size + timestamp only (no brand, note, ABV, rating) |
| Sizes | `1/3` = 333 ml, `1/2` = 500 ml (Israeli pub pours) |
| Widget tap | logs instantly, no confirmation |
| Palette | dark canvas, single amber accent |
| Extras in scope | weekly goal/limit, streaks, export, settings |
| Platform | Android only |
| Distribution | `flutter build apk`, sideloaded, open source |

## 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Android process (com.shakedash.beercount)               │
│                                                         │
│  ┌───────────────────────┐   ┌───────────────────────┐  │
│  │ Flutter engine (Dart) │   │ AppWidgetProvider     │  │
│  │                       │   │ (Kotlin, RemoteViews) │  │
│  │  UI / stats / edit    │   │  one-tap append       │  │
│  └──────────┬────────────┘   └──────────┬────────────┘  │
│             │                            │              │
│             └────────────┬───────────────┘              │
│                          ▼                              │
│            filesDir/beer_log.ndjson                     │
│            (append-only, one JSON object per line)      │
└─────────────────────────────────────────────────────────┘
```

### 3.1 Why a shared NDJSON file, not SQLite

The widget must log without a running Flutter engine. Three options were
considered:

1. **`home_widget` interactivity callback** - widget tap spins up a headless
   Flutter engine to run Dart. Rejected: engine cold start on every tap is
   hundreds of milliseconds and can be killed by the OS; it makes the single
   most important interaction the least reliable one.
2. **Shared SQLite** - Kotlin opens the same `.db` file with
   `SQLiteOpenHelper`. Rejected: duplicate schema/migration logic in two
   languages, plus WAL/multi-connection subtleties, for a dataset of at most a
   few thousand rows.
3. **Append-only NDJSON** - chosen.

Volume check: a heavy drinker at 5 beers/day for 20 years produces ~36 500
lines at ~60 bytes = ~2.2 MB. Parsing that in Dart is single-digit
milliseconds. The widget path never parses the whole file (see 3.3).

Properties:

- **Append is O(1) and crash-safe.** Kotlin opens in append mode, writes one
  line ending in `\n`, flushes. A torn write can only damage the last line.
- **Readers tolerate damage.** Any line that fails to parse is skipped and
  counted; the rest of the log is unaffected.
- **Mutations rewrite.** Delete/undo (in-app only, rare) writes a temp file and
  `rename()`s over the original - atomic on the same filesystem.
- **Single process.** The widget's `BroadcastReceiver` and the Flutter engine
  live in the same app process, so a Kotlin `synchronized` monitor plus atomic
  rename is sufficient; there is no cross-process locking problem.

### 3.2 Record format

One JSON object per line, no nesting, stable key names:

```json
{"id":"1758391992123-a4f1","ml":333,"at":1758391992123}
```

- `id` - `"<epochMillis>-<4 hex random>"`. Generated identically in Dart and
  Kotlin. No uuid dependency.
- `ml` - integer millilitres. `333` or `500` today; the schema does not
  constrain it, so adding a size later needs no migration.
- `at` - epoch milliseconds, UTC. All day-bucketing is done in **local time**
  at read time.

Unknown keys are preserved on rewrite where practical and otherwise ignored.
Forward compatibility is free: a future field is simply an extra key.

### 3.3 Widget counter

The widget shows today's count and volume. To avoid parsing the full log in a
`BroadcastReceiver`, the widget reads a tiny summary from `SharedPreferences`
(`HomeWidgetPreferences`, shared with Dart through the `home_widget` plugin):

```
today_key   = "2026-09-20"   // local date the counter belongs to
today_count = 4
today_ml    = 1832
```

- **Kotlin tap path**: append line → if `today_key` != today, reset counter to
  zero first → increment count and ml → write prefs → `updateAppWidget`.
  No file parsing at all. Constant time.
- **Dart path**: after any mutation (log, delete, undo, import), recompute the
  summary from the in-memory log, write it to the same prefs, and call
  `HomeWidget.updateWidget()`.
- **Divergence recovery**: Dart recomputes the summary from the file on every
  app resume, so the prefs cache is self-healing. It is a cache, never a
  source of truth.

### 3.4 Data flow

```
widget tap ──► BeerLogAppender.append(ml)      [Kotlin]
                 ├─ append line to ndjson
                 ├─ bump SharedPreferences summary
                 └─ RemoteViews update

app open   ──► BeerRepository.load()           [Dart]
                 ├─ read + parse ndjson  (skips bad lines)
                 ├─ recompute summary → prefs → updateWidget()
                 └─ notifyListeners()

app resume ──► BeerRepository.reload()         picks up widget-logged entries

in-app log ──► BeerRepository.add(ml)
                 ├─ append line
                 ├─ update in-memory list
                 └─ summary → prefs → updateWidget()
```

## 4. Module boundaries

Each unit is independently testable; nothing below `ui/` touches Flutter
widgets, and nothing above `data/` touches the filesystem.

```
lib/
  main.dart                     app entry, theme, nav shell
  models/
    beer.dart                   Beer value type, encode/decode, id gen
    beer_size.dart              BeerSize enum: third(333) / half(500)
  data/
    beer_log_file.dart          low-level NDJSON read/append/rewrite (io only)
    beer_repository.dart        ChangeNotifier over List<Beer>; owns mutations
    widget_bridge.dart          summary -> home_widget prefs + refresh
    settings_store.dart         weekly goal, week start (SharedPreferences)
    exporter.dart               List<Beer> -> CSV / JSON strings
  stats/
    stats.dart                  pure functions: List<Beer> -> stat structs
    buckets.dart                day/week/hour/weekday bucketing helpers
  ui/
    theme.dart                  colors, type scale, spacing tokens
    timeline_screen.dart
    stats_screen.dart
    settings_screen.dart
    widgets/                    day_header, entry_row, log_buttons,
                                goal_bar, bar_chart, heatmap, stat_tile
android/app/src/main/kotlin/.../
    BeerWidgetProvider.kt       RemoteViews render + click intents
    BeerLogAppender.kt          shared-file append + summary bump
android/app/src/main/res/
    layout/beer_widget.xml      widget layout
    drawable/*.xml              pills, background, vector icons
    xml/beer_widget_info.xml    AppWidgetProviderInfo
```

**Key boundary:** `stats/stats.dart` takes `List<Beer>` and a `DateTime now`
and returns plain data. No IO, no clock access, no Flutter. That makes every
statistic deterministically testable, which is where most of the test value
sits.

## 5. Statistics

Computed on the full log, recomputed on change (cheap at this size).

**Headline**
- Today: count + litres
- This week: count vs weekly goal, with progress bar
- All time: total beers, total litres, days tracked, first-ever entry date

**Rhythm**
- Daily average over last 30 days
- Weekly average over last 12 weeks
- This week vs last week, signed delta and percent
- Busiest weekday - 7-bar chart, average beers per weekday
- Time-of-day histogram - 24 bars, collapsed to a "peak hour" headline
- Last 30 days - one bar per day

**Records & streaks**
- Current dry streak (consecutive local days with zero entries)
- Longest dry streak ever
- Current drinking streak (consecutive days with >= 1)
- Biggest single day (count + date)
- Weeks under goal, out of the last 12

**Mix**
- `1/3` vs `1/2` split - single stacked bar + percentages

**Year heatmap**
- GitHub-style grid, 53 columns x 7 rows, amber intensity by daily count.

Edge cases that must be covered by tests: empty log, single entry, entries
spanning a DST change, entries after midnight, a day with zero entries inside
a streak, a week boundary that depends on the `week start` setting.

## 6. Visual design

Dark, one accent, generous whitespace, large numerals.

```
bg          #0B0B0C     canvas
surface     #141416     cards, widget background
surfaceAlt  #1C1C1F     pressed / secondary fill
hairline    #26262A     1px dividers and chart baselines
text        #F4F1EA     primary
textDim     #8A8780     labels, timestamps
amber       #E8A33D     the only accent - bars, progress, active state
amberDim    #4A3A1E     inactive heatmap cells, track behind progress
over        #D9603F     weekly goal exceeded (used sparingly)
```

- Type: system sans. Numerals are the hero - headline stats at 48-56sp with
  tight letter spacing; labels at 12sp uppercase, `textDim`, tracked out.
- Corners: 16dp cards, 12dp pills, 999 for the progress track.
- No shadows. Separation comes from surface value, not elevation.
- No icons other than the fractions, a settings gear, and the app glyph.
- Motion: only two - a 180 ms count tick when a beer is logged, and a 400 ms
  ease-out fill on the weekly goal bar. Nothing else animates.

### 6.1 App layout

Bottom navigation, two tabs. Settings is a gear in the app bar.

**Timeline tab**
```
┌───────────────────────────────────────┐
│ BEER COUNT                        ⚙   │
│                                       │
│ 4                                     │
│ today · 1.83 L                        │
│                                       │
│ THIS WEEK            9 / 14           │
│ ████████████░░░░░░░░░░                │
│                                       │
│ ┌─────────────┐ ┌─────────────┐       │
│ │     ⅓       │ │     ½       │       │
│ │   333 ml    │ │   500 ml    │       │
│ └─────────────┘ └─────────────┘       │
│                                       │
│ TODAY                    4 · 1.83 L   │
│ ──────────────────────────────────    │
│  21:48   ½                            │
│  20:12   ⅓                            │
│  19:30   ½                            │
│  18:05   ⅓                            │
│                                       │
│ YESTERDAY                2 · 0.83 L   │
│ ──────────────────────────────────    │
│  23:10   ½                            │
│  21:02   ⅓                            │
└───────────────────────────────────────┘
```
Entries are grouped by local day, newest first, lazily built. Swipe an entry
left to delete, with a snackbar undo. Day headers stick while scrolling.

**Stats tab** - a vertical stack of cards in the order given in section 5,
each card one idea. Charts are hand-built from `Container`s and a small
`CustomPainter`; no charting dependency, so the look is exactly the palette
above and the build stays light.

### 6.2 Widget

`RemoteViews`, not Jetpack Glance - Glance would drag the Compose compiler
into a Flutter Gradle build for no visual gain at this complexity.

Resizable, default 4x1, min 3x1.

```
┌────────────────────────────────────────────┐
│  4                      ┌─────┐  ┌─────┐   │
│  today · 1.83 L         │  ⅓  │  │  ½  │   │
│                         └─────┘  └─────┘   │
└────────────────────────────────────────────┘
```

- Background `#141416` at 16dp radius, using
  `system_app_widget_background_radius` on API 31+ and a static 16dp
  `<shape>` below it.
- Count in `#F4F1EA` at 32sp; sub-label in `#8A8780` at 11sp.
- Pills: 1dp `#E8A33D` stroke on transparent, amber text, with a pressed
  state that fills amber at 20% alpha.
- The number area opens the app; each pill logs its size.
- After a tap the count re-renders immediately from the prefs summary.

## 7. Settings

- **Weekly goal** - integer beers per week, default 14, `0` disables the bar.
- **Week starts on** - Sunday or Monday, default Sunday. Feeds all weekly
  stats and the heatmap rows.
- **Export** - CSV and JSON, handed to the Android share sheet via
  `share_plus`.
- **Erase all data** - two-step confirm, truncates the log and resets the
  widget summary.

No theme switch: the app is dark-only by design.

## 8. Dependencies

Deliberately small. Every addition is a thing that can break a build I cannot
run on the target device.

| Package | Why |
|---|---|
| `path_provider` | resolve `filesDir` identically to Kotlin's `context.filesDir` |
| `home_widget` | write the widget summary + trigger `updateWidget()` |
| `provider` | inject `BeerRepository` / `SettingsStore` |
| `intl` | date and number formatting |
| `share_plus` | export via the share sheet |
| `shared_preferences` | settings |
| dev: `flutter_lints`, `flutter_test` | analysis + tests |

Rejected: `fl_chart` (hand-built charts match the palette better and cost
less), `sqflite`/`drift` (see 3.1), `uuid` (four lines of Dart).

## 9. Error handling

| Failure | Behaviour |
|---|---|
| Log file missing | treated as empty log; created on first append |
| Unparseable line | skipped; a `skippedLines` count is surfaced in Settings |
| Truncated final line | skipped by the same path; next append starts on a fresh line after a defensive `\n` if the file does not end with one |
| Rewrite interrupted | temp file is discarded on next launch; original intact |
| `filesDir` unwritable | in-app logging shows an error snackbar; widget tap is a no-op rather than a crash |
| Prefs summary stale/wrong | recomputed from the file on every app resume |

The widget's `BroadcastReceiver` wraps its whole body in a `try/catch`: a
failed log must never produce a system "widget isn't responding" dialog.

## 10. Testing

Run in the sandbox with a full Flutter SDK; no device required.

- **`stats/` unit tests** - the bulk of the suite. Fixed `List<Beer>`
  fixtures and an injected `now`. Covers empty/single/DST/midnight/week-start
  cases from section 5.
- **`data/beer_log_file` tests** - append then read round-trip, bad-line
  tolerance, missing trailing newline, atomic rewrite, delete.
- **`models/beer` tests** - encode/decode round-trip, id format, unknown-key
  tolerance.
- **`exporter` tests** - CSV header and escaping, JSON shape.
- **Widget tests** - timeline groups by day and renders headers; tapping a log
  button appends exactly one entry; goal bar reflects the setting.
- **`flutter analyze`** must be clean before any commit.

The Kotlin widget code is not unit tested - there is no Android emulator in
the sandbox. It is kept deliberately small (two files, no branching beyond a
date comparison) and is verified by `flutter build apk` compiling it and by
manual check on the device.

## 11. Build and signing

- `minSdk 26`, `targetSdk 36`, `compileSdk 36`. (`minSdk` was raised
  from 23 during implementation so the launcher icon can be a pure vector
  adaptive icon and the repo carries no binary image assets.)
- `applicationId com.shakedash.beercount`.
- Release signing is **optional and local**: if `android/key.properties`
  exists it is used; otherwise the build falls back to the debug signing
  config so `flutter build apk --release` works out of the box on a fresh
  clone.
- `android/key.properties`, `*.jks` and `*.keystore` are in `.gitignore`.
  No secret, key or token is committed. README documents keystore creation
  for anyone who wants a properly signed build.
- App icon is an XML `VectorDrawable` adaptive icon (amber glass on dark), so
  no binary asset and no icon-generation tooling is required.

## 12. Out of scope

Cloud sync, multi-device, accounts, notifications, reminders, BAC estimation,
brands/photos/ratings, iOS, Play Store, localisation beyond English.
