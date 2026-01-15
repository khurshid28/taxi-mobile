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
  });
}

enum OrderStatusType {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
}
