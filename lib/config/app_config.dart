import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Application-wide configuration.
///
/// Override the GraphQL endpoint at build/run time:
///   flutter run --dart-define=GRAPHQL_ENDPOINT=http://192.168.1.10:8080/graphql
///
/// Or point at the deployed production service (Oracle Cloud) without
/// retyping the URL — the API key is never committed, so pass your own:
///   flutter run --dart-define=GRAPHQL_ENV=production --dart-define=GRAPHQL_API_KEY=`prod read key`
///
/// Use bundled demo data instead of the network:
///   flutter run --dart-define=GRAPHQL_USE_DEMO=true
class AppConfig {
  AppConfig._();

  static const String _endpointOverride = String.fromEnvironment(
    'GRAPHQL_ENDPOINT',
  );

  /// Set via --dart-define=GRAPHQL_ENV=production to use [_productionGraphqlEndpoint]
  /// instead of the localhost default. Anything other than 'production' (including
  /// unset) leaves the existing dev/emulator behavior unchanged.
  static const String _env = String.fromEnvironment('GRAPHQL_ENV');

  static const String _productionGraphqlEndpoint =
      'https://152-67-98-125.sslip.io/graphql';

  /// When true, serves bundled Sydney demo incidents (offline UI testing).
  static const bool useDemoData = bool.fromEnvironment(
    'GRAPHQL_USE_DEMO',
    defaultValue: false,
  );

  /// Crime Service API key (`X-API-Key` header). Dev profile default: `dev-read-key`.
  /// Always pass the real key via --dart-define=GRAPHQL_API_KEY=... when using
  /// GRAPHQL_ENV=production — the default only works against a local dev server.
  static const String apiKey = String.fromEnvironment(
    'GRAPHQL_API_KEY',
    defaultValue: 'dev-read-key',
  );

  /// GraphQL HTTP endpoint for the Crime Service.
  ///
  /// Resolution order: explicit GRAPHQL_ENDPOINT override, then
  /// GRAPHQL_ENV=production, then the localhost default with
  /// platform-specific host mapping:
  /// - iOS simulator / macOS: 127.0.0.1
  /// - Android emulator: 10.0.2.2 (host loopback)
  static String get graphqlEndpoint {
    if (_endpointOverride.isNotEmpty) return _endpointOverride;
    if (_env == 'production') return _productionGraphqlEndpoint;
    return _defaultGraphqlEndpoint();
  }

  static String _defaultGraphqlEndpoint() {
    const port = 8080;
    const path = '/graphql';
    if (kIsWeb) return 'http://127.0.0.1:$port$path';
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$port$path';
    }
    return 'http://127.0.0.1:$port$path';
  }

  static const String appName = 'Crime Watch AU';

  /// Continental Australia view shown when the map first loads.
  static const double australiaCenterLatitude = -25.2744;
  static const double australiaCenterLongitude = 133.7751;
  static const double australiaStartupZoom = 4.2;

  /// How long parsed GraphQL crime results stay in the in-app cache.
  static const Duration graphqlCacheTtl = Duration(minutes: 10);

  /// Fallback map centre when the user's location is unavailable (Sydney CBD).
  static const double fallbackLatitude = -33.8688;
  static const double fallbackLongitude = 151.2093;
}
