import 'dart:io';

import 'package:beer_count/data/beer_log_file.dart';
import 'package:beer_count/data/beer_repository.dart';
import 'package:beer_count/data/beer_sound.dart';
import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/models/beer_size.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSound implements BeerSound {
  int plays = 0;

  @override
  Future<void> play() async => plays++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late BeerLogFile log;
  late FakeSound sound;
  late BeerRepository repo;
  final now = DateTime(2026, 9, 21, 21);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('beersound');
    log = BeerLogFile(File('${dir.path}/beer_log.ndjson'));
    sound = FakeSound();
    repo = BeerRepository(
      log: log,
      widget: const NoopWidgetBridge(),
      sound: sound,
      clock: () => now,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('every tap plays once', () async {
    await repo.load();
    await repo.add(BeerSize.third);
    await repo.add(BeerSize.half);
    await repo.add(BeerSize.half);
    expect(sound.plays, 3);
  });

  test('seeding with addAt and undo-restore stay silent', () async {
    await repo.load();
    final beer = await repo.addAt(ml: 500, at: now);
    await repo.remove(beer!.id);
    await repo.restore(beer);
    expect(sound.plays, 0);
  });

  test('a beer that failed to save plays nothing', () async {
    await log.append(Beer(id: 'x', ml: 333, at: now));
    final broken = BeerRepository(
      log: BeerLogFile(File('${log.file.path}/nested/beer_log.ndjson')),
      widget: const NoopWidgetBridge(),
      sound: sound,
      clock: () => now,
    );
    await broken.load();
    expect(await broken.add(BeerSize.half), isNull);
    expect(sound.plays, 0);
  });

  group('PlatformBeerSound', () {
    const channel = MethodChannel(kSoundChannel);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('calls play on the shared channel', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      await const PlatformBeerSound().play();
      expect(calls, ['play']);
    });

    test('swallows a platform failure', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      await expectLater(const PlatformBeerSound().play(), completes);
    });

    test('swallows a missing native handler', () async {
      await expectLater(const PlatformBeerSound().play(), completes);
    });
  });
}
