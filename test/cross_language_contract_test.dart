import 'dart:io';

import 'package:beer_count/data/widget_bridge.dart';
import 'package:beer_count/models/beer.dart';
import 'package:beer_count/models/beer_size.dart';
import 'package:flutter_test/flutter_test.dart';

/// The NDJSON record shape and the SharedPreferences keys are a contract
/// between `lib/data/` and `android/.../BeerLog.kt`. Nothing at runtime
/// enforces it: a rename on one side just silently stops the widget from
/// agreeing with the app. These tests read the Kotlin source and check.
void main() {
  final kotlinDir = Directory(
    'android/app/src/main/kotlin/com/shakedash/beercount',
  );
  late String beerLog;
  late String provider;

  setUpAll(() {
    beerLog = File('${kotlinDir.path}/BeerLog.kt').readAsStringSync();
    provider =
        File('${kotlinDir.path}/BeerWidgetProvider.kt').readAsStringSync();
  });

  test('kotlin sources are where we think they are', () {
    expect(kotlinDir.existsSync(), isTrue, reason: kotlinDir.path);
  });

  test('both sides use the same log file name', () {
    expect(beerLog, contains('"beer_log.ndjson"'));
  });

  test('both sides use the same preference file and keys', () {
    expect(beerLog, contains('"HomeWidgetPreferences"'));
    expect(beerLog, contains('"$kPrefTodayKey"'));
    expect(beerLog, contains('"$kPrefTodayCount"'));
    expect(beerLog, contains('"$kPrefTodayMl"'));
  });

  test('kotlin stores every preference value as a String', () {
    expect(beerLog, contains('putString(KEY_DAY'));
    expect(beerLog, contains('putString(KEY_COUNT'));
    expect(beerLog, contains('putString(KEY_ML'));
    expect(
      beerLog,
      isNot(contains('putInt(')),
      reason: 'ints would not survive the round trip through home_widget',
    );
  });

  test('kotlin writes the same three record keys as Dart', () {
    final dartKeys = Beer(id: 'x', ml: 333, at: DateTime(2026)).toJsonMap().keys;
    expect(dartKeys, containsAll(<String>['id', 'ml', 'at']));
    for (final key in dartKeys) {
      expect(
        beerLog,
        contains('.put("$key"'),
        reason: 'Kotlin never writes "$key"',
      );
    }
  });

  test('kotlin uses the same day-key format as Dart', () {
    expect(beerLog, contains('"yyyy-MM-dd"'));
    expect(formatDayKey(DateTime(2026, 9, 7)), '2026-09-07');
  });

  test('the widget provider class name matches kAndroidWidgetName', () {
    expect(provider, contains('class $kAndroidWidgetName'));
    expect(
      File('${kotlinDir.path}/$kAndroidWidgetName.kt').existsSync(),
      isTrue,
    );
  });

  test('the widget logs exactly the two sizes the app knows', () {
    expect(provider, contains('ML_THIRD = ${BeerSize.third.ml}'));
    expect(provider, contains('ML_HALF = ${BeerSize.half.ml}'));
  });

  test('the manifest registers the receiver with both actions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:name=".$kAndroidWidgetName"'));
    expect(manifest, contains('android:exported="true"'));
    expect(
      manifest,
      contains('android.appwidget.action.APPWIDGET_UPDATE'),
    );
    expect(manifest, contains('com.shakedash.beercount.LOG'));
    expect(manifest, contains('@xml/beer_widget_info'));
  });

  test('the receiver never lets an exception escape', () {
    expect(provider, contains('catch (t: Throwable)'));
  });
}
