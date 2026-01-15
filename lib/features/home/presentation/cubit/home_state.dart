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

  const HomeState({
    this.status = OrderStatus.initial,
    this.currentLocation,
    this.destinationLocation,
    this.routePoints = const [],
    this.currentOrder,
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    OrderStatus? status,
    Point? currentLocation,
    Point? destinationLocation,
    List<Point>? routePoints,
    OrderModel? currentOrder,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      routePoints: routePoints ?? this.routePoints,
      currentOrder: currentOrder ?? this.currentOrder,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
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
