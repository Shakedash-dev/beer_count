import 'package:flutter/material.dart';

import '../theme.dart';

/// Weekly goal progress. A goal of zero means the user turned it off, and
/// the whole block disappears rather than showing an empty track.
class GoalBar extends StatelessWidget {
  const GoalBar({required this.count, required this.goal, super.key});

  final int count;
  final int goal;

  @override
  Widget build(BuildContext context) {
    if (goal <= 0) return const SizedBox.shrink();
    final fraction = (count / goal).clamp(0.0, 1.0);
    final over = count > goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('THIS WEEK', style: AppText.label),
            Text(
              '$count / $goal',
              style: AppText.mono.copyWith(
                color: over ? AppColors.over : AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: AppColors.amberDim,
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              widthFactor: fraction,
              heightFactor: 1,
              child: ColoredBox(
                color: over ? AppColors.over : AppColors.amber,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
