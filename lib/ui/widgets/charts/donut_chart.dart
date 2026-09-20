import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

class DonutSlice {
  const DonutSlice({
    required this.value,
    required this.color,
    required this.label,
  });

  final int value;
  final Color color;
  final String label;
}

/// Two-slice donut for the size mix, with the dominant share in the hole.
class DonutChart extends StatelessWidget {
  const DonutChart({
    required this.slices,
    required this.centerLabel,
    required this.centerCaption,
    this.diameter = 150,
    super.key,
  });

  final List<DonutSlice> slices;
  final String centerLabel;
  final String centerCaption;
  final double diameter;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: diameter,
        height: diameter,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _DonutPainter(slices: slices, progress: t),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerLabel, style: AppText.title.copyWith(fontSize: 26)),
                  const SizedBox(height: 2),
                  Text(centerCaption, style: AppText.label),
                ],
              ),
            ),
          ),
        ),
      );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.progress});

  final List<DonutSlice> slices;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 2);
    final total = slices.fold<int>(0, (sum, s) => sum + s.value);

    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = AppColors.surfaceAlt,
      );
      return;
    }

    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value == 0) continue;
      final sweep = 2 * math.pi * (slice.value / total) * progress;
      canvas.drawArc(
        rect,
        start,
        // Leave a hairline gap so the two shares stay visually distinct.
        math.max(sweep - 0.03, 0.001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.slices != slices;
}
