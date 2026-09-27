import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/beer_repository.dart';
import '../../data/settings_store.dart';
import '../../data/widget_bridge.dart';
import '../../stats/buckets.dart';
import '../theme.dart';

/// Watches the log and the goal, and lays [GoalFireworks] over [child] the
/// first time the week's count reaches the goal. It checks on every change,
/// not just on in-app taps, so a goal reached from the home-screen widget
/// still gets its fireworks the next time the app is opened.
class GoalCelebration extends StatefulWidget {
  const GoalCelebration({required this.child, this.clock, super.key});

  final Widget child;

  /// Injected by tests.
  final DateTime Function()? clock;

  @override
  State<GoalCelebration> createState() => _GoalCelebrationState();
}

class _GoalCelebrationState extends State<GoalCelebration> {
  late final BeerRepository _repo;
  late final SettingsStore _settings;
  (int, int)? _showing;

  @override
  void initState() {
    super.initState();
    _repo = context.read<BeerRepository>()..addListener(_check);
    _settings = context.read<SettingsStore>()..addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _repo.removeListener(_check);
    _settings.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || _showing != null) return;
    final goal = _settings.weeklyGoal;
    if (goal <= 0) return;

    final now = (widget.clock ?? DateTime.now)();
    final start = weekStartOf(now, _settings.weekStartWeekday);
    final end = addDays(start, 7);
    final count = _repo.beers.where((b) {
      final day = dayKey(b.at);
      return !day.isBefore(start) && day.isBefore(end);
    }).length;
    if (count < goal) return;

    final key = '${formatDayKey(start)}#$goal';
    if (_settings.celebratedGoal == key) return;
    setState(() => _showing = (count, goal));
    _settings.markGoalCelebrated(key);
  }

  @override
  Widget build(BuildContext context) {
    final showing = _showing;
    return Stack(
      children: [
        widget.child,
        if (showing != null)
          Positioned.fill(
            child: GoalFireworks(
              count: showing.$1,
              goal: showing.$2,
              onDone: () {
                if (mounted) setState(() => _showing = null);
              },
            ),
          ),
      ],
    );
  }
}

/// A few seconds of amber fireworks over a dimmed screen, with the week's
/// tally in the middle. Never takes a tap: the app underneath stays usable.
class GoalFireworks extends StatefulWidget {
  const GoalFireworks({
    required this.count,
    required this.goal,
    required this.onDone,
    this.seed,
    super.key,
  });

  final int count;
  final int goal;
  final VoidCallback onDone;
  final int? seed;

  static const duration = Duration(milliseconds: 3400);

  @override
  State<GoalFireworks> createState() => _GoalFireworksState();
}

class _GoalFireworksState extends State<GoalFireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Burst> _bursts;

  @override
  void initState() {
    super.initState();
    _bursts = _Burst.show(Random(widget.seed));
    _controller = AnimationController(vsync: this, duration: GoalFireworks.duration)
      ..forward().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // In over the first 8%, out over the last 15%.
          final fade = (min(t / 0.08, 1.0) * min((1 - t) / 0.15, 1.0))
              .clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.45 * fade)),
              if (!still)
                CustomPaint(
                  painter: _FireworksPainter(
                    _bursts,
                    t * GoalFireworks.duration.inMilliseconds / 1000,
                  ),
                ),
              Center(
                child: Opacity(
                  opacity: fade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WEEKLY GOAL',
                        style: AppText.label.copyWith(color: AppColors.amber),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        '${widget.count} / ${widget.goal}',
                        style: AppText.hero.copyWith(color: AppColors.amber),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle(this.angle, this.speed, this.color, this.radius);

  final double angle;

  /// Fraction of the shorter screen side travelled by the end of the burst.
  final double speed;
  final Color color;
  final double radius;
}

/// One rocket: it rises for [_rise] seconds from the bottom edge, then
/// bursts at [origin] (fractions of the screen) for [_life] seconds.
class _Burst {
  const _Burst(this.at, this.origin, this.launchX, this.particles);

  static const double _rise = 0.45;
  static const double _life = 1.5;

  /// Launch time in seconds from the start of the show.
  final double at;
  final Offset origin;
  final double launchX;
  final List<_Particle> particles;

  static final _colors = [
    AppColors.amber,
    AppColors.amber,
    Color.lerp(AppColors.amber, AppColors.text, 0.55)!,
    AppColors.text,
  ];

  static List<_Burst> show(Random random) => List.generate(6, (i) {
        final origin = Offset(
          0.18 + random.nextDouble() * 0.64,
          0.14 + random.nextDouble() * 0.36,
        );
        final count = 34 + random.nextInt(14);
        return _Burst(
          // The last one must finish inside GoalFireworks.duration.
          i * 0.28,
          origin,
          origin.dx + (random.nextDouble() - 0.5) * 0.2,
          List.generate(count, (j) {
            final angle = 2 * pi * j / count + random.nextDouble() * 0.2;
            return _Particle(
              angle,
              0.22 + random.nextDouble() * 0.18,
              _colors[random.nextInt(_colors.length)],
              1.6 + random.nextDouble() * 1.4,
            );
          }),
        );
      });
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.bursts, this.seconds);

  final List<_Burst> bursts;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final burst in bursts) {
      final local = seconds - burst.at;
      if (local < 0) continue;
      final origin =
          Offset(burst.origin.dx * size.width, burst.origin.dy * size.height);

      if (local < _Burst._rise) {
        final u = Curves.easeOutCubic.transform(local / _Burst._rise);
        final from = Offset(burst.launchX * size.width, size.height);
        final head = Offset.lerp(from, origin, u)!;
        final tail = Offset.lerp(from, origin, max(0, u - 0.12))!;
        paint
          ..color = AppColors.amber.withValues(alpha: 0.9)
          ..strokeWidth = 2;
        canvas
          ..drawLine(tail, head, paint)
          ..drawCircle(head, 2.4, paint);
        continue;
      }

      final u = (local - _Burst._rise) / _Burst._life;
      if (u >= 1) continue;

      if (u < 0.15) {
        paint.color = AppColors.amber.withValues(alpha: 0.35 * (1 - u / 0.15));
        canvas.drawCircle(origin, unit * 0.09 * (0.5 + u * 3), paint);
      }

      Offset at(_Particle p, double v) {
        final reach = p.speed * unit * (1 - pow(1 - v, 3));
        final drop = 0.08 * unit * v * v;
        return origin +
            Offset(cos(p.angle) * reach, sin(p.angle) * reach + drop);
      }

      final alpha = pow(1 - u, 1.4).toDouble();
      for (final p in burst.particles) {
        final head = at(p, u);
        paint
          ..color = p.color.withValues(alpha: alpha * 0.55)
          ..strokeWidth = p.radius;
        canvas.drawLine(at(p, max(0, u - 0.07)), head, paint);
        paint.color = p.color.withValues(alpha: alpha);
        canvas.drawCircle(head, p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => old.seconds != seconds;
}
