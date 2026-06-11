import 'package:yandex_mapkit/yandex_mapkit.dart';

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
  });

  /// Mercure / REST javoblari uchun parser. Backend bir nechta
  /// nom variantlarini ishlatadi - imkon qadar moslashuvchan.
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    Point point(dynamic lat, dynamic lng) =>
        Point(latitude: toDouble(lat), longitude: toDouble(lng));

    final id = (json['id'] ?? json['orderId'] ?? json['@id'] ?? '').toString();

    final pickupLat = json['startLat'] ??
        json['pickupLat'] ??
        json['fromLat'] ??
        (json['pickup'] is Map ? json['pickup']['lat'] : null);
    final pickupLng = json['startLng'] ??
        json['pickupLng'] ??
        json['fromLng'] ??
        (json['pickup'] is Map ? json['pickup']['lng'] : null);

    final destLat = json['endLat'] ??
        json['destLat'] ??
        json['toLat'] ??
        (json['destination'] is Map ? json['destination']['lat'] : null);
    final destLng = json['endLng'] ??
        json['destLng'] ??
        json['toLng'] ??
        (json['destination'] is Map ? json['destination']['lng'] : null);

    DateTime created;
    final c = json['createdAt'] ?? json['created_at'];
    if (c is String) {
      created = DateTime.tryParse(c) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return OrderModel(
      id: id,
      clientName:
          (json['clientName'] ?? json['userName'] ?? 'Mijoz').toString(),
      clientPhone:
          (json['clientPhone'] ?? json['userPhone'] ?? '').toString(),
      pickupLocation: point(pickupLat, pickupLng),
      destinationLocation: point(destLat, destLng),
      pickupAddress:
          (json['pickupAddress'] ?? json['startAddress'] ?? json['adress'] ?? '')
              .toString(),
      destinationAddress:
          (json['destinationAddress'] ?? json['endAddress'] ?? '').toString(),
      distance: toDouble(json['distance']),
      price: toDouble(json['price'] ?? json['cost'] ?? json['amount']),
      createdAt: created,
      status: OrderStatusType.fromString(
        (json['status'] ?? json['orderStatus'] ?? json['state'])?.toString(),
      ),
      tariff: (json['tariff'] ?? json['tarif'])?.toString(),
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
