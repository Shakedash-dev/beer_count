import 'package:flutter/material.dart';

/// Counts from the previous value to the new one instead of snapping.
/// Small thing, but it is what makes a number feel like it happened.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    required this.value,
    required this.style,
    this.fractionDigits = 0,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 550),
    super.key,
  });

  final double value;
  final TextStyle style;
  final int fractionDigits;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          '${v.toStringAsFixed(fractionDigits)}$suffix',
          style: style,
        ),
      );
}
