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
  });

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

    final id = (json['id'] ?? json['orderId'] ?? json['@id'] ?? '').toString();

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

  /// Backend string -> enum. Noma'lum bo'lsa pending.
  static OrderStatusType fromString(String? raw) {
    switch (raw) {
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
