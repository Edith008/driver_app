class AppConfig {
  const AppConfig._();

  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL',
          defaultValue: 'https://8e88a067696a.ngrok-free.app');

  static const Duration driverPollingInterval = Duration(seconds: 10);
}
