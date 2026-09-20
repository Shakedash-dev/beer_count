import 'package:flutter/material.dart';

import '../theme.dart';

/// A row of bars scaled to the largest value. Hand-built rather than pulled
/// from a chart package so it matches the palette exactly and adds no
/// dependency to the build.
class BarChart extends StatelessWidget {
  const BarChart({
    required this.values,
    required this.labels,
    this.highlightIndex,
    this.height = 96,
    super.key,
  }) : assert(values.length == labels.length, 'one label per bar');

  final List<double> values;
  final List<String> labels;
  final int? highlightIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final gap = values.length > 12 ? 0.5 : 2.0;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gap),
                child: Column(
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomCenter,
                        // The 0.02 floor keeps an empty chart readable and
                        // keeps us out of a divide-by-zero.
                        heightFactor: max == 0
                            ? 0.02
                            : (values[i] / max).clamp(0.02, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i == highlightIndex
                                ? AppColors.amber
                                : AppColors.amberDim,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    SizedBox(
                      height: 12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          style: AppText.label.copyWith(
                            fontSize: 9,
                            letterSpacing: 0,
                            color: i == highlightIndex
                                ? AppColors.amber
                                : AppColors.textDim,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
