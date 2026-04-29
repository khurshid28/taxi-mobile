import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
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
  List<String> _activeTariffs = const [];

  /// Hub'ga ulanish.
  void connect({
    required int driverId,
    required int companyId,
    required List<String> activeTariffs,
    String? jwtToken,
  }) {
    disconnect();
    _activeTariffs = activeTariffs.map((e) => e.toLowerCase()).toList();

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
        token: jwtToken,
      );

      _subscription = _mercure!.listen(
        (event) {
          isConnected = true;
          _processMessage(event.data, event.id);
        },
        onError: (error) {
          isConnected = false;
          // ignore: avoid_print
          print('🔴 Mercure error: $error');
        },
        onDone: () {
          isConnected = false;
        },
      );
      // ignore: avoid_print
      print('🟢 Mercure subscribed: $topics');
    } catch (e) {
      // ignore: avoid_print
      print('🔴 Mercure connect failed: $e');
    }
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
    _subscription?.cancel();
    _subscription = null;
    _mercure = null;
    isConnected = false;
  }

  Future<void> dispose() async {
    disconnect();
    await _eventsCtrl.close();
  }
}
