import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/auth/auth_events.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_type_model.dart';
import '../../../../core/network/mapbox_route_service.dart';
import '../../../../core/network/mercure_service.dart';
import '../../../../core/network/yandex_route_drawer.dart';
import '../../../../core/utils/notification_service.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../injection_container.dart';
import '../../../orders/data/order_service.dart';
import '../../../profile/data/driver_service.dart';
import 'home_state.dart';

/// Real backend asosida ishlovchi HomeCubit. Mock/simulyatsiya yo'q.
/// - Buyurtma faqat Mercure orqali keladi.
/// - Mahalliy GPS - haqiqiy joylashuv.
/// - Masofa, narx, kelish - real GPS hisobida.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  // Streams / timers
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<MercureEvent>? _mercureSub;
  StreamSubscription<void>? _sessionSub;
  StreamSubscription<void>? _sessionExpiringSub;
  Timer? _waitingTimer;
  Timer? _locationPushTimer;
  Timer? _tripTimer;

  // Backend session
  int? _driverId;
  int? _companyId;
  List<String> _tariffs = const ['Start'];
  String? _accessToken;
  String? _mercureToken;

  // Tarif narxlari (OrderTypes). Bir marta yuklab, cache qilinadi.
  List<OrderTypeModel> _orderTypes = const [];
  // Aktiv buyurtma uchun aniqlangan tarif (narx hisobida ishlatiladi).
  OrderTypeModel? _activeTariff;

  // Aktiv safar holatini saqlash kaliti — app yopilib qayta ochilsa
  // (time, km, narx) yo'qolmasligi uchun.
  static const String _activeTripKey = 'active_trip_state';

  // ============== Init ==============

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _loadDriverSession();

      // Sessiya tugaganda hammasini to'xtatish
      _sessionSub ??= AuthEvents.instance.onSessionExpired.listen((_) {
        _onSessionExpired();
      });
      // Tugashidan oldin: token hali bor - oxirgi cancel chaqiruvi
      _sessionExpiringSub ??=
          AuthEvents.instance.onSessionExpiring.listen((_) {
        _tryCancelActiveOrder();
      });

      final position = await _getCurrentLocation();
      emit(
        state.copyWith(
          currentLocation:
              Point(latitude: position.latitude, longitude: position.longitude),
          heading: position.heading,
          status: OrderStatus.initial,
          isLoading: false,
        ),
      );

      _loadOrderTypes();
      await _restoreActiveTrip();
      _startLocationTracking();
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _loadDriverSession() async {
    _driverId = await StorageHelper.getInt(AppConstants.keyDriverId);
    _companyId = await StorageHelper.getInt(AppConstants.keyCompanyId);
    _accessToken =
        await StorageHelper.getString(AppConstants.keyAccessToken);
    _mercureToken =
        await StorageHelper.getString(AppConstants.keyMercureToken);

    // Cache'da driver/company ID yo'q bo'lsa - bir marta about_me orqali
    // olib kelamiz va cache'laymiz. Keyingi safar so'rov bermaymiz.
    if (_driverId == null || _companyId == null) {
      try {
        final profile = await sl<DriverService>().aboutMe();
        _driverId = profile.id ?? _driverId;
        _companyId = profile.companyId ?? _companyId;
        // ignore: avoid_print
        print('\ud83d\udd04 about_me orqali yuklandi: driverId=$_driverId, '
            'companyId=$_companyId');
      } catch (e) {
        // ignore: avoid_print
        print('\ud83d\udd34 about_me yuklash xato: $e');
      }
    } else {
      // ignore: avoid_print
      print('\ud83d\udcbe Cache\'dan: driverId=$_driverId, companyId=$_companyId');
    }
    final raw = await StorageHelper.getString(AppConstants.keyDriverTariffs);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List && list.isNotEmpty) {
          _tariffs = list.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
  }

  /// Tarif ro'yxatini (narx parametrlari bilan) backenddan yuklab cache qiladi.
  Future<void> _loadOrderTypes() async {
    try {
      final types = await sl<OrderService>().fetchOrderTypes();
      if (types.isNotEmpty) _orderTypes = types;
    } catch (e) {
      // ignore: avoid_print
      print('\u26a0\ufe0f order_types: $e');
    }
  }

  /// Buyurtma uchun mos tarifni aniqlaydi: avval embed narx, keyin id/nom.
  OrderTypeModel? _resolveTariff(OrderModel order) {
    if (order.orderType != null && order.orderType!.hasPricing) {
      return order.orderType;
    }
    if (order.orderTypeId != null) {
      for (final t in _orderTypes) {
        if (t.id == order.orderTypeId) return t;
      }
    }
    final name = (order.tariff ?? '').toLowerCase();
    if (name.isNotEmpty) {
      for (final t in _orderTypes) {
        if (t.name.toLowerCase() == name) return t;
      }
    }
    return null;
  }

  // ============== Online toggle ==============

  Future<void> toggleOnline() async {
    final newOnline = !state.isOnline;
    emit(state.copyWith(isOnline: newOnline));

    if (newOnline) {
      await _loadDriverSession();
      _loadOrderTypes();
      _connectMercure();
      _startLocationPush();
    } else {
      _disconnectMercure();
      _stopLocationPush();
      _waitingTimer?.cancel();
      _tripTimer?.cancel();
      _activeTariff = null;
      emit(state.copyWith(
        status: OrderStatus.initial,
        currentOrder: null,
        destinationLocation: null,
        routePoints: const [],
        routeGeometry: null,
        distanceToClient: null,
        clientPickedUp: false,
        waitingSeconds: 0,
        currentPrice: 0,
        traveledDistance: 0,
        tripSeconds: 0,
        isWaitingTimerActive: false,
      ));
      StorageHelper.remove(_activeTripKey);
    }
  }

  // ============== Mercure ==============

  void _connectMercure() {
    if (_driverId == null || _companyId == null) {
      // ignore: avoid_print
      print('\u26a0\ufe0f Mercure ulanmadi: driver/company ID yo\'q '
          '(driverId=$_driverId, companyId=$_companyId)');
      return;
    }
    final svc = sl<MercureService>();
    // Mercure uchun maxsus token bo'lsa - shuni, bo'lmasa access token.
    final mercureJwt =
        (_mercureToken != null && _mercureToken!.isNotEmpty)
            ? _mercureToken
            : _accessToken;
    // ignore: avoid_print
    print('\ud83d\udce1 Mercure connect \u2192 driverId=$_driverId, '
        'companyId=$_companyId, tariffs=$_tariffs, '
        'token=${mercureJwt != null ? "bor (${_mercureToken != null ? "mercure" : "access"})" : "yoq"}');
    svc.connect(
      driverId: _driverId!,
      companyId: _companyId!,
      activeTariffs: _tariffs,
      jwtToken: mercureJwt,
    );
    _mercureSub?.cancel();
    _mercureSub = svc.events.listen(_onMercureEvent);
  }

  void _disconnectMercure() {
    _mercureSub?.cancel();
    _mercureSub = null;
    sl<MercureService>().disconnect();
  }

  void _onMercureEvent(MercureEvent event) {
    switch (event.type) {
      case MercureEventType.newOrder:
        if (event.order != null && state.status == OrderStatus.initial) {
          emit(state.copyWith(
            status: OrderStatus.orderReceived,
            currentOrder: event.order,
          ));
          // Ovoz showNewOrderNotification ichida bir marta ijro etiladi
          // (ikki marta chaqirilsa player qotib qolardi).
          NotificationService().showNewOrderNotification();
        }
        break;
      case MercureEventType.accepted:
      case MercureEventType.canceled:
        if (state.currentOrder?.id == event.orderId &&
            state.status == OrderStatus.orderReceived) {
          emit(state.copyWith(
            status: OrderStatus.initial,
            currentOrder: null,
          ));
        }
        break;
      case MercureEventType.unknown:
        break;
    }
  }

  // ============== Location push (har 10 sek) ==============

  void _startLocationPush() {
    _locationPushTimer?.cancel();
    _locationPushTimer = Timer.periodic(
      const Duration(seconds: AppConstants.locationPushIntervalSec),
      (_) {
        _pushLocation();
        _persistActiveTrip();
      },
    );
    _pushLocation();
  }

  void _stopLocationPush() {
    _locationPushTimer?.cancel();
    _locationPushTimer = null;
  }

  Future<void> _pushLocation() async {
    if (_driverId == null || _companyId == null) {
      // ignore: avoid_print
      print('⚠️ Location push (10s) o\'tkazildi: driver/company ID yo\'q '
          '(driverId=$_driverId, companyId=$_companyId)');
      return;
    }
    final loc = state.currentLocation;
    if (loc == null) {
      // ignore: avoid_print
      print('⚠️ Location push (10s) o\'tkazildi: GPS lokatsiya hali yo\'q');
      return;
    }
    // Safar davomida (mijoz mashinada) km + narx ham yuboriladi.
    final onTrip = state.status == OrderStatus.inProgress;
    try {
      await sl<DriverService>().updateLocation(
        driverId: _driverId!,
        companyId: _companyId!,
        tariff: _tariffs,
        lat: loc.latitude,
        lng: loc.longitude,
        orderId: onTrip ? state.currentOrder?.id : null,
        distance: onTrip ? state.traveledDistance : null,
        price: onTrip ? state.currentPrice.toDouble() : null,
        status: onTrip ? 'on_the_way' : null,
      );
      // ignore: avoid_print
      print('📍 Location push (10s) yuborildi → driver=$_driverId, '
          'lat=${loc.latitude}, lng=${loc.longitude}, onTrip=$onTrip');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ location push xato: $e');
    }
  }

  // ============== Real GPS tracking ==============

  Future<Position> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onPositionChanged);
  }

  void _onPositionChanged(Position position) {
    final newLocation =
        Point(latitude: position.latitude, longitude: position.longitude);

    final prev = state.currentLocation;
    final heading = (prev != null)
        ? _calculateHeading(prev, newLocation)
        : (position.heading.isFinite ? position.heading : state.heading);

    // Real masofa qo'shilishi (faqat safar davomida)
    double traveled = state.traveledDistance;
    if (state.status == OrderStatus.inProgress && prev != null) {
      final segMeters = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );
      traveled += segMeters / 1000.0;
    }

    // Mijoz oldiga / manzilga avto-kelish (real GPS)
    double? distanceToClient = state.distanceToClient;

    if (state.status == OrderStatus.goingToClient &&
        state.currentOrder?.pickupLocation != null) {
      final dMeters = Geolocator.distanceBetween(
        newLocation.latitude,
        newLocation.longitude,
        state.currentOrder!.pickupLocation.latitude,
        state.currentOrder!.pickupLocation.longitude,
      );
      distanceToClient = dMeters;

      if (dMeters <= 50) {
        emit(state.copyWith(
          currentLocation: newLocation,
          heading: heading,
          distanceToClient: 0,
          status: OrderStatus.waitingForClient,
        ));
        NotificationService().showNotification(
          title: '📍 Mijoz oldida',
          body: 'Siz mijoz oldiga yetib keldingiz. Kutish boshlandi.',
          playSound: true,
        );

        _startWaitingTimer();
        _persistActiveTrip();
        return;
      }
    } else if (state.status == OrderStatus.inProgress &&
        state.destinationLocation != null) {
      final dMeters = Geolocator.distanceBetween(
        newLocation.latitude,
        newLocation.longitude,
        state.destinationLocation!.latitude,
        state.destinationLocation!.longitude,
      );
      if (dMeters <= 50) {
        emit(state.copyWith(
          currentLocation: newLocation,
          heading: heading,
          traveledDistance: traveled,
          currentPrice: _computePrice(traveled, state.waitingSeconds),
          status: OrderStatus.completed,
        ));
        NotificationService().showNotification(
          title: '🎉 Safar tugadi',
          body: 'Manzilga yetib keldingiz.',
          playSound: true,
        );
        // Auto-complete
        Future.delayed(const Duration(seconds: 1), () {
          if (state.status == OrderStatus.completed) completeOrder();
        });
        return;
      }
    }

    emit(state.copyWith(
      currentLocation: newLocation,
      heading: heading,
      traveledDistance: traveled,
      currentPrice: state.status == OrderStatus.inProgress
          ? _computePrice(traveled, state.waitingSeconds)
          : state.currentPrice,
      distanceToClient: distanceToClient,
    ));
  }

  // ============== Order actions (real backend) ==============

  Future<void> acceptOrder() async {
    if (state.currentOrder == null || _driverId == null) return;

    // Ovozni kutmaymiz (fire-and-forget) — accept jarayonini sekinlatmaslik uchun.
    SoundService().playOrderAcceptedSound();

    try {
      await sl<OrderService>()
          .accept(orderId: state.currentOrder!.id, driverId: _driverId!);
    } catch (e) {
      emit(state.copyWith(error: 'Accept xatosi: $e'));
      // ignore: avoid_print
      print('⚠️ accept: $e');
      return;
    }

    // Mos tarifni aniqlaymiz (narx hisobi shu asosda). Kerak bo'lsa yuklaymiz.
    if (_orderTypes.isEmpty) await _loadOrderTypes();
    _activeTariff = _resolveTariff(state.currentOrder!);

    emit(state.copyWith(
      status: OrderStatus.orderAccepted,
      currentPrice: 0,
      traveledDistance: 0,
      waitingSeconds: 0,
      isWaitingTimerActive: false,
    ));

    // Yo'l olish
    await _requestRouteToClient();

    emit(state.copyWith(status: OrderStatus.goingToClient));
    _persistActiveTrip();
  }

  Future<void> rejectOrder() async {
    if (state.currentOrder != null &&
        (state.status == OrderStatus.orderAccepted ||
            state.status == OrderStatus.goingToClient ||
            state.status == OrderStatus.waitingForClient)) {
      try {
        await sl<OrderService>().cancelByDriver(state.currentOrder!.id);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ cancel: $e');
      }
    }

    _resetOrderState();
  }

  void markClientPickedUp() {
    if (state.currentOrder == null) return;

    // Mijoz olindi: kutish vaqtini muzlatamiz (u allaqachon narxga kirgan),
    // safar vaqti (tripSeconds) shu ondan yangidan boshlanadi.
    _stopWaitingTimer();

    // Backend: on_the_way — mijoz mashinaga chiqdi, safar boshlandi.
    if (state.currentOrder != null) {
      sl<OrderService>().onTheWay(state.currentOrder!.id).catchError((e) {
        // ignore: avoid_print
        print('\u26a0\ufe0f on_the_way: $e');
        return <String, dynamic>{};
      });
    }

    NotificationService().showNotification(
      title: '🚗 Safar boshlandi!',
      body: 'Mijoz olindi. Manzilga yo\'l oldik.',
      playSound: true,
    );

    emit(state.copyWith(
      clientPickedUp: true,
      status: OrderStatus.inProgress,
      destinationLocation: state.currentOrder!.destinationLocation,
      // Bazaviy narx + kutish haqi (agar bo'lsa) saqlanadi, masofa 0 dan boshlanadi
      currentPrice: _computePrice(0, state.waitingSeconds),
      traveledDistance: 0,
      tripStartTime: DateTime.now(),
      tripSeconds: 0,
    ));

    _startTripTimer();
    _requestRouteToDestination();
    _persistActiveTrip();
  }

  Future<void> completeOrder() async {
    _waitingTimer?.cancel();
    _stopTripTimer();

    // Haqiqiy safar davomiyligi (daqiqa) - tripStartTime asosida hisoblanadi
    int tripMinutes;
    if (state.tripStartTime != null) {
      final secs = DateTime.now().difference(state.tripStartTime!).inSeconds;
      tripMinutes = (secs / 60).round();
    } else {
      tripMinutes = (state.tripSeconds / 60).round();
    }
    if (tripMinutes < 1) tripMinutes = 1;

    // Kutish vaqti (daqiqa) - waitTime maydoni uchun.
    final waitMinutes = (state.waitingSeconds / 60).round();

    final order = state.currentOrder;
    if (order != null) {
      final completed = OrderModel(
        id: order.id,
        clientName: order.clientName,
        clientPhone: order.clientPhone,
        pickupLocation: order.pickupLocation,
        destinationLocation: order.destinationLocation,
        pickupAddress: order.pickupAddress,
        destinationAddress: order.destinationAddress,
        distance: state.traveledDistance,
        price: state.currentPrice.toDouble(),
        createdAt: order.createdAt,
        status: OrderStatusType.completed,
      );

      // Safar tugagan nuqta: haydovchining haqiqiy joriy joylashuvi,
      // bo'lmasa manzil koordinatalari.
      final endPoint = state.currentLocation ?? completed.destinationLocation;

      try {
        await sl<OrderService>().complete(
          orderId: completed.id,
          distance: completed.distance,
          minut: tripMinutes,
          waitTime: waitMinutes,
          price: completed.price,
          adress: completed.destinationAddress,
          endLat: endPoint.latitude,
          endLng: endPoint.longitude,
        );
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ complete: $e');
      }

      await _saveCompletedOrder(completed);
    }

    _resetOrderState();
  }

  void _resetOrderState() {
    emit(state.copyWith(
      status: OrderStatus.initial,
      currentOrder: null,
      destinationLocation: null,
      routePoints: const [],
      routeGeometry: null,
      currentRouteIndex: 0,
      distanceToClient: null,
      clientPickedUp: false,
      waitingSeconds: 0,
      currentPrice: 0,
      traveledDistance: 0,
      tripSeconds: 0,
      isWaitingTimerActive: false,
      routeDurationMinutes: null,
      routeDistanceKm: null,
    ));
    _activeTariff = null;
    StorageHelper.remove(_activeTripKey);
  }

  /// 401 + refresh fail: hamma narsani to'xtatib, online'dan chiqib, state'ni reset qilamiz.
  /// Cancel allaqachon `_tryCancelActiveOrder` (onSessionExpiring) da yuborilgan.
  void _onSessionExpired() {
    _disconnectMercure();
    _stopLocationPush();
    _waitingTimer?.cancel();
    _waitingTimer = null;
    _tripTimer?.cancel();
    _tripTimer = null;
    _resetOrderState();
    emit(state.copyWith(isOnline: false));
  }

  /// Token hali bor paytda chaqiriladi - aktiv buyurtmani serverda bekor qilish.
  Future<void> _tryCancelActiveOrder() async {
    final activeOrder = state.currentOrder;
    if (activeOrder == null) return;
    final hasActiveTrip = state.status == OrderStatus.orderAccepted ||
        state.status == OrderStatus.goingToClient ||
        state.status == OrderStatus.waitingForClient ||
        state.status == OrderStatus.inProgress;
    if (!hasActiveTrip) return;
    try {
      await sl<OrderService>()
          .cancelByDriver(activeOrder.id)
          .timeout(const Duration(milliseconds: 400));
    } catch (_) {}
  }

  // ============== Route ==============

  Future<void> _requestRouteToClient() async {
    final from = state.currentLocation;
    final to = state.currentOrder?.pickupLocation;
    if (from == null || to == null) return;
    await _loadRoute(from, to);
  }

  Future<void> _requestRouteToDestination() async {
    final from = state.currentLocation;
    final to = state.destinationLocation;
    if (from == null || to == null) return;
    await _loadRoute(from, to);
  }

  Future<void> _loadRoute(Point from, Point to) async {
    try {
      final routeData =
          await MapboxRouteService.getRoute(from, to, mode: 'driving');
      if (routeData['points'] != null &&
          (routeData['points'] as List).isNotEmpty) {
        emit(state.copyWith(
          routeGeometry: routeData['points'],
          currentRouteIndex: 0,
          routeDurationMinutes: routeData['durationMinutes'],
          routeDistanceKm: routeData['distanceKm'],
        ));
        return;
      }
    } catch (_) {}

    try {
      final geom =
          await YandexRouteDrawer.getRoute(from, to, mode: 'driving');
      if (geom.isNotEmpty) {
        emit(state.copyWith(routeGeometry: geom, currentRouteIndex: 0));
        return;
      }
    } catch (_) {}
  }

  // ============== Waiting timer ==============

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    emit(state.copyWith(isWaitingTimerActive: true));

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Kutish hisoblagichi faqat mijozni kutish bosqichida yoki safar ichida
      // qo'lda yoqilgan bo'lsa ishlaydi. Aks holda to'xtaydi.
      final canRun = state.status == OrderStatus.waitingForClient ||
          (state.status == OrderStatus.inProgress &&
              state.isWaitingTimerActive);
      if (!canRun) {
        timer.cancel();
        return;
      }

      final next = state.waitingSeconds + 1;
      // Mijozni kutish bosqichida narx ko'rsatilmaydi (0 turadi) — narx hisobi
      // on_the_way (mijoz mashinaga chiqqach) boshlanadi. Kutilgan vaqt esa
      // saqlanadi va keyin narxga (kutish haqi sifatida) qo'shiladi.
      if (state.status == OrderStatus.waitingForClient) {
        emit(state.copyWith(waitingSeconds: next));
      } else {
        final price = _computePrice(state.traveledDistance, next);
        emit(state.copyWith(waitingSeconds: next, currentPrice: price));
      }
    });
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
    emit(state.copyWith(isWaitingTimerActive: false));
  }

  void toggleWaitingTimer() {
    if (state.isWaitingTimerActive) {
      _stopWaitingTimer();
    } else {
      _startWaitingTimer();
    }
  }

  // ============== Trip timer (safar vaqti) ==============

  void _startTripTimer() {
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != OrderStatus.inProgress) {
        timer.cancel();
        return;
      }
      emit(state.copyWith(tripSeconds: state.tripSeconds + 1));
    });
  }

  void _stopTripTimer() {
    _tripTimer?.cancel();
    _tripTimer = null;
  }

  void toggleTimeout() {
    emit(state.copyWith(isTimeoutEnabled: !state.isTimeoutEnabled));
  }

  // ============== Helpers ==============

  /// Narx hisobi tarif (OrderTypes) asosida:
  ///   narx = minPrice + km*kmPrice + kutish haqi
  ///   kutish haqi = max(0, kutishDaqiqa - waitTime) * waitPrice (timeout yoqilgan bo'lsa)
  /// Tarif topilmasa AppConstants qiymatlari zaxira sifatida ishlatiladi.
  int _computePrice(double distanceKm, int waitingSeconds) {
    final t = _activeTariff;
    final base = t?.minPrice ?? AppConstants.basePrice.toDouble();
    final perKm = t?.kmPrice ?? AppConstants.pricePerKm.toDouble();
    final freeWaitMin = t?.waitTime ?? (AppConstants.freeWaitSeconds ~/ 60);
    final perWaitMin =
        t?.waitPrice ?? AppConstants.pricePerWaitingMinute.toDouble();

    final road = distanceKm * perKm;
    double waitCharge = 0;
    if (state.isTimeoutEnabled) {
      final overMin = (waitingSeconds / 60.0) - freeWaitMin;
      if (overMin > 0) waitCharge = overMin * perWaitMin;
    }
    final total = base + road + waitCharge;
    return ((total / 500).round() * 500).toInt();
  }

  double _calculateHeading(Point start, Point end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360;
  }

  Future<void> _saveCompletedOrder(OrderModel order) async {
    try {
      final raw =
          await StorageHelper.getString('completed_orders') ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      list.insert(0, {
        'id': order.id,
        'clientName': order.clientName,
        'clientPhone': order.clientPhone,
        'pickupAddress': order.pickupAddress,
        'destinationAddress': order.destinationAddress,
        'pickupLat': order.pickupLocation.latitude,
        'pickupLng': order.pickupLocation.longitude,
        'destLat': order.destinationLocation.latitude,
        'destLng': order.destinationLocation.longitude,
        'distance': order.distance,
        'price': order.price,
        'createdAt': order.createdAt.toIso8601String(),
        'status': 'completed',
      });
      if (list.length > 50) list.removeRange(50, list.length);
      await StorageHelper.saveString('completed_orders', jsonEncode(list));
    } catch (_) {}
  }

  // ============== Aktiv safarni saqlash / tiklash ==============

  /// Aktiv safar holatini diskka saqlaydi (app o'lib qayta ochilsa,
  /// time/km/narx yo'qolmasligi uchun). Aktiv safar bo'lmasa kalitni o'chiradi.
  Future<void> _persistActiveTrip() async {
    final order = state.currentOrder;
    final isActive = order != null &&
        (state.status == OrderStatus.orderAccepted ||
            state.status == OrderStatus.goingToClient ||
            state.status == OrderStatus.waitingForClient ||
            state.status == OrderStatus.inProgress);
    if (!isActive) {
      await StorageHelper.remove(_activeTripKey);
      return;
    }

    final dest = state.destinationLocation;
    final t = _activeTariff;
    final snapshot = <String, dynamic>{
      'status': state.status.name,
      'order': order.toJson(),
      'traveledDistance': state.traveledDistance,
      'waitingSeconds': state.waitingSeconds,
      'currentPrice': state.currentPrice,
      'clientPickedUp': state.clientPickedUp,
      'isWaitingTimerActive': state.isWaitingTimerActive,
      'isTimeoutEnabled': state.isTimeoutEnabled,
      'tripStartTime': state.tripStartTime?.toIso8601String(),
      'destLat': dest?.latitude,
      'destLng': dest?.longitude,
      'tariff': t == null
          ? null
          : {
              'id': t.id,
              'name': t.name,
              'minPrice': t.minPrice,
              'kmPrice': t.kmPrice,
              'waitTime': t.waitTime,
              'waitPrice': t.waitPrice,
              'status': t.status,
            },
      'savedAt': DateTime.now().toIso8601String(),
    };
    try {
      await StorageHelper.saveString(_activeTripKey, jsonEncode(snapshot));
    } catch (_) {}
  }

  /// Saqlangan aktiv safarni tiklaydi. Vaqt (kutish/safar) timestamp'lardan
  /// qayta hisoblanadi — app yopiq turgan vaqt ham hisobga olinadi.
  Future<void> _restoreActiveTrip() async {
    String? raw;
    try {
      raw = await StorageHelper.getString(_activeTripKey);
    } catch (_) {
      return;
    }
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic> snap;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      snap = decoded.cast<String, dynamic>();
    } catch (_) {
      await StorageHelper.remove(_activeTripKey);
      return;
    }

    // Juda eski (tashlab ketilgan) safarni tiklamaymiz.
    final savedAt = DateTime.tryParse((snap['savedAt'] ?? '').toString());
    if (savedAt == null ||
        DateTime.now().difference(savedAt) > const Duration(hours: 6)) {
      await StorageHelper.remove(_activeTripKey);
      return;
    }

    final status = OrderStatus.values.firstWhere(
      (s) => s.name == (snap['status'] ?? '').toString(),
      orElse: () => OrderStatus.initial,
    );
    if (status == OrderStatus.initial) {
      await StorageHelper.remove(_activeTripKey);
      return;
    }

    OrderModel? order;
    try {
      final om = snap['order'];
      if (om is Map) order = OrderModel.fromJson(om.cast<String, dynamic>());
    } catch (_) {}
    if (order == null) {
      await StorageHelper.remove(_activeTripKey);
      return;
    }

    // Tarif: avval snapshotdan, bo'lmasa ro'yxatdan qayta aniqlanadi.
    final tm = snap['tariff'];
    if (tm is Map) {
      try {
        _activeTariff = OrderTypeModel.fromJson(tm.cast<String, dynamic>());
      } catch (_) {}
    }
    if (_activeTariff == null) {
      if (_orderTypes.isEmpty) await _loadOrderTypes();
      _activeTariff = _resolveTariff(order);
    }

    // Time / km — null bo'lmasligi kafolatlanadi.
    final traveled = (snap['traveledDistance'] as num?)?.toDouble() ?? 0;
    int waitingSeconds = (snap['waitingSeconds'] as num?)?.toInt() ?? 0;
    int currentPrice = (snap['currentPrice'] as num?)?.toInt() ?? 0;
    final clientPickedUp = snap['clientPickedUp'] == true;
    final isWaitingActive = snap['isWaitingTimerActive'] == true;
    final isTimeoutEnabled = snap['isTimeoutEnabled'] != false;
    final tripStartTime =
        DateTime.tryParse((snap['tripStartTime'] ?? '').toString());

    // Kutish hisoblagichi yoqilgan bo'lsa, app yopiq turgan vaqt ham
    // kutishga qo'shiladi (wall-clock).
    if (isWaitingActive) {
      final gap = DateTime.now().difference(savedAt).inSeconds;
      if (gap > 0) waitingSeconds += gap;
    }

    // Safar vaqti har doim tripStartTime'dan hisoblanadi.
    int tripSeconds = state.tripSeconds;
    if (tripStartTime != null) {
      final secs = DateTime.now().difference(tripStartTime).inSeconds;
      tripSeconds = secs < 0 ? 0 : secs;
    }

    final destLat = (snap['destLat'] as num?)?.toDouble();
    final destLng = (snap['destLng'] as num?)?.toDouble();
    final destination = (destLat != null && destLng != null)
        ? Point(latitude: destLat, longitude: destLng)
        : order.destinationLocation;

    // Narxni qayta hisoblaymiz (faqat safar bosqichida ko'rsatiladi).
    if (status == OrderStatus.inProgress) {
      currentPrice = _computePrice(traveled, waitingSeconds);
    }

    emit(state.copyWith(
      status: status,
      currentOrder: order,
      destinationLocation: destination,
      traveledDistance: traveled,
      waitingSeconds: waitingSeconds,
      currentPrice: currentPrice,
      clientPickedUp: clientPickedUp,
      isWaitingTimerActive: isWaitingActive,
      isTimeoutEnabled: isTimeoutEnabled,
      tripStartTime: tripStartTime,
      tripSeconds: tripSeconds,
      isOnline: true,
    ));

    // Online rejimni tiklaymiz (Mercure + 10s location push).
    _connectMercure();
    _startLocationPush();

    // Tegishli taymerlar va yo'lni tiklaymiz.
    if (status == OrderStatus.inProgress) {
      _startTripTimer();
      if (isWaitingActive) _startWaitingTimer();
      _requestRouteToDestination();
    } else if (status == OrderStatus.waitingForClient) {
      _startWaitingTimer();
      _requestRouteToClient();
    } else {
      // orderAccepted / goingToClient
      _requestRouteToClient();
    }
  }

  // UI map'da bosilgan nuqta - mavjud chaqiruv saqlanishi uchun no-op
  void setDestination(Point _) {}

  void openInGoogleMaps() {}

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _mercureSub?.cancel();
    _sessionSub?.cancel();
    _sessionExpiringSub?.cancel();
    _waitingTimer?.cancel();
    _tripTimer?.cancel();
    _locationPushTimer?.cancel();
    _disconnectMercure();
    return super.close();
  }
}
