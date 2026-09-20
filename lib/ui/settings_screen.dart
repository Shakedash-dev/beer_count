import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/beer_repository.dart';
import '../data/exporter.dart';
import '../data/settings_store.dart';
import 'theme.dart';
import 'widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final repo = context.watch<BeerRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS', style: AppText.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          AppSpace.xl,
        ),
        children: [
          SectionCard(
            title: 'WEEKLY GOAL',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.weeklyGoal == 0 ? 'off' : '${settings.weeklyGoal} beers',
                  style: AppText.title,
                ),
                Slider(
                  value: settings.weeklyGoal.toDouble(),
                  max: 42,
                  divisions: 42,
                  activeColor: AppColors.amber,
                  inactiveColor: AppColors.amberDim,
                  onChanged: (v) => settings.setWeeklyGoal(v.round()),
                ),
                const Text(
                  'Zero turns the weekly bar off entirely.',
                  style: AppText.mono,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'WEEK STARTS ON',
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<int>(
                    value: DateTime.sunday,
                    label: Text('Sunday'),
                  ),
                  ButtonSegment<int>(
                    value: DateTime.monday,
                    label: Text('Monday'),
                  ),
                ],
                selected: {settings.weekStartWeekday},
                onSelectionChanged: (s) =>
                    settings.setWeekStartWeekday(s.first),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'EXPORT',
            child: Column(
              children: [
                _Row(
                  label: 'Export CSV',
                  onTap: () => _export(
                    repo,
                    'beer_count.csv',
                    beersToCsv(repo.beers),
                  ),
                ),
                const Divider(),
                _Row(
                  label: 'Export JSON',
                  onTap: () => _export(
                    repo,
                    'beer_count.json',
                    beersToJson(repo.beers),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SectionCard(
            title: 'DATA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${repo.beers.length} entries', style: AppText.body),
                if (repo.skippedLines > 0) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${repo.skippedLines} unreadable lines skipped',
                    style: AppText.mono.copyWith(color: AppColors.over),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                InkWell(
                  onTap: () => _confirmErase(context, repo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                    child: Text(
                      'ERASE ALL DATA',
                      style: AppText.label.copyWith(color: AppColors.over),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          const SectionCard(
            title: 'ABOUT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beer Count 1.0.0', style: AppText.body),
                SizedBox(height: AppSpace.xs),
                Text(
                  'Local only. Nothing leaves your phone.',
                  style: AppText.mono,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BeerRepository repo,
    String fileName,
    String contents,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(contents, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'Beer Count export');
  }

  Future<void> _confirmErase(BuildContext context, BeerRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Erase everything?', style: AppText.body),
        content: const Text(
          'This deletes every logged beer. It cannot be undone.',
          style: AppText.mono,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: AppText.label),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'ERASE',
              style: AppText.label.copyWith(color: AppColors.over),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await repo.eraseAll();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.body),
              const Icon(
                Icons.ios_share,
                size: 18,
                color: AppColors.textDim,
              ),
            ],
          ),
        ),
      );
}
