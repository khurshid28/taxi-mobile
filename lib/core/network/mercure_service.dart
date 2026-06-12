import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:mercure_client/mercure_client.dart' as mc;

import '../constants/app_constants.dart';
import '../models/order_model.dart';

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

enum MercureEventType { newOrder, accepted, canceled, unknown }

/// Real-time ulanish holati (UI banner uchun).
enum MercureStatus { connecting, connected, disconnected }

class MercureService {
  MercureService._internal();
  static final MercureService _instance = MercureService._internal();
  factory MercureService() => _instance;

  mc.Mercure? _mercure;
  StreamSubscription<mc.MercureEvent>? _subscription;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    try {
      final dynamic decoded = jsonDecode(rawData);
      final Map<String, dynamic> data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};

      // Topic ko'pincha payload ichida bo'lmaydi - turini taxmin qilamiz
      final action = (data['action'] ?? data['type'] ?? data['event'] ?? '')
          .toString()
          .toLowerCase();

      if (action.contains('cancel')) {
        _eventsCtrl.add(MercureEvent(
          type: MercureEventType.canceled,
          orderId: (data['id'] ?? data['orderId'])?.toString(),
          raw: data,
        ));
        return;
      }

      if (action.contains('accept')) {
        _eventsCtrl.add(MercureEvent(
          type: MercureEventType.accepted,
          orderId: (data['id'] ?? data['orderId'])?.toString(),
          raw: data,
        ));
        return;
      }

      // Default: yangi buyurtma
      final order = OrderModel.fromJson(data);

      // Tarif filter
      final incomingTariff =
          (data['tariff'] ?? order.tariff ?? '').toString().toLowerCase();
      if (_activeTariffs.isNotEmpty &&
          incomingTariff.isNotEmpty &&
          !_activeTariffs.contains(incomingTariff)) {
        // ignore: avoid_print
        print('⏭️ Tarif mos kelmadi: $incomingTariff vs $_activeTariffs');
        return;
      }

      _playOrderSound();
      _eventsCtrl.add(MercureEvent(
        type: MercureEventType.newOrder,
        order: order,
        orderId: order.id,
        raw: data,
      ));
    } catch (e) {
      // ignore: avoid_print
      print('🔴 Mercure decode error: $e | raw=$rawData');
      _eventsCtrl.add(MercureEvent(
        type: MercureEventType.unknown,
        raw: const {},
      ));
    }
  }

  Future<void> _playOrderSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/new_order.mp3'));
    } catch (_) {}
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
