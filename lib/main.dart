import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/beer_log_file.dart';
import 'data/beer_repository.dart';
import 'data/settings_store.dart';
import 'data/widget_bridge.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Must resolve to the same directory Kotlin sees as `context.filesDir`,
  // because the home-screen widget appends to the very same file.
  final dir = await getApplicationSupportDirectory();
  final log = BeerLogFile(File(p.join(dir.path, 'beer_log.ndjson')));

  final repo = BeerRepository(
    log: log,
    widget:
        Platform.isAndroid ? const HomeWidgetBridge() : const NoopWidgetBridge(),
  );
  final settings = SettingsStore();

  await settings.load();
  await repo.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BeerRepository>.value(value: repo),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ],
      child: MaterialApp(
        title: 'Beer Count',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    ),
  );
}
