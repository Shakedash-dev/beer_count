import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/beer_repository.dart';
import '../data/settings_store.dart';
import '../stats/beer_stats.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets/bar_chart.dart';
import 'widgets/heatmap.dart';
import 'widgets/section_card.dart';
import 'widgets/stat_tile.dart';

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
            SectionCard(
              title: 'TODAY',
              child: StatRow(
                tiles: [
                  StatTile(
                    label: 'BEERS',
                    value: '${stats.todayCount}',
                    emphasis: true,
                  ),
                  StatTile(
                    label: 'VOLUME',
                    value: formatLiters(stats.todayLiters),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SectionCard(
              title: 'THIS WEEK',
              child: StatRow(
                tiles: [
                  StatTile(
                    label: 'BEERS',
                    value: '${stats.weekCount}',
                    sub: stats.weeklyGoal > 0
                        ? 'goal ${stats.weeklyGoal}'
                        : 'no goal',
                    emphasis: stats.overGoal,
                  ),
                  StatTile(
                    label: 'VOLUME',
                    value: formatLiters(stats.weekLiters),
                  ),
                  StatTile(
                    label: 'VS LAST',
                    value: formatSigned(stats.weekDelta),
                    sub: 'was ${stats.lastWeekCount}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SectionCard(
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
                  Text(
                    stats.firstEntry == null
                        ? 'Nothing logged yet.'
                        : 'Since ${formatDate(stats.firstEntry!)}',
                    style: AppText.mono.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SectionCard(
              title: 'RHYTHM',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        label: 'PEAK HOUR',
                        value: stats.peakHour == null
                            ? '-'
                            : formatHour(stats.peakHour!),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const Text('BY WEEKDAY', style: AppText.label),
                  const SizedBox(height: AppSpace.sm),
                  BarChart(
                    values: weekdayValues,
                    labels: weekdayLabels,
                    highlightIndex: weekdayValues[busiest] > 0 ? busiest : null,
                    height: 80,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const Text('BY HOUR', style: AppText.label),
                  const SizedBox(height: AppSpace.sm),
                  BarChart(
                    values: [
                      for (final c in stats.countByHour) c.toDouble(),
                    ],
                    labels: [
                      for (var h = 0; h < 24; h++)
                        h % 6 == 0 ? h.toString().padLeft(2, '0') : '',
                    ],
                    highlightIndex: stats.peakHour,
                    height: 72,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const Text('LAST 30 DAYS', style: AppText.label),
                  const SizedBox(height: AppSpace.sm),
                  BarChart(
                    values: [
                      for (final d in stats.last30Days) d.count.toDouble(),
                    ],
                    labels: [
                      for (var i = 0; i < stats.last30Days.length; i++)
                        (stats.last30Days.length - 1 - i) % 7 == 0
                            ? '${stats.last30Days[i].day.day}'
                            : '',
                    ],
                    height: 80,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SectionCard(
              title: 'STREAKS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: AppSpace.lg),
                  StatRow(
                    tiles: [
                      StatTile(
                        label: 'BIGGEST DAY',
                        value: '${stats.biggestDay?.count ?? 0}',
                        sub: stats.biggestDay == null
                            ? '-'
                            : formatDate(stats.biggestDay!.day),
                      ),
                      StatTile(
                        label: 'WEEKS UNDER GOAL',
                        value: stats.weeksConsidered == 0
                            ? '-'
                            : '${stats.weeksUnderGoal}/${stats.weeksConsidered}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SectionCard(
              title: 'MIX',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MixBar(stats: stats),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '⅓  ${stats.thirdPercent}%  ·  '
                        '${stats.thirdCount}',
                        style: AppText.mono.copyWith(color: AppColors.amber),
                      ),
                      Text(
                        '${stats.halfCount}  ·  '
                        '${stats.halfPercent}%  ½',
                        style: AppText.mono,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SectionCard(
              title: 'YEAR',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heatmap(days: stats.yearGrid),
                  const SizedBox(height: AppSpace.sm),
                  const Text(
                    'one square per day, 53 weeks',
                    style: AppText.mono,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixBar extends StatelessWidget {
  const _MixBar({required this.stats});

  final BeerStats stats;

  @override
  Widget build(BuildContext context) {
    final known = stats.thirdCount + stats.halfCount;
    if (known == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: const SizedBox(
          height: 10,
          child: ColoredBox(color: AppColors.surfaceAlt),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: stats.thirdCount,
              child: const ColoredBox(color: AppColors.amber),
            ),
            Expanded(
              flex: stats.halfCount,
              child: const ColoredBox(color: AppColors.amberDim),
            ),
          ],
        ),
      ),
    );
  }
}
