import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'home_state.dart';
import '../../../../core/constants/app_constants.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  StreamSubscription<Position>? _positionSubscription;
  Timer? _orderWaitingTimer;

  void initialize() async {
    emit(state.copyWith(isLoading: true));

    try {
      // Get current location
      final position = await _getCurrentLocation();
      final currentLocation = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      emit(state.copyWith(
        currentLocation: currentLocation,
        status: OrderStatus.initial,
        isLoading: false,
      ));

      // Start listening to location updates
      _startLocationTracking();
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      final newLocation = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      emit(state.copyWith(currentLocation: newLocation));

      // Update route if order is in progress
      if (state.status == OrderStatus.inProgress) {
        _updateRoute();
      }
    });
  }

  void startDrawingRoute() {
    emit(state.copyWith(status: OrderStatus.drawingRoute));
  }

  void setDestination(Point destination) {
    emit(state.copyWith(
      destinationLocation: destination,
      status: OrderStatus.waitingForOrder,
    ));

    // Simulate waiting for order
    _simulateOrderArrival();
  }

  void _simulateOrderArrival() {
    _orderWaitingTimer = Timer(
      Duration(milliseconds: AppConstants.orderWaitingTime),
      () {
        // Simulate order arrival
        final order = OrderModel(
          id: '12345',
          clientName: 'Ali Valiyev',
          pickupLocation: state.currentLocation!,
          dropoffLocation: state.destinationLocation!,
          distance: 5.2,
          price: 15000,
        );

        emit(state.copyWith(
          status: OrderStatus.orderReceived,
          currentOrder: order,
        ));
      },
    );
  }

  void acceptOrder() {
    emit(state.copyWith(status: OrderStatus.orderAccepted));
    _calculateRoute();
  }

  void rejectOrder() {
    emit(state.copyWith(
      status: OrderStatus.waitingForOrder,
      currentOrder: null,
    ));
    _simulateOrderArrival();
  }

  void _calculateRoute() async {
    // Simulate route calculation
    await Future.delayed(const Duration(seconds: 1));

    final routePoints = _generateRoutePoints(
      state.currentLocation!,
      state.destinationLocation!,
    );

    emit(state.copyWith(
      status: OrderStatus.inProgress,
      routePoints: routePoints,
    ));
  }

  List<Point> _generateRoutePoints(Point start, Point end) {
    // Simple simulation of route points
    final points = <Point>[];
    final steps = 10;

    for (int i = 0; i <= steps; i++) {
      final lat = start.latitude + (end.latitude - start.latitude) * i / steps;
      final lon = start.longitude + (end.longitude - start.longitude) * i / steps;
      points.add(Point(latitude: lat, longitude: lon));
    }

    return points;
  }

  void _updateRoute() {
    // Update route based on current location
    if (state.currentLocation != null && state.destinationLocation != null) {
      final routePoints = _generateRoutePoints(
        state.currentLocation!,
        state.destinationLocation!,
      );

      emit(state.copyWith(routePoints: routePoints));
    }
  }

  void completeOrder() {
    emit(state.copyWith(
      status: OrderStatus.completed,
    ));

    // Reset after completion
    Future.delayed(const Duration(seconds: 3), () {
      emit(state.copyWith(
        status: OrderStatus.initial,
        currentOrder: null,
        destinationLocation: null,
        routePoints: [],
      ));
    });
  }

  void openInGoogleMaps() {
    // This will be implemented to open Google Maps with coordinates
    // For now, just log
    print('Opening Google Maps with route');
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _orderWaitingTimer?.cancel();
    return super.close();
  }
}
