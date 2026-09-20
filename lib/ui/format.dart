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

String formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

String formatDate(DateTime day) => DateFormat('d MMM yyyy').format(day);

String formatSigned(int value) => value > 0 ? '+$value' : '$value';
