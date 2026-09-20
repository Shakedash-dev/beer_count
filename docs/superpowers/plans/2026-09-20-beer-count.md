# Beer Count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a dark, minimal, offline Android app that logs a 1/3 or 1/2 beer in one tap from a home-screen widget and presents a timeline plus a statistics screen.

**Architecture:** A single Android process holds both the Flutter engine and a native Kotlin `AppWidgetProvider`. They share one append-only NDJSON file in `context.filesDir`. The widget appends a line and bumps a tiny `SharedPreferences` summary without ever starting a Flutter engine; Dart re-reads the file on resume and recomputes that summary, so the prefs are a self-healing cache and the file is the only source of truth.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4, Kotlin + RemoteViews for the widget, `path_provider`, `home_widget`, `provider`, `intl`, `share_plus`, `shared_preferences`. No database, no charting library.

**Spec:** `docs/superpowers/specs/2026-09-20-beer-count-design.md`

## Global Constraints

- `applicationId` / Kotlin package: `com.shakedash.beercount`.
- `minSdk 23`, `targetSdk 36`, `compileSdk 36`.
- Sizes are exactly two: `333` ml (`⅓`, "1/3") and `500` ml (`½`, "1/2").
- The log file is `<context.filesDir>/beer_log.ndjson`. Dart resolves that
  directory with `getApplicationSupportDirectory()`; Kotlin with
  `context.filesDir`. These are the same path on Android. Nothing else may
  write to it.
- Shared prefs file name is `HomeWidgetPreferences` (the name the
  `home_widget` plugin uses on Android). Keys `today_key`, `today_count`,
  `today_ml`. **Every value is stored as a `String` on both sides** - the
  Dart/Kotlin int width mismatch through the plugin's method channel is a
  real hazard, and strings sidestep it entirely.
- All day/week bucketing is **local time**. Never advance a date with
  `Duration(days: 1)`; always construct `DateTime(y, m, d + n)`. Adding a
  `Duration` across a DST boundary silently lands on the wrong day, and
  Israel observes DST.
- `DateTime.weekday` is 1 = Monday .. 7 = Sunday. Weekday-indexed lists are
  length 7 indexed by `weekday - 1`.
- Every pure computation lives under `lib/stats/` or `lib/models/` and must
  not import `dart:io` or `package:flutter/material.dart`.
- Palette is fixed: bg `#0B0B0C`, surface `#141416`, surfaceAlt `#1C1C1F`,
  hairline `#26262A`, text `#F4F1EA`, textDim `#8A8780`, amber `#E8A33D`,
  amberDim `#4A3A1E`, over `#D9603F`. Amber is the only accent.
- `flutter analyze` must report zero issues before any commit.
- No secrets, keystores, or `key.properties` in git.

## File Structure

| File | Responsibility |
|---|---|
| `lib/main.dart` | entry point, providers, `MaterialApp`, nav shell |
| `lib/models/beer_size.dart` | `BeerSize` enum: ml, glyph, label |
| `lib/models/beer.dart` | `Beer` value type, NDJSON encode/decode, id generation |
| `lib/data/beer_log_file.dart` | NDJSON read / append / atomic rewrite (only file doing IO on the log) |
| `lib/data/widget_bridge.dart` | `WidgetSummary`, `summarize()`, `WidgetBridge` + home_widget impl |
| `lib/data/beer_repository.dart` | `ChangeNotifier` owning the in-memory log and all mutations |
| `lib/data/settings_store.dart` | weekly goal + week start, backed by `shared_preferences` |
| `lib/data/exporter.dart` | `List<Beer>` -> CSV / JSON strings |
| `lib/stats/buckets.dart` | `dayKey`, `addDays`, `weekStartOf`, `groupByDay`, `DayCount` |
| `lib/stats/streaks.dart` | dry / drinking streak computation over a day set |
| `lib/stats/beer_stats.dart` | `BeerStats.from(...)` aggregate of every number the UI shows |
| `lib/ui/theme.dart` | colour tokens, text styles, spacing, `buildTheme()` |
| `lib/ui/app_shell.dart` | bottom nav between Timeline and Stats |
| `lib/ui/timeline_screen.dart` | header, goal bar, log buttons, grouped day list |
| `lib/ui/stats_screen.dart` | stat cards in spec order |
| `lib/ui/settings_screen.dart` | goal, week start, export, erase |
| `lib/ui/widgets/log_buttons.dart` | the two big ⅓ / ½ buttons |
| `lib/ui/widgets/goal_bar.dart` | weekly goal progress track |
| `lib/ui/widgets/stat_tile.dart` | label + big numeral + optional sub-line |
| `lib/ui/widgets/bar_chart.dart` | generic labelled bar row chart (weekday, hour, 30-day) |
| `lib/ui/widgets/heatmap.dart` | 53x7 year grid |
| `lib/ui/widgets/day_section.dart` | sticky day header + entry rows |
| `android/app/src/main/kotlin/com/shakedash/beercount/MainActivity.kt` | Flutter host |
| `android/app/src/main/kotlin/com/shakedash/beercount/BeerLog.kt` | Kotlin-side append + summary bump |
| `android/app/src/main/kotlin/com/shakedash/beercount/BeerWidgetProvider.kt` | RemoteViews render + click intents |
| `android/app/src/main/res/layout/beer_widget.xml` | widget layout |
| `android/app/src/main/res/xml/beer_widget_info.xml` | `AppWidgetProviderInfo` |

Tests mirror `lib/` under `test/`.

---

## Task 1: Project scaffold, theme tokens, analysis gate

**Files:**
- Create: whole Flutter project at repo root via `flutter create`
- Create: `lib/ui/theme.dart`
- Create: `.gitignore` additions, `analysis_options.yaml`
- Test: `test/ui/theme_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppColors` (static `Color` fields `bg`, `surface`, `surfaceAlt`, `hairline`, `text`, `textDim`, `amber`, `amberDim`, `over`), `AppText` (static `TextStyle` fields `hero`, `title`, `label`, `body`, `mono`), `AppSpace` (static `double` `xs`=4, `sm`=8, `md`=16, `lg`=24, `xl`=32), `ThemeData buildTheme()`.

- [ ] **Step 1: Scaffold the project into the existing repo**

```bash
cd "$(git rev-parse --show-toplevel)"
flutter create --org com.shakedash --project-name beer_count \
  --platforms android --template app .
```

`flutter create` into a non-empty directory is fine; it will not clobber
`README.md`, `docs/` or `.git`.

- [ ] **Step 2: Pin dependencies**

Replace the `dependencies` / `dev_dependencies` blocks of `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  path_provider: ^2.1.5
  path: ^1.9.0
  home_widget: ^0.7.0
  provider: ^6.1.2
  intl: ^0.20.2
  share_plus: ^10.1.4
  shared_preferences: ^2.3.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

Then run `flutter pub get`. If a constraint is rejected by the resolver,
relax that single caret bound to whatever `flutter pub get` reports as
compatible - do not add packages that are not on this list.

- [ ] **Step 3: Tighten analysis**

`analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    require_trailing_commas: true
    prefer_single_quotes: true

analyzer:
  errors:
    missing_required_param: error
    missing_return: error
```

- [ ] **Step 4: Guard secrets in `.gitignore`**

Append:

```gitignore
# signing - never commit
android/key.properties
*.jks
*.keystore
```

- [ ] **Step 5: Write the failing theme test**

`test/ui/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beer_count/ui/theme.dart';

void main() {
  test('palette matches the spec exactly', () {
    expect(AppColors.bg, const Color(0xFF0B0B0C));
    expect(AppColors.surface, const Color(0xFF141416));
    expect(AppColors.surfaceAlt, const Color(0xFF1C1C1F));
    expect(AppColors.hairline, const Color(0xFF26262A));
    expect(AppColors.text, const Color(0xFFF4F1EA));
    expect(AppColors.textDim, const Color(0xFF8A8780));
    expect(AppColors.amber, const Color(0xFFE8A33D));
    expect(AppColors.amberDim, const Color(0xFF4A3A1E));
    expect(AppColors.over, const Color(0xFFD9603F));
  });

  test('theme is dark and uses amber as the only accent', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.bg);
    expect(theme.colorScheme.primary, AppColors.amber);
    expect(theme.colorScheme.secondary, AppColors.amber);
  });
}
```

- [ ] **Step 6: Run it and watch it fail**

Run: `flutter test test/ui/theme_test.dart`
Expected: FAIL - `Target of URI doesn't exist: 'package:beer_count/ui/theme.dart'`.

- [ ] **Step 7: Implement `lib/ui/theme.dart`**

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0B0B0C);
  static const surface = Color(0xFF141416);
  static const surfaceAlt = Color(0xFF1C1C1F);
  static const hairline = Color(0xFF26262A);
  static const text = Color(0xFFF4F1EA);
  static const textDim = Color(0xFF8A8780);
  static const amber = Color(0xFFE8A33D);
  static const amberDim = Color(0xFF4A3A1E);
  static const over = Color(0xFFD9603F);
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppText {
  static const hero = TextStyle(
    fontSize: 56,
    height: 1.0,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
    color: AppColors.text,
  );
  static const title = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.8,
    color: AppColors.text,
  );
  static const label = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.textDim,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.35,
    color: AppColors.text,
  );
  static const mono = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textDim,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.amber,
    onPrimary: AppColors.bg,
    secondary: AppColors.amber,
    onSecondary: AppColors.bg,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.over,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
```

`FontFeature` comes from `dart:ui`; add `import 'dart:ui' show FontFeature;`
if the analyzer asks for it.

- [ ] **Step 8: Delete the scaffold test and confirm green**

```bash
rm -f test/widget_test.dart
flutter test
flutter analyze
```
Expected: tests PASS, analyze reports `No issues found!`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: scaffold flutter project and dark amber theme tokens"
```

---

## Task 2: `Beer` model and `BeerSize`

**Files:**
- Create: `lib/models/beer_size.dart`, `lib/models/beer.dart`
- Test: `test/models/beer_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum BeerSize { third, half }` with `int get ml`, `String get glyph`, `String get label`, `static BeerSize? fromMl(int ml)`.
  - `class Beer` with `final String id`, `final int ml`, `final DateTime at` (always local), `double get liters`, `BeerSize? get size`.
  - `factory Beer.create({required int ml, required DateTime at, Random? random})`
  - `factory Beer.fromJsonLine(String line)` - throws `FormatException` on anything malformed.
  - `String toJsonLine()` - a single line, no trailing newline.
  - `Map<String, Object?> toJsonMap()`
  - `String newBeerId(DateTime at, Random random)`

- [ ] **Step 1: Write the failing tests**

`test/models/beer_test.dart`:

```dart
import 'dart:math';

import 'package:beer_count/models/beer.dart';
import 'package:beer_count/models/beer_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeerSize', () {
    test('has exactly two sizes with the spec volumes', () {
      expect(BeerSize.values, hasLength(2));
      expect(BeerSize.third.ml, 333);
      expect(BeerSize.half.ml, 500);
      expect(BeerSize.third.glyph, '⅓');
      expect(BeerSize.half.glyph, '½');
    });

    test('fromMl maps known volumes and nulls unknown ones', () {
      expect(BeerSize.fromMl(333), BeerSize.third);
      expect(BeerSize.fromMl(500), BeerSize.half);
      expect(BeerSize.fromMl(250), isNull);
    });
  });

  group('Beer', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1758391992123);

    test('create generates a stable id shape', () {
      final beer = Beer.create(ml: 333, at: at, random: Random(7));
      expect(beer.ml, 333);
      expect(beer.at, at);
      expect(
        RegExp(r'^\d+-[0-9a-f]{4}$').hasMatch(beer.id),
        isTrue,
        reason: 'got ${beer.id}',
      );
      expect(beer.id.split('-').first, '${at.millisecondsSinceEpoch}');
    });

    test('ids differ for the same instant', () {
      final random = Random(1);
      final ids = List.generate(
        50,
        (_) => Beer.create(ml: 500, at: at, random: random).id,
      ).toSet();
      expect(ids.length, greaterThan(1));
    });

    test('round-trips through a json line', () {
      final beer = Beer.create(ml: 500, at: at, random: Random(3));
      final decoded = Beer.fromJsonLine(beer.toJsonLine());
      expect(decoded.id, beer.id);
      expect(decoded.ml, beer.ml);
      expect(decoded.at, beer.at);
    });

    test('json line is single-line and has no trailing newline', () {
      final line = Beer.create(ml: 333, at: at, random: Random(3)).toJsonLine();
      expect(line, isNot(contains('\n')));
    });

    test('at is decoded as local time from epoch millis', () {
      const raw = '{"id":"1-aaaa","ml":333,"at":1758391992123}';
      final beer = Beer.fromJsonLine(raw);
      expect(beer.at.isUtc, isFalse);
      expect(beer.at.millisecondsSinceEpoch, 1758391992123);
    });

    test('tolerates unknown keys', () {
      const raw = '{"id":"1-aaaa","ml":500,"at":10,"brand":"Goldstar"}';
      expect(Beer.fromJsonLine(raw).ml, 500);
    });

    test('rejects malformed lines with FormatException', () {
      const bad = <String>[
        '',
        '   ',
        'not json',
        '{"id":"x"}',
        '{"ml":333,"at":10}',
        '{"id":"x","ml":"333","at":10}',
        '{"id":"x","ml":333,"at":"soon"}',
        '[1,2,3]',
      ];
      for (final line in bad) {
        expect(
          () => Beer.fromJsonLine(line),
          throwsFormatException,
          reason: 'should reject: $line',
        );
      }
    });

    test('liters and size derive from ml', () {
      expect(Beer.create(ml: 500, at: at).liters, 0.5);
      expect(Beer.create(ml: 333, at: at).size, BeerSize.third);
      expect(Beer.create(ml: 250, at: at).size, isNull);
    });
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/models/beer_test.dart`
Expected: FAIL - URIs do not exist.

- [ ] **Step 3: Implement `lib/models/beer_size.dart`**

```dart
enum BeerSize {
  third(333, '⅓', '1/3'),
  half(500, '½', '1/2');

  const BeerSize(this.ml, this.glyph, this.label);

  final int ml;
  final String glyph;
  final String label;

  static BeerSize? fromMl(int ml) {
    for (final size in values) {
      if (size.ml == ml) return size;
    }
    return null;
  }
}
```

- [ ] **Step 4: Implement `lib/models/beer.dart`**

```dart
import 'dart:convert';
import 'dart:math';

import 'beer_size.dart';

final Random _defaultRandom = Random();

String newBeerId(DateTime at, Random random) {
  final suffix = random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
  return '${at.millisecondsSinceEpoch}-$suffix';
}

class Beer {
  const Beer({required this.id, required this.ml, required this.at});

  factory Beer.create({
    required int ml,
    required DateTime at,
    Random? random,
  }) {
    final local = at.isUtc ? at.toLocal() : at;
    return Beer(
      id: newBeerId(local, random ?? _defaultRandom),
      ml: ml,
      at: local,
    );
  }

  factory Beer.fromJsonLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('empty line');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException('not a json object', trimmed);
    }
    final id = decoded['id'];
    final ml = decoded['ml'];
    final at = decoded['at'];
    if (id is! String || id.isEmpty) {
      throw FormatException('bad id', trimmed);
    }
    if (ml is! int || ml <= 0) {
      throw FormatException('bad ml', trimmed);
    }
    if (at is! int) {
      throw FormatException('bad at', trimmed);
    }
    return Beer(
      id: id,
      ml: ml,
      at: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  final String id;
  final int ml;

  /// Always local time. Persisted as epoch millis.
  final DateTime at;

  BeerSize? get size => BeerSize.fromMl(ml);

  double get liters => ml / 1000;

  Map<String, Object?> toJsonMap() => <String, Object?>{
        'id': id,
        'ml': ml,
        'at': at.millisecondsSinceEpoch,
      };

  String toJsonLine() => jsonEncode(toJsonMap());

  @override
  bool operator ==(Object other) => other is Beer && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Beer($id, ${ml}ml, $at)';
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/models/beer_test.dart && flutter analyze`
Expected: all PASS, analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/models test/models
git commit -m "feat: add Beer model and BeerSize with NDJSON codec"
```

---

## Task 3: NDJSON log file

**Files:**
- Create: `lib/data/beer_log_file.dart`
- Test: `test/data/beer_log_file_test.dart`

**Interfaces:**
- Consumes: `Beer` from Task 2.
- Produces:
  - `class BeerLogReadResult { final List<Beer> beers; final int skippedLines; }`
  - `class BeerLogFile` with `BeerLogFile(File file)`, `Future<BeerLogReadResult> readAll()`, `Future<void> append(Beer beer)`, `Future<void> rewrite(List<Beer> beers)`, `Future<void> clear()`, `File get file`.
  - `readAll` returns beers in file order (oldest first) and never throws on malformed content.

- [ ] **Step 1: Write the failing tests**

`test/data/beer_log_file_test.dart`:

```dart
import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late BeerLogFile log;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('beerlog');
    log = BeerLogFile(File('${dir.path}/beer_log.ndjson'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Beer beerAt(int millis, int ml) =>
      Beer(id: '$millis-aaaa', ml: ml, at: DateTime.fromMillisecondsSinceEpoch(millis));

  test('missing file reads as an empty log', () async {
    final result = await log.readAll();
    expect(result.beers, isEmpty);
    expect(result.skippedLines, 0);
  });

  test('append then read round-trips in file order', () async {
    await log.append(beerAt(1000, 333));
    await log.append(beerAt(2000, 500));
    final result = await log.readAll();
    expect(result.beers.map((b) => b.ml), [333, 500]);
    expect(result.skippedLines, 0);
  });

  test('each append writes exactly one newline-terminated line', () async {
    await log.append(beerAt(1000, 333));
    await log.append(beerAt(2000, 500));
    final raw = await log.file.readAsString();
    expect(raw.endsWith('\n'), isTrue);
    expect(raw.split('\n').where((l) => l.isNotEmpty), hasLength(2));
  });

  test('skips malformed lines and counts them', () async {
    await log.file.writeAsString(
      '${beerAt(1000, 333).toJsonLine()}\n'
      'garbage\n'
      '\n'
      '{"id":"x"}\n'
      '${beerAt(2000, 500).toJsonLine()}\n',
    );
    final result = await log.readAll();
    expect(result.beers.map((b) => b.ml), [333, 500]);
    expect(result.skippedLines, 2, reason: 'blank lines are not failures');
  });

  test('recovers from a truncated final line and appends cleanly', () async {
    await log.file.writeAsString(
      '${beerAt(1000, 333).toJsonLine()}\n{"id":"trunc","ml":5',
    );
    await log.append(beerAt(3000, 500));
    final result = await log.readAll();
    expect(result.beers.map((b) => b.ml), [333, 500]);
    expect(result.skippedLines, 1);
  });

  test('rewrite replaces the whole file atomically', () async {
    await log.append(beerAt(1000, 333));
    await log.append(beerAt(2000, 500));
    await log.rewrite([beerAt(2000, 500)]);
    final result = await log.readAll();
    expect(result.beers.map((b) => b.id), ['2000-aaaa']);
    expect(
      Directory(dir.path).listSync().map((e) => e.path.split('/').last),
      ['beer_log.ndjson'],
      reason: 'temp file must not survive',
    );
  });

  test('clear empties the log', () async {
    await log.append(beerAt(1000, 333));
    await log.clear();
    expect((await log.readAll()).beers, isEmpty);
  });

  test('creates parent directories on append', () async {
    final nested = BeerLogFile(File('${dir.path}/a/b/beer_log.ndjson'));
    await nested.append(beerAt(1000, 333));
    expect((await nested.readAll()).beers, hasLength(1));
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/data/beer_log_file_test.dart`
Expected: FAIL - `beer_log_file.dart` does not exist.

- [ ] **Step 3: Implement `lib/data/beer_log_file.dart`**

The truncated-final-line case is the subtle one: before appending, check the
last byte of the existing file and prepend a `\n` if it is missing, so a torn
write can never fuse with the next record.

```dart
import 'dart:io';

import '../models/beer.dart';

class BeerLogReadResult {
  const BeerLogReadResult({required this.beers, required this.skippedLines});

  final List<Beer> beers;
  final int skippedLines;

  static const empty = BeerLogReadResult(beers: <Beer>[], skippedLines: 0);
}

/// Append-only NDJSON log. The only thing in the app that touches the log
/// file on the Dart side.
class BeerLogFile {
  BeerLogFile(this.file);

  final File file;

  Future<BeerLogReadResult> readAll() async {
    if (!file.existsSync()) return BeerLogReadResult.empty;
    final raw = await file.readAsString();
    final beers = <Beer>[];
    var skipped = 0;
    for (final line in raw.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        beers.add(Beer.fromJsonLine(line));
      } on FormatException {
        skipped++;
      }
    }
    return BeerLogReadResult(beers: beers, skippedLines: skipped);
  }

  Future<void> append(Beer beer) async {
    await file.parent.create(recursive: true);
    final prefix = await _needsLeadingNewline() ? '\n' : '';
    await file.writeAsString(
      '$prefix${beer.toJsonLine()}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> rewrite(List<Beer> beers) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    final buffer = StringBuffer();
    for (final beer in beers) {
      buffer
        ..write(beer.toJsonLine())
        ..write('\n');
    }
    await temp.writeAsString(buffer.toString(), flush: true);
    await temp.rename(file.path);
  }

  Future<void> clear() => rewrite(const <Beer>[]);

  Future<bool> _needsLeadingNewline() async {
    if (!file.existsSync()) return false;
    final length = await file.length();
    if (length == 0) return false;
    final handle = await file.open();
    try {
      await handle.setPosition(length - 1);
      final last = await handle.read(1);
      return last.isNotEmpty && last.first != 0x0A;
    } finally {
      await handle.close();
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/beer_log_file_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/beer_log_file.dart test/data/beer_log_file_test.dart
git commit -m "feat: add append-only NDJSON beer log file"
```

---

## Task 4: Day/week bucketing and streaks

**Files:**
- Create: `lib/stats/buckets.dart`, `lib/stats/streaks.dart`
- Test: `test/stats/buckets_test.dart`, `test/stats/streaks_test.dart`

**Interfaces:**
- Consumes: `Beer` from Task 2.
- Produces:
  - `class DayCount { final DateTime day; final int count; final int ml; }` with `const DayCount({required this.day, required this.count, required this.ml})` and value equality.
  - `DateTime dayKey(DateTime t)` - local midnight of `t`.
  - `DateTime addDays(DateTime day, int n)` - calendar arithmetic, DST-safe.
  - `int daysBetween(DateTime from, DateTime to)` - signed calendar-day count.
  - `DateTime weekStartOf(DateTime t, int weekStartWeekday)` - `weekStartWeekday` is 1..7 (`DateTime.monday`..`DateTime.sunday`).
  - `Map<DateTime, List<Beer>> groupByDay(List<Beer> beers)` - keys are day keys.
  - `List<DayCount> dayCountsBetween(List<Beer> beers, DateTime from, DateTime to)` - inclusive, zero-filled, oldest first.
  - `class StreakResult { final int currentDry; final int longestDry; final int currentDrinking; }`
  - `StreakResult computeStreaks(Set<DateTime> activeDays, DateTime today)` - `activeDays` holds day keys.

- [ ] **Step 1: Write the failing bucket tests**

`test/stats/buckets_test.dart`:

```dart
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/stats/buckets.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, [int ml = 333]) =>
    Beer(id: '${t.millisecondsSinceEpoch}-aaaa', ml: ml, at: t);

void main() {
  test('dayKey strips the time component', () {
    expect(dayKey(DateTime(2026, 3, 27, 23, 59, 59)), DateTime(2026, 3, 27));
    expect(dayKey(DateTime(2026, 3, 27)), DateTime(2026, 3, 27));
  });

  test('addDays uses calendar arithmetic, not Duration', () {
    expect(addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
  });

  test('addDays crosses a DST boundary without drifting', () {
    // Whatever the host timezone, adding one calendar day must land on the
    // next calendar date at local midnight.
    for (var month = 1; month <= 12; month++) {
      for (final day in [1, 15, 27, 28]) {
        final start = DateTime(2026, month, day);
        final next = addDays(start, 1);
        expect(next.hour, 0, reason: 'drifted at $start');
        expect(daysBetween(start, next), 1);
      }
    }
  });

  test('daysBetween is signed', () {
    expect(daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 1)), 0);
    expect(daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 8)), 7);
    expect(daysBetween(DateTime(2026, 1, 8), DateTime(2026, 1, 1)), -7);
    expect(daysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
  });

  test('weekStartOf honours a Sunday week start', () {
    // 2026-09-20 is a Sunday.
    final sunday = DateTime(2026, 9, 20, 13);
    expect(weekStartOf(sunday, DateTime.sunday), DateTime(2026, 9, 20));
    expect(
      weekStartOf(DateTime(2026, 9, 26), DateTime.sunday),
      DateTime(2026, 9, 20),
    );
  });

  test('weekStartOf honours a Monday week start', () {
    expect(
      weekStartOf(DateTime(2026, 9, 20), DateTime.monday),
      DateTime(2026, 9, 14),
    );
    expect(
      weekStartOf(DateTime(2026, 9, 21), DateTime.monday),
      DateTime(2026, 9, 21),
    );
  });

  test('groupByDay buckets by local day and keeps entries', () {
    final beers = [
      at(DateTime(2026, 9, 20, 23, 30)),
      at(DateTime(2026, 9, 21, 0, 15)),
      at(DateTime(2026, 9, 21, 22)),
    ];
    final grouped = groupByDay(beers);
    expect(grouped.keys.toSet(), {DateTime(2026, 9, 20), DateTime(2026, 9, 21)});
    expect(grouped[DateTime(2026, 9, 21)], hasLength(2));
  });

  test('dayCountsBetween zero-fills gaps and sums ml', () {
    final beers = [
      at(DateTime(2026, 9, 18, 20), 333),
      at(DateTime(2026, 9, 20, 20), 500),
      at(DateTime(2026, 9, 20, 22), 500),
    ];
    final counts =
        dayCountsBetween(beers, DateTime(2026, 9, 18), DateTime(2026, 9, 21));
    expect(counts.map((d) => d.day), [
      DateTime(2026, 9, 18),
      DateTime(2026, 9, 19),
      DateTime(2026, 9, 20),
      DateTime(2026, 9, 21),
    ]);
    expect(counts.map((d) => d.count), [1, 0, 2, 0]);
    expect(counts.map((d) => d.ml), [333, 0, 1000, 0]);
  });

  test('dayCountsBetween ignores beers outside the range', () {
    final beers = [at(DateTime(2026, 1, 1)), at(DateTime(2026, 9, 20))];
    final counts =
        dayCountsBetween(beers, DateTime(2026, 9, 20), DateTime(2026, 9, 20));
    expect(counts, hasLength(1));
    expect(counts.single.count, 1);
  });

  test('dayCountsBetween returns empty when the range is inverted', () {
    expect(
      dayCountsBetween(const [], DateTime(2026, 9, 21), DateTime(2026, 9, 20)),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Write the failing streak tests**

`test/stats/streaks_test.dart`:

```dart
import 'package:beer_count/stats/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

Set<DateTime> days(List<int> septemberDays) =>
    septemberDays.map((d) => DateTime(2026, 9, d)).toSet();

void main() {
  final today = DateTime(2026, 9, 20);

  test('empty history has no streaks', () {
    final r = computeStreaks(const <DateTime>{}, today);
    expect(r.currentDry, 0);
    expect(r.longestDry, 0);
    expect(r.currentDrinking, 0);
  });

  test('drinking today means a zero dry streak', () {
    final r = computeStreaks(days([18, 19, 20]), today);
    expect(r.currentDry, 0);
    expect(r.currentDrinking, 3);
  });

  test('current dry streak counts back from today', () {
    final r = computeStreaks(days([17]), today);
    expect(r.currentDry, 3, reason: '18, 19 and 20 are dry');
    expect(r.currentDrinking, 0);
  });

  test('longest dry streak includes the trailing gap up to today', () {
    final r = computeStreaks(days([1, 10]), today);
    expect(r.longestDry, 10, reason: '11..20 inclusive');
  });

  test('longest dry streak finds an interior gap', () {
    final r = computeStreaks(days([1, 15, 16, 17, 18, 19, 20]), today);
    expect(r.longestDry, 13, reason: '2..14 inclusive');
    expect(r.currentDry, 0);
  });

  test('days before the first entry are not counted as dry', () {
    final r = computeStreaks(days([20]), today);
    expect(r.longestDry, 0);
  });

  test('a single entry today gives a drinking streak of one', () {
    final r = computeStreaks(days([20]), today);
    expect(r.currentDrinking, 1);
    expect(r.currentDry, 0);
  });

  test('future-dated days do not break the current streak logic', () {
    final r = computeStreaks(days([19, 20, 25]), today);
    expect(r.currentDrinking, 2);
    expect(r.currentDry, 0);
  });

  test('normalises a non-midnight today', () {
    final r = computeStreaks(days([20]), DateTime(2026, 9, 20, 23, 45));
    expect(r.currentDrinking, 1);
  });
}
```

- [ ] **Step 3: Run both and confirm failure**

Run: `flutter test test/stats/`
Expected: FAIL - `buckets.dart` and `streaks.dart` do not exist.

- [ ] **Step 4: Implement `lib/stats/buckets.dart`**

```dart
import '../models/beer.dart';

/// Count and volume for one local calendar day.
class DayCount {
  const DayCount({required this.day, required this.count, required this.ml});

  final DateTime day;
  final int count;
  final int ml;

  double get liters => ml / 1000;

  @override
  bool operator ==(Object other) =>
      other is DayCount &&
      other.day == day &&
      other.count == count &&
      other.ml == ml;

  @override
  int get hashCode => Object.hash(day, count, ml);

  @override
  String toString() => 'DayCount($day, $count, ${ml}ml)';
}

/// Local midnight of [t].
DateTime dayKey(DateTime t) => DateTime(t.year, t.month, t.day);

/// Calendar-day arithmetic. Never use `Duration(days: n)` for this: across a
/// DST transition a day is 23 or 25 hours and the result lands on the wrong
/// date.
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// Signed number of calendar days from [from] to [to].
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Start of the week containing [t], where [weekStartWeekday] is one of
/// `DateTime.monday` (1) .. `DateTime.sunday` (7).
DateTime weekStartOf(DateTime t, int weekStartWeekday) {
  final delta = (t.weekday - weekStartWeekday) % 7;
  return addDays(dayKey(t), -delta);
}

Map<DateTime, List<Beer>> groupByDay(List<Beer> beers) {
  final grouped = <DateTime, List<Beer>>{};
  for (final beer in beers) {
    grouped.putIfAbsent(dayKey(beer.at), () => <Beer>[]).add(beer);
  }
  return grouped;
}

/// Inclusive, zero-filled, oldest first.
List<DayCount> dayCountsBetween(
  List<Beer> beers,
  DateTime from,
  DateTime to,
) {
  final start = dayKey(from);
  final end = dayKey(to);
  final span = daysBetween(start, end);
  if (span < 0) return const <DayCount>[];

  final counts = <DateTime, int>{};
  final volumes = <DateTime, int>{};
  for (final beer in beers) {
    final key = dayKey(beer.at);
    if (key.isBefore(start) || key.isAfter(end)) continue;
    counts[key] = (counts[key] ?? 0) + 1;
    volumes[key] = (volumes[key] ?? 0) + beer.ml;
  }

  return List<DayCount>.generate(span + 1, (i) {
    final day = addDays(start, i);
    return DayCount(day: day, count: counts[day] ?? 0, ml: volumes[day] ?? 0);
  });
}
```

- [ ] **Step 5: Implement `lib/stats/streaks.dart`**

```dart
import 'buckets.dart';

class StreakResult {
  const StreakResult({
    required this.currentDry,
    required this.longestDry,
    required this.currentDrinking,
  });

  static const none =
      StreakResult(currentDry: 0, longestDry: 0, currentDrinking: 0);

  /// Consecutive days ending today with no beers. Zero if today has one.
  final int currentDry;

  /// Longest run of dry days since the first ever entry, including the run
  /// that ends today.
  final int longestDry;

  /// Consecutive days ending today with at least one beer. Zero if today has
  /// none.
  final int currentDrinking;
}

/// [activeDays] must contain day keys (local midnights).
StreakResult computeStreaks(Set<DateTime> activeDays, DateTime today) {
  if (activeDays.isEmpty) return StreakResult.none;

  final end = dayKey(today);
  final past = activeDays.where((d) => !d.isAfter(end)).toList();
  if (past.isEmpty) return StreakResult.none;

  final first = past.reduce((a, b) => a.isBefore(b) ? a : b);
  final active = past.toSet();

  var currentDry = 0;
  var cursor = end;
  while (!active.contains(cursor) && !cursor.isBefore(first)) {
    currentDry++;
    cursor = addDays(cursor, -1);
  }

  var currentDrinking = 0;
  cursor = end;
  while (active.contains(cursor)) {
    currentDrinking++;
    cursor = addDays(cursor, -1);
  }

  var longestDry = 0;
  var run = 0;
  final span = daysBetween(first, end);
  for (var i = 0; i <= span; i++) {
    if (active.contains(addDays(first, i))) {
      run = 0;
    } else {
      run++;
      if (run > longestDry) longestDry = run;
    }
  }

  return StreakResult(
    currentDry: currentDry,
    longestDry: longestDry,
    currentDrinking: currentDrinking,
  );
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/stats/ && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```
git add lib/stats test/stats
git commit -m "feat: add DST-safe day bucketing and streak computation"
```

---

## Task 5: `BeerStats` aggregate

**Files:**
- Create: `lib/stats/beer_stats.dart`
- Test: `test/stats/beer_stats_test.dart`

**Interfaces:**
- Consumes: `Beer`, `DayCount`, `dayKey`, `addDays`, `daysBetween`, `weekStartOf`, `dayCountsBetween`, `computeStreaks`.
- Produces `class BeerStats` built by
  `BeerStats.from(List<Beer> beers, {required DateTime now, required int weekStartWeekday, required int weeklyGoal})`
  with these final fields:

```
int todayCount, todayMl
int weekCount, weekMl, lastWeekCount, weeklyGoal
int totalCount, totalMl, daysTracked, activeDays
DateTime? firstEntry
double dailyAvg30, weeklyAvg12
List<double> avgByWeekday      // length 7, index = weekday - 1
List<int> countByHour          // length 24
int? peakHour
List<DayCount> last30Days      // oldest -> newest, length 30
int currentDryStreak, longestDryStreak, currentDrinkingStreak
DayCount? biggestDay
int weeksUnderGoal, weeksConsidered
int thirdCount, halfCount, otherCount
List<DayCount> yearGrid        // length 371, week-aligned, oldest -> newest
```

and getters `bool get isEmpty`, `double get todayLiters`, `double get weekLiters`,
`double get totalLiters`, `int get weekDelta` (`weekCount - lastWeekCount`),
`double get goalFraction` (0 when `weeklyGoal <= 0`, else `weekCount / weeklyGoal`),
`bool get overGoal`.

Rules that the tests pin down:
- `daysTracked` is calendar days from `firstEntry` to `now` inclusive; `0` when empty.
- `dailyAvg30` is beers in the last 30 calendar days (ending today) divided by 30.
- `weeklyAvg12` averages the last 12 week buckets that overlap the tracked range, current week included.
- `avgByWeekday[i]` is total beers on that weekday divided by how many times that weekday occurred between `firstEntry` and `now` inclusive; `0` when that weekday never occurred.
- `peakHour` is the hour with the highest count, lowest hour wins ties, `null` when empty.
- `weeksConsidered` is the number of **completed** weeks in the last 12 that overlap the tracked range; `weeksUnderGoal` counts those with `count <= weeklyGoal`. Both are `0` when `weeklyGoal <= 0`.
- `biggestDay` is the day with the highest count, earliest day wins ties, `null` when empty.
- `yearGrid` ends on the last day of the current week and spans exactly 371 days.

- [ ] **Step 1: Write the failing tests**

`test/stats/beer_stats_test.dart`:

```dart
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/stats/beer_stats.dart';
import 'package:beer_count/stats/buckets.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, [int ml = 333]) =>
    Beer(id: '${t.microsecondsSinceEpoch}-aaaa', ml: ml, at: t);

// 2026-09-20 is a Sunday.
final now = DateTime(2026, 9, 20, 21, 30);

BeerStats build(List<Beer> beers, {int goal = 14, int weekStart = DateTime.sunday}) =>
    BeerStats.from(beers, now: now, weekStartWeekday: weekStart, weeklyGoal: goal);

void main() {
  group('empty log', () {
    final stats = build(const []);

    test('is empty and every aggregate is a safe zero', () {
      expect(stats.isEmpty, isTrue);
      expect(stats.totalCount, 0);
      expect(stats.todayCount, 0);
      expect(stats.weekCount, 0);
      expect(stats.daysTracked, 0);
      expect(stats.firstEntry, isNull);
      expect(stats.dailyAvg30, 0);
      expect(stats.weeklyAvg12, 0);
      expect(stats.peakHour, isNull);
      expect(stats.biggestDay, isNull);
      expect(stats.goalFraction, 0);
      expect(stats.overGoal, isFalse);
    });

    test('still returns correctly shaped series', () {
      expect(stats.avgByWeekday, hasLength(7));
      expect(stats.countByHour, hasLength(24));
      expect(stats.last30Days, hasLength(30));
      expect(stats.yearGrid, hasLength(371));
      expect(stats.last30Days.every((d) => d.count == 0), isTrue);
    });
  });

  group('single entry today', () {
    final stats = build([at(DateTime(2026, 9, 20, 20), 500)]);

    test('counts today and all time', () {
      expect(stats.isEmpty, isFalse);
      expect(stats.todayCount, 1);
      expect(stats.todayMl, 500);
      expect(stats.todayLiters, 0.5);
      expect(stats.totalCount, 1);
      expect(stats.daysTracked, 1);
      expect(stats.activeDays, 1);
      expect(stats.firstEntry, DateTime(2026, 9, 20, 20));
    });

    test('week bucket uses the configured week start', () {
      expect(stats.weekCount, 1, reason: 'Sunday start, today is Sunday');
      expect(build([at(DateTime(2026, 9, 20, 20))], weekStart: DateTime.monday).weekCount, 1);
    });

    test('peak hour and size split', () {
      expect(stats.peakHour, 20);
      expect(stats.countByHour[20], 1);
      expect(stats.halfCount, 1);
      expect(stats.thirdCount, 0);
      expect(stats.otherCount, 0);
    });

    test('biggest day is that day', () {
      expect(stats.biggestDay, isNotNull);
      expect(stats.biggestDay!.day, DateTime(2026, 9, 20));
      expect(stats.biggestDay!.count, 1);
    });
  });

  group('week comparison', () {
    // Sunday week start: this week starts 2026-09-20, last week 09-13..09-19.
    final stats = build([
      at(DateTime(2026, 9, 20, 18)),
      at(DateTime(2026, 9, 20, 19)),
      at(DateTime(2026, 9, 15, 18)),
      at(DateTime(2026, 9, 16, 18)),
      at(DateTime(2026, 9, 17, 18)),
    ]);

    test('splits this week from last week', () {
      expect(stats.weekCount, 2);
      expect(stats.lastWeekCount, 3);
      expect(stats.weekDelta, -1);
    });

    test('goal fraction tracks the weekly goal', () {
      expect(stats.weeklyGoal, 14);
      expect(stats.goalFraction, closeTo(2 / 14, 1e-9));
      expect(stats.overGoal, isFalse);
    });

    test('a zero goal disables the goal entirely', () {
      final noGoal = build([at(DateTime(2026, 9, 20, 18))], goal: 0);
      expect(noGoal.goalFraction, 0);
      expect(noGoal.overGoal, isFalse);
      expect(noGoal.weeksConsidered, 0);
      expect(noGoal.weeksUnderGoal, 0);
    });

    test('over goal flips when the week exceeds it', () {
      final many = List.generate(5, (i) => at(DateTime(2026, 9, 20, 12 + i)));
      expect(build(many, goal: 4).overGoal, isTrue);
    });
  });

  group('averages', () {
    test('dailyAvg30 divides by 30 calendar days', () {
      final beers = [
        for (var i = 0; i < 15; i++) at(addDays(DateTime(2026, 9, 20), -i)),
      ];
      expect(build(beers).dailyAvg30, closeTo(15 / 30, 1e-9));
    });

    test('dailyAvg30 ignores entries older than 30 days', () {
      final beers = [
        at(DateTime(2026, 9, 20, 18)),
        at(addDays(DateTime(2026, 9, 20), -45)),
      ];
      expect(build(beers).dailyAvg30, closeTo(1 / 30, 1e-9));
    });

    test('avgByWeekday averages over weekday occurrences', () {
      // Four Sundays in a row, two beers on each.
      final beers = <Beer>[];
      for (var w = 0; w < 4; w++) {
        final day = addDays(DateTime(2026, 9, 20), -7 * w);
        beers
          ..add(at(DateTime(day.year, day.month, day.day, 18)))
          ..add(at(DateTime(day.year, day.month, day.day, 20)));
      }
      final stats = build(beers);
      expect(stats.avgByWeekday, hasLength(7));
      expect(stats.avgByWeekday[DateTime.sunday - 1], closeTo(2.0, 1e-9));
      expect(stats.avgByWeekday[DateTime.wednesday - 1], 0);
    });
  });

  group('series', () {
    test('last30Days ends today and is zero-filled', () {
      final stats = build([at(DateTime(2026, 9, 20, 18))]);
      expect(stats.last30Days, hasLength(30));
      expect(stats.last30Days.last.day, DateTime(2026, 9, 20));
      expect(stats.last30Days.last.count, 1);
      expect(stats.last30Days.first.day, addDays(DateTime(2026, 9, 20), -29));
      expect(stats.last30Days.first.count, 0);
    });

    test('yearGrid is week-aligned and 371 days long', () {
      final stats = build([at(DateTime(2026, 9, 20, 18))]);
      expect(stats.yearGrid, hasLength(371));
      expect(stats.yearGrid.first.day.weekday, DateTime.sunday);
      expect(stats.yearGrid.last.day, addDays(stats.yearGrid.first.day, 370));
      final today =
          stats.yearGrid.firstWhere((d) => d.day == DateTime(2026, 9, 20));
      expect(today.count, 1);
    });

    test('yearGrid respects a Monday week start', () {
      final stats = build([at(DateTime(2026, 9, 20, 18))], weekStart: DateTime.monday);
      expect(stats.yearGrid.first.day.weekday, DateTime.monday);
    });
  });

  group('streaks and records', () {
    test('surfaces streaks from the streak module', () {
      final stats = build([
        at(DateTime(2026, 9, 18, 18)),
        at(DateTime(2026, 9, 19, 18)),
        at(DateTime(2026, 9, 20, 18)),
      ]);
      expect(stats.currentDrinkingStreak, 3);
      expect(stats.currentDryStreak, 0);
    });

    test('dry streak counts back from today', () {
      final stats = build([at(DateTime(2026, 9, 16, 18))]);
      expect(stats.currentDryStreak, 4);
    });

    test('biggest day picks the highest count, earliest on a tie', () {
      final stats = build([
        at(DateTime(2026, 9, 10, 18)),
        at(DateTime(2026, 9, 10, 19)),
        at(DateTime(2026, 9, 12, 18)),
        at(DateTime(2026, 9, 12, 19)),
      ]);
      expect(stats.biggestDay!.day, DateTime(2026, 9, 10));
      expect(stats.biggestDay!.count, 2);
    });

    test('weeks under goal only counts completed weeks', () {
      // Completed week 09-13..09-19 has 3 beers; current week has 99.
      final beers = <Beer>[
        at(DateTime(2026, 9, 15, 18)),
        at(DateTime(2026, 9, 16, 18)),
        at(DateTime(2026, 9, 17, 18)),
        for (var i = 0; i < 99; i++) at(DateTime(2026, 9, 20, 10)),
      ];
      final stats = build(beers, goal: 5);
      expect(stats.weeksConsidered, 1);
      expect(stats.weeksUnderGoal, 1);
    });
  });

  group('boundaries', () {
    test('an entry just after midnight belongs to the new day', () {
      final stats = build([at(DateTime(2026, 9, 20, 0, 1))]);
      expect(stats.todayCount, 1);
    });

    test('an entry just before midnight belongs to the old day', () {
      final stats = build([at(DateTime(2026, 9, 19, 23, 59))]);
      expect(stats.todayCount, 0);
      expect(stats.totalCount, 1);
    });

    test('unknown volumes land in otherCount', () {
      final stats = build([at(DateTime(2026, 9, 20, 18), 250)]);
      expect(stats.otherCount, 1);
      expect(stats.thirdCount, 0);
      expect(stats.halfCount, 0);
      expect(stats.totalMl, 250);
    });

    test('input order does not matter', () {
      final ordered = build([
        at(DateTime(2026, 9, 18, 18)),
        at(DateTime(2026, 9, 20, 18)),
      ]);
      final reversed = build([
        at(DateTime(2026, 9, 20, 18)),
        at(DateTime(2026, 9, 18, 18)),
      ]);
      expect(reversed.firstEntry, ordered.firstEntry);
      expect(reversed.daysTracked, ordered.daysTracked);
      expect(reversed.totalCount, ordered.totalCount);
    });
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/stats/beer_stats_test.dart`
Expected: FAIL - `beer_stats.dart` does not exist.

- [ ] **Step 3: Implement `lib/stats/beer_stats.dart`**

```dart
import '../models/beer.dart';
import '../models/beer_size.dart';
import 'buckets.dart';
import 'streaks.dart';

class BeerStats {
  const BeerStats._({
    required this.todayCount,
    required this.todayMl,
    required this.weekCount,
    required this.weekMl,
    required this.lastWeekCount,
    required this.weeklyGoal,
    required this.totalCount,
    required this.totalMl,
    required this.daysTracked,
    required this.activeDays,
    required this.firstEntry,
    required this.dailyAvg30,
    required this.weeklyAvg12,
    required this.avgByWeekday,
    required this.countByHour,
    required this.peakHour,
    required this.last30Days,
    required this.currentDryStreak,
    required this.longestDryStreak,
    required this.currentDrinkingStreak,
    required this.biggestDay,
    required this.weeksUnderGoal,
    required this.weeksConsidered,
    required this.thirdCount,
    required this.halfCount,
    required this.otherCount,
    required this.yearGrid,
  });

  factory BeerStats.from(
    List<Beer> beers, {
    required DateTime now,
    required int weekStartWeekday,
    required int weeklyGoal,
  }) {
    final today = dayKey(now);
    final weekStart = weekStartOf(now, weekStartWeekday);
    final lastWeekStart = addDays(weekStart, -7);

    final gridEnd = addDays(weekStart, 6);
    final gridStart = addDays(gridEnd, -370);
    final yearGrid = dayCountsBetween(beers, gridStart, gridEnd);
    final last30Days =
        dayCountsBetween(beers, addDays(today, -29), today);

    if (beers.isEmpty) {
      return BeerStats._(
        todayCount: 0,
        todayMl: 0,
        weekCount: 0,
        weekMl: 0,
        lastWeekCount: 0,
        weeklyGoal: weeklyGoal,
        totalCount: 0,
        totalMl: 0,
        daysTracked: 0,
        activeDays: 0,
        firstEntry: null,
        dailyAvg30: 0,
        weeklyAvg12: 0,
        avgByWeekday: List<double>.filled(7, 0),
        countByHour: List<int>.filled(24, 0),
        peakHour: null,
        last30Days: last30Days,
        currentDryStreak: 0,
        longestDryStreak: 0,
        currentDrinkingStreak: 0,
        biggestDay: null,
        weeksUnderGoal: 0,
        weeksConsidered: 0,
        thirdCount: 0,
        halfCount: 0,
        otherCount: 0,
        yearGrid: yearGrid,
      );
    }

    var todayCount = 0;
    var todayMl = 0;
    var weekCount = 0;
    var weekMl = 0;
    var lastWeekCount = 0;
    var totalMl = 0;
    var thirdCount = 0;
    var halfCount = 0;
    var otherCount = 0;
    final countByHour = List<int>.filled(24, 0);
    final byWeekdayTotal = List<int>.filled(7, 0);
    var firstEntry = beers.first.at;

    for (final beer in beers) {
      final day = dayKey(beer.at);
      if (beer.at.isBefore(firstEntry)) firstEntry = beer.at;
      totalMl += beer.ml;
      countByHour[beer.at.hour]++;
      byWeekdayTotal[beer.at.weekday - 1]++;

      switch (beer.size) {
        case BeerSize.third:
          thirdCount++;
        case BeerSize.half:
          halfCount++;
        case null:
          otherCount++;
      }

      if (day == today) {
        todayCount++;
        todayMl += beer.ml;
      }
      if (!day.isBefore(weekStart) && day.isBefore(addDays(weekStart, 7))) {
        weekCount++;
        weekMl += beer.ml;
      } else if (!day.isBefore(lastWeekStart) && day.isBefore(weekStart)) {
        lastWeekCount++;
      }
    }

    final firstDay = dayKey(firstEntry);
    final daysTracked = daysBetween(firstDay, today) + 1;

    final dayCounts = dayCountsBetween(beers, firstDay, today);
    final activeDays = dayCounts.where((d) => d.count > 0).length;

    DayCount? biggestDay;
    for (final d in dayCounts) {
      if (d.count == 0) continue;
      if (biggestDay == null || d.count > biggestDay.count) biggestDay = d;
    }

    final last30Count =
        last30Days.fold<int>(0, (sum, d) => sum + d.count);

    final weekdayOccurrences = List<int>.filled(7, 0);
    for (final d in dayCounts) {
      weekdayOccurrences[d.day.weekday - 1]++;
    }
    final avgByWeekday = List<double>.generate(7, (i) {
      final occurrences = weekdayOccurrences[i];
      return occurrences == 0 ? 0 : byWeekdayTotal[i] / occurrences;
    });

    var peakHour = 0;
    for (var h = 1; h < 24; h++) {
      if (countByHour[h] > countByHour[peakHour]) peakHour = h;
    }

    // Week buckets: index 0 is the current week, 1 is last week, and so on.
    final weekTotals = List<int>.filled(13, 0);
    for (final beer in beers) {
      final bucketStart = weekStartOf(beer.at, weekStartWeekday);
      final index = daysBetween(bucketStart, weekStart) ~/ 7;
      if (index >= 0 && index < weekTotals.length) weekTotals[index]++;
    }

    final trackedWeeks = (daysBetween(
                weekStartOf(firstDay, weekStartWeekday), weekStart) ~/
            7) +
        1;
    final consideredForAvg = trackedWeeks.clamp(1, 12);
    final weeklyAvg12 = weekTotals
            .take(consideredForAvg)
            .fold<int>(0, (sum, c) => sum + c) /
        consideredForAvg;

    var weeksConsidered = 0;
    var weeksUnderGoal = 0;
    if (weeklyGoal > 0) {
      final completed = (trackedWeeks - 1).clamp(0, 12);
      for (var i = 1; i <= completed; i++) {
        weeksConsidered++;
        if (weekTotals[i] <= weeklyGoal) weeksUnderGoal++;
      }
    }

    final streaks = computeStreaks(
      dayCounts.where((d) => d.count > 0).map((d) => d.day).toSet(),
      today,
    );

    return BeerStats._(
      todayCount: todayCount,
      todayMl: todayMl,
      weekCount: weekCount,
      weekMl: weekMl,
      lastWeekCount: lastWeekCount,
      weeklyGoal: weeklyGoal,
      totalCount: beers.length,
      totalMl: totalMl,
      daysTracked: daysTracked,
      activeDays: activeDays,
      firstEntry: firstEntry,
      dailyAvg30: last30Count / 30,
      weeklyAvg12: weeklyAvg12,
      avgByWeekday: avgByWeekday,
      countByHour: countByHour,
      peakHour: countByHour[peakHour] == 0 ? null : peakHour,
      last30Days: last30Days,
      currentDryStreak: streaks.currentDry,
      longestDryStreak: streaks.longestDry,
      currentDrinkingStreak: streaks.currentDrinking,
      biggestDay: biggestDay,
      weeksUnderGoal: weeksUnderGoal,
      weeksConsidered: weeksConsidered,
      thirdCount: thirdCount,
      halfCount: halfCount,
      otherCount: otherCount,
      yearGrid: yearGrid,
    );
  }

  final int todayCount;
  final int todayMl;
  final int weekCount;
  final int weekMl;
  final int lastWeekCount;
  final int weeklyGoal;
  final int totalCount;
  final int totalMl;
  final int daysTracked;
  final int activeDays;
  final DateTime? firstEntry;
  final double dailyAvg30;
  final double weeklyAvg12;
  final List<double> avgByWeekday;
  final List<int> countByHour;
  final int? peakHour;
  final List<DayCount> last30Days;
  final int currentDryStreak;
  final int longestDryStreak;
  final int currentDrinkingStreak;
  final DayCount? biggestDay;
  final int weeksUnderGoal;
  final int weeksConsidered;
  final int thirdCount;
  final int halfCount;
  final int otherCount;
  final List<DayCount> yearGrid;

  bool get isEmpty => totalCount == 0;

  double get todayLiters => todayMl / 1000;
  double get weekLiters => weekMl / 1000;
  double get totalLiters => totalMl / 1000;

  int get weekDelta => weekCount - lastWeekCount;

  double get goalFraction =>
      weeklyGoal <= 0 ? 0 : weekCount / weeklyGoal;

  bool get overGoal => weeklyGoal > 0 && weekCount > weeklyGoal;
}
```

- [ ] **Step 4: Run tests until green**

Run: `flutter test test/stats/beer_stats_test.dart && flutter analyze`
Expected: PASS, clean. If `weeklyAvg12` or `weeksConsidered` disagree with the
tests, the week-bucket index arithmetic is the place to look - `index 0` must
be the current week.

- [ ] **Step 5: Commit**

```
git add lib/stats/beer_stats.dart test/stats/beer_stats_test.dart
git commit -m "feat: add BeerStats aggregate over the beer log"
```

---

## Task 6: Settings store and exporter

**Files:**
- Create: `lib/data/settings_store.dart`, `lib/data/exporter.dart`
- Test: `test/data/settings_store_test.dart`, `test/data/exporter_test.dart`

**Interfaces:**
- Consumes: `Beer`, `BeerSize`.
- Produces:
  - `class SettingsStore extends ChangeNotifier` with `static const int defaultWeeklyGoal = 14`, `static const String kWeeklyGoal = 'weekly_goal'`, `static const String kWeekStart = 'week_start_weekday'`, `int get weeklyGoal`, `int get weekStartWeekday`, `Future<void> load()`, `Future<void> setWeeklyGoal(int value)`, `Future<void> setWeekStartWeekday(int value)`.
  - `String beersToCsv(List<Beer> beers)` and `String beersToJson(List<Beer> beers)`.

- [ ] **Step 1: Write the failing settings tests**

`test/data/settings_store_test.dart`:

```dart
import 'package:beer_count/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('defaults to a goal of 14 beers and a Sunday week start', () async {
    final store = SettingsStore();
    await store.load();
    expect(store.weeklyGoal, 14);
    expect(store.weekStartWeekday, DateTime.sunday);
  });

  test('reads persisted values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStore.kWeeklyGoal: 7,
      SettingsStore.kWeekStart: DateTime.monday,
    });
    final store = SettingsStore();
    await store.load();
    expect(store.weeklyGoal, 7);
    expect(store.weekStartWeekday, DateTime.monday);
  });

  test('setting the goal persists and notifies', () async {
    final store = SettingsStore();
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.setWeeklyGoal(21);
    expect(store.weeklyGoal, 21);
    expect(notifications, 1);

    final reloaded = SettingsStore();
    await reloaded.load();
    expect(reloaded.weeklyGoal, 21);
  });

  test('goal is clamped to 0..99 and 0 means disabled', () async {
    final store = SettingsStore();
    await store.load();
    await store.setWeeklyGoal(-5);
    expect(store.weeklyGoal, 0);
    await store.setWeeklyGoal(500);
    expect(store.weeklyGoal, 99);
  });

  test('week start only accepts Monday or Sunday', () async {
    final store = SettingsStore();
    await store.load();
    await store.setWeekStartWeekday(DateTime.monday);
    expect(store.weekStartWeekday, DateTime.monday);
    await store.setWeekStartWeekday(DateTime.wednesday);
    expect(store.weekStartWeekday, DateTime.monday, reason: 'unchanged');
  });

  test('a corrupt stored weekday falls back to Sunday', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStore.kWeekStart: 99,
    });
    final store = SettingsStore();
    await store.load();
    expect(store.weekStartWeekday, DateTime.sunday);
  });
}
```

- [ ] **Step 2: Write the failing exporter tests**

`test/data/exporter_test.dart`:

```dart
import 'dart:convert';

import 'package:beer_count/data/exporter.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, int ml) =>
    Beer(id: '${t.millisecondsSinceEpoch}-aaaa', ml: ml, at: t);

void main() {
  final beers = [
    at(DateTime(2026, 9, 20, 21, 5), 500),
    at(DateTime(2026, 9, 18, 9, 30), 333),
  ];

  test('csv has a header and one row per beer, oldest first', () {
    final lines = const LineSplitter().convert(beersToCsv(beers));
    expect(lines.first, 'id,logged_at_local,epoch_ms,ml,size');
    expect(lines, hasLength(3));
    expect(lines[1], contains('2026-09-18T09:30:00'));
    expect(lines[1], endsWith(',333,1/3'));
    expect(lines[2], endsWith(',500,1/2'));
  });

  test('csv labels an unknown volume as "other"', () {
    final csv = beersToCsv([at(DateTime(2026, 9, 20, 12), 250)]);
    expect(csv, contains(',250,other'));
  });

  test('csv of an empty log is just the header', () {
    expect(beersToCsv(const []).trim(), 'id,logged_at_local,epoch_ms,ml,size');
  });

  test('json is a parseable list, oldest first', () {
    final decoded = jsonDecode(beersToJson(beers)) as List<Object?>;
    expect(decoded, hasLength(2));
    final first = decoded.first! as Map<String, Object?>;
    expect(first['ml'], 333);
    expect(first['at'], DateTime(2026, 9, 18, 9, 30).millisecondsSinceEpoch);
  });

  test('json round-trips back into Beer objects', () {
    final decoded = jsonDecode(beersToJson(beers)) as List<Object?>;
    final back = decoded
        .map((e) => Beer.fromJsonLine(jsonEncode(e)))
        .toList();
    expect(back.map((b) => b.ml), [333, 500]);
  });
}
```

- [ ] **Step 3: Run both and confirm failure**

Run: `flutter test test/data/settings_store_test.dart test/data/exporter_test.dart`
Expected: FAIL - files do not exist.

- [ ] **Step 4: Implement `lib/data/settings_store.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weekly goal and week start. Nothing else is configurable by design.
class SettingsStore extends ChangeNotifier {
  static const int defaultWeeklyGoal = 14;
  static const String kWeeklyGoal = 'weekly_goal';
  static const String kWeekStart = 'week_start_weekday';

  int _weeklyGoal = defaultWeeklyGoal;
  int _weekStartWeekday = DateTime.sunday;

  /// Beers per week. Zero disables the goal entirely.
  int get weeklyGoal => _weeklyGoal;

  /// `DateTime.sunday` or `DateTime.monday`.
  int get weekStartWeekday => _weekStartWeekday;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _weeklyGoal = (prefs.getInt(kWeeklyGoal) ?? defaultWeeklyGoal).clamp(0, 99);
    final stored = prefs.getInt(kWeekStart);
    _weekStartWeekday =
        stored == DateTime.monday || stored == DateTime.sunday
            ? stored!
            : DateTime.sunday;
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int value) async {
    final clamped = value.clamp(0, 99);
    if (clamped == _weeklyGoal) return;
    _weeklyGoal = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kWeeklyGoal, clamped);
    notifyListeners();
  }

  Future<void> setWeekStartWeekday(int value) async {
    if (value != DateTime.monday && value != DateTime.sunday) return;
    if (value == _weekStartWeekday) return;
    _weekStartWeekday = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kWeekStart, value);
    notifyListeners();
  }
}
```

- [ ] **Step 5: Implement `lib/data/exporter.dart`**

```dart
import 'dart:convert';

import '../models/beer.dart';

List<Beer> _oldestFirst(List<Beer> beers) =>
    [...beers]..sort((a, b) => a.at.compareTo(b.at));

String _isoLocal(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String beersToCsv(List<Beer> beers) {
  final buffer = StringBuffer('id,logged_at_local,epoch_ms,ml,size\n');
  for (final beer in _oldestFirst(beers)) {
    buffer
      ..write(beer.id)
      ..write(',')
      ..write(_isoLocal(beer.at))
      ..write(',')
      ..write(beer.at.millisecondsSinceEpoch)
      ..write(',')
      ..write(beer.ml)
      ..write(',')
      ..write(beer.size?.label ?? 'other')
      ..write('\n');
  }
  return buffer.toString();
}

String beersToJson(List<Beer> beers) => const JsonEncoder.withIndent('  ')
    .convert(_oldestFirst(beers).map((b) => b.toJsonMap()).toList());
```

Ids and labels contain no commas or quotes by construction, so no CSV escaping
is needed. If a future field can contain a comma, add quoting then.

- [ ] **Step 6: Run tests**

Run: `flutter test test/data/ && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```
git add lib/data/settings_store.dart lib/data/exporter.dart test/data
git commit -m "feat: add settings store and CSV/JSON exporter"
```

---

## Task 7: Widget bridge and `BeerRepository`

**Files:**
- Create: `lib/data/widget_bridge.dart`, `lib/data/beer_repository.dart`
- Test: `test/data/widget_bridge_test.dart`, `test/data/beer_repository_test.dart`

**Interfaces:**
- Consumes: `Beer`, `BeerSize`, `BeerLogFile`, `dayKey`.
- Produces:
  - `class WidgetSummary` with `final String dayKey`, `final int count`, `final int ml`, `static const WidgetSummary empty`, value equality.
  - `String formatDayKey(DateTime day)` - `yyyy-MM-dd`, zero padded.
  - `WidgetSummary summarizeToday(List<Beer> beers, DateTime now)`.
  - `abstract interface class WidgetBridge { Future<void> push(WidgetSummary summary); }`
  - `class HomeWidgetBridge implements WidgetBridge` - writes the three String keys and calls `HomeWidget.updateWidget`.
  - `class NoopWidgetBridge implements WidgetBridge` - used on non-Android hosts and in tests.
  - `class BeerRepository extends ChangeNotifier` with the constructor
    `BeerRepository({required BeerLogFile log, required WidgetBridge widget, DateTime Function()? clock, Random? random})`
    and members `List<Beer> get beers` (newest first, unmodifiable), `int get skippedLines`, `bool get isLoading`, `String? get lastError`, `Future<void> load()`, `Future<Beer?> add(BeerSize size)`, `Future<Beer?> addAt({required int ml, required DateTime at})`, `Future<void> remove(String id)`, `Future<void> restore(Beer beer)`, `Future<void> eraseAll()`.

- [ ] **Step 1: Write the failing widget-bridge tests**

`test/data/widget_bridge_test.dart`:

```dart
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

Beer at(DateTime t, int ml) =>
    Beer(id: '${t.millisecondsSinceEpoch}-aaaa', ml: ml, at: t);

void main() {
  final now = DateTime(2026, 9, 20, 21, 30);

  test('formatDayKey zero-pads', () {
    expect(formatDayKey(DateTime(2026, 9, 7)), '2026-09-07');
    expect(formatDayKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('summarizes only today', () {
    final summary = summarizeToday([
      at(DateTime(2026, 9, 20, 18), 333),
      at(DateTime(2026, 9, 20, 20), 500),
      at(DateTime(2026, 9, 19, 20), 500),
    ], now);
    expect(summary.dayKey, '2026-09-20');
    expect(summary.count, 2);
    expect(summary.ml, 833);
  });

  test('an empty day still carries today key', () {
    final summary = summarizeToday(const [], now);
    expect(summary.dayKey, '2026-09-20');
    expect(summary.count, 0);
    expect(summary.ml, 0);
  });

  test('value equality', () {
    expect(
      summarizeToday(const [], now),
      summarizeToday(const [], DateTime(2026, 9, 20, 1)),
    );
  });

  test('noop bridge does nothing and does not throw', () async {
    await const NoopWidgetBridge().push(WidgetSummary.empty);
  });
}
```

- [ ] **Step 2: Write the failing repository tests**

`test/data/beer_repository_test.dart`:

```dart
import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/models/beer_size.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBridge implements WidgetBridge {
  final pushes = <WidgetSummary>[];

  @override
  Future<void> push(WidgetSummary summary) async => pushes.add(summary);
}

void main() {
  late Directory dir;
  late BeerLogFile log;
  late FakeBridge bridge;
  late BeerRepository repo;
  var now = DateTime(2026, 9, 20, 21, 30);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('beerrepo');
    log = BeerLogFile(File('${dir.path}/beer_log.ndjson'));
    bridge = FakeBridge();
    repo = BeerRepository(log: log, widget: bridge, clock: () => now);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('loads an empty log without error', () async {
    await repo.load();
    expect(repo.beers, isEmpty);
    expect(repo.isLoading, isFalse);
    expect(repo.lastError, isNull);
    expect(repo.skippedLines, 0);
  });

  test('add appends, keeps newest first and notifies', () async {
    await repo.load();
    var notifications = 0;
    repo.addListener(() => notifications++);

    now = DateTime(2026, 9, 20, 20);
    await repo.add(BeerSize.third);
    now = DateTime(2026, 9, 20, 21);
    await repo.add(BeerSize.half);

    expect(repo.beers.map((b) => b.ml), [500, 333]);
    expect(notifications, 2);
    expect((await log.readAll()).beers, hasLength(2));
  });

  test('add pushes the widget summary for today', () async {
    await repo.load();
    await repo.add(BeerSize.half);
    expect(bridge.pushes.last.dayKey, '2026-09-20');
    expect(bridge.pushes.last.count, 1);
    expect(bridge.pushes.last.ml, 500);
  });

  test('load sorts a shuffled file newest first', () async {
    await log.append(Beer(
      id: 'b',
      ml: 500,
      at: DateTime(2026, 9, 20, 10),
    ));
    await log.append(Beer(
      id: 'a',
      ml: 333,
      at: DateTime(2026, 9, 19, 10),
    ));
    await repo.load();
    expect(repo.beers.map((b) => b.id), ['b', 'a']);
  });

  test('load surfaces skipped lines', () async {
    await log.file.writeAsString('garbage\n');
    await repo.load();
    expect(repo.skippedLines, 1);
    expect(repo.beers, isEmpty);
  });

  test('load picks up entries written by the widget', () async {
    await repo.load();
    await log.append(Beer(id: 'w', ml: 500, at: DateTime(2026, 9, 20, 22)));
    expect(repo.beers, isEmpty);
    await repo.load();
    expect(repo.beers.single.id, 'w');
  });

  test('remove drops the entry from memory and file', () async {
    await repo.load();
    final beer = await repo.add(BeerSize.third);
    await repo.remove(beer!.id);
    expect(repo.beers, isEmpty);
    expect((await log.readAll()).beers, isEmpty);
  });

  test('remove of an unknown id is a no-op', () async {
    await repo.load();
    await repo.add(BeerSize.third);
    await repo.remove('nope');
    expect(repo.beers, hasLength(1));
  });

  test('restore puts a removed entry back in order', () async {
    await repo.load();
    now = DateTime(2026, 9, 20, 18);
    final first = await repo.add(BeerSize.third);
    now = DateTime(2026, 9, 20, 22);
    await repo.add(BeerSize.half);

    await repo.remove(first!.id);
    expect(repo.beers.map((b) => b.ml), [500]);

    await repo.restore(first);
    expect(repo.beers.map((b) => b.ml), [500, 333]);
    expect((await log.readAll()).beers, hasLength(2));
  });

  test('eraseAll clears memory, file and the widget summary', () async {
    await repo.load();
    await repo.add(BeerSize.half);
    await repo.eraseAll();
    expect(repo.beers, isEmpty);
    expect((await log.readAll()).beers, isEmpty);
    expect(bridge.pushes.last.count, 0);
  });

  test('addAt accepts an explicit time and volume', () async {
    await repo.load();
    final beer = await repo.addAt(ml: 250, at: DateTime(2026, 9, 19, 12));
    expect(beer, isNotNull);
    expect(repo.beers.single.ml, 250);
    expect(repo.beers.single.at, DateTime(2026, 9, 19, 12));
  });

  test('an unwritable log surfaces an error instead of throwing', () async {
    final broken = BeerRepository(
      // A path whose parent is a file, so directory creation must fail.
      log: BeerLogFile(File('${log.file.path}/nested/beer_log.ndjson')),
      widget: bridge,
      clock: () => now,
    );
    await log.append(Beer(id: 'x', ml: 333, at: now));
    await broken.load();
    final result = await broken.add(BeerSize.half);
    expect(result, isNull);
    expect(broken.lastError, isNotNull);
  });
}
```

- [ ] **Step 3: Run and confirm failure**

Run: `flutter test test/data/widget_bridge_test.dart test/data/beer_repository_test.dart`
Expected: FAIL - files do not exist.

- [ ] **Step 4: Implement `lib/data/widget_bridge.dart`**

```dart
import 'package:home_widget/home_widget.dart';

import '../models/beer.dart';
import '../stats/buckets.dart';

/// The Android widget provider class name. Must match the Kotlin class.
const String kAndroidWidgetName = 'BeerWidgetProvider';

const String kPrefTodayKey = 'today_key';
const String kPrefTodayCount = 'today_count';
const String kPrefTodayMl = 'today_ml';

String formatDayKey(DateTime day) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// The tiny cache the home-screen widget renders from. The NDJSON log stays
/// the source of truth; this is recomputed from it on every app load.
class WidgetSummary {
  const WidgetSummary({
    required this.dayKey,
    required this.count,
    required this.ml,
  });

  static const empty = WidgetSummary(dayKey: '', count: 0, ml: 0);

  final String dayKey;
  final int count;
  final int ml;

  @override
  bool operator ==(Object other) =>
      other is WidgetSummary &&
      other.dayKey == dayKey &&
      other.count == count &&
      other.ml == ml;

  @override
  int get hashCode => Object.hash(dayKey, count, ml);

  @override
  String toString() => 'WidgetSummary($dayKey, $count, ${ml}ml)';
}

WidgetSummary summarizeToday(List<Beer> beers, DateTime now) {
  final today = dayKey(now);
  var count = 0;
  var ml = 0;
  for (final beer in beers) {
    if (dayKey(beer.at) != today) continue;
    count++;
    ml += beer.ml;
  }
  return WidgetSummary(dayKey: formatDayKey(today), count: count, ml: ml);
}

abstract interface class WidgetBridge {
  Future<void> push(WidgetSummary summary);
}

class NoopWidgetBridge implements WidgetBridge {
  const NoopWidgetBridge();

  @override
  Future<void> push(WidgetSummary summary) async {}
}

/// Everything is stored as a String so Dart and Kotlin cannot disagree about
/// integer width across the plugin's method channel.
class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge();

  @override
  Future<void> push(WidgetSummary summary) async {
    await HomeWidget.saveWidgetData<String>(kPrefTodayKey, summary.dayKey);
    await HomeWidget.saveWidgetData<String>(
      kPrefTodayCount,
      '${summary.count}',
    );
    await HomeWidget.saveWidgetData<String>(kPrefTodayMl, '${summary.ml}');
    await HomeWidget.updateWidget(
      name: kAndroidWidgetName,
      androidName: kAndroidWidgetName,
    );
  }
}
```

- [ ] **Step 5: Implement `lib/data/beer_repository.dart`**

```dart
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/beer.dart';
import '../models/beer_size.dart';
import 'beer_log_file.dart';
import 'widget_bridge.dart';

/// Owns the in-memory log and is the only place that mutates it.
/// Entries are always exposed newest first.
class BeerRepository extends ChangeNotifier {
  BeerRepository({
    required BeerLogFile log,
    required WidgetBridge widget,
    DateTime Function()? clock,
    Random? random,
  })  : _log = log,
        _widget = widget,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final BeerLogFile _log;
  final WidgetBridge _widget;
  final DateTime Function() _clock;
  final Random _random;

  List<Beer> _beers = <Beer>[];
  int _skippedLines = 0;
  bool _isLoading = false;
  String? _lastError;

  List<Beer> get beers => List<Beer>.unmodifiable(_beers);
  int get skippedLines => _skippedLines;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _log.readAll();
      _beers = _sorted(result.beers);
      _skippedLines = result.skippedLines;
      _lastError = null;
    } on Object catch (e) {
      _lastError = '$e';
    } finally {
      _isLoading = false;
    }
    await _pushSummary();
    notifyListeners();
  }

  Future<Beer?> add(BeerSize size) =>
      addAt(ml: size.ml, at: _clock());

  Future<Beer?> addAt({required int ml, required DateTime at}) async {
    final beer = Beer.create(ml: ml, at: at, random: _random);
    try {
      await _log.append(beer);
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return null;
    }
    _beers = _sorted([..._beers, beer]);
    _lastError = null;
    await _pushSummary();
    notifyListeners();
    return beer;
  }

  Future<void> restore(Beer beer) async {
    if (_beers.any((b) => b.id == beer.id)) return;
    try {
      await _log.append(beer);
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return;
    }
    _beers = _sorted([..._beers, beer]);
    _lastError = null;
    await _pushSummary();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final remaining = _beers.where((b) => b.id != id).toList();
    if (remaining.length == _beers.length) return;
    try {
      await _log.rewrite(remaining.reversed.toList());
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return;
    }
    _beers = remaining;
    _lastError = null;
    await _pushSummary();
    notifyListeners();
  }

  Future<void> eraseAll() async {
    try {
      await _log.clear();
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
      return;
    }
    _beers = <Beer>[];
    _skippedLines = 0;
    _lastError = null;
    await _pushSummary();
    notifyListeners();
  }

  Future<void> _pushSummary() async {
    try {
      await _widget.push(summarizeToday(_beers, _clock()));
    } on Object {
      // The widget cache is best-effort; never fail a log because of it.
    }
  }

  static List<Beer> _sorted(List<Beer> beers) =>
      [...beers]..sort((a, b) => b.at.compareTo(a.at));
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/data/ && flutter analyze`
Expected: PASS, clean. `home_widget` is only imported, never called, in these
tests, so no platform channel is touched.

- [ ] **Step 7: Commit**

```
git add lib/data/widget_bridge.dart lib/data/beer_repository.dart test/data
git commit -m "feat: add widget summary bridge and beer repository"
```

---

## Task 8: App shell and timeline screen

**Files:**
- Create: `lib/main.dart` (replace scaffold), `lib/ui/app_shell.dart`, `lib/ui/timeline_screen.dart`, `lib/ui/widgets/log_buttons.dart`, `lib/ui/widgets/goal_bar.dart`, `lib/ui/widgets/day_section.dart`, `lib/ui/format.dart`
- Test: `test/ui/timeline_screen_test.dart`

**Interfaces:**
- Consumes: `BeerRepository`, `SettingsStore`, `BeerStats`, `groupByDay`, theme tokens.
- Produces:
  - `String formatLiters(double liters)` - one decimal, trailing `L`, e.g. `1.8 L`.
  - `String formatDayLabel(DateTime day, DateTime now)` - `TODAY`, `YESTERDAY`, else `EEE d MMM` uppercased.
  - `String formatTime(DateTime t)` - `HH:mm`.
  - `class LogButtons extends StatelessWidget` - `LogButtons({required ValueChanged<BeerSize> onLog})`.
  - `class GoalBar extends StatelessWidget` - `GoalBar({required int count, required int goal})`; renders nothing when `goal <= 0`.
  - `class DaySection extends StatelessWidget` - `DaySection({required DateTime day, required List<Beer> beers, required DateTime now, required ValueChanged<Beer> onDelete})`.
  - `class AppShell extends StatefulWidget` - bottom nav, index 0 Timeline, index 1 Stats, reloads the repository on `AppLifecycleState.resumed`.
  - `class TimelineScreen extends StatelessWidget`.

**Layout contract** (from spec 6.1, top to bottom inside a `CustomScrollView`):
1. `SliverAppBar` - title `BEER COUNT` in `AppText.label`, trailing settings `IconButton` pushing `SettingsScreen`.
2. Hero block - `stats.todayCount` in `AppText.hero`, sub-line `today · <liters>` in `AppText.mono`.
3. `GoalBar` - label row `THIS WEEK` / `<count> / <goal>`, then a 6dp rounded track: `AppColors.amberDim` background, `AppColors.amber` fill, `AppColors.over` fill when over goal, animated with `AnimatedFractionallySizedBox` over 400 ms `Curves.easeOut`.
4. `LogButtons` - two equal-width 88dp-tall cards, `AppColors.surface`, 12dp radius, 1dp `AppColors.hairline` border, glyph in `AppText.title` amber, `label` under it in `AppText.label`.
5. One `DaySection` per day, newest first: a pinned header (`formatDayLabel` in `AppText.label`, right-aligned `<count> · <liters>` in `AppText.mono`, 1dp `AppColors.hairline` underline) and one `Dismissible` row per beer (`formatTime` in `AppText.mono`, glyph in `AppText.body` amber, `direction: DismissDirection.endToStart`, red-tinted background).
6. Empty state when `repo.beers.isEmpty`: centred `NO BEERS YET` in `AppText.label`.

Deleting shows a `SnackBar` with an `UNDO` action calling `repo.restore(beer)`.

- [ ] **Step 1: Write the failing widget tests**

`test/ui/timeline_screen_test.dart`:

```dart
import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late BeerRepository repo;
  late SettingsStore settings;
  final now = DateTime(2026, 9, 20, 21, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    dir = Directory.systemTemp.createTempSync('beerui');
    repo = BeerRepository(
      log: BeerLogFile(File('${dir.path}/beer_log.ndjson')),
      widget: const NoopWidgetBridge(),
      clock: () => now,
    );
    settings = SettingsStore();
    await settings.load();
    await repo.load();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BeerRepository>.value(value: repo),
            ChangeNotifierProvider<SettingsStore>.value(value: settings),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: TimelineScreen(now: now),
          ),
        ),
      );

  testWidgets('empty log shows the empty state and no day headers',
      (tester) async {
    await pump(tester);
    expect(find.text('NO BEERS YET'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('tapping the 1/3 button logs exactly one beer', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('log-third')));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
    expect(repo.beers.single.ml, 333);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('tapping the 1/2 button logs a 500ml beer', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('log-half')));
    await tester.pumpAndSettle();
    expect(repo.beers.single.ml, 500);
  });

  testWidgets('groups entries under day headers, newest day first',
      (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 19, 20));
    await pump(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    final today = tester.getTopLeft(find.text('TODAY')).dy;
    final yesterday = tester.getTopLeft(find.text('YESTERDAY')).dy;
    expect(today, lessThan(yesterday));
  });

  testWidgets('shows today count and litres in the hero block',
      (tester) async {
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
    await pump(tester);
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('1.0 L'), findsWidgets);
  });

  testWidgets('goal bar reflects the weekly goal and hides when zero',
      (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    expect(find.text('1 / 14'), findsOneWidget);

    await settings.setWeeklyGoal(0);
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK'), findsNothing);
  });

  testWidgets('swiping an entry deletes it and offers undo', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    await tester.drag(find.text('18:00'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(repo.beers, isEmpty);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
  });

  testWidgets('entry rows show local time and size glyph', (tester) async {
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 9, 5));
    await pump(tester);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('½'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/ui/timeline_screen_test.dart`
Expected: FAIL - `timeline_screen.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/format.dart`**

```dart
import 'package:intl/intl.dart';

import '../stats/buckets.dart';

String formatLiters(double liters) => '${liters.toStringAsFixed(1)} L';

String formatTime(DateTime t) => DateFormat('HH:mm').format(t);

String formatDayLabel(DateTime day, DateTime now) {
  final today = dayKey(now);
  final target = dayKey(day);
  if (target == today) return 'TODAY';
  if (target == addDays(today, -1)) return 'YESTERDAY';
  return DateFormat('EEE d MMM').format(target).toUpperCase();
}
```

- [ ] **Step 4: Implement the three leaf widgets**

`lib/ui/widgets/log_buttons.dart` - a `Row` of two `Expanded` `_LogButton`s
with keys `Key('log-third')` and `Key('log-half')`, built from
`BeerSize.values`. Each is an `InkWell` inside a `Container` styled per the
layout contract, calling `onLog(size)`.

`lib/ui/widgets/goal_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

class GoalBar extends StatelessWidget {
  const GoalBar({required this.count, required this.goal, super.key});

  final int count;
  final int goal;

  @override
  Widget build(BuildContext context) {
    if (goal <= 0) return const SizedBox.shrink();
    final fraction = (count / goal).clamp(0.0, 1.0);
    final over = count > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('THIS WEEK', style: AppText.label),
            Text('$count / $goal', style: AppText.mono),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: AppColors.amberDim,
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              widthFactor: fraction,
              child: Container(
                color: over ? AppColors.over : AppColors.amber,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

`lib/ui/widgets/day_section.dart` - a `Column` with the header row and a
`Dismissible` per beer, keyed `ValueKey(beer.id)`.

- [ ] **Step 5: Implement `lib/ui/timeline_screen.dart`**

`TimelineScreen({DateTime? now, super.key})` - `now ?? DateTime.now()` so the
tests can pin the clock. It watches `BeerRepository` and `SettingsStore`,
builds `BeerStats.from(...)`, groups with `groupByDay`, sorts the day keys
descending, and lays out the six blocks from the layout contract inside a
`CustomScrollView` with `SliverPadding` of `AppSpace.md`.

Delete handler:

```dart
Future<void> _delete(BuildContext context, BeerRepository repo, Beer beer) async {
  final messenger = ScaffoldMessenger.of(context);
  await repo.remove(beer.id);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceAlt,
        content: const Text('Beer removed', style: AppText.body),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.amber,
          onPressed: () => repo.restore(beer),
        ),
      ),
    );
}
```

- [ ] **Step 6: Implement `lib/ui/app_shell.dart` and `lib/main.dart`**

`AppShell` holds the `NavigationBar` (`AppColors.surface`, amber indicator)
and a `WidgetsBindingObserver` that calls `context.read<BeerRepository>().load()`
on `AppLifecycleState.resumed` - this is what picks up widget-logged beers.

`lib/main.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/beer_log_file.dart';
import 'data/beer_repository.dart';
import 'data/settings_store.dart';
import 'data/widget_bridge.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must resolve to the same directory Kotlin sees as context.filesDir.
  final dir = await getApplicationSupportDirectory();
  final log = BeerLogFile(File(p.join(dir.path, 'beer_log.ndjson')));

  final repo = BeerRepository(
    log: log,
    widget: Platform.isAndroid
        ? const HomeWidgetBridge()
        : const NoopWidgetBridge(),
  );
  final settings = SettingsStore();

  await Future.wait([repo.load(), settings.load()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BeerRepository>.value(value: repo),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ],
      child: MaterialApp(
        title: 'Beer Count',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    ),
  );
}
```

- [ ] **Step 7: Run tests**

Run: `flutter test && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 8: Commit**

```
git add lib/main.dart lib/ui test/ui
git commit -m "feat: add app shell and timeline screen"
```

---

## Task 9: Statistics screen

**Files:**
- Create: `lib/ui/stats_screen.dart`, `lib/ui/widgets/stat_tile.dart`, `lib/ui/widgets/bar_chart.dart`, `lib/ui/widgets/heatmap.dart`, `lib/ui/widgets/section_card.dart`
- Test: `test/ui/stats_screen_test.dart`

**Interfaces:**
- Consumes: `BeerStats`, `DayCount`, theme tokens, `formatLiters`.
- Produces:
  - `class SectionCard extends StatelessWidget` - `SectionCard({required String title, required Widget child})`; `AppColors.surface`, 16dp radius, 16dp padding, title in `AppText.label`.
  - `class StatTile extends StatelessWidget` - `StatTile({required String label, required String value, String? sub})`.
  - `class BarChart extends StatelessWidget` - `BarChart({required List<double> values, required List<String> labels, int? highlightIndex, double height = 96})`; bars are `AppColors.amberDim`, the highlighted bar `AppColors.amber`, all-zero input renders flat 2dp stubs rather than dividing by zero.
  - `class Heatmap extends StatelessWidget` - `Heatmap({required List<DayCount> days})`; 53 columns x 7 rows, 10dp cells, 2dp gaps, horizontally scrollable, reversed so the newest week is on the right; intensity buckets `0 -> AppColors.surfaceAlt`, `1 -> amberDim`, `2 -> amber@0.45`, `3 -> amber@0.7`, `>=4 -> amber`.
  - `class StatsScreen extends StatelessWidget` - `StatsScreen({DateTime? now, super.key})`.

**Card order** (spec section 5): Headline (today / this week / all time) -> Rhythm
(daily avg 30d, weekly avg 12w, this week vs last week, weekday bars, hour bars
with peak-hour headline, last-30-days bars) -> Records & streaks (current dry,
longest dry, current drinking, biggest day, weeks under goal) -> Mix (stacked
1/3 vs 1/2 bar with percentages) -> Year heatmap.

Empty log renders every card with zeroes and the heatmap all-cold - no
crashes, no `NaN`, no "no data" special case except the year card, which shows
the heatmap regardless.

- [ ] **Step 1: Write the failing widget tests**

`test/ui/stats_screen_test.dart`:

```dart
import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/stats_screen.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/ui/widgets/bar_chart.dart';
import 'package:beer_count/ui/widgets/heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late BeerRepository repo;
  late SettingsStore settings;
  final now = DateTime(2026, 9, 20, 21, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    dir = Directory.systemTemp.createTempSync('beerstats');
    repo = BeerRepository(
      log: BeerLogFile(File('${dir.path}/beer_log.ndjson')),
      widget: const NoopWidgetBridge(),
      clock: () => now,
    );
    settings = SettingsStore();
    await settings.load();
    await repo.load();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: StatsScreen(now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every section with an empty log', (tester) async {
    await pump(tester);
    for (final title in const [
      'TODAY',
      'THIS WEEK',
      'ALL TIME',
      'RHYTHM',
      'STREAKS',
      'MIX',
      'YEAR',
    ]) {
      expect(find.text(title), findsWidgets, reason: 'missing $title');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows totals for a populated log', (tester) async {
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 20));
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 14, 20));
    await pump(tester);
    expect(find.textContaining('1.3 L'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('renders the year heatmap with 371 cells', (tester) async {
    await pump(tester);
    final heatmap = tester.widget<Heatmap>(find.byType(Heatmap));
    expect(heatmap.days, hasLength(371));
  });

  testWidgets('renders weekday, hour and 30-day charts', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    final charts = tester.widgetList<BarChart>(find.byType(BarChart)).toList();
    expect(charts.length, greaterThanOrEqualTo(3));
    expect(charts.any((c) => c.values.length == 7), isTrue);
    expect(charts.any((c) => c.values.length == 24), isTrue);
    expect(charts.any((c) => c.values.length == 30), isTrue);
  });

  testWidgets('bar chart survives all-zero input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: BarChart(
            values: List<double>.filled(7, 0),
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the peak hour when there is data', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 21));
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 19, 21));
    await pump(tester);
    expect(find.textContaining('21:00'), findsWidgets);
  });

  testWidgets('shows the size mix percentages', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await repo.addAt(ml: 500, at: DateTime(2026, 9, 20, 19));
    await pump(tester);
    expect(find.textContaining('50%'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/ui/stats_screen_test.dart`
Expected: FAIL - `stats_screen.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/widgets/bar_chart.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme.dart';

class BarChart extends StatelessWidget {
  const BarChart({
    required this.values,
    required this.labels,
    this.highlightIndex,
    this.height = 96,
    super.key,
  }) : assert(values.length == labels.length, 'one label per bar');

  final List<double> values;
  final List<String> labels;
  final int? highlightIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomCenter,
                        // 2dp stub keeps an empty chart readable and keeps
                        // us out of a divide-by-zero.
                        heightFactor: max == 0
                            ? 0.02
                            : (values[i] / max).clamp(0.02, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i == highlightIndex
                                ? AppColors.amber
                                : AppColors.amberDim,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      labels[i],
                      style: AppText.label.copyWith(fontSize: 9, letterSpacing: 0),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `lib/ui/widgets/heatmap.dart`**

A `SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true)`
wrapping a `Row` of 53 `Column`s of 7 cells, each cell a 10x10
`DecoratedBox` with 2dp radius and the colour from the intensity buckets
above. `days` is consumed in the order `BeerStats.yearGrid` produces it, so
column `c` row `r` is `days[c * 7 + r]`.

- [ ] **Step 5: Implement `lib/ui/widgets/section_card.dart` and `stat_tile.dart`**

`SectionCard` is a `Container` with `AppColors.surface`, `BorderRadius.circular(16)`,
`EdgeInsets.all(AppSpace.md)`, and a `Column` of the title plus the child.
`StatTile` is a `Column` of `label` (`AppText.label`), `value`
(`AppText.title`) and an optional `sub` (`AppText.mono`).

- [ ] **Step 6: Implement `lib/ui/stats_screen.dart`**

Watches both providers, builds `BeerStats.from(...)`, and returns a
`ListView` of `SectionCard`s in the card order above, separated by
`AppSpace.md`. Weekday labels are `['M','T','W','T','F','S','S']` rotated so
index 0 matches `settings.weekStartWeekday`; hour labels are `''` except at
0, 6, 12, 18 where they are `'00'`, `'06'`, `'12'`, `'18'`; 30-day labels are
`''` except every 7th bar. Percentages are computed as
`(thirdCount / totalCount * 100).round()` guarded by `totalCount > 0`.

- [ ] **Step 7: Run tests**

Run: `flutter test && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 8: Commit**

```
git add lib/ui test/ui
git commit -m "feat: add statistics screen with hand-built charts"
```

---

## Task 10: Settings screen

**Files:**
- Create: `lib/ui/settings_screen.dart`
- Test: `test/ui/settings_screen_test.dart`

**Interfaces:**
- Consumes: `SettingsStore`, `BeerRepository`, `beersToCsv`, `beersToJson`, `share_plus`.
- Produces: `class SettingsScreen extends StatelessWidget`.

**Contract:**
- `WEEKLY GOAL` - a `Slider` from 0 to 42 in steps of 1, value read from
  `settings.weeklyGoal`, live label `<n> beers` or `off` at 0.
- `WEEK STARTS ON` - a two-option `SegmentedButton<int>` for
  `DateTime.sunday` / `DateTime.monday`.
- `EXPORT` - two rows, `Export CSV` and `Export JSON`, each writing to a temp
  file and handing it to `SharePlus.instance.share(ShareParams(files: [...]))`.
  If the running `share_plus` version exposes the older `Share.shareXFiles`
  API instead, use that - check the installed package's API before writing
  this and match it.
- `DATA` - `<n> entries`, plus `<n> unreadable lines skipped` only when
  `repo.skippedLines > 0`.
- `ERASE ALL DATA` - `AppColors.over` text, opens an `AlertDialog` requiring
  an explicit `ERASE` tap before calling `repo.eraseAll()`.
- `ABOUT` - app name, version string `1.0.0`, and the line
  `Local only. Nothing leaves your phone.`

- [ ] **Step 1: Write the failing tests**

`test/ui/settings_screen_test.dart`:

```dart
import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/settings_screen.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late BeerRepository repo;
  late SettingsStore settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    dir = Directory.systemTemp.createTempSync('beersettings');
    repo = BeerRepository(
      log: BeerLogFile(File('${dir.path}/beer_log.ndjson')),
      widget: const NoopWidgetBridge(),
      clock: () => DateTime(2026, 9, 20, 21),
    );
    settings = SettingsStore();
    await settings.load();
    await repo.load();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ],
        child: MaterialApp(theme: buildTheme(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current goal and week start', (tester) async {
    await pump(tester);
    expect(find.text('14 beers'), findsOneWidget);
    expect(find.text('WEEK STARTS ON'), findsOneWidget);
  });

  testWidgets('a zero goal reads as off', (tester) async {
    await settings.setWeeklyGoal(0);
    await pump(tester);
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('switching the week start persists it', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    expect(settings.weekStartWeekday, DateTime.monday);
  });

  testWidgets('shows the entry count', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    expect(find.textContaining('1 entr'), findsOneWidget);
  });

  testWidgets('erase requires confirmation', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);

    await tester.tap(find.text('ERASE ALL DATA'));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1), reason: 'not erased before confirming');

    await tester.tap(find.text('ERASE'));
    await tester.pumpAndSettle();
    expect(repo.beers, isEmpty);
  });

  testWidgets('cancelling the erase dialog keeps the data', (tester) async {
    await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
    await pump(tester);
    await tester.tap(find.text('ERASE ALL DATA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(repo.beers, hasLength(1));
  });

  testWidgets('skipped lines are surfaced only when present', (tester) async {
    await pump(tester);
    expect(find.textContaining('skipped'), findsNothing);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/ui/settings_screen_test.dart`
Expected: FAIL - `settings_screen.dart` does not exist.

- [ ] **Step 3: Check the installed `share_plus` API before writing the export rows**

```bash
grep -rn "class SharePlus\|Future<ShareResult> share\|shareXFiles" \
  "$HOME/.pub-cache/hosted/pub.dev/share_plus-"*/lib/share_plus.dart | head
```

Use whichever of `SharePlus.instance.share(ShareParams(files: ...))` or
`Share.shareXFiles([...])` that output shows. Do not guess.

- [ ] **Step 4: Implement `lib/ui/settings_screen.dart`**

Follow the contract above. The erase dialog:

```dart
Future<void> _confirmErase(BuildContext context, BeerRepository repo) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Erase everything?', style: AppText.body),
      content: const Text(
        'This deletes every logged beer. It cannot be undone.',
        style: AppText.mono,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL', style: AppText.label),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'ERASE',
            style: AppText.label.copyWith(color: AppColors.over),
          ),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await repo.eraseAll();
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 6: Commit**

```
git add lib/ui/settings_screen.dart test/ui/settings_screen_test.dart
git commit -m "feat: add settings screen with export and erase"
```

---

## Task 11: Native Android home-screen widget

**Files:**
- Create: `android/app/src/main/kotlin/com/shakedash/beercount/BeerLog.kt`
- Create: `android/app/src/main/kotlin/com/shakedash/beercount/BeerWidgetProvider.kt`
- Create: `android/app/src/main/res/layout/beer_widget.xml`
- Create: `android/app/src/main/res/xml/beer_widget_info.xml`
- Create: `android/app/src/main/res/drawable/widget_bg.xml`, `widget_pill.xml`
- Create: `android/app/src/main/res/values/beer_dimens.xml`, `values-v31/beer_dimens.xml`, `values/beer_strings.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: the NDJSON file contract and the `HomeWidgetPreferences` key contract from Global Constraints.
- Produces: an `AppWidgetProvider` named `BeerWidgetProvider`, matching `kAndroidWidgetName` in `lib/data/widget_bridge.dart`.

**Deviation from the spec, applied here:** `minSdk` becomes **26**, not 23.
That lets the launcher icon be an adaptive vector with no PNG fallback, so the
repo carries no binary image assets at all. Android 8.0 is from 2017; nothing
is lost. Update the spec's section 11 line to match.

There are no unit tests for this task - the sandbox has no emulator. The gate
is that `flutter build apk --release` compiles it and that the device check in
Task 12 passes.

- [ ] **Step 1: Set `minSdk` and confirm the package path**

In `android/app/build.gradle.kts` set `minSdk = 26`, `targetSdk = 36`,
`compileSdk = 36`, and `applicationId = "com.shakedash.beercount"`. Confirm
`MainActivity.kt` lives at
`android/app/src/main/kotlin/com/shakedash/beercount/MainActivity.kt`; if
`flutter create` put it elsewhere, move it and fix its `package` line.

- [ ] **Step 2: Write `BeerLog.kt`**

```kotlin
package com.shakedash.beercount

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.random.Random

/**
 * The Kotlin half of the shared beer log. Mirrors lib/data/beer_log_file.dart
 * and lib/data/widget_bridge.dart. Keep the two in step: same file name, same
 * record shape, same preference keys, every preference value a String.
 */
object BeerLog {
    private const val FILE_NAME = "beer_log.ndjson"
    private const val PREFS = "HomeWidgetPreferences"
    private const val KEY_DAY = "today_key"
    private const val KEY_COUNT = "today_count"
    private const val KEY_ML = "today_ml"

    data class Summary(val dayKey: String, val count: Int, val ml: Int)

    private val lock = Any()

    fun todayKey(now: Long = System.currentTimeMillis()): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))

    /** Reads the cached counter, resetting it when the day has rolled over. */
    fun summary(context: Context): Summary = synchronized(lock) {
        val today = todayKey()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (readString(prefs, KEY_DAY) != today) {
            return Summary(today, 0, 0)
        }
        Summary(
            today,
            readString(prefs, KEY_COUNT)?.toIntOrNull() ?: 0,
            readString(prefs, KEY_ML)?.toIntOrNull() ?: 0,
        )
    }

    /** Appends one record and bumps the cached counter. Never parses the log. */
    fun append(context: Context, ml: Int): Summary = synchronized(lock) {
        val now = System.currentTimeMillis()
        val id = now.toString() + "-" +
            String.format(Locale.US, "%04x", Random.nextInt(0x10000))
        val line = JSONObject()
            .put("id", id)
            .put("ml", ml)
            .put("at", now)
            .toString()

        val file = File(context.filesDir, FILE_NAME)
        val prefix = if (needsLeadingNewline(file)) "\n" else ""
        file.appendText(prefix + line + "\n")

        val current = summary(context)
        val next = Summary(current.dayKey, current.count + 1, current.ml + ml)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_DAY, next.dayKey)
            .putString(KEY_COUNT, next.count.toString())
            .putString(KEY_ML, next.ml.toString())
            .apply()
        next
    }

    /**
     * home_widget has historically stored ints as ints. Reading such a key as
     * a String throws, so fall back instead of crashing the widget.
     */
    private fun readString(
        prefs: android.content.SharedPreferences,
        key: String,
    ): String? = try {
        prefs.getString(key, null)
    } catch (e: ClassCastException) {
        null
    }

    /** Guards against a torn final line fusing with the next record. */
    private fun needsLeadingNewline(file: File): Boolean {
        if (!file.exists() || file.length() == 0L) return false
        return RandomAccessFile(file, "r").use {
            it.seek(file.length() - 1)
            it.read() != '\n'.code
        }
    }
}
```

- [ ] **Step 3: Write `BeerWidgetProvider.kt`**

```kotlin
package com.shakedash.beercount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale

class BeerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val summary = BeerLog.summary(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, summary))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_LOG) return
        val ml = intent.getIntExtra(EXTRA_ML, 0)
        if (ml <= 0) return
        // A throwing receiver shows the user a system "not responding"
        // dialog. Logging a beer must never do that.
        val summary = try {
            BeerLog.append(context, ml)
        } catch (t: Throwable) {
            try {
                BeerLog.summary(context)
            } catch (t2: Throwable) {
                return
            }
        }
        renderAll(context, summary)
    }

    companion object {
        const val ACTION_LOG = "com.shakedash.beercount.LOG"
        const val EXTRA_ML = "ml"

        fun renderAll(context: Context, summary: BeerLog.Summary) {
            AppWidgetManager.getInstance(context).updateAppWidget(
                ComponentName(context, BeerWidgetProvider::class.java),
                buildViews(context, summary),
            )
        }

        private fun buildViews(
            context: Context,
            summary: BeerLog.Summary,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.beer_widget)
            views.setTextViewText(R.id.beer_count, summary.count.toString())
            views.setTextViewText(
                R.id.beer_sub,
                String.format(Locale.US, "today · %.1f L", summary.ml / 1000.0),
            )
            views.setOnClickPendingIntent(R.id.beer_open, openApp(context))
            views.setOnClickPendingIntent(R.id.beer_third, log(context, 333, 11))
            views.setOnClickPendingIntent(R.id.beer_half, log(context, 500, 12))
            return views
        }

        private fun log(context: Context, ml: Int, requestCode: Int): PendingIntent {
            val intent = Intent(context, BeerWidgetProvider::class.java)
                .setAction(ACTION_LOG)
                .putExtra(EXTRA_ML, ml)
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            return PendingIntent.getActivity(
                context,
                10,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
```

- [ ] **Step 4: Write the widget resources**

`res/values/beer_dimens.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <dimen name="widget_radius">16dp</dimen>
    <dimen name="widget_pill_radius">12dp</dimen>
</resources>
```

`res/values-v31/beer_dimens.xml` - on Android 12+ match the launcher's own
corner radius so the widget sits flush:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <dimen name="widget_radius">@android:dimen/system_app_widget_background_radius</dimen>
    <dimen name="widget_pill_radius">12dp</dimen>
</resources>
```

`res/values/beer_strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="widget_description">Log a beer in one tap.</string>
    <string name="widget_third">⅓</string>
    <string name="widget_half">½</string>
</resources>
```

`res/drawable/widget_bg.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#141416" />
    <corners android:radius="@dimen/widget_radius" />
</shape>
```

`res/drawable/widget_pill.xml` - a selector so a tap shows feedback:

```xml
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:state_pressed="true">
        <shape android:shape="rectangle">
            <solid android:color="#33E8A33D" />
            <stroke android:width="1dp" android:color="#E8A33D" />
            <corners android:radius="@dimen/widget_pill_radius" />
        </shape>
    </item>
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#00000000" />
            <stroke android:width="1dp" android:color="#E8A33D" />
            <corners android:radius="@dimen/widget_pill_radius" />
        </shape>
    </item>
</selector>
```

`res/layout/beer_widget.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_bg"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:paddingStart="16dp"
    android:paddingEnd="12dp"
    android:paddingTop="10dp"
    android:paddingBottom="10dp">

    <LinearLayout
        android:id="@+id/beer_open"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical">

        <TextView
            android:id="@+id/beer_count"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:includeFontPadding="false"
            android:text="0"
            android:textColor="#F4F1EA"
            android:textSize="32sp" />

        <TextView
            android:id="@+id/beer_sub"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="2dp"
            android:includeFontPadding="false"
            android:text="today · 0.0 L"
            android:textColor="#8A8780"
            android:textSize="11sp" />
    </LinearLayout>

    <TextView
        android:id="@+id/beer_third"
        android:layout_width="56dp"
        android:layout_height="44dp"
        android:background="@drawable/widget_pill"
        android:contentDescription="@string/widget_third"
        android:gravity="center"
        android:text="@string/widget_third"
        android:textColor="#E8A33D"
        android:textSize="20sp" />

    <TextView
        android:id="@+id/beer_half"
        android:layout_width="56dp"
        android:layout_height="44dp"
        android:layout_marginStart="8dp"
        android:background="@drawable/widget_pill"
        android:contentDescription="@string/widget_half"
        android:gravity="center"
        android:text="@string/widget_half"
        android:textColor="#E8A33D"
        android:textSize="20sp" />
</LinearLayout>
```

`res/xml/beer_widget_info.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/widget_description"
    android:initialLayout="@layout/beer_widget"
    android:minHeight="40dp"
    android:minResizeHeight="40dp"
    android:minResizeWidth="180dp"
    android:minWidth="250dp"
    android:previewLayout="@layout/beer_widget"
    android:resizeMode="horizontal|vertical"
    android:targetCellHeight="1"
    android:targetCellWidth="4"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />
```

- [ ] **Step 5: Register the receiver in `AndroidManifest.xml`**

Inside `<application>`, after the `<activity>` block. `exported` must be
`true` - the system AppWidgetHost broadcasts to it from outside the app, and a
`false` here makes the widget silently never update.

```xml
<receiver
    android:name=".BeerWidgetProvider"
    android:exported="true"
    android:label="Beer Count">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="com.shakedash.beercount.LOG" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/beer_widget_info" />
</receiver>
```

Also set `android:label="Beer Count"` on `<application>`.

- [ ] **Step 6: Compile**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. Kotlin compile errors here are the whole point of
the step - fix them before moving on. `flutter test && flutter analyze` must
still be green.

- [ ] **Step 7: Commit**

```
git add android
git commit -m "feat: add native android home-screen widget"
```

---

## Task 12: Icon, signing fallback, README, full validation

**Files:**
- Create: `android/app/src/main/res/drawable/ic_launcher_foreground.xml`
- Create: `android/app/src/main/res/values/ic_launcher_background.xml`
- Create: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Delete: `android/app/src/main/res/mipmap-hdpi/`, `-mdpi/`, `-xhdpi/`, `-xxhdpi/`, `-xxxhdpi/`
- Modify: `android/app/build.gradle.kts`, `README.md`, `docs/superpowers/specs/2026-09-20-beer-count-design.md` (minSdk line)
- Create: `LICENSE`

- [ ] **Step 1: Write the adaptive launcher icon**

`res/values/ic_launcher_background.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B0B0C</color>
</resources>
```

`res/drawable/ic_launcher_foreground.xml` - a beer glass, amber, inside the
66dp safe zone of the 108dp canvas:

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <!-- glass body -->
    <path
        android:fillColor="#00000000"
        android:strokeColor="#E8A33D"
        android:strokeWidth="4"
        android:strokeLineJoin="round"
        android:pathData="M40,32 L68,32 L64,80 L44,80 Z" />
    <!-- head of foam -->
    <path
        android:fillColor="#E8A33D"
        android:pathData="M40,32 L68,32 L66.8,46 L41.2,46 Z" />
    <!-- handle -->
    <path
        android:fillColor="#00000000"
        android:strokeColor="#E8A33D"
        android:strokeWidth="4"
        android:strokeLineJoin="round"
        android:pathData="M68,42 L76,42 L76,64 L65.2,64" />
</vector>
```

`res/mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
```

Then delete the density mipmap folders `flutter create` generated. With
`minSdk 26` nothing resolves `@mipmap/ic_launcher` outside
`mipmap-anydpi-v26`, and the repo ends up with zero binary assets.

- [ ] **Step 2: Add the optional local signing config**

At the top of `android/app/build.gradle.kts`:

```kotlin
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
```

Inside `android { }`:

```kotlin
signingConfigs {
    if (keystorePropertiesFile.exists()) {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
}

buildTypes {
    release {
        // Falls back to debug signing so a fresh clone can build a release
        // APK with no secrets present. Drop a key.properties in android/ to
        // sign it properly.
        signingConfig = if (keystorePropertiesFile.exists()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
```

- [ ] **Step 3: Confirm nothing secret is tracked**

```bash
git check-ignore -v android/key.properties
git ls-files | grep -Ei 'key\.properties|\.jks$|\.keystore$' || echo "clean"
```
Expected: the first prints a `.gitignore` match, the second prints `clean`.

- [ ] **Step 4: Write `README.md`**

Cover: what it is, a screenshot-free feature list, the data model and where
the log lives on device, how to build (`flutter build apk --release`), how to
install (`adb install -r`), how to add the widget, how to make a real
keystore, how to export data, and the licence. Keep it short.

- [ ] **Step 5: Add an MIT `LICENSE`**

Copyright line: `Copyright (c) 2026 Shkedo`.

- [ ] **Step 6: Full validation sweep**

```bash
flutter analyze
flutter test
flutter build apk --release
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

Expected: `No issues found!`, every test passing with the count printed, a
successful release build, and an APK on disk. Record the real numbers - do not
claim success without this output.

- [ ] **Step 7: Verify the APK actually contains the widget**

```bash
"$ANDROID_HOME/build-tools/36.0.0/aapt2" dump xmltree \
  --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk \
  | grep -A3 -i receiver
```
Expected: the `BeerWidgetProvider` receiver with its `APPWIDGET_UPDATE` and
`com.shakedash.beercount.LOG` actions.

- [ ] **Step 8: Commit and push the branch**

```
git add -A
git commit -m "feat: add launcher icon, signing fallback and docs"
git push -u origin HEAD
```

---

## Self-review notes

- Spec section 3.3 (widget counter) is covered by Tasks 7 and 11; section 5
  (statistics) by Tasks 4, 5 and 9; section 6.2 (widget visuals) by Task 11;
  section 7 (settings) by Tasks 6 and 10; section 9 (error handling) by the
  tolerance tests in Tasks 2, 3 and 7 plus the receiver `try/catch` in Task 11;
  section 11 (build and signing) by Task 12.
- The one deliberate deviation from the spec is `minSdk 26` instead of 23,
  recorded in Task 11 and applied to the spec in Task 12.
- Names used across tasks and checked for consistency: `BeerLogFile.readAll`,
  `BeerLogFile.append`, `BeerLogFile.rewrite`, `BeerLogFile.clear`,
  `BeerRepository.add/addAt/remove/restore/eraseAll/load`,
  `WidgetBridge.push`, `summarizeToday`, `formatDayKey`, `BeerStats.from`,
  `dayKey`, `addDays`, `daysBetween`, `weekStartOf`, `dayCountsBetween`,
  `computeStreaks`, `kAndroidWidgetName` == the Kotlin class
  `BeerWidgetProvider`.
