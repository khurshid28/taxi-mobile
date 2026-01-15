import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'home_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/notification_service.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/models/order_model.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  StreamSubscription<Position>? _positionSubscription;
  Timer? _orderWaitingTimer;
  Timer? _locationUpdateTimer;
  Point? _previousLocation;
  bool _hasShownArrivalNotification = false;

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
        heading: position.heading,
      ));

      _previousLocation = currentLocation;

      // Start listening to location updates
      _startLocationTracking();
      
      // Start periodic location updates every 3 seconds
      _startPeriodicLocationUpdates();
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

      // Calculate heading if we have previous location
      double heading = state.heading;
      if (_previousLocation != null) {
        heading = _calculateHeading(_previousLocation!, newLocation);
      }

      emit(state.copyWith(
        currentLocation: newLocation,
        heading: heading,
      ));

      _previousLocation = newLocation;

      // Update route if order is in progress
      if (state.status == OrderStatus.inProgress) {
        _updateRoute();
      }
    });
  }

  void _startPeriodicLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

          final newLocation = Point(
            latitude: position.latitude,
            longitude: position.longitude,
          );

          // Calculate heading
          double heading = state.heading;
          if (_previousLocation != null) {
            heading = _calculateHeading(_previousLocation!, newLocation);
          }

          // Calculate distance to client if destination exists
          double? distanceToClient;
          if (state.destinationLocation != null) {
            distanceToClient = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              state.destinationLocation!.latitude,
              state.destinationLocation!.longitude,
            );

            // Show notification when within 150m and not shown yet
            if (distanceToClient <= 150 && !_hasShownArrivalNotification) {
              NotificationService().showNotification(
                title: 'Yetib keldingiz',
                body: 'Siz client joylashuviga yetib keldingiz!',
              );
              _hasShownArrivalNotification = true;
            }

            // Reset flag if moved away
            if (distanceToClient > 200) {
              _hasShownArrivalNotification = false;
            }
          }

          emit(state.copyWith(
            currentLocation: newLocation,
            heading: heading,
            distanceToClient: distanceToClient,
          ));

          _previousLocation = newLocation;

          // Update route if order is in progress
          if (state.status == OrderStatus.inProgress) {
            _updateRoute();
          }
        } catch (e) {
          // Silently fail, will retry in 3 seconds
        }
      },
    );
  }

  double _calculateHeading(Point start, Point end) {
    // Calculate bearing between two points
    final lat1 = start.latitude * (3.14159265359 / 180);
    final lat2 = end.latitude * (3.14159265359 / 180);
    final dLon = (end.longitude - start.longitude) * (3.14159265359 / 180);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x);

    // Convert to degrees and normalize to 0-360
    final degrees = (bearing * 180 / 3.14159265359 + 360) % 360;
    return degrees;
  }

  double _calculateDistance(Point start, Point end) {
    // Calculate distance in kilometers
    final distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return distanceInMeters / 1000; // Convert to km
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
        // Simulate order arrival with full details
        final order = OrderModel(
          id: 'ORDER${DateTime.now().millisecondsSinceEpoch}',
          clientName: 'Ali Valiyev',
          clientPhone: '+998901234567',
          pickupLocation: state.currentLocation!,
          destinationLocation: state.destinationLocation!,
          pickupAddress: 'Yunusobod, 5-mavze',
          destinationAddress: 'Chilonzor, 9-kvartal',
          distance: _calculateDistance(
            state.currentLocation!,
            state.destinationLocation!,
          ),
          price: 15000,
          createdAt: DateTime.now(),
          status: OrderStatusType.pending,
        );

        emit(state.copyWith(
          status: OrderStatus.orderReceived,
          currentOrder: order,
        ));
      },
    );
  }

  void acceptOrder() async {
    // Increase rating by 2 for accepting order
    final currentRating = await StorageHelper.getInt('driver_rating') ?? 50;
    final newRating = (currentRating + 2).clamp(0, 100);
    await StorageHelper.setInt('driver_rating', newRating);

    emit(state.copyWith(status: OrderStatus.orderAccepted));
    _calculateRoute();
  }

  void rejectOrder() async {
    // Decrease rating by 5 for rejecting order
    final currentRating = await StorageHelper.getInt('driver_rating') ?? 50;
    final newRating = (currentRating - 5).clamp(0, 100);
    await StorageHelper.setInt('driver_rating', newRating);

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

  void markClientPickedUp() {
    emit(state.copyWith(
      clientPickedUp: true,
    ));
  }

  void completeOrder() {
    _hasShownArrivalNotification = false;
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
        distanceToClient: null,
        clientPickedUp: false,
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
    _locationUpdateTimer?.cancel();
    return super.close();
  }
}
