import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'database/isar_service.dart';
import 'providers/cycle_provider.dart';
import 'providers/log_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await IsarService.init();
  await NotificationService.instance.init();

  final settings = SettingsProvider(db);
  final cycle = CycleProvider(db);
  final logs = LogProvider(db);
  await Future.wait([settings.load(), cycle.load(), logs.load()]);
  cycle.updateDefaults(settings.cycleLength, settings.periodLength);
  NotificationService.instance.bind(settings, cycle);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProxyProvider<SettingsProvider, CycleProvider>(
          create: (_) => cycle,
          update: (_, s, c) => c!..updateDefaults(s.cycleLength, s.periodLength),
        ),
        ChangeNotifierProvider.value(value: logs),
      ],
      child: const LunaApp(),
    ),
  );
}
