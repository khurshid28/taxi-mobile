import 'package:equatable/equatable.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../../../core/models/order_model.dart';

enum OrderStatus {
  initial,
  drawingRoute,
  waitingForOrder,
  orderReceived,
  orderAccepted,
  goingToClient,
  waitingForClient,
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
  final int waitingSeconds; // Waiting time in seconds
  final int currentPrice; // Current price (increases with waiting time)
  final double traveledDistance; // Kilometers traveled
  final bool isWaitingTimerActive; // Waiting timer active flag

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
    this.waitingSeconds = 0,
    this.currentPrice = 0,
    this.traveledDistance = 0.0,
    this.isWaitingTimerActive = false,
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
    int? waitingSeconds,
    int? currentPrice,
    double? traveledDistance,
    bool? isWaitingTimerActive,
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
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      currentPrice: currentPrice ?? this.currentPrice,
      traveledDistance: traveledDistance ?? this.traveledDistance,
      isWaitingTimerActive: isWaitingTimerActive ?? this.isWaitingTimerActive,
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
        waitingSeconds,
        currentPrice,
        traveledDistance,
        isWaitingTimerActive,
      ];
}
