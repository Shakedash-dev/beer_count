import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/beer_repository.dart';
import '../data/settings_store.dart';
import '../models/beer.dart';
import '../stats/beer_stats.dart';
import 'format.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/animated_number.dart';
import 'widgets/beer_detail_sheet.dart';
import 'widgets/goal_bar.dart';
import 'widgets/journey_timeline.dart';
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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xl),
          children: [
            Padding(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedNumber(
                        value: stats.todayCount.toDouble(),
                        style: AppText.hero,
                      ),
                      const SizedBox(width: AppSpace.md),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'today\n${formatLiters(stats.todayLiters)}',
                          style: AppText.mono.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  GoalBar(count: stats.weekCount, goal: stats.weeklyGoal),
                  SizedBox(height: stats.weeklyGoal > 0 ? AppSpace.xl : 0),
                  LogButtons(
                    onLog: (size) => context.read<BeerRepository>().add(size),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('THE JOURNEY', style: AppText.label),
                      Text(
                        repo.beers.isEmpty ? '' : 'tap a beer to edit it',
                        style: AppText.mono.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            JourneyTimeline(
              beers: repo.beers,
              now: clock,
              onTapBeer: (beer) => _openBeer(context, beer),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBeer(BuildContext context, Beer beer) async {
    final action = await BeerDetailSheet.show(context, beer);
    if (!context.mounted) return;
    switch (action) {
      case BeerSheetAction.delete:
        await _delete(context, beer);
      case BeerSheetAction.changeTime:
        await _changeTime(context, beer);
      case BeerSheetAction.keep:
        return;
    }
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

  /// Date first, then time, so "the one from last night" is a few taps.
  Future<void> _changeTime(BuildContext context, Beer beer) async {
    final repo = context.read<BeerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final clock = now ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: beer.at,
      firstDate: DateTime(2000),
      lastDate: clock,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(beer.at),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;

    final at =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    messenger.clearSnackBars();
    if (at.isAfter(clock)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Can't log a beer in the future", style: AppText.body),
        ),
      );
      return;
    }

    final previous = await repo.retime(beer.id, at);
    if (previous == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Moved to ${formatTime(at)} · ${formatDate(at)}',
          style: AppText.body,
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.amber,
          onPressed: () => repo.retime(beer.id, previous.at),
        ),
      ),
    );
  }
}
