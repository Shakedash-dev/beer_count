import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Seven axes, one polygon. The shape of a week is the point: a Thursday
/// spike looks like a spike, not like a taller bar among six others.
class WeekdayRadar extends StatelessWidget {
  const WeekdayRadar({
    required this.values,
    required this.labels,
    this.diameter = 200,
    super.key,
  }) : assert(values.length == 7 && labels.length == 7, 'seven weekdays');

  final List<double> values;
  final List<String> labels;
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
            painter: _RadarPainter(
              values: values,
              labels: labels,
              progress: t,
            ),
          ),
        ),
      );
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.labels,
    required this.progress,
  });

  final List<double> values;
  final List<String> labels;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 20;
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);

    Offset point(int i, double r) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 7);
      return Offset(
        centre.dx + r * math.cos(angle),
        centre.dy + r * math.sin(angle),
      );
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.hairline;

    for (final ring in const [0.34, 0.67, 1.0]) {
      final path = Path();
      for (var i = 0; i < 7; i++) {
        final p = point(i, radius * ring);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), grid);
    }
    for (var i = 0; i < 7; i++) {
      canvas.drawLine(centre, point(i, radius), grid);
    }

    if (max > 0) {
      final shape = Path();
      for (var i = 0; i < 7; i++) {
        // A floor of 6% keeps a zero day visible as a pinch, not a hole.
        final r = radius * (0.06 + 0.94 * (values[i] / max)) * progress;
        final p = point(i, r);
        i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
      }
      shape.close();

      canvas.drawPath(
        shape,
        Paint()..color = AppColors.amber.withValues(alpha: 0.22),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.amber,
      );

      for (var i = 0; i < 7; i++) {
        final r = radius * (0.06 + 0.94 * (values[i] / max)) * progress;
        canvas.drawCircle(
          point(i, r),
          3,
          Paint()..color = AppColors.amber,
        );
      }
    }

    for (var i = 0; i < 7; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = point(i, radius + 13);
      painter.paint(
        canvas,
        Offset(p.dx - painter.width / 2, p.dy - painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.labels != labels;
}
