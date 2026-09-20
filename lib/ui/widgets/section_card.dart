import 'package:flutter/material.dart';

import '../theme.dart';

/// One idea per card. Separation comes from surface value, never a shadow.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.label),
            const SizedBox(height: AppSpace.md),
            child,
          ],
        ),
      );
}
