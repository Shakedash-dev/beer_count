import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// A 270-degree gauge for the weekly goal. Sweeps in on build so the week
/// reads as something in progress rather than a printed number.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    required this.value,
    required this.max,
    required this.label,
    required this.caption,
    this.over = false,
    this.diameter = 168,
    super.key,
  });

  final double value;
  final double max;

  /// Drawn large in the middle of the arc.
  final String label;

  /// Drawn small underneath it.
  final String caption;
  final bool over;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _ArcGaugePainter(fraction: t, over: over),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.hero.copyWith(
                    fontSize: 44,
                    color: over ? AppColors.over : AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(caption, style: AppText.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({required this.fraction, required this.over});

  final double fraction;
  final bool over;

  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2 + 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.amberDim;
    canvas.drawArc(inset, _start, _sweep, false, track);

    if (fraction <= 0) return;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: over
            ? const [AppColors.amber, AppColors.over]
            : [AppColors.amber.withValues(alpha: 0.55), AppColors.amber],
      ).createShader(inset);
    canvas.drawArc(inset, _start, _sweep * fraction, false, progress);

    // A cap dot at the head of the sweep so the eye finds "where am I".
    final angle = _start + _sweep * fraction;
    final centre = inset.center;
    final radius = inset.width / 2;
    canvas.drawCircle(
      Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle),
      ),
      stroke / 2 + 2,
      Paint()..color = over ? AppColors.over : AppColors.amber,
    );
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.fraction != fraction || old.over != over;
}
