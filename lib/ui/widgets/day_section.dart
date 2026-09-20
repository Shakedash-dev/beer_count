import 'package:flutter/material.dart';

import '../../models/beer.dart';
import '../format.dart';
import '../theme.dart';

/// One local day of the timeline: a header and its entries, newest first.
class DaySection extends StatelessWidget {
  const DaySection({
    required this.day,
    required this.beers,
    required this.now,
    required this.onDelete,
    super.key,
  });

  final DateTime day;
  final List<Beer> beers;
  final DateTime now;
  final ValueChanged<Beer> onDelete;

  @override
  Widget build(BuildContext context) {
    final ml = beers.fold<int>(0, (sum, b) => sum + b.ml);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpace.lg,
            bottom: AppSpace.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDayLabel(day, now), style: AppText.label),
              Text(
                '${beers.length} · ${formatLiters(ml / 1000)}',
                style: AppText.mono.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(),
        for (final beer in beers) _EntryRow(beer: beer, onDelete: onDelete),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.beer, required this.onDelete});

  final Beer beer;
  final ValueChanged<Beer> onDelete;

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(beer.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(beer),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpace.sm),
          color: AppColors.over.withValues(alpha: 0.18),
          child: Text(
            'DELETE',
            style: AppText.label.copyWith(color: AppColors.over),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Text(formatTime(beer.at), style: AppText.mono),
              const SizedBox(width: AppSpace.md),
              Text(
                beer.size?.glyph ?? '?',
                style: AppText.body.copyWith(
                  color: AppColors.amber,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Text(
                '${beer.ml} ml',
                style: AppText.mono.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      );
}
