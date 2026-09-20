import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../stats/buckets.dart';
import '../theme.dart';

Color heatColor(int count) => switch (count) {
      0 => AppColors.surfaceAlt,
      1 => AppColors.amberDim,
      2 => AppColors.amber.withValues(alpha: 0.45),
      3 => AppColors.amber.withValues(alpha: 0.7),
      _ => AppColors.amber,
    };

/// 53 weeks by 7 days. [days] arrives oldest first and week-aligned, so
/// column `c`, row `r` is `days[c * 7 + r]`.
class Heatmap extends StatelessWidget {
  const Heatmap({required this.days, super.key});

  static const double cell = 11;
  static const double gap = 2.5;

  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final columns = days.length ~/ 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++)
                      SizedBox(
                        width: cell + gap,
                        child: _monthLabel(c),
                      ),
                  ],
                ),
              ),
              Row(
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
                                    color: heatColor(days[c * 7 + r].count),
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Text('DRY', style: AppText.label.copyWith(fontSize: 9)),
            const SizedBox(width: AppSpace.sm),
            for (final level in const [0, 1, 2, 3, 4])
              Padding(
                padding: const EdgeInsets.only(right: gap),
                child: SizedBox(
                  width: cell,
                  height: cell,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: heatColor(level),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: AppSpace.sm),
            Text('4+', style: AppText.label.copyWith(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  /// Label a column only when its week is the first of a new month, which is
  /// how the year reads as months rather than as 53 anonymous stripes.
  Widget _monthLabel(int column) {
    final first = days[column * 7].day;
    if (column > 0) {
      final previous = days[(column - 1) * 7].day;
      if (previous.month == first.month) return const SizedBox.shrink();
    }
    return Text(
      DateFormat('MMM').format(first).toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
      style: AppText.label.copyWith(fontSize: 9, letterSpacing: 0.5),
    );
  }
}
