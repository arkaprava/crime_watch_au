import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Application-wide configuration.
///
/// Override the GraphQL endpoint at build/run time:
///   flutter run --dart-define=GRAPHQL_ENDPOINT=http://192.168.1.10:8080/graphql
///
/// Use bundled demo data instead of the network:
///   flutter run --dart-define=GRAPHQL_USE_DEMO=true
class AppConfig {
  AppConfig._();

  static const String _endpointOverride = String.fromEnvironment(
    'GRAPHQL_ENDPOINT',
  );

  /// When true, serves bundled Sydney demo incidents (offline UI testing).
  static const bool useDemoData = bool.fromEnvironment(
    'GRAPHQL_USE_DEMO',
    defaultValue: false,
  );

  /// Crime Service API key (`X-API-Key` header). Dev profile default: `dev-read-key`.
  static const String apiKey = String.fromEnvironment(
    'GRAPHQL_API_KEY',
    defaultValue: 'dev-read-key',
  );

  /// GraphQL HTTP endpoint for the Crime Service.
  ///
  /// Defaults to localhost with platform-specific host mapping:
  /// - iOS simulator / macOS: 127.0.0.1
  /// - Android emulator: 10.0.2.2 (host loopback)
  static String get graphqlEndpoint {
    if (_endpointOverride.isNotEmpty) return _endpointOverride;
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

  /// Fallback map centre when the user's location is unavailable (Sydney CBD).
  static const double fallbackLatitude = -33.8688;
  static const double fallbackLongitude = 151.2093;
}
