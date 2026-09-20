import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/beer_repository.dart';
import '../data/settings_store.dart';
import '../stats/beer_stats.dart';
import '../stats/buckets.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets/charts/arc_gauge.dart';
import 'widgets/charts/donut_chart.dart';
import 'widgets/charts/radial_hours.dart';
import 'widgets/charts/sparkline.dart';
import 'widgets/charts/streak_ribbon.dart';
import 'widgets/charts/weekday_radar.dart';
import 'widgets/heatmap.dart';
import 'widgets/section_card.dart';
import 'widgets/stat_tile.dart';

const _weekdayInitials = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

class StatsScreen extends StatelessWidget {
  const StatsScreen({this.now, super.key});

  /// Injected by tests so every window is deterministic.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final repo = context.watch<BeerRepository>();
    final settings = context.watch<SettingsStore>();
    final stats = BeerStats.from(
      repo.beers,
      now: clock,
      weekStartWeekday: settings.weekStartWeekday,
      weeklyGoal: settings.weeklyGoal,
    );

    // Rotate the weekday axis so it opens on the configured week start.
    final order = List<int>.generate(
      7,
      (i) => (settings.weekStartWeekday - 1 + i) % 7,
    );
    final weekdayValues = [for (final i in order) stats.avgByWeekday[i]];
    final weekdayLabels = [for (final i in order) _weekdayInitials[i]];
    var busiest = 0;
    for (var i = 1; i < weekdayValues.length; i++) {
      if (weekdayValues[i] > weekdayValues[busiest]) busiest = i;
    }

    final ribbon = stats.yearGrid.length >= 60
        ? stats.yearGrid.sublist(
            stats.yearGrid.length - 60 - _daysAfterToday(stats, clock),
            stats.yearGrid.length - _daysAfterToday(stats, clock),
          )
        : stats.yearGrid;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            AppSpace.xl,
          ),
          children: [
            _WeekCard(stats: stats),
            const SizedBox(height: AppSpace.md),
            _Last30Card(stats: stats),
            const SizedBox(height: AppSpace.md),
            _HourCard(stats: stats),
            const SizedBox(height: AppSpace.md),
            _WeekdayCard(
              values: weekdayValues,
              labels: weekdayLabels,
              busiest: busiest,
            ),
            const SizedBox(height: AppSpace.md),
            _StreakCard(stats: stats, ribbon: ribbon),
            const SizedBox(height: AppSpace.md),
            _MixCard(stats: stats),
            const SizedBox(height: AppSpace.md),
            _AllTimeCard(stats: stats),
            const SizedBox(height: AppSpace.md),
            SectionCard(
              title: 'YEAR',
              child: Heatmap(days: stats.yearGrid),
            ),
          ],
        ),
      ),
    );
  }

  /// The year grid runs to the end of the current week, so trim the future
  /// days off before slicing the last 60 for the ribbon.
  static int _daysAfterToday(BeerStats stats, DateTime now) {
    if (stats.yearGrid.isEmpty) return 0;
    return daysBetween(dayKey(now), stats.yearGrid.last.day).clamp(0, 6);
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats});

  final BeerStats stats;

  @override
  Widget build(BuildContext context) {
    final hasGoal = stats.weeklyGoal > 0;
    return SectionCard(
      title: 'THIS WEEK',
      child: Column(
        children: [
          Center(
            child: ArcGauge(
              value: stats.weekCount.toDouble(),
              max: hasGoal
                  ? stats.weeklyGoal.toDouble()
                  : (stats.weekCount == 0 ? 1 : stats.weekCount.toDouble()),
              label: '${stats.weekCount}',
              caption: hasGoal ? 'OF ${stats.weeklyGoal}' : 'BEERS',
              over: stats.overGoal,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          StatRow(
            tiles: [
              StatTile(
                label: 'TODAY',
                value: '${stats.todayCount}',
                sub: formatLiters(stats.todayLiters),
                emphasis: true,
              ),
              StatTile(
                label: 'VOLUME',
                value: formatLiters(stats.weekLiters),
                sub: 'this week',
              ),
              StatTile(
                label: 'VS LAST',
                value: formatSigned(stats.weekDelta),
                sub: 'was ${stats.lastWeekCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Last30Card extends StatelessWidget {
  const _Last30Card({required this.stats});

  final BeerStats stats;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'LAST 30 DAYS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Sparkline(
              values: [for (final d in stats.last30Days) d.count.toDouble()],
            ),
            const SizedBox(height: AppSpace.md),
            StatRow(
              tiles: [
                StatTile(
                  label: 'PER DAY',
                  value: stats.dailyAvg30.toStringAsFixed(1),
                  sub: 'last 30 days',
                ),
                StatTile(
                  label: 'PER WEEK',
                  value: stats.weeklyAvg12.toStringAsFixed(1),
                  sub: 'last 12 weeks',
                ),
                StatTile(
                  label: 'BIGGEST DAY',
                  value: '${stats.biggestDay?.count ?? 0}',
                  sub: stats.biggestDay == null
                      ? '-'
                      : formatDate(stats.biggestDay!.day),
                ),
              ],
            ),
          ],
        ),
      );
}

class _HourCard extends StatelessWidget {
  const _HourCard({required this.stats});

  final BeerStats stats;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'BY HOUR',
        child: Column(
          children: [
            Center(
              child: RadialHours(
                countByHour: stats.countByHour,
                peakHour: stats.peakHour,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              stats.peakHour == null
                  ? 'No beers logged yet.'
                  : 'Peak hour is ${formatHour(stats.peakHour!)}.',
              style: AppText.mono,
            ),
          ],
        ),
      );
}

class _WeekdayCard extends StatelessWidget {
  const _WeekdayCard({
    required this.values,
    required this.labels,
    required this.busiest,
  });

  final List<double> values;
  final List<String> labels;
  final int busiest;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'BY WEEKDAY',
        child: Column(
          children: [
            Center(child: WeekdayRadar(values: values, labels: labels)),
            const SizedBox(height: AppSpace.md),
            Text(
              values[busiest] == 0
                  ? 'Every day looks the same so far.'
                  : '${labels[busiest]} is your biggest day, '
                      '${values[busiest].toStringAsFixed(1)} on average.',
              textAlign: TextAlign.center,
              style: AppText.mono,
            ),
          ],
        ),
      );
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats, required this.ribbon});

  final BeerStats stats;
  final List<DayCount> ribbon;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'STREAKS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreakRibbon(days: ribbon),
            const SizedBox(height: AppSpace.xs),
            Text(
              'last ${ribbon.length} days',
              style: AppText.mono.copyWith(fontSize: 11),
            ),
            const SizedBox(height: AppSpace.lg),
            StatRow(
              tiles: [
                StatTile(
                  label: 'DRY NOW',
                  value: '${stats.currentDryStreak}',
                  sub: 'days',
                  emphasis: stats.currentDryStreak > 0,
                ),
                StatTile(
                  label: 'LONGEST DRY',
                  value: '${stats.longestDryStreak}',
                  sub: 'days',
                ),
                StatTile(
                  label: 'IN A ROW',
                  value: '${stats.currentDrinkingStreak}',
                  sub: 'days',
                ),
              ],
            ),
          ],
        ),
      );
}

class _MixCard extends StatelessWidget {
  const _MixCard({required this.stats});

  final BeerStats stats;

  @override
  Widget build(BuildContext context) {
    final dominant =
        stats.halfCount >= stats.thirdCount ? '½' : '⅓';
    final dominantPercent = stats.halfCount >= stats.thirdCount
        ? stats.halfPercent
        : stats.thirdPercent;

    return SectionCard(
      title: 'MIX',
      child: Row(
        children: [
          DonutChart(
            slices: [
              DonutSlice(
                value: stats.thirdCount,
                color: AppColors.amber.withValues(alpha: 0.45),
                label: '⅓',
              ),
              DonutSlice(
                value: stats.halfCount,
                color: AppColors.amber,
                label: '½',
              ),
              DonutSlice(
                value: stats.otherCount,
                color: AppColors.surfaceAlt,
                label: 'other',
              ),
            ],
            centerLabel: stats.isEmpty ? '-' : dominant,
            centerCaption: stats.isEmpty ? 'NO DATA' : '$dominantPercent%',
            diameter: 140,
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendRow(
                  color: AppColors.amber.withValues(alpha: 0.45),
                  glyph: '⅓',
                  count: stats.thirdCount,
                  percent: stats.thirdPercent,
                ),
                const SizedBox(height: AppSpace.sm),
                _LegendRow(
                  color: AppColors.amber,
                  glyph: '½',
                  count: stats.halfCount,
                  percent: stats.halfPercent,
                ),
                if (stats.otherCount > 0) ...[
                  const SizedBox(height: AppSpace.sm),
                  _LegendRow(
                    color: AppColors.surfaceAlt,
                    glyph: '?',
                    count: stats.otherCount,
                    percent: 100 - stats.thirdPercent - stats.halfPercent,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.glyph,
    required this.count,
    required this.percent,
  });

  final Color color;
  final String glyph;
  final int count;
  final int percent;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(glyph, style: AppText.body.copyWith(color: AppColors.amber)),
          const Spacer(),
          Text('$count', style: AppText.body),
          const SizedBox(width: AppSpace.sm),
          SizedBox(
            width: 42,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: AppText.mono,
            ),
          ),
        ],
      );
}

class _AllTimeCard extends StatelessWidget {
  const _AllTimeCard({required this.stats});

  final BeerStats stats;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'ALL TIME',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatRow(
              tiles: [
                StatTile(label: 'BEERS', value: '${stats.totalCount}'),
                StatTile(
                  label: 'VOLUME',
                  value: formatLiters(stats.totalLiters),
                ),
                StatTile(
                  label: 'DAYS',
                  value: '${stats.daysTracked}',
                  sub: '${stats.activeDays} with beer',
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stats.firstEntry == null
                      ? 'Nothing logged yet.'
                      : 'Since ${formatDate(stats.firstEntry!)}',
                  style: AppText.mono.copyWith(fontSize: 12),
                ),
                if (stats.weeksConsidered > 0)
                  Text(
                    '${stats.weeksUnderGoal}/${stats.weeksConsidered} '
                    'weeks under goal',
                    style: AppText.mono.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      );
}
