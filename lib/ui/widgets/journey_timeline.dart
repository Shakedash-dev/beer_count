import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/beer.dart';
import '../../models/beer_size.dart';
import '../../stats/buckets.dart';
import '../format.dart';
import '../theme.dart';

/// Horizontal space each beer occupies on the path.
const double _nodeGap = 64;

/// Extra breathing room inserted at every day boundary.
const double _dayGap = 52;

const double _leadIn = 34;
const double _tailOut = 84;

const double timelineHeight = 216;

/// The journey is laid out eagerly inside one Stack, so it shows a recent
/// window rather than every beer ever logged. Older history lives in the
/// stats heatmap and the export.
const int maxWaypoints = 150;

/// The path is a gentle sine so the walk reads as a journey rather than a
/// ruler. Keep the amplitude small: this is a timeline, not a rollercoaster.
const double _amplitude = 15;
const double _wavelength = 196;

double _pathY(double x, double centerY) =>
    centerY + _amplitude * math.sin(2 * math.pi * x / _wavelength);

class _Node {
  const _Node({required this.beer, required this.x, required this.y});

  final Beer beer;
  final double x;
  final double y;
}

class _DayMark {
  const _DayMark({
    required this.day,
    required this.x,
    required this.count,
    required this.ml,
  });

  final DateTime day;
  final double x;
  final int count;
  final int ml;
}

class _Layout {
  const _Layout({
    required this.nodes,
    required this.marks,
    required this.width,
    required this.centerY,
    required this.hidden,
  });

  final List<_Node> nodes;
  final List<_DayMark> marks;
  final double width;
  final double centerY;

  /// Beers older than the visible window.
  final int hidden;
}

_Layout _layout(List<Beer> newestFirst) {
  const centerY = timelineHeight * 0.5;
  final hidden = math.max(newestFirst.length - maxWaypoints, 0);
  final visible = hidden == 0
      ? newestFirst
      : newestFirst.sublist(0, maxWaypoints);
  final oldestFirst = visible.reversed.toList();
  final grouped = groupByDay(oldestFirst);
  final days = grouped.keys.toList()..sort();

  final nodes = <_Node>[];
  final marks = <_DayMark>[];
  var x = _leadIn;

  for (var d = 0; d < days.length; d++) {
    final day = days[d];
    final beers = grouped[day]!..sort((a, b) => a.at.compareTo(b.at));
    if (d > 0) x += _dayGap;
    marks.add(
      _DayMark(
        day: day,
        x: x - _dayGap / 2,
        count: beers.length,
        ml: beers.fold<int>(0, (sum, b) => sum + b.ml),
      ),
    );
    for (final beer in beers) {
      nodes.add(_Node(beer: beer, x: x, y: _pathY(x, centerY)));
      x += _nodeGap;
    }
  }

  return _Layout(
    nodes: nodes,
    marks: marks,
    width: x + _tailOut,
    centerY: centerY,
    hidden: hidden,
  );
}

/// The timeline as a walk: a dotted path running left to right through time,
/// with every beer a waypoint on it. Tap a waypoint to inspect or remove it.
class JourneyTimeline extends StatefulWidget {
  const JourneyTimeline({
    required this.beers,
    required this.now,
    required this.onTapBeer,
    super.key,
  });

  /// Newest first, as [BeerRepository] exposes them.
  final List<Beer> beers;
  final DateTime now;
  final ValueChanged<Beer> onTapBeer;

  @override
  State<JourneyTimeline> createState() => _JourneyTimelineState();
}

class _JourneyTimelineState extends State<JourneyTimeline> {
  final _controller = ScrollController();
  String? _newestId;

  @override
  void initState() {
    super.initState();
    _newestId = widget.beers.isEmpty ? null : widget.beers.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _snapToNow(false));
  }

  @override
  void didUpdateWidget(JourneyTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newest = widget.beers.isEmpty ? null : widget.beers.first.id;
    if (newest != _newestId) {
      _newestId = newest;
      WidgetsBinding.instance.addPostFrameCallback((_) => _snapToNow(true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Now" is the right-hand end of the path, so that is where the view opens
  /// and where it returns to after a beer is logged.
  void _snapToNow(bool animated) {
    if (!_controller.hasClients) return;
    final end = _controller.position.maxScrollExtent;
    if (animated) {
      _controller.animateTo(
        end,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beers.isEmpty) return const _EmptyJourney();

    final layout = _layout(widget.beers);
    final viewport = MediaQuery.sizeOf(context).width;
    final width = math.max(layout.width, viewport);

    return SizedBox(
      height: timelineHeight,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: width,
          height: timelineHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    marks: layout.marks,
                    centerY: layout.centerY,
                    endX: layout.width - _tailOut + 26,
                  ),
                ),
              ),
              for (final mark in layout.marks)
                _DayLabel(mark: mark, now: widget.now, centerY: layout.centerY),
              for (final node in layout.nodes)
                _Waypoint(
                  node: node,
                  isNewest: node.beer.id == _newestId,
                  onTap: () => widget.onTapBeer(node.beer),
                ),
              _NowCap(
                x: layout.width - _tailOut + 26,
                centerY: layout.centerY,
              ),
              if (layout.hidden > 0)
                _EarlierCap(hidden: layout.hidden, centerY: layout.centerY),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  const _PathPainter({
    required this.marks,
    required this.centerY,
    required this.endX,
  });

  final List<_DayMark> marks;
  final double centerY;
  final double endX;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.hairline;
    // Dots rather than a stroked dashed path: a sampled sine reads cleanly and
    // avoids PathMetric work on every frame.
    for (var x = 8.0; x <= endX; x += 9) {
      final t = (x / endX).clamp(0.0, 1.0);
      dot.color = Color.lerp(AppColors.hairline, AppColors.amberDim, t)!;
      canvas.drawCircle(Offset(x, _pathY(x, centerY)), 1.6, dot);
    }

    final tick = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (final mark in marks) {
      final y = _pathY(mark.x, centerY);
      for (var dy = -46.0; dy < 46; dy += 7) {
        canvas.drawLine(
          Offset(mark.x, y + dy),
          Offset(mark.x, y + dy + 3.5),
          tick,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.endX != endX || old.centerY != centerY || old.marks != marks;
}

class _Waypoint extends StatelessWidget {
  const _Waypoint({
    required this.node,
    required this.isNewest,
    required this.onTap,
  });

  final _Node node;
  final bool isNewest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isHalf = node.beer.size == BeerSize.half;
    final diameter = isHalf ? 38.0 : 30.0;

    final dot = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amber.withValues(alpha: isHalf ? 0.2 : 0.12),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: isHalf ? 1 : 0.7),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              node.beer.size?.glyph ?? '?',
              style: TextStyle(
                fontSize: isHalf ? 17 : 14,
                height: 1,
                color: AppColors.amber,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatTime(node.beer.at),
            style: AppText.mono.copyWith(fontSize: 10),
          ),
        ],
      ),
    );

    return Positioned(
      left: node.x - 26,
      top: node.y - diameter / 2,
      width: 52,
      child: Center(
        child: isNewest
            ? TweenAnimationBuilder<double>(
                key: ValueKey(node.beer.id),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (context, t, child) =>
                    Transform.scale(scale: 0.4 + 0.6 * t, child: child),
                child: dot,
              )
            : dot,
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.mark,
    required this.now,
    required this.centerY,
  });

  final _DayMark mark;
  final DateTime now;
  final double centerY;

  @override
  Widget build(BuildContext context) => Positioned(
        left: mark.x - 60,
        top: _pathY(mark.x, centerY) - 86,
        width: 120,
        child: Column(
          children: [
            Text(
              formatDayLabel(mark.day, now),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: AppText.label.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              '${mark.count} · ${formatLiters(mark.ml / 1000)}',
              textAlign: TextAlign.center,
              style: AppText.mono.copyWith(fontSize: 10),
            ),
          ],
        ),
      );
}

class _NowCap extends StatelessWidget {
  const _NowCap({required this.x, required this.centerY});

  final double x;
  final double centerY;

  @override
  Widget build(BuildContext context) => Positioned(
        left: x - 24,
        top: _pathY(x, centerY) - 9,
        width: 48,
        child: Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.amber, width: 1.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'NOW',
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(fontSize: 9, letterSpacing: 1),
            ),
          ],
        ),
      );
}

class _EarlierCap extends StatelessWidget {
  const _EarlierCap({required this.hidden, required this.centerY});

  final int hidden;
  final double centerY;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        top: _pathY(4, centerY) - 34,
        width: 30,
        child: Column(
          children: [
            Text(
              '\u2026',
              style: AppText.label.copyWith(fontSize: 16, letterSpacing: 0),
            ),
            const SizedBox(height: 2),
            Text(
              '$hidden',
              textAlign: TextAlign.center,
              style: AppText.mono.copyWith(fontSize: 9),
            ),
            Text(
              'more',
              textAlign: TextAlign.center,
              style: AppText.mono.copyWith(fontSize: 9),
            ),
          ],
        ),
      );
}

class _EmptyJourney extends StatelessWidget {
  const _EmptyJourney();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: timelineHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PathPainter(
                  marks: [],
                  centerY: timelineHeight * 0.5,
                  endX: 2000,
                ),
              ),
            ),
            Center(
              child: Text('THE JOURNEY STARTS HERE', style: AppText.label),
            ),
          ],
        ),
      );
}
