import 'package:dio/dio.dart';
import '../auth/auth_events.dart';
import '../constants/app_constants.dart';
import '../utils/storage_helper.dart';

/// Bearer token injektsiyasi + 401 da bitta refresh, qolgan so'rovlarni
/// navbatga qo'yib qayta yuborish.
///
/// MUHIM (concurrency): bir vaqtda bir nechta so'rov 401 olishi mumkin
/// (masalan lokatsiya push + buyurtma tortish). Avval faqat BIRINCHISI
/// refresh qilardi, qolganlari darhol XATO bilan qaytardi (yangi token bilan
/// qayta urinmasdan). Endi refresh davom etayotganda kelgan 401'lar
/// [_pendingQueue] ga qo'yiladi va refresh tugagach hammasi yangi token bilan
/// qayta yuboriladi (yoki refresh fail bo'lsa hammasi rad etiladi).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  final Dio _dio; // refresh uchun ishlatamiz (asosiy dio bilan bir xil)

  bool _isRefreshing = false;

  /// Refresh tugashini kutayotgan so'rovlar (401 olganlar).
  final List<_PendingRequest> _pendingQueue = [];

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

    // 401 EMAS yoki public (login/refresh) so'rov bo'lsa — aralashmaymiz.
    if (status != 401 || _isPublic(reqPath)) {
      handler.next(err);
      return;
    }

    // Ushbu so'rovni allaqachon bir marta retry qilgan bo'lsak, takror urinmaymiz
    // (refresh keyin ham 401 bersa — cheksiz tsikldan saqlanish).
    if (err.requestOptions.extra['__retried__'] == true) {
      handler.next(err);
      return;
    }

    // Refresh hozir davom etayotgan bo'lsa — shu so'rovni navbatga qo'yamiz.
    if (_isRefreshing) {
      _pendingQueue.add(_PendingRequest(err.requestOptions, handler));
      return;
    }

    // Birinchi 401 — refresh boshlovchisi.
    _isRefreshing = true;
    bool ok = false;
    try {
      ok = await _refreshToken();
    } catch (_) {
      ok = false;
    }
    _isRefreshing = false;

    if (ok) {
      final newToken =
          await StorageHelper.getString(AppConstants.keyAccessToken);
      // 1) Navbatdagilarni yangi token bilan qayta yuboramiz.
      await _drainQueue(newToken);
      // 2) Joriy so'rovni ham qayta yuboramiz.
      await _retry(err.requestOptions, newToken, handler);
    } else {
      // Refresh fail — navbatdagilarni ham, joriyni ham rad etamiz.
      _rejectQueue(err);
      handler.next(err);
      // Sessiyani tozalab login'ga yo'naltiramiz (bir marta).
      await AuthEvents.instance.notifyExpired();
    }
  }

  /// Navbatdagi barcha so'rovlarni yangi token bilan qayta yuboradi.
  Future<void> _drainQueue(String? newToken) async {
    final queued = List<_PendingRequest>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final p in queued) {
      await _retry(p.options, newToken, p.handler);
    }
  }

  /// Refresh fail bo'lganda navbatdagilarni rad etadi.
  void _rejectQueue(DioException err) {
    final queued = List<_PendingRequest>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final p in queued) {
      p.handler.next(err);
    }
  }

  /// Bitta so'rovni yangi token bilan qayta yuboradi.
  Future<void> _retry(
    RequestOptions options,
    String? newToken,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      options.headers['Authorization'] = 'Bearer $newToken';
      options.extra['__retried__'] = true; // qayta urinish belgisi
      final clone = await _dio.fetch(options);
      handler.resolve(clone);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.reject(
        DioException(requestOptions: options, error: 'retry failed'),
      );
    }
  }

  /// Refresh token orqali yangi access (va kerak bo'lsa refresh) token oladi.
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
    } catch (_) {
      // refresh endpoint xatosi (401/4xx/timeout) — fail deb hisoblaymiz.
    }
    return false;
  }
}

/// 401 olib refresh tugashini kutayotgan so'rov.
class _PendingRequest {
  _PendingRequest(this.options, this.handler);

  final RequestOptions options;
  final ErrorInterceptorHandler handler;
}
