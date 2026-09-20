import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weekly goal and week start. Nothing else is configurable, by design.
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
