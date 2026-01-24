import 'dart:convert';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:dio/dio.dart';

class YandexRouteDrawer {
  // OSRM (Open Source Routing Machine) - Bepul routing API
  // https://router.project-osrm.org/
  static const String OSRM_BASE_URL =
      'https://router.project-osrm.org/route/v1';

  /// Yo'l so'rash funksiyasi
  /// [start] - Boshlang'ich nuqta
  /// [end] - Tugash nuqta
  /// [mode] - Yo'l turi: driving (mashina), walking (piyoda), cycling (velosiped)
  static Future<List<Point>> getRoute(
    Point start,
    Point end, {
    String mode = 'driving',
  }) async {
    print('🌐 OSRM Routing API so\'rov...');

    try {
      final dio = Dio();

      // OSRM uses lon,lat format (opposite of Yandex)
      final url =
          '$OSRM_BASE_URL/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}';

      final response = await dio.get(
        url,
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );

      print('📡 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        final points = _decodeOSRMRoute(data);
        print('✅ OSRM yo\'l olindi: ${points.length} nuqta');
        return points;
      } else {
        print('❌ Server xatosi: ${response.statusCode}');
        print('Response: ${response.data}');
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Dio xatosi: ${e.type} - ${e.message}');
      if (e.response != null) {
        print('Status: ${e.response?.statusCode}');
        print('Data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ HTTP xatosi: $e');
      rethrow;
    }
  }

  /// OSRM GeoJSON dan yo'l nuqtalarini olish
  static List<Point> _decodeOSRMRoute(Map<String, dynamic> data) {
    List<Point> points = [];

    try {
      if (data.containsKey('routes') &&
          data['routes'] is List &&
          (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];

        if (route.containsKey('geometry') &&
            route['geometry'] is Map &&
            route['geometry']['type'] == 'LineString') {
          final coordinates = route['geometry']['coordinates'] as List;

          // OSRM returns [longitude, latitude] format
          for (var coord in coordinates) {
            if (coord is List && coord.length >= 2) {
              points.add(
                Point(
                  latitude: (coord[1] as num).toDouble(),
                  longitude: (coord[0] as num).toDouble(),
                ),
              );
            }
          }
        }
      }

      print('📍 Decoded ${points.length} nuqta');
    } catch (e) {
      print('❌ GeoJSON decode xatosi: $e');
    }

    return points;
  }
}
