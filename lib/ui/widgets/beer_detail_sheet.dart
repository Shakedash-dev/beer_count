import 'package:flutter/material.dart';

import '../../models/beer.dart';
import '../format.dart';
import '../theme.dart';

/// Tapping a waypoint opens this. Its only job is to let a mis-tap be undone,
/// so DELETE is the one action and it is the only red thing on screen.
class BeerDetailSheet extends StatelessWidget {
  const BeerDetailSheet({required this.beer, super.key});

  final Beer beer;

  static Future<bool> show(BuildContext context, Beer beer) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BeerDetailSheet(beer: beer),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber.withValues(alpha: 0.16),
                      border: Border.all(color: AppColors.amber, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      beer.size?.glyph ?? '?',
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${beer.ml} ml',
                          style: AppText.title.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          '${formatTime(beer.at)}  ·  '
                          '${formatDate(beer.at)}',
                          style: AppText.mono,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              const Divider(),
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'DELETE THIS BEER',
                  style: AppText.label.copyWith(color: AppColors.over),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                ),
                child: const Text('KEEP IT', style: AppText.label),
              ),
            ],
          ),
        ),
      );
}
