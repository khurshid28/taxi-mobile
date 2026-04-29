import 'package:dio/dio.dart';
import '../auth/auth_events.dart';
import '../constants/app_constants.dart';
import '../utils/storage_helper.dart';

/// Bearer token injektsiyasi va 401 da refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  final Dio _dio; // refresh uchun ishlatamiz (asosiy dio bilan bir xil)
  bool _isRefreshing = false;

  // Auth talab qilmaydigan yo'llar
  static const _publicPaths = <String>[
    'drivers/auth',
    'drivers/auth/refreshToken',
  ];

  bool _isPublic(String path) {
    return _publicPaths.any((p) => path.contains(p));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final token = await StorageHelper.getString(AppConstants.keyAccessToken);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final reqPath = err.requestOptions.path;

    if (status == 401 && !_isPublic(reqPath) && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final ok = await _refreshToken();
        if (ok) {
          // Asl so'rovni yangi token bilan qayta yuborish
          final newToken =
              await StorageHelper.getString(AppConstants.keyAccessToken);
          final req = err.requestOptions;
          req.headers['Authorization'] = 'Bearer $newToken';
          final clone = await _dio.fetch(req);
          _isRefreshing = false;
          return handler.resolve(clone);
        }
      } catch (_) {
        // refresh fail
      }
      _isRefreshing = false;
      // Refresh fail bo'ldi -> butun session'ni tozalash + login'ga yo'naltirish
      await AuthEvents.instance.notifyExpired();
    }
    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    final refresh =
        await StorageHelper.getString(AppConstants.keyRefreshToken);
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _dio.post(
        'drivers/auth/refreshToken',
        data: {'refreshToken': refresh},
      );
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final access = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (access != null && access.isNotEmpty) {
        await StorageHelper.saveString(AppConstants.keyAccessToken, access);
        if (newRefresh != null && newRefresh.isNotEmpty) {
          await StorageHelper.saveString(
              AppConstants.keyRefreshToken, newRefresh);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }
}
