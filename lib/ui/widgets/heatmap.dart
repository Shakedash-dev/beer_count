import 'package:flutter/material.dart';

import '../../stats/buckets.dart';
import '../theme.dart';

/// 53 weeks by 7 days. [days] arrives oldest first and week-aligned, so
/// column `c`, row `r` is `days[c * 7 + r]`.
class Heatmap extends StatelessWidget {
  const Heatmap({required this.days, super.key});

  static const double cell = 10;
  static const double gap = 2;

  final List<DayCount> days;

  Color _colorFor(int count) => switch (count) {
        0 => AppColors.surfaceAlt,
        1 => AppColors.amberDim,
        2 => AppColors.amber.withValues(alpha: 0.45),
        3 => AppColors.amber.withValues(alpha: 0.7),
        _ => AppColors.amber,
      };

  @override
  Widget build(BuildContext context) {
    final columns = days.length ~/ 7;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++)
            Padding(
              padding: const EdgeInsets.only(right: gap),
              child: Column(
                children: [
                  for (var r = 0; r < 7; r++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: SizedBox(
                        width: cell,
                        height: cell,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _colorFor(days[c * 7 + r].count),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
