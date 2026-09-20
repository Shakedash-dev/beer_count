import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Twenty-four spokes arranged like a clock face: midnight at the top, noon
/// at the bottom. A drinking day has an obvious shape, which a bar chart of
/// the same numbers hides.
class RadialHours extends StatelessWidget {
  const RadialHours({
    required this.countByHour,
    this.peakHour,
    this.diameter = 200,
    super.key,
  });

  /// Length 24, indexed by local hour.
  final List<int> countByHour;
  final int? peakHour;
  final double diameter;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: diameter,
        height: diameter,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _RadialHoursPainter(
              counts: countByHour,
              peakHour: peakHour,
              progress: t,
            ),
          ),
        ),
      );
}

class _RadialHoursPainter extends CustomPainter {
  const _RadialHoursPainter({
    required this.counts,
    required this.peakHour,
    required this.progress,
  });

  final List<int> counts;
  final int? peakHour;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.width / 2 - 14;
    final inner = outer * 0.34;
    final max = counts.fold<int>(0, (m, c) => c > m ? c : m);

    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.hairline;
    canvas.drawCircle(centre, inner, guide);
    canvas.drawCircle(centre, outer, guide);

    for (var hour = 0; hour < 24; hour++) {
      // Midnight at the top, clockwise.
      final angle = -math.pi / 2 + hour * (2 * math.pi / 24);
      final value = max == 0 ? 0.0 : counts[hour] / max;
      final length = inner + (outer - inner) * value * progress;
      final isPeak = hour == peakHour && counts[hour] > 0;

      final paint = Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = counts[hour] == 0
            ? AppColors.surfaceAlt
            : isPeak
                ? AppColors.amber
                : AppColors.amber.withValues(alpha: 0.3 + 0.4 * value);

      canvas.drawLine(
        Offset(
          centre.dx + inner * math.cos(angle),
          centre.dy + inner * math.sin(angle),
        ),
        Offset(
          centre.dx + math.max(length, inner + 2) * math.cos(angle),
          centre.dy + math.max(length, inner + 2) * math.sin(angle),
        ),
        paint,
      );
    }

    for (final hour in const [0, 6, 12, 18]) {
      final angle = -math.pi / 2 + hour * (2 * math.pi / 24);
      final painter = TextPainter(
        text: TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: AppText.label.copyWith(fontSize: 9, letterSpacing: 0.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          centre.dx + (outer + 8) * math.cos(angle) - painter.width / 2,
          centre.dy + (outer + 8) * math.sin(angle) - painter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RadialHoursPainter old) =>
      old.progress != progress ||
      old.peakHour != peakHour ||
      old.counts != counts;
}
