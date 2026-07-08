import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'screens/map_screen.dart';
import 'services/suburb_index.dart';
import 'theme/app_theme.dart';
import 'widgets/marker_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    MarkerIconFactory.preload(),
    SuburbIndex.instance.load(),
  ]);
  runApp(const ProviderScope(child: CrimeWatchApp()));
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
