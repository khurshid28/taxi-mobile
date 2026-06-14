import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mercure_client/mercure_client.dart' as mc;

import '../constants/app_constants.dart';
import '../models/order_model.dart';
import '../utils/app_logger.dart';

/// Backend tomondan PHP `Update()` orqali yuboriladigan to'rt asosiy topic:
///  * `driver/{driverId}/orders`            - shaxsiy
///  * `company/{companyId}/orders/global`    - kompaniya bo'yicha barcha yangi
///  * `company/{companyId}/orders/accepted`  - boshqa kim qabul qilgani
///  * `company/{companyId}/orders/canceled`  - bekor qilingan
class MercureEvent {
  final MercureEventType type;
  final OrderModel? order;
  final String? orderId;
  final Map<String, dynamic> raw;

  const MercureEvent({
    required this.type,
    required this.raw,
    this.order,
    this.orderId,
  });
}

enum MercureEventType { newOrder, globalNewOrder, accepted, canceled, unknown }

/// Real-time ulanish holati (UI banner uchun).
enum MercureStatus { connecting, connected, disconnected }

class MercureService {
  MercureService._internal();
  static final MercureService _instance = MercureService._internal();
  factory MercureService() => _instance;

  mc.Mercure? _mercure;
  StreamSubscription<mc.MercureEvent>? _subscription;

  final StreamController<MercureEvent> _eventsCtrl =
      StreamController<MercureEvent>.broadcast();
  Stream<MercureEvent> get events => _eventsCtrl.stream;

  bool isConnected = false;

  /// UI shu holatni kuzatib, ulanish uzilsa banner ko'rsatadi.
  final ValueNotifier<MercureStatus> status =
      ValueNotifier<MercureStatus>(MercureStatus.disconnected);

  List<String> _activeTariffs = const [];

  // Qayta ulanish uchun saqlanadigan parametrlar.
  int? _driverId;
  int? _companyId;
  String? _jwtToken;
  bool _shouldConnect = false;
  Timer? _reconnectTimer;
  Timer? _connectedProbe;
  int _retryAttempt = 0;

  /// Hub'ga ulanish. Haydovchi online bo'lganda chaqiriladi. Shundan keyin
  /// ulanish uzilsa (tarmoq almashishi, SSE timeout, server qayta yuklanishi)
  /// avtomatik qayta ulanadi — haydovchi `driver/{id}/orders` kanalini DOIM
  /// eshitib turadi va yangi buyurtmani o'tkazib yubormaydi.
  void connect({
    required int driverId,
    required int companyId,
    required List<String> activeTariffs,
    String? jwtToken,
  }) {
    _driverId = driverId;
    _companyId = companyId;
    _jwtToken = jwtToken;
    _activeTariffs = activeTariffs.map((e) => e.toLowerCase()).toList();
    _shouldConnect = true;
    _retryAttempt = 0;
    _open();
  }

  void _open() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _connectedProbe?.cancel();

    final driverId = _driverId;
    final companyId = _companyId;
    if (driverId == null || companyId == null) return;

    status.value = MercureStatus.connecting;

    final topics = <String>[
      'driver/$driverId/orders',
      'company/$companyId/orders/global',
      'company/$companyId/orders/accepted',
      'company/$companyId/orders/canceled',
    ];

    try {
      _mercure = mc.Mercure(
        url: AppConstants.mercureUrl,
        topics: topics,
        token: _jwtToken,
      );

      _subscription = _mercure!.listen(
        (event) {
          isConnected = true;
          _retryAttempt = 0; // muvaffaqiyatli ulandik — hisobni nolga
          _connectedProbe?.cancel();
          status.value = MercureStatus.connected;
          _processMessage(event.data, event.id);
        },
        onError: (error) {
          isConnected = false;
          // ignore: avoid_print
          print('🔴 Mercure error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          isConnected = false;
          // ignore: avoid_print
          print('🔌 Mercure ulanishi yopildi (onDone)');
          _scheduleReconnect();
        },
      );
      // Xato tez keladi; agar ~1.2s ichida xato bo'lmasa — ulandik deb hisoblaymiz
      // (Mercure bo'sh paytda hech qanday event yubormasligi mumkin).
      _connectedProbe = Timer(const Duration(milliseconds: 1200), () {
        if (_shouldConnect && status.value == MercureStatus.connecting) {
          status.value = MercureStatus.connected;
        }
      });
      // ignore: avoid_print
      print('🟢 Mercure subscribed: $topics');
    } catch (e) {
      // ignore: avoid_print
      print('🔴 Mercure connect failed: $e');
      _scheduleReconnect();
    }
  }

  /// Ulanish uzilsa va biz hali online bo'lsak — qayta ulanamiz.
  /// Kechikish bosqichma-bosqich oshadi (3s, 6s, 9s ... maks 30s).
  void _scheduleReconnect() {
    _connectedProbe?.cancel();
    if (!_shouldConnect) return; // ataylab offline bo'ldik — ulanmaymiz
    status.value = MercureStatus.disconnected;
    _reconnectTimer?.cancel();
    _retryAttempt++;
    final delaySec = (3 * _retryAttempt).clamp(3, 30);
    // ignore: avoid_print
    print('🔄 Mercure qayta ulanish ${delaySec}s dan keyin '
        '(urinish #$_retryAttempt)');
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (_shouldConnect) _open();
    });
  }

  void _processMessage(String rawData, String? eventId) {
    // Hub'dan kelgan HAR QANDAY xabarni to'liq logga chiqaramiz — bu real
    // buyurtma kelganda nima sodir bo'layotganini ko'rish uchun eng muhim joy.
    AppLogger.header('MERCURE XABAR KELDI');
    AppLogger.mercure('event.id = $eventId');
    AppLogger.mercure('raw      = $rawData');
    try {
      final dynamic decoded = jsonDecode(rawData);
      final Map<String, dynamic> data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};

      // Backend payload: {type, orderId, tariff, message}. Turi (type) bo'yicha
      // yangi / qabul / bekor ekanini ajratamiz.
      final action = (data['action'] ?? data['type'] ?? data['event'] ?? '')
          .toString()
          .toLowerCase();
      // orderId turli nomlarda kelishi mumkin. Hammasini tekshiramiz.
      final nestedOrder = data['order'] is Map
          ? (data['order'] as Map)
          : (data['data'] is Map ? data['data'] as Map : null);
      final orderId = (data['orderId'] ??
              data['order_id'] ??
              data['orderID'] ??
              data['id'] ??
              data['@id'] ??
              nestedOrder?['orderId'] ??
              nestedOrder?['id'] ??
              '')
          .toString();

      // orderId ni qaysi maydondan olganimizni aniq ko'rsatamiz.
      AppLogger.info('action        = "$action"');
      AppLogger.info('orderId (xom) = "$orderId"  '
          '[orderId=${data['orderId']}, id=${data['id']}, @id=${data['@id']}]');

      if (action.contains('cancel')) {
        AppLogger.warn('Buyurtma BEKOR qilindi (orderId=$orderId)');
        _eventsCtrl.add(MercureEvent(
          type: MercureEventType.canceled,
          orderId: orderId.isNotEmpty ? orderId : null,
          raw: data,
        ));
        return;
      }

      if (action.contains('accept')) {
        AppLogger.success('Buyurtmani boshqa haydovchi QABUL qildi '
            '(orderId=$orderId)');
        _eventsCtrl.add(MercureEvent(
          type: MercureEventType.accepted,
          orderId: orderId.isNotEmpty ? orderId : null,
          raw: data,
        ));
        return;
      }

      // ===== Yangi buyurtma =====
      // Backend yangi buyurtmani turli "type" bilan yuborishi mumkin: "new",
      // "NEW_ORDER", "global", "GLOBAL_ORDER"... — hammasi shu yerga tushadi
      // (accept/cancel yuqorida qaytarilgan). Hammasini "Global buyurtmalar"
      // ro'yxatiga uzatamiz: istalgan online haydovchi qabul qiladi (birinchi
      // olgan yutadi). Foydalanuvchi talabi: "new" ham GLOBAL deb ko'rsatilsin.
      final incomingTariffs = _extractTariffs(data['tariff']);

      // Tarif filtri: haydovchi o'z tariflariga mos buyurtmalarni ko'radi.
      // Faqat ANIQ mos kelmaganda o'tkazib yuboramiz — tarif noma'lum/bo'sh
      // bo'lsa yoki haydovchi tariflari hali yuklanmagan bo'lsa, ko'rsatamiz
      // (adashib tushirib qoldirmaslik uchun).
      if (_activeTariffs.isNotEmpty &&
          incomingTariffs.isNotEmpty &&
          !incomingTariffs.any(_activeTariffs.contains)) {
        AppLogger.warn('Tarif mos kelmadi: $incomingTariffs ∉ $_activeTariffs '
            '— buyurtma o\'tkazib yuborildi');
        return;
      }

      final order = OrderModel.fromJson(data);
      // orderId xom holatda va OrderModel parse qilgandan keyin — solishtirish
      // uchun ikkalasini ham ko'rsatamiz. Accept URL aynan shu id bilan ketadi.
      final finalId = orderId.isNotEmpty ? orderId : order.id;
      AppLogger.info('OrderModel.id = "${order.id}"  '
          '(tariflar=$incomingTariffs)');
      AppLogger.order('GLOBAL buyurtma #$finalId → ro\'yxatga uzatildi');
      // Ovoz NotificationService ichida bir marta chalinadi.
      _eventsCtrl.add(MercureEvent(
        type: MercureEventType.globalNewOrder,
        order: order,
        orderId: finalId,
        raw: data,
      ));
    } catch (e) {
      AppLogger.error('Mercure decode XATO: $e | raw=$rawData');
      _eventsCtrl.add(MercureEvent(
        type: MercureEventType.unknown,
        raw: const {},
      ));
    }
  }

  /// Payload'dagi tarif(lar)ni kichik harfli nomlar ro'yxatiga aylantiradi.
  /// Backend tarifni string ("Start"), ro'yxat (["Start","Comfort"]) yoki
  /// obyektlar ro'yxati ([{name:"Start"}]) ko'rinishida yuborishi mumkin —
  /// hammasini bir xil ko'rinishga keltiramiz. Noma'lum/bo'sh → [].
  List<String> _extractTariffs(dynamic raw) {
    if (raw == null) return const [];
    final out = <String>[];
    void add(dynamic v) {
      if (v == null) return;
      if (v is Map) {
        final n = v['name'] ?? v['title'] ?? v['tariff'] ?? v['id'];
        if (n != null) out.add(n.toString().toLowerCase().trim());
      } else {
        final s = v.toString().toLowerCase().trim();
        if (s.isNotEmpty) out.add(s);
      }
    }

    if (raw is List) {
      for (final e in raw) {
        add(e);
      }
    } else {
      add(raw);
    }
    return out.where((e) => e.isNotEmpty).toList();
  }

  void disconnect() {
    _shouldConnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectedProbe?.cancel();
    _connectedProbe = null;
    _subscription?.cancel();
    _subscription = null;
    _mercure = null;
    isConnected = false;
    status.value = MercureStatus.disconnected;
  }

  Future<void> dispose() async {
    disconnect();
    await _eventsCtrl.close();
  }
}
