import 'dart:async';

import '../constants/app_constants.dart';
import '../utils/storage_helper.dart';

/// Sessiya hodisalari uchun global broadcast.
/// AuthInterceptor 401+refresh fail bo'lganda `notifyExpired()` chaqiradi.
/// MyApp shu stream'ni tinglab `/phone` ga yo'naltiradi.
class AuthEvents {
  AuthEvents._();
  static final AuthEvents instance = AuthEvents._();

  final StreamController<void> _expiring =
      StreamController<void>.broadcast();
  final StreamController<void> _expired =
      StreamController<void>.broadcast();

  /// Token hali tozalanmagan, lekin tugayapti.
  /// Tinglovchilar bu yerda oxirgi backend chaqiruvlarini qila oladi.
  Stream<void> get onSessionExpiring => _expiring.stream;

  /// Token va session storage tozalandi - foydalanuvchini login'ga olib chiqish vaqti.
  Stream<void> get onSessionExpired => _expired.stream;

  /// AuthInterceptor refresh fail bo'lganda chaqiradi.
  /// 1) `expiring` event - tinglovchilar oxirgi chaqiruvlar qiladi (cancel va h.k.)
  /// 2) Storage tozalanadi
  /// 3) `expired` event - router login'ga ko'chiradi
  Future<void> notifyExpired() async {
    if (!_expiring.isClosed) _expiring.add(null);
    // Listenerlarning oxirgi chaqiruvlari uchun qisqa muddat
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await clearSession();
    if (!_expired.isClosed) _expired.add(null);
  }

  /// Faqat tozalash (logout tugmasi uchun ham ishlatish mumkin).
  Future<void> clearSession() async {
    // Auth tokenlar va sessiya ma'lumoti
    await StorageHelper.remove(AppConstants.keyAccessToken);
    await StorageHelper.remove(AppConstants.keyRefreshToken);
    await StorageHelper.remove(AppConstants.keyToken); // legacy
    await StorageHelper.remove(AppConstants.keyDriverId);
    await StorageHelper.remove(AppConstants.keyCompanyId);
    await StorageHelper.remove(AppConstants.keyDriverTariffs);
    await StorageHelper.remove(AppConstants.keyUserId);
    await StorageHelper.remove(AppConstants.keyUserPhone);

    // Foydalanuvchi profili
    await StorageHelper.remove(AppConstants.keyProfileCompleted);
    await StorageHelper.remove('user_name');
    await StorageHelper.remove('user_fullname');
    await StorageHelper.remove('user_email');

    // Drayver lokal ma'lumotlari (safarlar tarixi)
    await StorageHelper.remove('completed_orders');

    await StorageHelper.saveBool(AppConstants.keyIsLoggedIn, false);
  }
}
