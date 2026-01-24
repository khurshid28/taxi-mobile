import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:dio/dio.dart';

/// Mapbox Directions API - 100,000 bepul so'rov/oy
/// https://docs.mapbox.com/api/navigation/directions/
class MapboxRouteService {
  static const String ACCESS_TOKEN =
      'pk.eyJ1Ijoia2h1cnNoaWRpMjgyNyIsImEiOiJjbWtzNzlldnExOWQ1M2NzYW16ZWtqaXgwIn0.7y5qAy-6st2yZdnIbmpVog';
  static const String BASE_URL = 'https://api.mapbox.com/directions/v5/mapbox';

  /// Yo'l so'rash va taxminiy vaqt olish
  /// [start] - Boshlang'ich nuqta
  /// [end] - Tugash nuqta
  /// [mode] - driving, walking, cycling
  /// Returns: {points, duration, distance}
  static Future<Map<String, dynamic>> getRoute(
    Point start,
    Point end, {
    String mode = 'driving',
  }) async {
    print('🌐 Mapbox Directions API so\'rov...');

    try {
      final dio = Dio();

      // Mapbox uses lon,lat format
      final url =
          '$BASE_URL/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}';

      print('🔗 URL: ${url.substring(0, 100)}...');

      final response = await dio.get(
        url,
        queryParameters: {
          'geometries': 'geojson',
          'access_token': ACCESS_TOKEN,
          'overview': 'full',
        },
      );

      print('📡 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          // Parse geometry
          final points = _parseGeometry(route['geometry']);

          // Duration in seconds
          final durationSeconds = (route['duration'] as num).toDouble();
          final durationMinutes = (durationSeconds / 60).round();

          // Distance in meters
          final distanceMeters = (route['distance'] as num).toDouble();
          final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);

          print('✅ Mapbox yo\'l olindi:');
          print('   📍 Nuqtalar: ${points.length}');
          print('   ⏱️ Vaqt: $durationMinutes daqiqa');
          print('   📏 Masofa: $distanceKm km');

          return {
            'points': points,
            'duration': durationSeconds,
            'durationMinutes': durationMinutes,
            'distance': distanceMeters,
            'distanceKm': distanceKm,
          };
        } else {
          throw Exception('Mapbox: Yo\'l topilmadi - ${data['code']}');
        }
      } else {
        throw Exception('Mapbox HTTP xatosi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Mapbox Dio xatosi: ${e.type} - ${e.message}');
      if (e.response != null) {
        print('Status: ${e.response?.statusCode}');
        print('Data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Mapbox xatosi: $e');
      rethrow;
    }
  }

  /// GeoJSON geometry dan Point list olish
  static List<Point> _parseGeometry(Map<String, dynamic> geometry) {
    List<Point> points = [];

    try {
      if (geometry['type'] == 'LineString' && geometry['coordinates'] is List) {
        final coordinates = geometry['coordinates'] as List;

        for (var coord in coordinates) {
          if (coord is List && coord.length >= 2) {
            // Mapbox returns [longitude, latitude]
            points.add(
              Point(
                latitude: (coord[1] as num).toDouble(),
                longitude: (coord[0] as num).toDouble(),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Geometry parse xatosi: $e');
    }

    return points;
  }
}
