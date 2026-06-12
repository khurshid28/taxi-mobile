class AppConstants {
  // App Info
  static const String appName = 'Taxi Mobile';
  static const String appVersion = '1.0.1';

  // API
  static const String baseUrl = 'http://89.39.95.62/api/';
  static const String mercureUrl = 'http://89.39.95.62/mercure';
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Test credentials (UI hozircha telefon+OTP kabi ko'rinadi —
  // backend esa carNumber+password talab qiladi). UI o'zgarmaguncha
  // shu test akkaunti bilan ulanamiz.
  static const String testCarNumber = '70h007xa';
  static const String testPassword = 'o535';

  // Storage Keys
  static const String keyToken = 'auth_token'; // legacy
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyDriverId = 'driver_id';
  static const String keyCompanyId = 'company_id';
  static const String keyDriverTariffs = 'driver_tariffs';
  static const String keyUserPhone = 'user_phone';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyProfileCompleted = 'profile_completed';
  static const String keyOnboardingShown = 'onboarding_shown';

  // Order States
  static const int orderWaitingTime = 8000; // 8 seconds
  static const int freeWaitSeconds = 120; // 2 daqiqa bepul kutish

  // Pricing (real safar uchun)
  static const int basePrice = 3000;
  static const int pricePerKm = 2500;
  static const int pricePerWaitingMinute = 1000;

  // Driver location push (sec)
  static const int locationPushIntervalSec = 10;

  // Yandex Map
  static const double defaultZoom = 15.0;
  static const double defaultLat = 41.2995;
  static const double defaultLon = 69.2401;
}
