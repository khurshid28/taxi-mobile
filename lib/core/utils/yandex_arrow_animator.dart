import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class YandexLikeArrowAnimator {
  final YandexMapController mapController;
  final Function(MapObject) onMarkerUpdate;
  Timer? _animationTimer;
  PlacemarkMapObject? _arrowMarker;
  List<Point> _routePoints = [];
  int _currentPointIndex = 0;
  double _currentProgress = 0.0;
  double _speed = 40.0; // km/h - Yandex navigatsiyasiga o'xshash

  // Smooth interpolation uchun
  final List<Point> _smoothPoints = [];
  static const double INTERPOLATION_DISTANCE = 25.0; // metr

  YandexLikeArrowAnimator(this.mapController, this.onMarkerUpdate);

  /// ✅ ASOSIY FUNKSIYA - Yandexga o'xshash strelka harakati
  Future<void> startYandexStyleNavigation({
    required List<Point> routePoints,
    double speedKmH = 40.0,
    bool followCamera = true,
    bool showRouteLine = true,
  }) async {
    // 1. Tozalash
    _stopAnimation();

    // 2. Sozlamalar
    _speed = speedKmH;
    _routePoints = routePoints;
    _currentPointIndex = 0;
    _currentProgress = 0.0;

    // 3. Use original route points directly (no interpolation)
    _smoothPoints.clear();
    _smoothPoints.addAll(routePoints);

    if (_smoothPoints.length < 2) {
      print('❌ Yo\'l nuqtalari yetarli emas');
      return;
    }

    // 4. Strelka yaratish
    await _createArrowMarker();

    // 5. Kamera sozlamalari
    if (followCamera) {
      await _setupInitialCamera();
    }

    // 6. Yo'l chizish (ixtiyoriy)
    if (showRouteLine) {
      _drawRouteLine();
    }

    // 7. Animatsiyani boshlash
    _startSmoothAnimation();

    print('🚀 Yandex-style navigatsiya boshlandi!');
    print('📍 Nuqtalar: ${_smoothPoints.length} ta');
    print('⚡ Tezlik: ${_speed}km/h');
  }

  /// 🔄 SILLIQ YO'L YARATISH (Yandex style interpolation)
  List<Point> _createSmoothRoute(List<Point> originalPoints) {
    if (originalPoints.length < 2) return originalPoints;

    List<Point> smoothPoints = [];

    for (int i = 0; i < originalPoints.length - 1; i++) {
      final start = originalPoints[i];
      final end = originalPoints[i + 1];

      // Segmentni hisoblash
      final distance = _calculateDistance(start, end);
      final segments = max(2, (distance / INTERPOLATION_DISTANCE).ceil());

      // Catmull-Rom interpolation (Yandex style smooth)
      for (int j = 0; j <= segments; j++) {
        final t = j / segments;

        // Cubic interpolation
        final lat = _cubicInterpolate(
          i > 0 ? originalPoints[i - 1].latitude : start.latitude,
          start.latitude,
          end.latitude,
          i < originalPoints.length - 2
              ? originalPoints[i + 2].latitude
              : end.latitude,
          t,
        );

        final lon = _cubicInterpolate(
          i > 0 ? originalPoints[i - 1].longitude : start.longitude,
          start.longitude,
          end.longitude,
          i < originalPoints.length - 2
              ? originalPoints[i + 2].longitude
              : end.longitude,
          t,
        );

        smoothPoints.add(Point(latitude: lat, longitude: lon));
      }
    }

    // Duplicate nuqtalarni olib tashlash
    return _removeDuplicates(smoothPoints);
  }

  /// 🎯 STRELKA YARATISH
  Future<void> _createArrowMarker() async {
    // Create a programmatic arrow icon
    final arrowIcon = await _createArrowIcon();

    _arrowMarker = PlacemarkMapObject(
      mapId: const MapObjectId('yandex_arrow'),
      point: _smoothPoints.first,
      opacity: 1.0,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: arrowIcon,
          scale: 1.0,
          rotationType: RotationType.rotate,
          anchor: const Offset(0.5, 0.5), // Markazda
        ),
      ),
      direction: 0,
      zIndex: 100,
      isDraggable: false,
    );

    onMarkerUpdate(_arrowMarker!);
  }

  /// 🎨 STRELKA ICON YARATISH (programmatically - red arrow)
  Future<BitmapDescriptor> _createArrowIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 120.0; // Larger than current_location (100)

    // Draw navigation arrow shape (red like current_location)
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size / 2, size * 0.15) // Top point (sharper)
      ..lineTo(size * 0.25, size * 0.85) // Bottom left (wider)
      ..lineTo(size / 2, size * 0.65) // Center bottom
      ..lineTo(size * 0.75, size * 0.85) // Bottom right (wider)
      ..close();

    canvas.drawPath(path, paint);

    // White border for better visibility
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(path, borderPaint);

    // Shadow for depth
    canvas.drawShadow(path, Colors.black, 4.0, true);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  /// 🎥 KAMERA SOZLASH (Yandex style 3D)
  Future<void> _setupInitialCamera() async {
    final firstPoint = _smoothPoints.first;
    final secondPoint = _smoothPoints.length > 1
        ? _smoothPoints[1]
        : firstPoint;

    // Yo'nalish hisoblash
    final initialBearing = _calculateBearing(
      firstPoint.latitude,
      firstPoint.longitude,
      secondPoint.latitude,
      secondPoint.longitude,
    );

    await mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: firstPoint,
          zoom: 17.5, // Yandex navigatsiya zoom'i
          tilt: 65.0, // 3D ko'rinish
          azimuth: initialBearing, // Yo'nalishga qarab
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.5,
      ),
    );
  }

  /// 🛣️ YO'L CHIZISH (Yandex style line)
  void _drawRouteLine() {
    final routeLine = PolylineMapObject(
      mapId: const MapObjectId('yandex_route_line'),
      polyline: Polyline(points: _smoothPoints),
      strokeColor: Colors.blue.withOpacity(0.7),
      strokeWidth: 6.0,
      outlineColor: Colors.white,
      outlineWidth: 2.0,
      zIndex: 50,
    );

    onMarkerUpdate(routeLine);
  }

  /// 🚀 SMOOTH ANIMATSIYA BOSHLASH
  void _startSmoothAnimation() {
    _animationTimer?.cancel();

    final startTime = DateTime.now();

    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // 60 FPS ga yaqin (16ms)
      final elapsedSeconds =
          DateTime.now().difference(startTime).inMilliseconds / 1000;

      // Progress hisoblash (tezlik asosida)
      _currentProgress =
          elapsedSeconds * (_speed / 3.6) / _calculateTotalDistance();

      if (_currentProgress >= 1.0) {
        timer.cancel();
        _onRouteCompleted();
        return;
      }

      // Joriy pozitsiya va yo'nalish
      final currentPosition = _getCurrentPosition();
      final currentBearing = _getCurrentBearing();

      // Strelkani yangilash
      _updateArrow(currentPosition, currentBearing);

      // Kamerani ergashtirish
      _followWithCamera(currentPosition, currentBearing);
    });
  }

  /// 📍 JORIY POZITSIYANI HISOBLASH
  Point _getCurrentPosition() {
    if (_smoothPoints.length < 2) return _smoothPoints.first;

    final totalPoints = _smoothPoints.length;
    final exactIndex = _currentProgress * (totalPoints - 1);

    final index = exactIndex.floor();
    final fraction = exactIndex - index;

    if (index >= totalPoints - 1) {
      return _smoothPoints.last;
    }

    // Linear interpolation
    final start = _smoothPoints[index];
    final end = _smoothPoints[index + 1];

    return Point(
      latitude: start.latitude + (end.latitude - start.latitude) * fraction,
      longitude: start.longitude + (end.longitude - start.longitude) * fraction,
    );
  }

  /// 🧭 JORIY YO'NALISHNI HISOBLASH
  double _getCurrentBearing() {
    if (_smoothPoints.length < 2) return 0;

    final totalPoints = _smoothPoints.length;
    final exactIndex = _currentProgress * (totalPoints - 1);
    final index = exactIndex.floor();

    if (index >= totalPoints - 2) {
      // Oxirgi segment
      return _calculateBearing(
        _smoothPoints[totalPoints - 2].latitude,
        _smoothPoints[totalPoints - 2].longitude,
        _smoothPoints.last.latitude,
        _smoothPoints.last.longitude,
      );
    }

    // Kelajakdagi nuqtaga qarab yo'nalish
    final lookAheadIndex = min(index + 3, totalPoints - 1);

    return _calculateBearing(
      _smoothPoints[index].latitude,
      _smoothPoints[index].longitude,
      _smoothPoints[lookAheadIndex].latitude,
      _smoothPoints[lookAheadIndex].longitude,
    );
  }

  /// 🎯 STRELKANI YANGILASH
  void _updateArrow(Point position, double bearing) {
    if (_arrowMarker == null) return;

    _arrowMarker = _arrowMarker!.copyWith(point: position, direction: bearing);

    onMarkerUpdate(_arrowMarker!);
  }

  /// 🎥 KAMERA ERGASHISH (Yandex style)
  void _followWithCamera(Point position, double bearing) {
    mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 17.5,
          tilt: 65.0,
          azimuth: bearing,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.linear,
        duration: 0.016, // 60 FPS ga mos
      ),
    );
  }

  /// ✅ YO'L YAKUNLANSA
  void _onRouteCompleted() {
    print('🏁 Yo\'l yakunlandi!');

    // Strelkani yo'nalishini to'g'rilash
    _arrowMarker = _arrowMarker!.copyWith(direction: _calculateFinalBearing());

    onMarkerUpdate(_arrowMarker!);
  }

  /// ⏹️ TO'XTATISH
  void _stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  /// ⏹️ PUBLIC STOP METHOD
  void stop() {
    _stopAnimation();
    _arrowMarker = null;
    _smoothPoints.clear();
    _routePoints.clear();
    _currentPointIndex = 0;
    _currentProgress = 0.0;
  }

  /// ⏸️ PAUSE
  void pauseAnimation() {
    _animationTimer?.cancel();
  }

  /// ▶️ DAVOM ETTIRISH
  void resumeAnimation() {
    if (_animationTimer == null && _smoothPoints.isNotEmpty) {
      _startSmoothAnimation();
    }
  }

  /// 🗑️ TOZALASH
  void dispose() {
    _stopAnimation();
    _arrowMarker = null;
  }

  /// 📏 MASOFA HISOBLASH
  double _calculateDistance(Point p1, Point p2) {
    const R = 6371000.0;
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLon = (p2.longitude - p1.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  /// 🧭 YO'NALISH HISOBLASH
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;
    final dLonRad = (lon2 - lon1) * pi / 180;

    final y = sin(dLonRad) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLonRad);

    var bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  /// 📊 UMUMIY MASOFA
  double _calculateTotalDistance() {
    double total = 0;
    for (int i = 0; i < _smoothPoints.length - 1; i++) {
      total += _calculateDistance(_smoothPoints[i], _smoothPoints[i + 1]);
    }
    return max(total, 1.0); // Division by zero oldini olish
  }

  /// 🔢 CUBIC INTERPOLATION
  double _cubicInterpolate(
    double y0,
    double y1,
    double y2,
    double y3,
    double t,
  ) {
    final a0 = y3 - y2 - y0 + y1;
    final a1 = y0 - y1 - a0;
    final a2 = y2 - y0;
    final a3 = y1;

    return a0 * t * t * t + a1 * t * t + a2 * t + a3;
  }

  /// 🧹 DUPLICATE NUQTALARNI OLIB TASHLASH
  List<Point> _removeDuplicates(List<Point> points) {
    final uniquePoints = <Point>[];
    Point? lastPoint;

    for (final point in points) {
      if (lastPoint == null || _calculateDistance(lastPoint, point) > 0.1) {
        uniquePoints.add(point);
        lastPoint = point;
      }
    }

    return uniquePoints;
  }

  /// 🏁 YAKUNIY YO'NALISH
  double _calculateFinalBearing() {
    if (_smoothPoints.length < 2) return 0;

    return _calculateBearing(
      _smoothPoints[_smoothPoints.length - 2].latitude,
      _smoothPoints[_smoothPoints.length - 2].longitude,
      _smoothPoints.last.latitude,
      _smoothPoints.last.longitude,
    );
  }

  /// 📍 JORIY POZITSIYANI OLISH (tashqi foydalanish uchun)
  Point? get currentPosition {
    if (_smoothPoints.isEmpty) return null;
    return _getCurrentPosition();
  }

  /// ⏱️ ANIMATSIYA HOLATINI TEKSHIRISH
  bool get isAnimating => _animationTimer != null && _animationTimer!.isActive;
}
