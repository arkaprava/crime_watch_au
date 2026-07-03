/// Application-wide configuration.
///
/// The GraphQL endpoint can be overridden at build/run time:
///   flutter run --dart-define=GRAPHQL_ENDPOINT=https://api.example.com/graphql
class AppConfig {
  AppConfig._();

  /// Placeholder value used until a real endpoint is supplied.
  static const String _placeholderEndpoint =
      'https://crimewatch-au.example.com/graphql';

  static const String graphqlEndpoint = String.fromEnvironment(
    'GRAPHQL_ENDPOINT',
    defaultValue: _placeholderEndpoint,
  );

  /// Optional bearer token for the GraphQL service.
  static const String authToken = String.fromEnvironment('GRAPHQL_AUTH_TOKEN');

  /// True once a real endpoint has been provided. While false, the app
  /// serves bundled demo incidents so the UI remains usable.
  static bool get isConfigured => graphqlEndpoint != _placeholderEndpoint;

  static const String appName = 'Crime Watch AU';

  /// Fallback map centre when the user's location is unavailable (Sydney CBD).
  static const double fallbackLatitude = -33.8688;
  static const double fallbackLongitude = 151.2093;
}
