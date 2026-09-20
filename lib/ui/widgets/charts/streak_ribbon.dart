import 'package:flutter/material.dart';

import '../../../stats/buckets.dart';
import '../../theme.dart';

/// The last stretch of days as a ribbon: one bar per day, amber if a beer was
/// logged, dark if it was dry. Streaks become visible as runs rather than as
/// a number you have to trust.
class StreakRibbon extends StatelessWidget {
  const StreakRibbon({required this.days, this.height = 46, super.key});

  /// Oldest first.
  final List<DayCount> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 320 + i * 6),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: days[i].count == 0
                        ? 0.22
                        : (0.42 + 0.58 * (max == 0 ? 0 : days[i].count / max)) *
                            t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: days[i].count == 0
                            ? AppColors.surfaceAlt
                            : AppColors.amber.withValues(
                                alpha: 0.45 +
                                    0.55 *
                                        (max == 0 ? 0 : days[i].count / max),
                              ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
