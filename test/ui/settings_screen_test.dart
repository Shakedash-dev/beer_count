import 'dart:convert';

import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/document_files.dart';
import 'package:beer_count/data/settings_store.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/ui/settings_screen.dart';
import 'package:beer_count/ui/theme.dart';
import 'package:beer_count/models/beer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_beer_log.dart';

class FakeFiles implements DocumentFiles {
  String? toOpen;
  final saved = <String, String>{};
  bool failOpen = false;

  @override
  Future<bool> save(String fileName, String contents) async {
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<String?> open() async {
    if (failOpen) throw PlatformException(code: 'io', message: 'boom');
    return toOpen;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryBeerLog store;
  late BeerRepository repo;
  late SettingsStore settings;
  late FakeFiles files;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = InMemoryBeerLog();
    repo = BeerRepository(
      log: store,
      widget: const NoopWidgetBridge(),
      clock: () => DateTime(2026, 9, 20, 21),
    );
    settings = SettingsStore();
    files = FakeFiles();
    await settings.load();
    await repo.load();
  });


  Future<void> pump(WidgetTester tester) async {
    // Tall viewport so the lazy ListView builds every card at once.
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BeerRepository>.value(value: repo),
          ChangeNotifierProvider<SettingsStore>.value(value: settings),
          Provider<DocumentFiles>.value(value: files),
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
    expect(find.text('1 entries'), findsOneWidget);
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

  testWidgets('skipped lines are shown when the log has damage',
      (tester) async {
    store.skippedLines = 1;
    await repo.load();
    await pump(tester);
    expect(find.text('1 unreadable lines skipped'), findsOneWidget);
  });

  group('backup', () {
    testWidgets('save writes every beer as JSON to the picked file',
        (tester) async {
      await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      await pump(tester);
      await tester.tap(find.text('Save JSON backup'));
      await tester.pumpAndSettle();

      final json = jsonDecode(files.saved.values.single) as List<Object?>;
      expect(json, hasLength(1));
      expect(files.saved.keys.single, startsWith('beer_count_'));
      expect(find.text('Saved 1 beers'), findsOneWidget);
    });

    testWidgets('import merges and reports what it skipped', (tester) async {
      final here = await repo.addAt(ml: 333, at: DateTime(2026, 9, 20, 18));
      files.toOpen = jsonEncode([
        here!.toJsonMap(),
        Beer(id: 'old', ml: 500, at: DateTime(2026, 9, 1, 20)).toJsonMap(),
        {'id': 'broken'},
      ]);
      await pump(tester);
      await tester.tap(find.text('Import JSON backup'));
      await tester.pumpAndSettle();

      expect(repo.beers.map((b) => b.id), [here.id, 'old']);
      expect(
        find.text('Imported 1 beers, 1 already here, 1 unreadable'),
        findsOneWidget,
      );
    });

    testWidgets('a non-backup file is rejected', (tester) async {
      files.toOpen = 'id,ml\n1,333';
      await pump(tester);
      await tester.tap(find.text('Import JSON backup'));
      await tester.pumpAndSettle();
      expect(repo.beers, isEmpty);
      expect(find.text('Not a Beer Count JSON backup'), findsOneWidget);
    });

    testWidgets('backing out of the picker does nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Import JSON backup'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a picker error is shown, not thrown', (tester) async {
      files.failOpen = true;
      await pump(tester);
      await tester.tap(find.text('Import JSON backup'));
      await tester.pumpAndSettle();
      expect(find.text('Import failed: boom'), findsOneWidget);
    });
  });
}
