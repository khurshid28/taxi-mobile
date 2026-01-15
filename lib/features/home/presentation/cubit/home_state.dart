import 'package:equatable/equatable.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

enum OrderStatus {
  initial,
  drawingRoute,
  waitingForOrder,
  orderReceived,
  orderAccepted,
  inProgress,
  completed,
}

class HomeState extends Equatable {
  final OrderStatus status;
  final Point? currentLocation;
  final Point? destinationLocation;
  final List<Point> routePoints;
  final OrderModel? currentOrder;
  final bool isLoading;
  final String? error;
  final double heading; // Icon rotation angle
  final double? distanceToClient; // Distance to client in meters
  final bool clientPickedUp; // Client picked up flag

  const HomeState({
    this.status = OrderStatus.initial,
    this.currentLocation,
    this.destinationLocation,
    this.routePoints = const [],
    this.currentOrder,
    this.isLoading = false,
    this.error,
    this.heading = 0.0,
    this.distanceToClient,
    this.clientPickedUp = false,
  });

  HomeState copyWith({
    OrderStatus? status,
    Point? currentLocation,
    Point? destinationLocation,
    List<Point>? routePoints,
    OrderModel? currentOrder,
    bool? isLoading,
    String? error,
    double? heading,
    double? distanceToClient,
    bool? clientPickedUp,
  }) {
    return HomeState(
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      routePoints: routePoints ?? this.routePoints,
      currentOrder: currentOrder ?? this.currentOrder,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      heading: heading ?? this.heading,
      distanceToClient: distanceToClient ?? this.distanceToClient,
      clientPickedUp: clientPickedUp ?? this.clientPickedUp,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentLocation,
        destinationLocation,
        routePoints,
        currentOrder,
        isLoading,
        error,
        heading,
        distanceToClient,
        clientPickedUp,
      ];
}

class OrderModel {
  final String id;
  final String clientName;
  final Point pickupLocation;
  final Point dropoffLocation;
  final double distance;
  final double price;

  OrderModel({
    required this.id,
    required this.clientName,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.distance,
    required this.price,
  });
}
