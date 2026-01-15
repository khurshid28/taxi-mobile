import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'home_state.dart';
import '../../../../core/utils/notification_service.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/models/order_model.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  StreamSubscription<Position>? _positionSubscription;
  Timer? _orderWaitingTimer;
  Timer? _locationUpdateTimer;
  Timer? _waitingTimer;
  Timer? _pricingTimer;
  Timer? _simulationTimer;
  Point? _previousLocation;
  bool _hasShownArrivalNotification = false;
  bool _hasShownNearbyNotification = false;
  final Random _random = Random();

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

            // Show notification when within 200m and not shown yet
            if (distanceToClient <= 200 && !_hasShownNearbyNotification) {
              NotificationService().showNotification(
                title: 'Yaqinlashdingiz',
                body: 'Siz client joylashuviga yaqinlashdingiz!',
              );
              _hasShownNearbyNotification = true;
            }

            // Show arrival notification when very close
            if (distanceToClient <= 50 && !_hasShownArrivalNotification) {
              NotificationService().showNotification(
                title: 'Yetib keldingiz',
                body: 'Siz client joylashuviga yetib keldingiz!',
              );
              _hasShownArrivalNotification = true;
              emit(state.copyWith(status: OrderStatus.waitingForClient));
              _startWaitingTimer();
            }

            // Reset flags if moved away
            if (distanceToClient > 250) {
              _hasShownArrivalNotification = false;
              _hasShownNearbyNotification = false;
            }
          }

          emit(state.copyWith(
            currentLocation: newLocation,
            heading: heading,
            distanceToClient: distanceToClient,
          ));

          _previousLocation = newLocation;

          // Update route if order is in progress
          if (state.status == OrderStatus.goingToClient || 
              state.status == OrderStatus.inProgress) {
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
    // Start simulation with 7-8 seconds delay
    _orderWaitingTimer = Timer(
      Duration(milliseconds: 7000 + _random.nextInt(1000)), // 7-8 seconds
      () {
        // Generate random pickup location 1.2 km away
        final pickupLocation = _generateNearbyLocation(state.currentLocation!, 1.2);
        
        // Simulate order arrival with full details
        final order = OrderModel(
          id: 'ORDER${DateTime.now().millisecondsSinceEpoch}',
          clientName: 'Ali Valiyev',
          clientPhone: '+998901234567',
          pickupLocation: pickupLocation,
          destinationLocation: state.destinationLocation!,
          pickupAddress: 'Yunusobod, 5-mavze',
          destinationAddress: 'Chilonzor, 9-kvartal',
          distance: _calculateDistance(
            pickupLocation,
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

  Point _generateNearbyLocation(Point center, double distanceKm) {
    // Generate random location at specified distance
    final random = Random();
    final angle = random.nextDouble() * 2 * pi;
    final distance = distanceKm / 111.0; // Rough conversion to degrees
    
    final lat = center.latitude + (distance * cos(angle));
    final lon = center.longitude + (distance * sin(angle));
    
    return Point(latitude: lat, longitude: lon);
  }

  void acceptOrder() async {
    // Increase rating by 2 for accepting order
    final currentRating = await StorageHelper.getInt('driver_rating') ?? 50;
    final newRating = (currentRating + 2).clamp(0, 100);
    await StorageHelper.setInt('driver_rating', newRating);

    emit(state.copyWith(status: OrderStatus.orderAccepted));
    
    // Start going to client
    Timer(const Duration(seconds: 1), () {
      emit(state.copyWith(status: OrderStatus.goingToClient));
      _startUserMovementSimulation();
    });
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
    _stopWaitingTimer();
    
    // Add pickup charge (3000-4000 som)
    final pickupCharge = 3000 + _random.nextInt(1000);
    
    emit(state.copyWith(
      clientPickedUp: true,
      status: OrderStatus.inProgress,
      currentPrice: pickupCharge,
      traveledDistance: 0,
    ));
    
    // Start pricing timer (500 som every 20 seconds)
    _startPricingTimer();
    _startDistanceTracking();
  }

  void completeOrder() {
    _hasShownArrivalNotification = false;
    _hasShownNearbyNotification = false;
    _stopWaitingTimer();
    _stopPricingTimer();
    _stopDistanceTracking();
    _stopUserMovementSimulation();
    
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
        waitingSeconds: 0,
        currentPrice: 0,
        traveledDistance: 0,
        isWaitingTimerActive: false,
      ));
    });
  }

  // Movement simulation - moves user location by 200m towards client
  void _startUserMovementSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (state.status != OrderStatus.goingToClient) {
        timer.cancel();
        return;
      }

      if (state.currentLocation != null && state.currentOrder?.pickupLocation != null) {
        final clientLocation = state.currentOrder!.pickupLocation;
        final currentDistance = _calculateDistance(state.currentLocation!, clientLocation);
        
        // Move 200m closer each time
        if (currentDistance > 0.05) { // 50m threshold
          final newLocation = _moveTowards(
            state.currentLocation!,
            clientLocation,
            0.2, // 200m in km
          );
          
          emit(state.copyWith(currentLocation: newLocation));
          _previousLocation = newLocation;
        }
      }
    });
  }

  void _stopUserMovementSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Point _moveTowards(Point from, Point to, double distanceKm) {
    final totalDistance = _calculateDistance(from, to);
    if (totalDistance <= distanceKm) {
      return to;
    }
    
    final ratio = distanceKm / totalDistance;
    final lat = from.latitude + (to.latitude - from.latitude) * ratio;
    final lon = from.longitude + (to.longitude - from.longitude) * ratio;
    
    return Point(latitude: lat, longitude: lon);
  }

  // Waiting timer - starts when arrived at client (2 minutes free)
  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    
    emit(state.copyWith(
      isWaitingTimerActive: true,
      waitingSeconds: 0,
    ));
    
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != OrderStatus.waitingForClient) {
        timer.cancel();
        return;
      }
      
      final newWaitingSeconds = state.waitingSeconds + 1;
      emit(state.copyWith(waitingSeconds: newWaitingSeconds));
      
      // After 2 minutes (120 seconds), start charging 1500 som per minute
      if (newWaitingSeconds > 120) {
        // Charge 1500 som per 60 seconds = 25 som per second
        final minutesOver = (newWaitingSeconds - 120) / 60.0;
        final waitingCharge = (minutesOver * 1500).round();
        emit(state.copyWith(currentPrice: waitingCharge));
      }
    });
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
    emit(state.copyWith(isWaitingTimerActive: false));
  }

  // Pricing timer - charges 500 som every 20 seconds during trip
  void _startPricingTimer() {
    _pricingTimer?.cancel();
    
    _pricingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (state.status != OrderStatus.inProgress) {
        timer.cancel();
        return;
      }
      
      final newPrice = state.currentPrice + 500;
      emit(state.copyWith(currentPrice: newPrice));
    });
  }

  void _stopPricingTimer() {
    _pricingTimer?.cancel();
    _pricingTimer = null;
  }

  // Distance tracking - simulates distance traveled during trip
  Timer? _distanceTimer;
  
  void _startDistanceTracking() {
    _distanceTimer?.cancel();
    
    _distanceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.status != OrderStatus.inProgress) {
        timer.cancel();
        return;
      }
      
      // Add random 0.1-0.3 km every 5 seconds
      final additionalDistance = 0.1 + _random.nextDouble() * 0.2;
      final newDistance = state.traveledDistance + additionalDistance;
      emit(state.copyWith(traveledDistance: newDistance));
    });
  }

  void _stopDistanceTracking() {
    _distanceTimer?.cancel();
    _distanceTimer = null;
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
