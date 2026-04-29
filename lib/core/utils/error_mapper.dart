import 'package:dio/dio.dart';

/// Maps backend / network errors into clean, user-friendly Uzbek messages.
class ErrorMapper {
  static String map(Object error) {
    if (error is DioException) {
      // Network-level
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Server javob bermayapti. Qayta urinib ko\'ring.';
        case DioExceptionType.connectionError:
          return 'Internet aloqasi yo\'q.';
        case DioExceptionType.cancel:
          return 'So\'rov bekor qilindi.';
        case DioExceptionType.badCertificate:
          return 'Xavfsizlik sertifikati noto\'g\'ri.';
        case DioExceptionType.badResponse:
          return _fromResponse(error);
        case DioExceptionType.unknown:
          return 'Noma\'lum xatolik. Qayta urinib ko\'ring.';
      }
    }
    final s = error.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  static String _fromResponse(DioException e) {
    final code = e.response?.statusCode ?? 0;
    final data = e.response?.data;

    // Try to extract a server-provided message first.
    String? serverMsg;
    if (data is Map) {
      for (final key in const ['message', 'error', 'detail', 'msg']) {
        final v = data[key];
        if (v is String && v.trim().isNotEmpty) {
          serverMsg = v.trim();
          break;
        }
      }
    } else if (data is String && data.trim().isNotEmpty && data.length < 160) {
      serverMsg = data.trim();
    }

    switch (code) {
      case 400:
        return serverMsg ?? 'So\'rov noto\'g\'ri.';
      case 401:
        return 'Login yoki parol noto\'g\'ri.';
      case 403:
        return 'Ruxsat yo\'q.';
      case 404:
        return 'Topilmadi.';
      case 408:
        return 'Vaqt tugadi. Qayta urining.';
      case 409:
        return serverMsg ?? 'Konflikt yuz berdi.';
      case 422:
        return serverMsg ?? 'Kiritilgan ma\'lumot noto\'g\'ri.';
      case 429:
        return 'Juda ko\'p urinish. Birozdan keyin urining.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Serverda xatolik. Birozdan keyin urinib ko\'ring.';
      default:
        return serverMsg ?? 'Xatolik yuz berdi (${code == 0 ? '—' : code}).';
    }
  }
}
