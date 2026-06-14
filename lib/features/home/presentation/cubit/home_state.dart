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
  final bool isOnline; // Driver online/offline status
  final bool isTimeoutEnabled; // Enable/disable waiting charge
  final List<Point>? routeGeometry; // Actual route points from Yandex
  final int currentRouteIndex; // Current position on route
  final int? routeDurationMinutes; // Estimated route duration in minutes
  final String? routeDistanceKm; // Route distance in km
  final DateTime? tripStartTime; // When the trip (inProgress) actually started
  final int tripSeconds; // Trip duration in seconds (pickup -> complete)

  /// Hech bir haydovchi 2 urinishda olmagan, kompaniya bo'yicha BARCHA online
  /// haydovchilarga yuborilgan "global" buyurtmalar. Istalgan haydovchi shu
  /// ro'yxatdan buyurtmani olishi mumkin (birinchi olgan yutadi). Mercure
  /// `GLOBAL_ORDER` ro'yxatga qo'shadi, `GLOBAL_ORDER_ACCEPTED`/`_CANCELED`
  /// esa olib tashlaydi (jim — ovoz/banner yo'q, faqat ma'lumot yangilanadi).
  final List<OrderModel> globalOrders;

  /// Haydovchi QABUL QILGAN, lekin hozir xaritada faol bo'lmagan (navbatdagi)
  /// buyurtmalar. App bir vaqtda BITTA safarni xaritada boshqaradi, lekin
  /// haydovchi 2 tagacha faol buyurtma olishi mumkin — 1-chisi `currentOrder`
  /// (xaritada), 2-chisi shu navbatda kutadi. 1-chi yakunlangach 2-chi
  /// avtomatik `currentOrder`ga ko'tariladi. Backend `orders/driver/{id}/active`
  /// maksimal 2 ta qaytaradi — shularga mos.
  final List<OrderModel> queuedOrders;

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
    this.isOnline = false,
    this.isTimeoutEnabled = true,
    this.routeGeometry,
    this.currentRouteIndex = 0,
    this.routeDurationMinutes,
    this.routeDistanceKm,
    this.tripStartTime,
    this.tripSeconds = 0,
    this.globalOrders = const [],
    this.queuedOrders = const [],
  });

  HomeState copyWith({
    OrderStatus? status,
    Point? currentLocation,
    Point? destinationLocation,
    List<Point>? routePoints,
    OrderModel? currentOrder,
    bool? isLoading,
    String? error,
    bool clearError = false,
    double? heading,
    double? distanceToClient,
    bool? clientPickedUp,
    int? waitingSeconds,
    int? currentPrice,
    double? traveledDistance,
    bool? isWaitingTimerActive,
    int? routeDurationMinutes,
    String? routeDistanceKm,
    bool? isOnline,
    bool? isTimeoutEnabled,
    List<Point>? routeGeometry,
    int? currentRouteIndex,
    DateTime? tripStartTime,
    int? tripSeconds,
    List<OrderModel>? globalOrders,
    List<OrderModel>? queuedOrders,
  }) {
    return HomeState(
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      routePoints: routePoints ?? this.routePoints,
      currentOrder: currentOrder ?? this.currentOrder,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      heading: heading ?? this.heading,
      distanceToClient: distanceToClient ?? this.distanceToClient,
      clientPickedUp: clientPickedUp ?? this.clientPickedUp,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      currentPrice: currentPrice ?? this.currentPrice,
      traveledDistance: traveledDistance ?? this.traveledDistance,
      isWaitingTimerActive: isWaitingTimerActive ?? this.isWaitingTimerActive,
      isOnline: isOnline ?? this.isOnline,
      isTimeoutEnabled: isTimeoutEnabled ?? this.isTimeoutEnabled,
      routeGeometry: routeGeometry ?? this.routeGeometry,
      currentRouteIndex: currentRouteIndex ?? this.currentRouteIndex,
      routeDurationMinutes: routeDurationMinutes ?? this.routeDurationMinutes,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      tripStartTime: tripStartTime ?? this.tripStartTime,
      tripSeconds: tripSeconds ?? this.tripSeconds,
      globalOrders: globalOrders ?? this.globalOrders,
      queuedOrders: queuedOrders ?? this.queuedOrders,
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
    isOnline,
    isTimeoutEnabled,
    routeGeometry,
    currentRouteIndex,
    routeDurationMinutes,
    routeDistanceKm,
    tripStartTime,
    tripSeconds,
    globalOrders,
    queuedOrders,
  ];
}
