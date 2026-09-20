import 'package:flutter/material.dart';

import '../../theme.dart';

/// A smoothed area curve. Used for the last 30 days, where the shape of the
/// month matters more than any individual bar.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    this.height = 110,
    this.markMax = true,
    super.key,
  });

  final List<double> values;
  final double height;
  final bool markMax;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _SparklinePainter(
              values: values,
              progress: t,
              markMax: markMax,
            ),
          ),
        ),
      );
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.progress,
    required this.markMax,
  });

  final List<double> values;
  final double progress;
  final bool markMax;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final baseline = size.height - 14;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..strokeWidth = 1
        ..color = AppColors.hairline,
    );

    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final step = size.width / (values.length - 1);

    Offset at(int i) => Offset(
          i * step,
          baseline - (max == 0 ? 0 : values[i] / max) * (baseline - 8) * progress,
        );

    // Cubic midpoint smoothing: cheap, always passes near the samples, and
    // never overshoots below the baseline the way Catmull-Rom can.
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final p = at(i);
      final q = at(i + 1);
      final mid = Offset((p.dx + q.dx) / 2, (p.dy + q.dy) / 2);
      line.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    final last = at(values.length - 1);
    line.lineTo(last.dx, last.dy);

    final area = Path.from(line)
      ..lineTo(size.width, baseline)
      ..lineTo(0, baseline)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59E8A33D), Color(0x00E8A33D)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.amber,
    );

    if (markMax && max > 0) {
      final peak = values.indexOf(max);
      final p = at(peak);
      canvas
        ..drawCircle(p, 5, Paint()..color = AppColors.bg)
        ..drawCircle(p, 3.5, Paint()..color = AppColors.amber);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values;
}
