import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/beer_repository.dart';
import '../data/settings_store.dart';
import '../models/beer.dart';
import '../stats/beer_stats.dart';
import '../stats/buckets.dart';
import 'format.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/day_section.dart';
import 'widgets/goal_bar.dart';
import 'widgets/log_buttons.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({this.now, super.key});

  /// Injected by tests so the "TODAY" grouping is deterministic.
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

    final grouped = groupByDay(repo.beers);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.sm,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('BEER COUNT', style: AppText.label),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: AppColors.textDim,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              sliver: SliverList.list(
                children: [
                  const SizedBox(height: AppSpace.lg),
                  Text('${stats.todayCount}', style: AppText.hero),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'today · ${formatLiters(stats.todayLiters)}',
                    style: AppText.mono,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  GoalBar(count: stats.weekCount, goal: stats.weeklyGoal),
                  SizedBox(height: stats.weeklyGoal > 0 ? AppSpace.xl : 0),
                  LogButtons(
                    onLog: (size) => context.read<BeerRepository>().add(size),
                  ),
                ],
              ),
            ),
            if (days.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.xl * 2),
                  child: Center(
                    child: Text('NO BEERS YET', style: AppText.label),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  0,
                  AppSpace.md,
                  AppSpace.xl,
                ),
                sliver: SliverList.builder(
                  itemCount: days.length,
                  itemBuilder: (context, i) => DaySection(
                    day: days[i],
                    beers: grouped[days[i]]!,
                    now: clock,
                    onDelete: (beer) => _delete(context, beer),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Beer beer) async {
    final repo = context.read<BeerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    await repo.remove(beer.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Beer removed', style: AppText.body),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.amber,
            onPressed: () => repo.restore(beer),
          ),
        ),
      );
  }
}
