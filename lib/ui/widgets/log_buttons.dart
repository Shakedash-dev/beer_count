import 'package:flutter/material.dart';

import '../../models/beer_size.dart';
import '../theme.dart';

/// The two big tap targets. Everything about this is sized for a thumb in a
/// dark bar.
class LogButtons extends StatelessWidget {
  const LogButtons({required this.onLog, super.key});

  final ValueChanged<BeerSize> onLog;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _LogButton(
              size: BeerSize.third,
              buttonKey: const Key('log-third'),
              onLog: onLog,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: _LogButton(
              size: BeerSize.half,
              buttonKey: const Key('log-half'),
              onLog: onLog,
            ),
          ),
        ],
      );
}

class _LogButton extends StatelessWidget {
  const _LogButton({
    required this.size,
    required this.buttonKey,
    required this.onLog,
  });

  final BeerSize size;
  final Key buttonKey;
  final ValueChanged<BeerSize> onLog;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.amber.withValues(alpha: 0.12),
          highlightColor: AppColors.amber.withValues(alpha: 0.06),
          onTap: () => onLog(size),
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  size.glyph,
                  style: AppText.title.copyWith(
                    color: AppColors.amber,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text('${size.ml} ML', style: AppText.label),
              ],
            ),
          ),
        ),
      );
}
