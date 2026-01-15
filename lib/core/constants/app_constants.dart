class AppConstants {
  // App Info
  static const String appName = 'Taxi Mobile';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = 'https://api.example.com/';
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Storage Keys
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserPhone = 'user_phone';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyProfileCompleted = 'profile_completed';
  static const String keyOnboardingShown = 'onboarding_shown';

  // Order States
  static const int orderWaitingTime = 8000; // 8 seconds

  // Yandex Map
  static const double defaultZoom = 15.0;
  static const double defaultLat = 41.2995;
  static const double defaultLon = 69.2401;
}
