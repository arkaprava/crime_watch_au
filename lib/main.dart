import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'providers/providers.dart';
import 'screens/map_screen.dart';
import 'services/crime_local_database.dart';
import 'services/suburb_index.dart';
import 'theme/app_theme.dart';
import 'widgets/marker_icons.dart';

late final CrimeLocalDatabase crimeLocalDatabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  crimeLocalDatabase = CrimeLocalDatabase();
  await crimeLocalDatabase.init();

  await Future.wait([
    MarkerIconFactory.preload(),
    SuburbIndex.instance.load(),
  ]);

  runApp(
    ProviderScope(
      overrides: [
        crimeLocalDatabaseProvider.overrideWithValue(crimeLocalDatabase),
      ],
      child: const CrimeWatchApp(),
    ),
  );
}

class CrimeWatchApp extends StatelessWidget {
  const CrimeWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MapScreen(),
    );
  }
}
