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
  int _accumulatedWaitingSeconds =
      0; // yakunlangan kutish segmentlari yig'indisi
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
      _sessionExpiringSub ??= AuthEvents.instance.onSessionExpiring.listen((_) {
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
              latitude: position.latitude,
              longitude: position.longitude,
            ),
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
      // Global buyurtmalar REST orqali (liniyaga chiqish shart emas) — Mercure
      // real-vaqt bilan id bo'yicha dedup qilib birlashtiriladi.
      // ignore: discarded_futures
      loadGlobalOrders();
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _loadDriverSession() async {
    _driverId = await StorageHelper.getInt(AppConstants.keyDriverId);
    _companyId = await StorageHelper.getInt(AppConstants.keyCompanyId);
    _mercureToken = await StorageHelper.getString(AppConstants.keyMercureToken);

    // Cache'da driver/company ID yo'q bo'lsa - bir marta about_me orqali
    // olib kelamiz va cache'laymiz. Keyingi safar so'rov bermaymiz.
    if (_driverId == null || _companyId == null) {
      try {
        final profile = await sl<DriverService>().aboutMe();
        _driverId = profile.id ?? _driverId;
        _companyId = profile.companyId ?? _companyId;
        // ignore: avoid_print
        print(
          '\ud83d\udd04 about_me orqali yuklandi: driverId=$_driverId, '
          'companyId=$_companyId',
        );
      } catch (e) {
        // ignore: avoid_print
        print('\ud83d\udd34 about_me yuklash xato: $e');
      }
      // `drivers/about_me` companyId qaytarmasligi mumkin. Hali null bo'lsa
      // `driver_datas/about_me` (company IRI) orqali olib kelamiz — Mercure
      // global topic (`company/{id}/orders/...`) uchun company majburiy.
      if (_companyId == null) {
        try {
          final data = await sl<DriverService>().aboutMyData();
          _companyId = data.companyId ?? _companyId;
          // ignore: avoid_print
          print(
            '\ud83d\udd04 driver_datas/about_me \u2192 companyId=$_companyId',
          );
        } catch (e) {
          // ignore: avoid_print
          print('\ud83d\udd34 driver_datas/about_me xato: $e');
        }
      }
    } else {
      // ignore: avoid_print
      print(
        '\ud83d\udcbe Cache\'dan: driverId=$_driverId, companyId=$_companyId',
      );
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
      emit(
        state.copyWith(
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
          queuedOrders: const [],
        ),
      );
      // Global buyurtmalar offline'da ham ko'rinadi — ro'yxatni TOZALAMAYMIZ.
      StorageHelper.remove(_activeTripKey);
    }
  }

  // ============== Mercure ==============

  void _connectMercure() {
    if (_driverId == null || _companyId == null) {
      // ignore: avoid_print
      print(
        '\u26a0\ufe0f Mercure ulanmadi: driver/company ID yo\'q '
        '(driverId=$_driverId, companyId=$_companyId)',
      );
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
    print(
      '\ud83d\udce1 Mercure connect → driverId=$_driverId, '
      'companyId=$_companyId, tariffs=$_tariffs, '
      'token=${_mercureToken != null && _mercureToken!.isNotEmpty ? "server" : "static"}',
    );
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
    AppLogger.info(
      'HomeCubit event: ${event.type} '
      '(orderId=${event.orderId}, holat=${state.status}, '
      'online=${state.isOnline})',
    );
    switch (event.type) {
      case MercureEventType.newOrder:
        if (event.order != null && state.status == OrderStatus.initial) {
          emit(
            state.copyWith(
              status: OrderStatus.orderReceived,
              currentOrder: event.order,
            ),
          );
          // Ovoz showNewOrderNotification ichida bir marta ijro etiladi
          // (ikki marta chaqirilsa player qotib qolardi).
          NotificationService().showNewOrderNotification();
          AppLogger.order('EKRANGA CHIQARILDI: buyurtma #${event.order!.id}');
        } else {
          AppLogger.warn(
            'Yangi buyurtma KO\'RSATILMADI: '
            'order=${event.order != null}, holat=${state.status} '
            '(faqat "initial" holatda chiqadi)',
          );
        }
        break;
      case MercureEventType.globalNewOrder:
        // Hech kim olmagan, hammaga yuborilgan buyurtma — alohida "Global
        // buyurtmalar" ro'yxatiga qo'shamiz (bottom-sheet emas).
        _addGlobalOrder(event.order);
        break;
      case MercureEventType.accepted:
      case MercureEventType.canceled:
        // 1) GLOBAL ro'yxatdan shu buyurtmani JIM olib tashlaymiz — kimdir
        //    oldi yoki bekor qilindi (ovoz/banner YO'Q, faqat ro'yxat
        //    yangilanadi — foydalanuvchi talabi).
        _removeGlobalOrder(event.orderId);
        // 2) Agar shu buyurtma AYNAN ekrandagi (shaxsiy) buyurtma bo'lsa —
        //    bottom-sheet'ni tozalaymiz.
        if (!_isAccepting &&
            state.currentOrder?.id == event.orderId &&
            state.status == OrderStatus.orderReceived) {
          AppLogger.info(
            'Buyurtma #${event.orderId} bekor/qabul qilindi — '
            'ekran tozalandi',
          );
          // Toza reset (copyWith null bilan currentOrder tozalanmaydi).
          _resetOrderState();
        }
        break;
      case MercureEventType.unknown:
        break;
    }
  }

  // ============== Global buyurtmalar ==============
  // Hech bir haydovchi 2 urinishda olmagan buyurtma kompaniya bo'yicha BARCHA
  // online haydovchilarga yuboriladi (`company/{id}/orders/global`). Ular
  // alohida "Global buyurtmalar" oynasida ro'yxat bo'lib turadi; istalgan
  // haydovchi oladi (birinchi olgan yutadi).

  /// Yangi global buyurtmani ro'yxatga qo'shadi (eng yangisi tepada) va
  /// haydovchini ogohlantiradi. To'liq ma'lumotni (manzil, narx) orqa fonda
  /// REST orqali to'ldiramiz (Mercure faqat {orderId, tariff} yuboradi).
  void _addGlobalOrder(OrderModel? order) {
    if (order == null) return;
    // Tarif filtri: haydovchining tarifiga mos kelmaydigan buyurtmani
    // ko'rsatmaymiz (mas. "comfront" yo'q bo'lsa, comfort buyurtma chiqmaydi).
    // Mercure xizmati ham filtrlaydi — bu cubit darajasidagi qo'shimcha kafolat.
    if (!_matchesDriverTariff(order)) return;
    // Global buyurtmalar online bo'lmasa ham ko'rinadi (liniyaga chiqish shart
    // emas). Allaqachon ro'yxatda yoki joriy faol buyurtma bo'lsa — takrorlamaymiz.
    if (order.id.isEmpty ||
        state.globalOrders.any((o) => o.id == order.id) ||
        state.currentOrder?.id == order.id) {
      return;
    }
    final updated = <OrderModel>[order, ...state.globalOrders];
    emit(state.copyWith(globalOrders: updated));
    // Ogohlantirish (ovoz + background banner). accepted/canceled'dan farqli —
    // bu yangi, olинadigan buyurtma. Foreground'da faqat ovoz + ro'yxat/badge.
    NotificationService().showGlobalOrderNotification();
    AppLogger.order(
      'GLOBAL buyurtma ro\'yxatga qo\'shildi: #${order.id} '
      '(jami: ${updated.length})',
    );
    // To'liq ma'lumotni orqa fonda tortib, kartani boyitamiz.
    // ignore: discarded_futures
    _enrichGlobalOrder(order.id);
  }

  /// Global buyurtmaning to'liq ma'lumotini (manzil, masofa) REST orqali
  /// tortib, ro'yxatdagi yengil nusxani almashtiradi.
  Future<void> _enrichGlobalOrder(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      final full = await sl<OrderService>().getOrder(orderId);
      final idx = state.globalOrders.indexWhere((o) => o.id == orderId);
      if (idx == -1) return; // oraliqda olib tashlangan
      final updated = List<OrderModel>.of(state.globalOrders);
      updated[idx] = full;
      emit(state.copyWith(globalOrders: updated));
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ global order to\'ldirish xato (#$orderId): $e');
    }
  }

  /// Global ro'yxatdan buyurtmani JIM olib tashlaydi (accepted/canceled).
  void _removeGlobalOrder(String? orderId) {
    if (orderId == null || orderId.isEmpty || state.globalOrders.isEmpty) {
      return;
    }
    final updated = state.globalOrders.where((o) => o.id != orderId).toList();
    if (updated.length != state.globalOrders.length) {
      emit(state.copyWith(globalOrders: updated));
      AppLogger.info(
        'Global ro\'yxatdan olindi: #$orderId '
        '(qoldi: ${updated.length})',
      );
    }
  }

  /// "Global buyurtmalar" oynasidan buyurtmani olish. Oddiy `acceptOrder`
  /// oqimini qayta ishlatamiz: buyurtmani currentOrder qilib qo'yib, accept
  /// yuboramiz. Backend boshqalarga `GLOBAL_ORDER_ACCEPTED` tarqatadi —
  /// ularning ro'yxatidan o'chiriladi.
  Future<void> acceptGlobalOrder(OrderModel order) async {
    if (_driverId == null) return;
    if (order.id.isEmpty) {
      emit(state.copyWith(error: 'Buyurtma raqami yo\'q.'));
      return;
    }
    // Allaqachon shu buyurtma faol yoki navbatda bo'lsa — takror olmaymiz.
    if (state.currentOrder?.id == order.id ||
        state.queuedOrders.any((o) => o.id == order.id)) {
      return;
    }
    // Maksimal 2 ta faol buyurtma. To'lgan bo'lsa — yangisini olmaymiz.
    if (_activeOrderCount >= 2) {
      emit(
        state.copyWith(
          error: 'Sizda 2 ta faol buyurtma bor. Avval birini yakunlang.',
        ),
      );
      return;
    }

    // Allaqachon bitta faol safar bor — yangisini NAVBATGA olamiz (xaritadagi
    // joriy safar buzilmaydi). Aks holda — to'g'ridan-to'g'ri faol safar.
    final hasCurrent =
        state.currentOrder != null && state.status != OrderStatus.initial;
    if (hasCurrent) {
      await _acceptToQueue(order);
      return;
    }

    // Liniyaga chiqish (online) SHART EMAS — global buyurtmani offline ham
    // olish mumkin. Muvaffaqiyatli olingach haydovchi avtomatik liniyaga
    // chiqariladi (pastda).
    final wasOnline = state.isOnline;
    // Ro'yxatdan darhol olib, currentOrder qilib qo'yamiz (acceptOrder uni
    // o'qiydi). Status'ni `orderReceived` QILMAYMIZ — aks holda asosiy oynada
    // shaxsiy bottom-sheet miltillab ochilib-yopilardi; acceptOrder
    // muvaffaqiyatda to'g'ridan-to'g'ri goingToClient'ga o'tadi.
    final remaining = state.globalOrders
        .where((o) => o.id != order.id)
        .toList();
    emit(state.copyWith(currentOrder: order, globalOrders: remaining));
    await acceptOrder();

    // Offline holatda global buyurtma olingan bo'lsa — endi faol safar bor,
    // shuning uchun haydovchini liniyaga chiqaramiz (lokatsiya push + Mercure).
    if (!wasOnline &&
        state.currentOrder?.id == order.id &&
        state.status != OrderStatus.initial) {
      emit(state.copyWith(isOnline: true));
      _connectMercure();
      _startLocationPush();
    }
  }

  /// Hozir faol (xaritadagi + navbatdagi) buyurtmalar soni. Maksimal 2.
  int get _activeOrderCount {
    final hasCurrent =
        state.currentOrder != null && state.status != OrderStatus.initial;
    return (hasCurrent ? 1 : 0) + state.queuedOrders.length;
  }

  /// Ikkinchi (navbatdagi) buyurtmani backendda qabul qilib, navbatga qo'shadi.
  /// Joriy xaritadagi safar buzilmaydi. Muvaffaqiyatsiz bo'lsa (allaqachon
  /// olingan) — global ro'yxatda qoladi va xato ko'rsatiladi.
  Future<void> _acceptToQueue(OrderModel order) async {
    final driverId = _driverId;
    if (driverId == null) return;
    try {
      await sl<OrderService>()
          .accept(orderId: order.id, driverId: driverId)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      AppLogger.error('Navbatga olish XATO (#${order.id}): $e');
      emit(
        state.copyWith(
          error: 'Ikkinchi buyurtmani olib bo\'lmadi — u allaqachon olingan.',
        ),
      );
      return;
    }
    // Navbatga DARHOL qo'shamiz (yengil nusxa bilan) — ro'yxat tez yangilanadi.
    // To'liq ma'lumotni (manzil, narx) order id orqali ORQA FONDA tortamiz.
    final queued = List<OrderModel>.of(state.queuedOrders)..add(order);
    final remaining = state.globalOrders
        .where((o) => o.id != order.id)
        .toList();
    emit(state.copyWith(queuedOrders: queued, globalOrders: remaining));
    AppLogger.success(
      'Navbatga olindi: #${order.id} (navbatda: ${queued.length})',
    );
    _persistActiveTrip();
    // ignore: discarded_futures
    _enrichQueuedOrder(order.id);
  }

  /// Navbatdagi buyurtmaning to'liq ma'lumotini (manzil, masofa) order id
  /// orqali REST'dan tortib, navbatdagi yengil nusxani almashtiradi.
  Future<void> _enrichQueuedOrder(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      final full = await sl<OrderService>().getOrder(orderId);
      final idx = state.queuedOrders.indexWhere((o) => o.id == orderId);
      if (idx == -1) return; // oraliqda faollashtirilgan yoki olib tashlangan
      final updated = List<OrderModel>.of(state.queuedOrders);
      updated[idx] = full;
      emit(state.copyWith(queuedOrders: updated));
      _persistActiveTrip();
      AppLogger.info('Navbatdagi buyurtma to\'ldirildi: #$orderId');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ navbatdagi buyurtma to\'ldirish xato (#$orderId): $e');
    }
  }

  /// Joriy safar yakunlangach (complete/cancel) navbatdagi keyingi buyurtmani
  /// xaritadagi faol safarga ko'taradi. Navbat bo'sh bo'lsa — hech narsa.
  void _promoteNextQueuedOrder() {
    if (state.queuedOrders.isEmpty) return;
    final next = state.queuedOrders.first;
    final rest = state.queuedOrders.skip(1).toList();
    if (next.id.isEmpty) {
      emit(state.copyWith(queuedOrders: rest));
      return;
    }

    if (_orderTypes.isEmpty) {
      // ignore: discarded_futures
      _loadOrderTypes();
    }
    _activeTariff = _resolveTariff(next);
    _accumulatedWaitingSeconds = 0;
    _waitingStartedAt = null;
    _tripDistanceKm = 0;
    _lastDistancePoint = state.currentLocation;
    _lastMapEmit = null;

    emit(
      state.copyWith(
        status: OrderStatus.goingToClient,
        currentOrder: next,
        queuedOrders: rest,
        destinationLocation: next.destinationLocation,
        clientPickedUp: false,
        traveledDistance: 0,
        waitingSeconds: 0,
        currentPrice: _computePrice(next.distance, 0),
        tripSeconds: 0,
        isWaitingTimerActive: false,
        isOnline: true,
      ),
    );
    AppLogger.order(
      'Navbatdagi buyurtma faollashtirildi: #${next.id} '
      '(navbatda qoldi: ${rest.length})',
    );
    _persistActiveTrip();
    // To'liq/yangi ma'lumotni order id orqali ORQA FONDA tortamiz, so'ng
    // marshrutni chizamiz. Tortib bo'lmasa — mavjud ma'lumot bilan davom etadi.
    // ignore: discarded_futures
    _activatePromotedOrder(next.id);
  }

  /// Navbatdan ko'tarilgan buyurtmaning eng so'nggi ma'lumotini order id orqali
  /// tortib (manzil, masofa, narx) joriy buyurtmani yangilaydi, keyin mijozga
  /// boradigan marshrutni so'raydi.
  Future<void> _activatePromotedOrder(String orderId) async {
    if (orderId.isNotEmpty) {
      try {
        final full = await sl<OrderService>().getOrder(orderId);
        if (state.currentOrder?.id == orderId) {
          emit(
            state.copyWith(
              currentOrder: full,
              destinationLocation: full.destinationLocation,
              currentPrice: _computePrice(
                full.distance,
                _currentWaitingSeconds,
              ),
            ),
          );
          _persistActiveTrip();
        }
      } catch (e) {
        AppLogger.error('Faollashtirilgan buyurtma datasi (#$orderId): $e');
      }
    }
    await _requestRouteToClient();
  }

  /// Buyurtma haydovchining tariflariga (aboutMe/_tariffs) mos keladimi.
  /// Faqat ANIQ mos kelmaganda `false` qaytaradi — buyurtma tarifi noma'lum
  /// yoki haydovchi tariflari hali yuklanmagan bo'lsa, ko'rsatamiz (Mercure
  /// filtri bilan bir xil mantiq). Masalan: haydovchida "comfort" tarifi
  /// yo'q bo'lsa, "comfort" buyurtmalar global ro'yxatda KO'RINMAYDI.
  bool _matchesDriverTariff(OrderModel order) {
    if (_tariffs.isEmpty) return true;
    final orderTariff = (order.tariff ?? '').toLowerCase().trim();
    if (orderTariff.isEmpty) return true;
    final active = _tariffs.map((e) => e.toLowerCase().trim()).toSet();
    return active.contains(orderTariff);
  }

  /// Global (hali hech kim olmagan, status=new) buyurtmalarni REST orqali
  /// tortib, mavjud ro'yxat bilan id bo'yicha BIRLASHTIRADI. Mercure real-vaqt
  /// + REST bir xil buyurtmani IKKI marta ko'rsatmasligi uchun dedup qilinadi.
  /// App ochilganda va "Global" bo'limida pull-to-refresh bosilganda chaqiriladi.
  /// Liniyaga chiqish (online) SHART EMAS — global buyurtmalar offline ham
  /// ko'rinadi.
  Future<void> loadGlobalOrders() async {
    if (_driverId == null) {
      await _loadDriverSession();
      if (_driverId == null) return;
    }
    List<OrderModel> remote;
    try {
      remote = await sl<OrderService>().fetchGlobalOrders().timeout(
        const Duration(seconds: 12),
      );
    } catch (e) {
      // ignore: avoid_print
      print('\u26a0\ufe0f global buyurtmalar (REST): $e');
      return;
    }

    // id bo'yicha birlashtiramiz: mavjud (ehtimol Mercure orqali boyitilgan)
    // nusxalar ustuvor, so'ng REST'dan YANGILARINI qo'shamiz (takror emas).
    final byId = <String, OrderModel>{};
    for (final o in state.globalOrders) {
      if (o.id.isNotEmpty) byId[o.id] = o;
    }
    for (final o in remote) {
      if (o.id.isEmpty) continue;
      if (state.currentOrder?.id == o.id) continue; // o'zimning faol buyurtmam
      if (!_matchesDriverTariff(o)) continue; // tarif mos emas — ko'rsatmaymiz
      byId.putIfAbsent(o.id, () => o);
    }
    // Birlashma faqat o'sadi yoki o'zgarmaydi (union). Yangi id qo'shilmagan
    // bo'lsa — ortiqcha rebuild qilmaymiz.
    if (byId.length == state.globalOrders.length) return;
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(globalOrders: merged));
    AppLogger.order(
      'Global buyurtmalar REST orqali yangilandi: ${merged.length} ta',
    );
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
      // 403 = backend "Siz boshqa qurilmada onlinesiz" deydi. Bir vaqtning
      // o'zida faqat BITTA qurilma online bo'la oladi (birinchi ulangani).
      // Bu qurilmani offline'ga o'tkazib, haydovchini ogohlantiramiz.
      if (e is DioException && e.response?.statusCode == 403) {
        AppLogger.warn('Location push 403 — boshqa qurilmada online');
        _onAnotherDeviceOnline();
        return;
      }
      // ignore: avoid_print
      print('⚠️ location push xato: $e');
    }
  }

  /// Backend 403 qaytardi: haydovchi BOSHQA qurilmada allaqachon online.
  /// Bir vaqtda faqat bitta qurilma ishlaydi (birinchi online bo'lgani).
  /// Bu qurilmada online bo'lib bo'lmaydi — to'liq offline'ga o'tamiz va
  /// bir martalik xabar ko'rsatamiz (push to'xtatilgani uchun takror chiqmaydi).
  void _onAnotherDeviceOnline() {
    _disconnectMercure();
    _stopLocationPush();
    _waitingTimer?.cancel();
    _waitingTimer = null;
    _tripTimer?.cancel();
    _tripTimer = null;
    _activeTariff = null;
    _tripDistanceKm = 0;
    _lastDistancePoint = null;
    _lastMapEmit = null;
    _accumulatedWaitingSeconds = 0;
    _waitingStartedAt = null;
    StorageHelper.remove(_activeTripKey);
    // Toza offline holat + xato xabari (home_page listener bir marta ko'rsatadi).
    emit(
      HomeState(
        status: OrderStatus.initial,
        currentLocation: state.currentLocation,
        heading: state.heading,
        isOnline: false,
        isTimeoutEnabled: state.isTimeoutEnabled,
        error:
            'Siz boshqa qurilmada online holatdasiz. Bu qurilmada ishlash '
            'uchun avval o\'sha qurilmadan chiqing.',
      ),
    );
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
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 8));
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
    final newLocation = Point(
      latitude: position.latitude,
      longitude: position.longitude,
    );

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
        emit(
          state.copyWith(
            currentLocation: newLocation,
            heading: heading,
            distanceToClient: 0,
            status: OrderStatus.waitingForClient,
          ),
        );
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

    emit(
      state.copyWith(
        currentLocation: newLocation,
        heading: heading,
        traveledDistance: state.status == OrderStatus.inProgress
            ? _tripDistanceKm
            : state.traveledDistance,
        currentPrice: state.status == OrderStatus.inProgress
            ? _computePrice(_tripDistanceKm, state.waitingSeconds)
            : state.currentPrice,
        distanceToClient: distanceToClient,
      ),
    );
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
      AppLogger.error(
        'ACCEPT BEKOR: orderId BO\'SH — Mercure xabarida '
        'orderId kelmagan. Backend payload\'ga orderId qo\'shishi kerak.',
      );
      _resetOrderState();
      emit(
        state.copyWith(
          error:
              'Buyurtma raqami (orderId) kelmadi. Backend Mercure xabariga '
              'orderId qo\'shishi kerak.',
        ),
      );
      return;
    }

    AppLogger.info(
      'URL      = ${AppConstants.baseUrl}orders/$orderId/'
      '$_driverId/accept',
    );

    // Accept davom etmoqda — Mercure "accepted" xabari (shu haydovchining o'z
    // qabuli ham) currentOrder'ni reset qilib qo'ymasin.
    _isAccepting = true;
    try {
      try {
        await sl<OrderService>()
            .accept(orderId: orderId, driverId: _driverId!)
            .timeout(const Duration(seconds: 12));
        AppLogger.success(
          'ACCEPT muvaffaqiyatli (orderId=$orderId, '
          'driverId=$_driverId)',
        );
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
        emit(
          state.copyWith(
            error:
                'Buyurtmani qabul qilib bo\'lmadi — u allaqachon olingan '
                'yoki mavjud emas.',
          ),
        );
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
      emit(
        state.copyWith(
          status: OrderStatus.goingToClient,
          currentOrder: acceptedOrder,
          // Taxminiy narx allaqachon trip km ni o'z ichiga oladi (base + km).
          currentPrice: _computePrice(acceptedOrder.distance, 0),
          traveledDistance: 0,
          waitingSeconds: 0,
          isWaitingTimerActive: false,
        ),
      );

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
    final current = state.currentOrder;
    final bool shouldCancel =
        current != null &&
        (state.status == OrderStatus.orderAccepted ||
            state.status == OrderStatus.goingToClient ||
            state.status == OrderStatus.waitingForClient);

    // UI ni DARHOL bo'shatamiz va navbatda buyurtma bo'lsa — uni avtomatik
    // faol safarga ko'taramiz. Backend (cancel) javobini KUTMAYMIZ: sekin
    // internetda "Bekor qilish" bosilgach ekran qotmasin.
    _resetOrderState();
    _promoteNextQueuedOrder();

    // Bekor qilishni orqa fonda yuboramiz (faqat haqiqatan qabul qilingan
    // buyurtma uchun — shaxsiy taklif/orderReceived'da backendga so'rov yo'q).
    if (shouldCancel) {
      // ignore: discarded_futures
      sl<OrderService>().cancelByDriver(current.id).catchError((e) {
        // ignore: avoid_print
        print('⚠️ cancel: $e');
        return <String, dynamic>{};
      });
    }
  }

  /// Qo'lda "Yetib keldim". GPS avto-o'tish (mijozdan 50 m) ishlamasa
  /// (mas. sinovda yoki signal sust bo'lsa), haydovchi shu tugma orqali
  /// `goingToClient` → `waitingForClient` bosqichiga o'tadi va kutish
  /// hisoblagichi boshlanadi. Ekran shu tariqa "qotib" qolmaydi.
  void arrivedAtClient() {
    if (state.status != OrderStatus.goingToClient) return;
    _lastMapEmit = null; // keyingi yangilanish darhol ko'rinsin
    emit(
      state.copyWith(status: OrderStatus.waitingForClient, distanceToClient: 0),
    );
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

    emit(
      state.copyWith(
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
      ),
    );

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
    // Navbatda buyurtma bo'lsa — uni avtomatik faol safarga ko'taramiz.
    _promoteNextQueuedOrder();

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
    emit(
      HomeState(
        status: OrderStatus.initial,
        currentLocation: state.currentLocation,
        heading: state.heading,
        isOnline: state.isOnline,
        isTimeoutEnabled: state.isTimeoutEnabled,
        // Global ro'yxat buyurtma yakunlangach ham saqlanadi (yangi safar
        // tugagandan keyin haydovchi yana global buyurtma olishi mumkin).
        globalOrders: state.globalOrders,
        // Navbatdagi (2-chi) buyurtma ham saqlanadi — joriy safar tugagach
        // `_promoteNextQueuedOrder` uni faol safarga ko'taradi.
        queuedOrders: state.queuedOrders,
      ),
    );
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
    final hasActiveTrip =
        state.status == OrderStatus.orderAccepted ||
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
      final routeData = await MapboxRouteService.getRoute(
        from,
        to,
        mode: 'driving',
      ).timeout(const Duration(seconds: 12));
      if (routeData['points'] != null &&
          (routeData['points'] as List).isNotEmpty) {
        emit(
          state.copyWith(
            routeGeometry: routeData['points'],
            currentRouteIndex: 0,
            routeDurationMinutes: routeData['durationMinutes'],
            routeDistanceKm: routeData['distanceKm'],
          ),
        );
        return;
      }
    } catch (_) {}

    try {
      final geom = await YandexRouteDrawer.getRoute(
        from,
        to,
        mode: 'driving',
      ).timeout(const Duration(seconds: 12));
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
    emit(
      state.copyWith(
        isWaitingTimerActive: true,
        waitingSeconds: _currentWaitingSeconds,
      ),
    );

    // Har 10 soniyada FAQAT ekranni yangilaymiz — vaqtning o'zi wall-clock'dan
    // o'lchanadi (qotmaslik uchun emit kam, lekin hisob aniq).
    _waitingTimer = Timer.periodic(
      const Duration(seconds: _updateIntervalSec),
      (timer) {
        // Kutish hisoblagichi faqat mijozni kutish bosqichida yoki safar ichida
        // qo'lda yoqilgan bo'lsa ishlaydi. Aks holda to'xtaydi.
        final canRun =
            state.status == OrderStatus.waitingForClient ||
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
          emit(
            state.copyWith(
              waitingSeconds: secs,
              currentPrice: _computePrice(_plannedDistanceKm, secs),
            ),
          );
        } else {
          emit(
            state.copyWith(
              waitingSeconds: secs,
              currentPrice: _computePrice(_tripDistanceKm, secs),
            ),
          );
        }
      },
    );
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
    // Faol segmentni yakunlab, ANIQ o'tgan vaqtni umumiy yig'indiga qo'shamiz.
    if (_waitingStartedAt != null) {
      _accumulatedWaitingSeconds += DateTime.now()
          .difference(_waitingStartedAt!)
          .inSeconds;
      _waitingStartedAt = null;
    }
    emit(
      state.copyWith(
        isWaitingTimerActive: false,
        waitingSeconds: _accumulatedWaitingSeconds,
      ),
    );
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
    // ham). GPS yurmasa ham soat shu yerda yuradi. Vaqt `tripStartTime`'dan
    // HAQIQIY o'tgan vaqt sifatida hisoblanadi — Timer kechiksa ham
    // (telefon band bo'lsa) sekundlar surilib/ortda qolib ketmaydi.
    _tripTimer = Timer.periodic(const Duration(seconds: _updateIntervalSec), (
      timer,
    ) {
      if (state.status != OrderStatus.inProgress) {
        timer.cancel();
        return;
      }
      final start = state.tripStartTime;
      final secs = start != null
          ? DateTime.now().difference(start).inSeconds
          : state.tripSeconds + _updateIntervalSec;
      emit(
        state.copyWith(
          tripSeconds: secs < 0 ? 0 : secs,
          currentPrice: _computePrice(_tripDistanceKm, state.waitingSeconds),
        ),
      );
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
      final raw = await StorageHelper.getString('completed_orders') ?? '[]';
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
    final isActive =
        order != null &&
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
      // Navbatdagi (2-chi) buyurtma(lar) ham saqlanadi.
      'queued': state.queuedOrders.map((o) => o.toJson()).toList(),
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
      raw = null;
    }
    // Lokal snapshot yo'q (boshqa qurilma yoki APK qayta o'rnatilgan) — faol
    // buyurtmani backenddan tiklashga urinamiz.
    if (raw == null || raw.isEmpty) {
      await _restoreActiveTripFromBackend();
      return;
    }

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
    final tripStartTime = DateTime.tryParse(
      (snap['tripStartTime'] ?? '').toString(),
    );

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

    // Navbatdagi (2-chi) buyurtmalarni tiklaymiz.
    List<OrderModel> queued = const [];
    final ql = snap['queued'];
    if (ql is List) {
      queued = ql
          .whereType<Map>()
          .map((m) => OrderModel.fromJson(m.cast<String, dynamic>()))
          .where((o) => o.id.isNotEmpty)
          .toList();
    }

    emit(
      state.copyWith(
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
        queuedOrders: queued,
      ),
    );

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

  /// Lokal snapshot bo'lmaganda backenddan faol (accepted) buyurtmani tiklaydi:
  /// `GET /api/orders/driver/{id}/active` (maks 2 ta). Eng so'nggi faol
  /// buyurtmani asosiy oynaga va "Faol" bo'limiga qaytaramiz — shunda haydovchi
  /// boshqa qurilmada qabul qilgan yoki APK qayta o'rnatilgan bo'lsa ham
  /// safarini davom ettira oladi. (App bitta faol safarni qo'llab-quvvatlaydi,
  /// shuning uchun eng yangisini olamiz.)
  Future<void> _restoreActiveTripFromBackend() async {
    final driverId = _driverId;
    if (driverId == null) return;
    // Allaqachon faol buyurtma bo'lsa — ustidan yozmaymiz.
    if (state.currentOrder != null && state.status != OrderStatus.initial) {
      return;
    }

    List<OrderModel> active;
    try {
      active = await sl<OrderService>()
          .fetchActiveOrders(driverId)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ faol buyurtmalar (backend tiklash): $e');
      return;
    }
    if (active.isEmpty) return;

    // Eng so'nggi (yangi) faol buyurtmani XARITADAGI safar qilamiz, qolganini
    // (maks 1 ta) NAVBATGA qo'yamiz — haydovchi 2 tagacha faol buyurtma
    // tutishi mumkin.
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final order = active.first;
    if (order.id.isEmpty) return;
    final restQueued = active.skip(1).where((o) => o.id.isNotEmpty).toList();

    // Tarifni aniqlaymiz (narx hisobi uchun).
    if (_orderTypes.isEmpty) await _loadOrderTypes();
    _activeTariff = _resolveTariff(order);

    // Buyurtma holatiga qarab app bosqichini tanlaymiz:
    //  on_the_way / arrive -> safar (inProgress), aks holda mijoz oldiga.
    final isOnTrip =
        order.status == OrderStatusType.onTheWay ||
        order.status == OrderStatusType.arrive;
    final restoredStatus = isOnTrip
        ? OrderStatus.inProgress
        : OrderStatus.goingToClient;

    _accumulatedWaitingSeconds = 0;
    _waitingStartedAt = null;
    _tripDistanceKm = 0;
    _lastDistancePoint = state.currentLocation;
    _lastMapEmit = null;
    final tripStart = isOnTrip ? DateTime.now() : null;

    emit(
      state.copyWith(
        status: restoredStatus,
        currentOrder: order,
        destinationLocation: order.destinationLocation,
        clientPickedUp: isOnTrip,
        traveledDistance: 0,
        waitingSeconds: 0,
        currentPrice: _computePrice(order.distance, 0),
        tripStartTime: tripStart,
        tripSeconds: 0,
        isOnline: true,
        queuedOrders: restQueued,
      ),
    );

    AppLogger.success(
      'Backenddan faol buyurtma tiklandi: #${order.id} '
      '(holat=${order.status.value} -> ${restoredStatus.name})',
    );

    // Online rejim: Mercure + 10s location push (push 403 bersa
    // _onAnotherDeviceOnline avtomatik offline'ga o'tkazadi).
    _connectMercure();
    _startLocationPush();
    _persistActiveTrip();

    if (isOnTrip) {
      _startTripTimer();
    } else {
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
