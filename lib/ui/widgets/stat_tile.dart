import 'package:flutter/material.dart';

import '../theme.dart';

/// Label above, big numeral below. The numeral is the hero.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.sub,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String value;
  final String? sub;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: AppSpace.sm),
          Text(
            value,
            style: AppText.title.copyWith(
              color: emphasis ? AppColors.amber : AppColors.text,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(sub!, style: AppText.mono.copyWith(fontSize: 12)),
          ],
        ],
      );
}

/// Two or three [StatTile]s sharing a row.
class StatRow extends StatelessWidget {
  const StatRow({required this.tiles, super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tile in tiles) Expanded(child: tile),
        ],
      );
}
