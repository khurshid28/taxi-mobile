import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
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
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/notification_service.dart';
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

  // ===== Yangilanish tezligi (qotmaslik uchun) =====
  // GPS signali har ~5 metrda keladi (yurganda sekundiga bir necha marta).
  // Har signalda EKRANGA emit qilsak, native xarita ustida qayta chizilib
  // app QOTADI. Shuning uchun masofani har signalda aniq yig'amiz, lekin
  // xaritaga/narxga FAQAT har 10 soniyada bir marta uzatamiz.
  static const int _updateIntervalSec = 10;
  Point? _lastDistancePoint; // masofa segmentini hisoblash uchun oxirgi nuqta
  double _tripDistanceKm = 0; // safar davomida yig'ilgan aniq masofa (km)
  DateTime? _lastMapEmit; // oxirgi emit vaqti (10s throttle)

  // ===== Kutish (pause) vaqti — ANIQ hisob (wall-clock) =====
  // Hisoblagichni 10s'da +10 qilib emas, HAQIQIY o'tgan vaqtni o'lchaymiz.
  // Shunda completed'ga yuboriladigan kutish vaqti soniyagacha aniq bo'ladi
  // (mijozni kutish + safar ichidagi qo'lda pauzalar yig'indisi).
  int _accumulatedWaitingSeconds = 0; // yakunlangan kutish segmentlari yig'indisi
  DateTime? _waitingStartedAt; // joriy faol kutish segmenti boshlangan vaqt

  // Backend session
  int? _driverId;
  int? _companyId;
  List<String> _tariffs = const ['Start'];
  String? _mercureToken;

  // Tarif narxlari (OrderTypes). Bir marta yuklab, cache qilinadi.
  List<OrderTypeModel> _orderTypes = const [];
  // Aktiv buyurtma uchun aniqlangan tarif (narx hisobida ishlatiladi).
  OrderTypeModel? _activeTariff;

  // Accept jarayoni davom etyaptimi. Backend buyurtma qabul qilinganda BARCHA
  // haydovchilarga Mercure "accepted" xabarini tarqatadi (shu haydovchiga ham).
  // accept/getOrder kutilayotgan payt status hali "orderReceived" bo'lgani uchun
  // _onMercureEvent currentOrder'ni reset qilib app'ni qotirardi. Bu bayroq
  // shu oraliqda reset'ni bloklaydi.
  bool _isAccepting = false;

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

      // Joriy joylashuv. GPS o'chiq/sekin bo'lsa ham (xato yoki uzoq osilish)
      // app ochilishi va AKTIV BUYURTMANI tiklash to'xtab qolmasligi kerak —
      // shuning uchun alohida try ichida. Aks holda getCurrentPosition xatosi
      // _restoreActiveTrip() gacha yetib bormay, qabul qilingan buyurtma
      // "Faol" bo'limida ko'rinmay qolardi.
      try {
        final position = await _getCurrentLocation();
        emit(
          state.copyWith(
            currentLocation: Point(
                latitude: position.latitude, longitude: position.longitude),
            heading: position.heading,
            status: OrderStatus.initial,
            isLoading: false,
          ),
        );
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ boshlang\'ich joylashuv olinmadi: $e');
        emit(state.copyWith(status: OrderStatus.initial, isLoading: false));
      }

      _loadOrderTypes();
      // Aktiv (qabul qilingan) safarni tiklaymiz — app o'chib qayta ochilsa
      // ham buyurtma "Faol" bo'limida va asosiy oynada ko'rinishi uchun.
      await _restoreActiveTrip();
      _startLocationTracking();
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _loadDriverSession() async {
    _driverId = await StorageHelper.getInt(AppConstants.keyDriverId);
    _companyId = await StorageHelper.getInt(AppConstants.keyCompanyId);
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

  /// Yangi buyurtma kartasida ko'rsatiladigan boshlang'ich (fix) narx.
  /// Tarif (OrderTypes) ning `minPrice` qiymati: Start=2500, Comfort=3000 ...
  /// Tarif topilmasa AppConstants.basePrice zaxira sifatida ishlatiladi.
  int resolveOrderBasePrice(OrderModel order) {
    final t = _resolveTariff(order);
    final base = t?.minPrice ?? AppConstants.basePrice.toDouble();
    return base.round();
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
    // Vaqtincha: barcha topiclarga obuna bo'luvchi static token ishlatamiz
    // (backend hali ishlaydigan dinamik mercure token bermayapti). Server
    // token bersa — o'shani, bo'lmasa static tokenni yuboramiz.
    final mercureJwt = (_mercureToken != null && _mercureToken!.isNotEmpty)
        ? _mercureToken
        : AppConstants.mercureStaticToken;
    // ignore: avoid_print
    print('\ud83d\udce1 Mercure connect → driverId=$_driverId, '
        'companyId=$_companyId, tariffs=$_tariffs, '
        'token=${_mercureToken != null && _mercureToken!.isNotEmpty ? "server" : "static"}');
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
    AppLogger.info('HomeCubit event: ${event.type} '
        '(orderId=${event.orderId}, holat=${state.status}, '
        'online=${state.isOnline})');
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
          AppLogger.order('EKRANGA CHIQARILDI: buyurtma #${event.order!.id}');
        } else {
          AppLogger.warn('Yangi buyurtma KO\'RSATILMADI: '
              'order=${event.order != null}, holat=${state.status} '
              '(faqat "initial" holatda chiqadi)');
        }
        break;
      case MercureEventType.accepted:
      case MercureEventType.canceled:
        if (!_isAccepting &&
            state.currentOrder?.id == event.orderId &&
            state.status == OrderStatus.orderReceived) {
          AppLogger.info('Buyurtma #${event.orderId} bekor/qabul qilindi — '
              'ekran tozalandi');
          // Toza reset (copyWith null bilan currentOrder tozalanmaydi).
          _resetOrderState();
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
      return;
    }
    final loc = state.currentLocation;
    if (loc == null) {
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
    // getCurrentPosition ba'zan uzoq osilib qoladi yoki xato beradi. 8s
    // timeout + oxirgi ma'lum joylashuv (cache) zaxira sifatida — app
    // ochilishi va buyurtma tiklash bloklanmasligi uchun.
    try {
      return await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
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

    // Yo'nalish (marker burilishi) — oldingi GPS nuqtasidan.
    final heading = (_lastDistancePoint != null)
        ? _calculateHeading(_lastDistancePoint!, newLocation)
        : (position.heading.isFinite ? position.heading : state.heading);

    // Masofani HAR signalda aniq yig'amiz (arzon hisob). Ekranga (emit) esa
    // pastda — faqat har 10 soniyada bir marta uzatamiz.
    if (state.status == OrderStatus.inProgress && _lastDistancePoint != null) {
      final segMeters = Geolocator.distanceBetween(
        _lastDistancePoint!.latitude,
        _lastDistancePoint!.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );
      _tripDistanceKm += segMeters / 1000.0;
    }
    _lastDistancePoint = newLocation;

    // ===== Avto-o'tishlar: chegarani kesib o'tish (kam uchraydi -> darhol) =====
    if (state.status == OrderStatus.goingToClient &&
        state.currentOrder?.pickupLocation != null) {
      final dMeters = Geolocator.distanceBetween(
        newLocation.latitude,
        newLocation.longitude,
        state.currentOrder!.pickupLocation.latitude,
        state.currentOrder!.pickupLocation.longitude,
      );
      if (dMeters <= 50) {
        _lastMapEmit = DateTime.now();
        emit(state.copyWith(
          currentLocation: newLocation,
          heading: heading,
          distanceToClient: 0,
          status: OrderStatus.waitingForClient,
        ));
        NotificationService().showNotification(
          title: '📍 Mijoz oldida',
          body: 'Siz mijoz oldiga yetib keldingiz. Kutish boshlandi.',
          playSound: false,
        );
        _startWaitingTimer();
        _persistActiveTrip();
        return;
      }
    }

    // ===== Oddiy yangilanish: FAQAT har 10 soniyada (qotmaslik uchun) =====
    final now = DateTime.now();
    if (_lastMapEmit != null &&
        now.difference(_lastMapEmit!).inSeconds < _updateIntervalSec) {
      return; // 10 soniya o'tmagan — hozircha emit yo'q
    }
    _lastMapEmit = now;

    double? distanceToClient = state.distanceToClient;
    if (state.status == OrderStatus.goingToClient &&
        state.currentOrder?.pickupLocation != null) {
      distanceToClient = Geolocator.distanceBetween(
        newLocation.latitude,
        newLocation.longitude,
        state.currentOrder!.pickupLocation.latitude,
        state.currentOrder!.pickupLocation.longitude,
      );
    }

    emit(state.copyWith(
      currentLocation: newLocation,
      heading: heading,
      traveledDistance: state.status == OrderStatus.inProgress
          ? _tripDistanceKm
          : state.traveledDistance,
      currentPrice: state.status == OrderStatus.inProgress
          ? _computePrice(_tripDistanceKm, state.waitingSeconds)
          : state.currentPrice,
      distanceToClient: distanceToClient,
    ));
  }

  // ============== Order actions (real backend) ==============

  Future<void> acceptOrder() async {
    if (state.currentOrder == null || _driverId == null) return;

    // Buyurtmani BOSHIDA lokal nusxaga saqlaymiz — accept/getOrder kutilayotgan
    // payt state biror sabab bilan o'zgarsa ham (mas. Mercure xabari) buyurtma
    // yo'qolmasin. Pastda state.currentOrder! o'rniga shu `order` ishlatiladi.
    final order = state.currentOrder!;
    final orderId = order.id;
    AppLogger.header('ACCEPT');
    AppLogger.info('orderId  = "$orderId"');
    AppLogger.info('driverId = $_driverId');

    // orderId bo'sh bo'lsa - so'rov yubormaymiz. Aks holda URL `orders//1/accept`
    // ko'rinishida buzilib backend 404 qaytaradi. Bu Mercure xabarida orderId
    // kelmaganini bildiradi (backend tomonidagi muammo).
    if (orderId.isEmpty) {
      AppLogger.error('ACCEPT BEKOR: orderId BO\'SH — Mercure xabarida '
          'orderId kelmagan. Backend payload\'ga orderId qo\'shishi kerak.');
      _resetOrderState();
      emit(state.copyWith(
        error: 'Buyurtma raqami (orderId) kelmadi. Backend Mercure xabariga '
            'orderId qo\'shishi kerak.',
      ));
      return;
    }

    AppLogger.info('URL      = ${AppConstants.baseUrl}orders/$orderId/'
        '$_driverId/accept');

    // Accept davom etmoqda — Mercure "accepted" xabari (shu haydovchining o'z
    // qabuli ham) currentOrder'ni reset qilib qo'ymasin.
    _isAccepting = true;
    try {
      try {
        await sl<OrderService>()
            .accept(orderId: orderId, driverId: _driverId!)
            .timeout(const Duration(seconds: 12));
        AppLogger.success('ACCEPT muvaffaqiyatli (orderId=$orderId, '
            'driverId=$_driverId)');
      } catch (e) {
        // Aniq diagnostika: qaysi URL, qaysi status, backend nima dedi.
        if (e is DioException) {
          final data = e.response?.data;
          final detail = data is Map
              ? (data['detail'] ?? data['title'] ?? data['message'] ?? data)
              : data;
          AppLogger.error('ACCEPT XATO — status ${e.response?.statusCode}');
          AppLogger.error('URL: ${e.requestOptions.uri}');
          AppLogger.error('Sabab: $detail');
        } else {
          AppLogger.error('ACCEPT XATO: $e');
        }
        // Qabul qilib bo'lmadi (mas. 404 — allaqachon olingan). Toza holatga
        // qaytamiz va xabar ko'rsatamiz.
        _activeTariff = null;
        _resetOrderState();
        emit(state.copyWith(
          error: 'Buyurtmani qabul qilib bo\'lmadi — u allaqachon olingan '
              'yoki mavjud emas.',
        ));
        return;
      }

      // Ovoz FAQAT yangi buyurtma kelganda chalinadi (showNewOrderNotification
      // ichida). Qabul/yetib kelish/yakunlashda ovoz YO'Q.

      // To'liq ma'lumotni (mijoz tel, aniq manzillar, narx) REST orqali
      // tortamiz. currentOrder o'rniga lokal `order` ishlatamiz.
      var acceptedOrder = order;
      try {
        acceptedOrder = await sl<OrderService>().getOrder(order.id);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ getOrder (accept keyin): $e');
      }

      // Mos tarifni aniqlaymiz (narx hisobi shu asosda). Kerak bo'lsa yuklaymiz.
      if (_orderTypes.isEmpty) await _loadOrderTypes();
      _activeTariff = _resolveTariff(acceptedOrder);

      // Yangi buyurtma — kutish (pause) hisoblagichini noldan boshlaymiz.
      _accumulatedWaitingSeconds = 0;
      _waitingStartedAt = null;

      // Darhol "Mijoz oldiga" (goingToClient) holatiga o'tamiz: panel ko'rinadi,
      // marshrut esa orqa fonda yuklanadi. currentOrder ni emitga qo'shamiz —
      // shunda oraliqda biror reset bo'lsa ham buyurtma qaytadi.
      _lastMapEmit = null; // marker/masofa darhol yangilansin (10s kutmasin)
      _lastDistancePoint = state.currentLocation;
      emit(state.copyWith(
        status: OrderStatus.goingToClient,
        currentOrder: acceptedOrder,
        // Taxminiy narx allaqachon trip km ni o'z ichiga oladi (base + km).
        currentPrice: _computePrice(acceptedOrder.distance, 0),
        traveledDistance: 0,
        waitingSeconds: 0,
        isWaitingTimerActive: false,
      ));

      // Snapshotni DARHOL saqlaymiz — marshrut yuklash (pastda) osilib qolsa
      // yoki haydovchi appni shu zahoti yopsa ham buyurtma "Faol" bo'limida
      // va qayta ochilganda tiklanadigan bo'lib qoladi.
      _persistActiveTrip();

      // Yo'l olish (mijozgacha) — tugagach polyline xaritaga chiziladi.
      await _requestRouteToClient();
      _persistActiveTrip();
    } finally {
      _isAccepting = false;
    }
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

  /// Qo'lda "Yetib keldim". GPS avto-o'tish (mijozdan 50 m) ishlamasa
  /// (mas. sinovda yoki signal sust bo'lsa), haydovchi shu tugma orqali
  /// `goingToClient` → `waitingForClient` bosqichiga o'tadi va kutish
  /// hisoblagichi boshlanadi. Ekran shu tariqa "qotib" qolmaydi.
  void arrivedAtClient() {
    if (state.status != OrderStatus.goingToClient) return;
    _lastMapEmit = null; // keyingi yangilanish darhol ko'rinsin
    emit(state.copyWith(
      status: OrderStatus.waitingForClient,
      distanceToClient: 0,
    ));
    NotificationService().showNotification(
      title: '📍 Mijoz oldida',
      body: 'Mijoz oldiga yetib keldingiz. Kutish boshlandi.',
      playSound: false,
    );
    _startWaitingTimer();
    _persistActiveTrip();
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
      playSound: false,
    );

    // Safar masofasini shu nuqtadan (mijoz olingan joydan) yangidan sanaymiz.
    _tripDistanceKm = 0;
    _lastDistancePoint = state.currentLocation;
    _lastMapEmit = null; // birinchi yangilanish darhol ko'rinsin

    emit(state.copyWith(
      clientPickedUp: true,
      status: OrderStatus.inProgress,
      // Boradigan manzil ANIQ EMAS — safar davomida xaritaga yo'l chizig'i
      // chizilmaydi. Haydovchi borib yetgach "Tugatish" tugmasi bilan o'zi
      // yakunlaydi. Shu sabab mijozga chizilgan eski chiziqni ham o'chiramiz.
      routeGeometry: const [],
      // Bazaviy narx + kutish haqi (agar bo'lsa) saqlanadi, masofa 0 dan boshlanadi
      currentPrice: _computePrice(0, state.waitingSeconds),
      traveledDistance: 0,
      tripStartTime: DateTime.now(),
      tripSeconds: 0,
    ));

    _startTripTimer();
    _persistActiveTrip();
  }

  Future<void> completeOrder() async {
    // Faol kutish segmentini yakunlaymiz — oxirgi pauza ham aniq qo'shiladi.
    _stopWaitingTimer();
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

    // Kutish vaqti (daqiqa) — waitTime maydoni uchun. _stopWaitingTimer()
    // chaqirilgani uchun _accumulatedWaitingSeconds yakuniy aniq qiymat.
    final waitMinutes = (_accumulatedWaitingSeconds / 60).round();

    final order = state.currentOrder;
    final OrderModel? completed = order == null
        ? null
        : OrderModel(
            id: order.id,
            clientName: order.clientName,
            clientPhone: order.clientPhone,
            pickupLocation: order.pickupLocation,
            destinationLocation: order.destinationLocation,
            pickupAddress: order.pickupAddress,
            destinationAddress: order.destinationAddress,
            distance: _tripDistanceKm > 0
                ? _tripDistanceKm
                : state.traveledDistance,
            price: state.currentPrice.toDouble(),
            createdAt: order.createdAt,
            status: OrderStatusType.completed,
          );

    // Safar tugagan nuqta: haydovchining haqiqiy joriy joylashuvi,
    // bo'lmasa manzil koordinatalari.
    final endPoint = state.currentLocation ?? completed?.destinationLocation;

    // UI ni DARHOL bo'shatamiz — backend (complete) javobini KUTMAYMIZ. Sekin
    // internetda "Tugatish" bosilgach app qotgandek turardi; endi ekran shu
    // zahoti tozalanadi, yuborish esa orqa fonda (timeout bilan) ketadi.
    _resetOrderState();

    if (completed != null && endPoint != null) {
      unawaited(
        _finishOrderInBackground(completed, tripMinutes, waitMinutes, endPoint),
      );
    }
  }

  /// Buyurtmani yakunlash so'rovini orqa fonda yuboradi va lokalga saqlaydi —
  /// UI bloklanmasligi uchun (timeout bilan, osilib qolmaydi).
  Future<void> _finishOrderInBackground(
    OrderModel completed,
    int tripMinutes,
    int waitMinutes,
    Point endPoint,
  ) async {
    try {
      await sl<OrderService>()
          .complete(
            orderId: completed.id,
            distance: completed.distance,
            minut: tripMinutes,
            waitTime: waitMinutes,
            price: completed.price,
            adress: completed.destinationAddress,
            endLat: endPoint.latitude,
            endLng: endPoint.longitude,
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ complete: $e');
    }
    await _saveCompletedOrder(completed);
  }

  void _resetOrderState() {
    // MUHIM: HomeState.copyWith `?? this` ishlatadi — null uzatish nullable
    // maydonni TOZALAMAYDI (eski qiymat qoladi). Shu sabab avval buyurtma
    // tugagach currentOrder / routeGeometry / destinationLocation / tripStartTime
    // eskича qolib ketardi va xaritada eski marshrut chizig'i "qotib" turardi.
    // Buni oldini olish uchun butunlay TOZA yangi HomeState quramiz — faqat
    // joylashuv, yo'nalish, online holati va timeout sozlamasi saqlanadi.
    emit(HomeState(
      status: OrderStatus.initial,
      currentLocation: state.currentLocation,
      heading: state.heading,
      isOnline: state.isOnline,
      isTimeoutEnabled: state.isTimeoutEnabled,
    ));
    _activeTariff = null;
    _tripDistanceKm = 0;
    _lastDistancePoint = null;
    _lastMapEmit = null;
    _accumulatedWaitingSeconds = 0;
    _waitingStartedAt = null;
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

  Future<void> _loadRoute(Point from, Point to) async {
    try {
      final routeData = await MapboxRouteService.getRoute(from, to,
              mode: 'driving')
          .timeout(const Duration(seconds: 12));
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
      final geom = await YandexRouteDrawer.getRoute(from, to, mode: 'driving')
          .timeout(const Duration(seconds: 12));
      if (geom.isNotEmpty) {
        emit(state.copyWith(routeGeometry: geom, currentRouteIndex: 0));
        return;
      }
    } catch (_) {}
  }

  // ============== Waiting timer ==============

  /// Joriy umumiy kutish vaqti (soniya): yakunlangan segmentlar + faol segment
  /// (wall-clock). App fonda turgan vaqt ham avtomatik hisobga olinadi.
  int get _currentWaitingSeconds {
    var total = _accumulatedWaitingSeconds;
    if (_waitingStartedAt != null) {
      total += DateTime.now().difference(_waitingStartedAt!).inSeconds;
    }
    return total < 0 ? 0 : total;
  }

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    // Faol segment boshlanish vaqti (resume bo'lsa eskisi saqlanadi).
    _waitingStartedAt ??= DateTime.now();
    emit(state.copyWith(
      isWaitingTimerActive: true,
      waitingSeconds: _currentWaitingSeconds,
    ));

    // Har 10 soniyada FAQAT ekranni yangilaymiz — vaqtning o'zi wall-clock'dan
    // o'lchanadi (qotmaslik uchun emit kam, lekin hisob aniq).
    _waitingTimer =
        Timer.periodic(const Duration(seconds: _updateIntervalSec), (timer) {
      // Kutish hisoblagichi faqat mijozni kutish bosqichida yoki safar ichida
      // qo'lda yoqilgan bo'lsa ishlaydi. Aks holda to'xtaydi.
      final canRun = state.status == OrderStatus.waitingForClient ||
          (state.status == OrderStatus.inProgress &&
              state.isWaitingTimerActive);
      if (!canRun) {
        timer.cancel();
        return;
      }

      final secs = _currentWaitingSeconds;
      // Mijozni kutish bosqichida ham "Taxminiy narx" JONLI yangilanadi:
      // bepul vaqt tugagach kutish haqi (yuqoriga yaxlitlangan daqiqalar)
      // darhol narxga qo'shilib boradi. Masofa — rejalashtirilgan trip km.
      if (state.status == OrderStatus.waitingForClient) {
        emit(state.copyWith(
          waitingSeconds: secs,
          currentPrice: _computePrice(_plannedDistanceKm, secs),
        ));
      } else {
        emit(state.copyWith(
          waitingSeconds: secs,
          currentPrice: _computePrice(_tripDistanceKm, secs),
        ));
      }
    });
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
    // Faol segmentni yakunlab, ANIQ o'tgan vaqtni umumiy yig'indiga qo'shamiz.
    if (_waitingStartedAt != null) {
      _accumulatedWaitingSeconds +=
          DateTime.now().difference(_waitingStartedAt!).inSeconds;
      _waitingStartedAt = null;
    }
    emit(state.copyWith(
      isWaitingTimerActive: false,
      waitingSeconds: _accumulatedWaitingSeconds,
    ));
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
    // Har 10 soniyada: safar vaqti + narx yangilanadi (svetoforda turganda
    // ham). GPS yurmasa ham soat shu yerda yuradi — lekin har 10 soniyada.
    _tripTimer =
        Timer.periodic(const Duration(seconds: _updateIntervalSec), (timer) {
      if (state.status != OrderStatus.inProgress) {
        timer.cancel();
        return;
      }
      emit(state.copyWith(
        tripSeconds: state.tripSeconds + _updateIntervalSec,
        currentPrice: _computePrice(_tripDistanceKm, state.waitingSeconds),
      ));
    });
  }

  void _stopTripTimer() {
    _tripTimer?.cancel();
    _tripTimer = null;
  }

  void toggleTimeout() {
    emit(state.copyWith(isTimeoutEnabled: !state.isTimeoutEnabled));
  }

  /// Xato xabarini tozalaydi (UI ko'rsatgandan keyin) — shunda u keyingi
  /// state emit'larida (mas. har 10s lokatsiya yangilanishi) qayta chiqmaydi.
  void clearError() {
    if (state.error != null) emit(state.copyWith(clearError: true));
  }

  // ============== Helpers ==============

  /// Buyurtmaning rejalashtirilgan masofasi (km) — backend bergan trip masofasi
  /// (pickup→manzil). "Taxminiy narx" shu masofa bo'yicha hisoblanadi; safar
  /// boshlangach esa haqiqiy bosib o'tilgan masofa (`_tripDistanceKm`) ishlatiladi.
  double get _plannedDistanceKm => state.currentOrder?.distance ?? 0;

  /// Narx hisobi tarif (OrderTypes) asosida:
  ///   narx = minPrice + km*kmPrice + kutish haqi
  ///   kutish haqi = ceil(max(0, kutish - bepulVaqt)) * waitPrice (timeout yoqilgan bo'lsa)
  /// Bepul vaqtdan oshgan qism daqiqaga YUQORIGA yaxlitlanadi (3:20 => 4 daqiqa).
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
      // Bepul vaqtdan oshgan qism YUQORIGA yaxlitlanadi — har boshlangan
      // daqiqa to'liq hisoblanadi (mas. 3:20 oshiq => 4 daqiqa).
      final overSeconds = waitingSeconds - (freeWaitMin * 60);
      if (overSeconds > 0) {
        final overMinutes = (overSeconds / 60.0).ceil();
        waitCharge = overMinutes * perWaitMin;
      }
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
    int currentPrice = (snap['currentPrice'] as num?)?.toInt() ?? 0;
    final clientPickedUp = snap['clientPickedUp'] == true;
    final isWaitingActive = snap['isWaitingTimerActive'] == true;
    final isTimeoutEnabled = snap['isTimeoutEnabled'] != false;
    final tripStartTime =
        DateTime.tryParse((snap['tripStartTime'] ?? '').toString());

    // Kutish vaqtini ANIQ tiklaymiz: saqlangan yig'indi + (kutish faol bo'lsa)
    // app yopiq turgan vaqt (wall-clock) avtomatik qo'shiladi.
    _accumulatedWaitingSeconds = (snap['waitingSeconds'] as num?)?.toInt() ?? 0;
    _waitingStartedAt = isWaitingActive ? savedAt : null;
    int waitingSeconds = _currentWaitingSeconds;

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

    // Masofa hisoblagichini tiklangan qiymatdan davom ettiramiz (aks holda
    // birinchi GPS signali traveledDistance'ni 0 ga tushirib yuborardi).
    _lastDistancePoint = state.currentLocation;
    _lastMapEmit = null;

    // Tegishli taymerlar va yo'lni tiklaymiz.
    if (status == OrderStatus.inProgress) {
      _tripDistanceKm = traveled;
      _startTripTimer();
      if (isWaitingActive) _startWaitingTimer();
      // Manzil aniq emas — safar davomida yo'l chizig'i tiklanmaydi.
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
