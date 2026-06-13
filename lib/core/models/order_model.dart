import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'order_type_model.dart';

class OrderModel {
  final String id;
  final String clientName;
  final String clientPhone;
  final Point pickupLocation;
  final Point destinationLocation;
  final String pickupAddress;
  final String destinationAddress;
  final double distance; // km
  final double price;
  final DateTime createdAt;
  final OrderStatusType status;
  final String? tariff;
  final int? orderTypeId;
  final OrderTypeModel? orderType;
  final int? driverId;

  OrderModel({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distance,
    required this.price,
    required this.createdAt,
    required this.status,
    this.tariff,
    this.orderTypeId,
    this.orderType,
    this.driverId,
  });

  /// Buyurtma vaqti O'zbekiston vaqtida (UTC+5). Backend vaqtni UTC'da
  /// (`...Z` / `+00:00`) qaytaradi — ekranda Toshkent vaqti ko'rinishi uchun
  /// UTC instantga 5 soat qo'shamiz (qurilma vaqt mintaqasidan qat'i nazar).
  DateTime get createdAtUz => createdAt.toUtc().add(const Duration(hours: 5));


  /// Mercure / REST javoblari uchun parser. Backend bir nechta
  /// nom variantlarini ishlatadi - imkon qadar moslashuvchan.
  ///
  /// Haqiqiy backend tuzilishi (API Platform / JSON-LD):
  /// ```json
  /// {
  ///   "id": 1,
  ///   "client": { "phone": "+998..." },
  ///   "startLocation": { "lat": .., "lng": .., "adress": ".." },
  ///   "endLocation":   { "lat": .., "lng": .., "adress": ".." },
  ///   "price": 0, "status": "new",
  ///   "orderType": { "@id": "/api/order_types/1", "name": "Start" }
  /// }
  /// ```
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    Point point(dynamic lat, dynamic lng) =>
        Point(latitude: toDouble(lat), longitude: toDouble(lng));

    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map<String, dynamic> ? v : null;

    // ID. JSON-LD `@id` to'liq IRI bo'lishi mumkin (`/api/orders/5`) - bunday
    // holatda oxirgi segment (raqamli id) olinadi. Aks holda accept URL
    // `orders//api/orders/5/.../accept` ko'rinishida buzilib 404 beradi.
    String parseId(dynamic raw) {
      final s = (raw ?? '').toString().trim();
      if (s.isEmpty || s == 'null') return '';
      if (s.contains('/')) return s.split('/').last;
      return s;
    }

    // Backend turli nomlar ishlatishi mumkin: orderId / order_id / orderID /
    // id / @id, yoki id nested `order`/`data` obyekti ichida. Hammasini
    // tekshiramiz - chunki accept URL aynan shu id bilan quriladi.
    final nestedOrder = asMap(json['order']) ?? asMap(json['data']);
    final id = parseId(json['id'] ??
        json['orderId'] ??
        json['order_id'] ??
        json['orderID'] ??
        json['@id'] ??
        nestedOrder?['id'] ??
        nestedOrder?['orderId'] ??
        nestedOrder?['@id']);

    // Mijoz (nested `client` obyekti yoki yassi maydonlar)
    final client = asMap(json['client']);
    final clientName = (client?['name'] ??
            client?['fullName'] ??
            json['clientName'] ??
            json['userName'] ??
            'Mijoz')
        .toString();
    final clientPhone = (client?['phone'] ??
            json['clientPhone'] ??
            json['userPhone'] ??
            '')
        .toString();

    // Boshlanish / tugash nuqtalari (nested `startLocation`/`endLocation`)
    final start = asMap(json['startLocation']) ?? asMap(json['pickup']);
    final end = asMap(json['endLocation']) ?? asMap(json['destination']);

    final pickupLat = start?['lat'] ??
        json['startLat'] ??
        json['pickupLat'] ??
        json['fromLat'];
    final pickupLng = start?['lng'] ??
        json['startLng'] ??
        json['pickupLng'] ??
        json['fromLng'];

    final destLat =
        end?['lat'] ?? json['endLat'] ?? json['destLat'] ?? json['toLat'];
    final destLng =
        end?['lng'] ?? json['endLng'] ?? json['destLng'] ?? json['toLng'];

    final pickupAddress = (start?['adress'] ??
            start?['address'] ??
            json['pickupAddress'] ??
            json['startAddress'] ??
            json['adress'] ??
            '')
        .toString();
    final destinationAddress = (end?['adress'] ??
            end?['address'] ??
            json['destinationAddress'] ??
            json['endAddress'] ??
            '')
        .toString();

    // Tarif: `orderType` (nested obyekt) yoki yassi `tariff`/`tarif`.
    // Embed bo'lsa narx maydonlari ham bo'lishi mumkin (minPrice/kmPrice/...).
    final orderTypeMap = asMap(json['orderType']);
    final orderType =
        orderTypeMap != null ? OrderTypeModel.fromJson(orderTypeMap) : null;
    final tariff =
        (orderTypeMap?['name'] ?? json['tariff'] ?? json['tarif'])?.toString();

    DateTime created;
    final c = json['createdAt'] ?? json['created_at'];
    if (c is String) {
      created = DateTime.tryParse(c) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    // Haydovchi id — nested `driver` obyekti, IRI (`/api/drivers/5`) yoki yassi
    // `driverId`. Tugatilgan buyurtmalar ro'yxatini aynan shu haydovchiga
    // ajratish uchun kerak.
    int? parseIntId(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      final last = s.contains('/') ? s.split('/').last : s;
      return int.tryParse(last);
    }

    final driverMap = asMap(json['driver']);
    final driverId = parseIntId(driverMap?['id'] ??
        json['driverId'] ??
        json['driver_id'] ??
        json['driver']);

    return OrderModel(
      id: id,
      clientName: clientName,
      clientPhone: clientPhone,
      pickupLocation: point(pickupLat, pickupLng),
      destinationLocation: point(destLat, destLng),
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      distance: toDouble(json['distance']),
      price: toDouble(json['price'] ?? json['cost'] ?? json['amount']),
      createdAt: created,
      status: OrderStatusType.fromString(
        (json['status'] ?? json['orderStatus'] ?? json['state'])?.toString(),
      ),
      tariff: tariff,
      orderTypeId: orderType?.id,
      orderType: orderType,
      driverId: driverId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'startLat': pickupLocation.latitude,
        'startLng': pickupLocation.longitude,
        'endLat': destinationLocation.latitude,
        'endLng': destinationLocation.longitude,
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'distance': distance,
        'price': price,
        'createdAt': createdAt.toIso8601String(),
        'status': status.value,
        'tariff': tariff,
      };
}

/// App\Enum\OrderStatus (backend) bilan bir xil statuslar.
enum OrderStatusType {
  newOrder('new'),
  pending('pending'),
  accepted('accepted'),
  onTheWay('on_the_way'),
  arrive('arrive'),
  completed('completed'),
  canceled('canceled');

  const OrderStatusType(this.value);

  /// Backenddagi string qiymati.
  final String value;

  /// Backend string -> enum. Noma'lum bo'lsa pending. Backend ba'zan katta
  /// harfda (`COMPLETED`, `ON_THE_WAY`) qaytaradi — shuning uchun kichik
  /// harfga keltirib solishtiramiz.
  static OrderStatusType fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'new':
        return OrderStatusType.newOrder;
      case 'pending':
        return OrderStatusType.pending;
      case 'accepted':
        return OrderStatusType.accepted;
      case 'on_the_way':
        return OrderStatusType.onTheWay;
      case 'arrive':
        return OrderStatusType.arrive;
      case 'completed':
        return OrderStatusType.completed;
      case 'canceled':
      case 'cancelled':
        return OrderStatusType.canceled;
      default:
        return OrderStatusType.pending;
    }
  }
}
