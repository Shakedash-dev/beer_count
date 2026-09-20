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
