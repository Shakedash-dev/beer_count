import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/beer_repository.dart';
import 'stats_screen.dart';
import 'theme.dart';
import 'timeline_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Beers logged from the home-screen widget only reach the UI through a
    // re-read of the log file, so resume is the moment that matters.
    if (state == AppLifecycleState.resumed) {
      context.read<BeerRepository>().load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [TimelineScreen(), StatsScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.amber.withValues(alpha: 0.18),
          surfaceTintColor: Colors.transparent,
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined, size: 20),
              selectedIcon: Icon(
                Icons.list_alt,
                size: 20,
                color: AppColors.amber,
              ),
              label: 'Timeline',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined, size: 20),
              selectedIcon: Icon(
                Icons.insights,
                size: 20,
                color: AppColors.amber,
              ),
              label: 'Stats',
            ),
          ],
        ),
      );
}
