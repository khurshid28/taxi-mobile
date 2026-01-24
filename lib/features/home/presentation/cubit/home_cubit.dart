import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'home_state.dart';
import '../../../../core/utils/notification_service.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/network/mapbox_route_service.dart';
import '../../../../core/network/yandex_route_drawer.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  StreamSubscription<Position>? _positionSubscription;
  Timer? _orderWaitingTimer;
  Timer? _locationUpdateTimer;
  Timer? _waitingTimer;
  Timer? _simulationTimer;
  Timer? _distanceTimer;
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

      emit(
        state.copyWith(
          currentLocation: currentLocation,
          status: OrderStatus.initial,
          isLoading: false,
          heading: position.heading,
        ),
      );

      _previousLocation = currentLocation;

      // Start listening to location updates
      _startLocationTracking();

      // Start periodic location updates every 3 seconds
      _startPeriodicLocationUpdates();

      // Auto-start removed - driver must go online first
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void toggleOnline() {
    final newOnlineStatus = !state.isOnline;
    emit(state.copyWith(isOnline: newOnlineStatus));

    if (newOnlineStatus) {
      // When going online, start order simulation after 10 seconds
      Timer(const Duration(seconds: 10), () {
        if (state.status == OrderStatus.initial && state.isOnline) {
          // Generate random destination 5-8 km away (farther for better testing)
          final destDistance = 5.0 + (_random.nextDouble() * 3); // 5-8 km
          final destLocation = _generateNearbyLocation(
            state.currentLocation!,
            destDistance,
          );
          setDestination(destLocation);
        }
      });
    } else {
      // When going offline, cancel any orders and reset to initial state
      _orderWaitingTimer?.cancel();
      _simulationTimer?.cancel();
      _distanceTimer?.cancel();

      emit(
        state.copyWith(
          status: OrderStatus.initial,
          destinationLocation: null,
          currentOrder: null,
          routePoints: [],
          distanceToClient: null,
          clientPickedUp: false,
          waitingSeconds: 0,
          currentPrice: 0,
          traveledDistance: 0,
          isWaitingTimerActive: false,
        ),
      );

      // Restart real location updates
      _startPeriodicLocationUpdates();
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
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          // SKIP during simulation statuses
          if (state.status == OrderStatus.goingToClient ||
              state.status == OrderStatus.inProgress ||
              state.status == OrderStatus.waitingForClient) {
            print('⏭️ Skipping real GPS update during simulation');
            return;
          }

          final newLocation = Point(
            latitude: position.latitude,
            longitude: position.longitude,
          );

          // Calculate heading if we have previous location
          double heading = state.heading;
          if (_previousLocation != null) {
            heading = _calculateHeading(_previousLocation!, newLocation);
          }

          emit(state.copyWith(currentLocation: newLocation, heading: heading));

          _previousLocation = newLocation;

          // Update route if order is in progress
          if (state.status == OrderStatus.inProgress) {
            _updateRoute();
          }
        });
  }

  void _startPeriodicLocationUpdates() {
    _locationUpdateTimer?.cancel(); // Cancel any existing timer first

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      // Don't update real location during simulation - STOP the timer completely
      if (state.status == OrderStatus.goingToClient ||
          state.status == OrderStatus.inProgress ||
          state.status == OrderStatus.waitingForClient) {
        print('⏹️ Stopping real location updates during simulation');
        timer.cancel();
        return;
      }

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

        // Only update if moved at least 5 meters
        if (_previousLocation != null) {
          final distance = Geolocator.distanceBetween(
            _previousLocation!.latitude,
            _previousLocation!.longitude,
            newLocation.latitude,
            newLocation.longitude,
          );

          // Skip update if not moved significantly
          if (distance < 5) {
            return;
          }
        }

        // Calculate heading
        double heading = state.heading;
        if (_previousLocation != null) {
          heading = _calculateHeading(_previousLocation!, newLocation);
        }

        emit(state.copyWith(currentLocation: newLocation, heading: heading));

        _previousLocation = newLocation;
      } catch (e) {
        // Silently fail, will retry in 3 seconds
      }
    });
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
    emit(
      state.copyWith(
        destinationLocation: destination,
        status: OrderStatus.initial, // Keep as initial, no waiting state
      ),
    );

    // Simulate waiting for order
    _simulateOrderArrival();
  }

  void _simulateOrderArrival() {
    // Don't simulate if already has order or not in initial status
    if (state.currentOrder != null || state.status != OrderStatus.initial) {
      return;
    }

    // Start simulation with 10 seconds delay
    _orderWaitingTimer = Timer(const Duration(seconds: 10), () {
      // Double check before generating order
      if (state.currentOrder != null || state.status != OrderStatus.initial) {
        return;
      }

      // Generate random pickup location 2-3 km away
      final randomDistance = 2.0 + _random.nextDouble(); // 2.0 to 3.0 km
      final pickupLocation = _generateNearbyLocation(
        state.currentLocation!,
        randomDistance,
      );

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

      emit(
        state.copyWith(status: OrderStatus.orderReceived, currentOrder: order),
      );

      // Play new order sound and show notification
      SoundService().playNewOrderSound();
      NotificationService().showNewOrderNotification();
    });
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
    // Play acceptance sound
    await SoundService().playOrderAcceptedSound();

    int estimatedPrice = 3000; // Default base price

    // Calculate estimated price and deduct 15% commission from balance
    if (state.currentOrder != null) {
      final estimatedDistance = state.currentOrder!.distance;
      estimatedPrice = 3000 + (estimatedDistance * 2100).round();
      final commission = (estimatedPrice * 0.15).round();

      // Deduct commission from balance
      final currentBalance =
          await StorageHelper.getDouble('driver_balance') ?? 295000;
      final newBalance = currentBalance - commission;
      await StorageHelper.setDouble('driver_balance', newBalance);

      // Request route and wait for it
      await _requestRouteToClient();
    }

    // Increase rating by 2 for accepting order
    final currentRating = await StorageHelper.getInt('driver_rating') ?? -5;
    final newRating = (currentRating + 2).clamp(-5, 50);
    await StorageHelper.setInt('driver_rating', newRating);

    emit(
      state.copyWith(
        status: OrderStatus.orderAccepted,
        currentPrice: 3000, // Always start with base price 3000
        traveledDistance: 0,
        waitingSeconds: 0, // Reset waiting timer
        isWaitingTimerActive: false,
      ),
    );

    // Start going to client immediately
    Timer(const Duration(milliseconds: 100), () {
      // Stop real location updates (both timer and stream)
      print('🛑 Stopping real location tracking for simulation...');
      _locationUpdateTimer?.cancel();
      _positionSubscription?.cancel();

      emit(state.copyWith(status: OrderStatus.goingToClient));
      _startUserMovementSimulation();
    });
  }

  void rejectOrder() async {
    // Decrease rating by 5 for rejecting order
    final currentRating = await StorageHelper.getInt('driver_rating') ?? -5;
    final newRating = (currentRating - 5).clamp(-5, 50);
    await StorageHelper.setInt('driver_rating', newRating);

    emit(
      state.copyWith(
        status: OrderStatus.initial,
        currentOrder: null,
        routeGeometry: null,
        currentRouteIndex: 0,
        routeDurationMinutes: null,
        routeDistanceKm: null,
      ),
    );

    // Simulate new order arrival
    _simulateOrderArrival();
  }

  // Request route from current location to client using Mapbox/OSRM
  Future<void> _requestRouteToClient() async {
    if (state.currentLocation == null ||
        state.currentOrder?.pickupLocation == null) {
      print('❌ Missing location data');
      return;
    }

    final from = state.currentLocation!;
    final to = state.currentOrder!.pickupLocation;

    print('📍 From: ${from.latitude}, ${from.longitude}');
    print('📍 To: ${to.latitude}, ${to.longitude}');

    try {
      // Try Mapbox first (100k bepul/oy, duration & distance included)
      print('🌐 Requesting Mapbox route...');
      final routeData = await MapboxRouteService.getRoute(
        from,
        to,
        mode: 'driving',
      );

      if (routeData['points'] != null &&
          (routeData['points'] as List).isNotEmpty) {
        print(
          '✅ Mapbox yo\'l olindi: ${(routeData['points'] as List).length} nuqta 🛣️',
        );
        emit(
          state.copyWith(
            routeGeometry: routeData['points'],
            currentRouteIndex: 0,
            routeDurationMinutes: routeData['durationMinutes'],
            routeDistanceKm: routeData['distanceKm'],
          ),
        );
        return;
      }
    } catch (e) {
      print('⚠️ Mapbox API xatosi: $e');
      print('🔄 Fallback: OSRM ishlatilmoqda...');
    }

    try {
      // Fallback to OSRM (bepul, lekin duration yo'q)
      final routeGeometry = await YandexRouteDrawer.getRoute(
        from,
        to,
        mode: 'driving',
      );

      if (routeGeometry.isNotEmpty) {
        print('✅ OSRM yo\'l olindi: ${routeGeometry.length} nuqta 🛣️');
        emit(
          state.copyWith(routeGeometry: routeGeometry, currentRouteIndex: 0),
        );
        return;
      }
    } catch (e) {
      print('⚠️ OSRM API xatosi: $e');
      print('🔄 Fallback: Interpolatsiya ishlatilmoqda...');
    }

    // Last fallback: Generate smooth interpolated route
    final routeGeometry = _generateInterpolatedRoute(from, to, 200);
    print('✅ Fallback yo\'l: ${routeGeometry.length} points 🛣️');

    emit(state.copyWith(routeGeometry: routeGeometry, currentRouteIndex: 0));
  }

  // Generate interpolated route between two points - straight line
  List<Point> _generateInterpolatedRoute(Point start, Point end, int segments) {
    final points = <Point>[];

    // Add start point
    points.add(start);

    // Calculate intermediate points - straight line without randomness
    for (int i = 1; i < segments; i++) {
      final t = i / segments;

      // Linear interpolation - to'g'ri chiziq
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lon = start.longitude + (end.longitude - start.longitude) * t;

      points.add(Point(latitude: lat, longitude: lon));
    }

    // Add end point
    points.add(end);

    return points;
  }

  List<Point> _generateRoutePoints(Point start, Point end) {
    // Simple simulation of route points
    final points = <Point>[];
    final steps = 10;

    for (int i = 0; i <= steps; i++) {
      final lat = start.latitude + (end.latitude - start.latitude) * i / steps;
      final lon =
          start.longitude + (end.longitude - start.longitude) * i / steps;
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
    // DON'T stop waiting timer - let it continue to accumulate time
    // Timer keeps running but toggle button will allow user to pause/resume
    print('🚗 Client picked up - timer continues: ${state.waitingSeconds}s');

    // Generate random destination 4-5 km away from current location
    final randomDistance = 4.0 + (_random.nextDouble() * 1.0); // 4.0 to 5.0 km
    final newDestination = _generateNearbyLocation(
      state.currentLocation!,
      randomDistance,
    );

    // Show "Qani ketdik" notification
    NotificationService().showNotification(
      title: '🚗 Safar boshlandi!',
      body: 'Client olindi. Qani ketdik, manzilga yo\'nalish!',
      playSound: true,
    );

    // Start with base price 3000 and set new destination
    emit(
      state.copyWith(
        clientPickedUp: true,
        status: OrderStatus.inProgress,
        currentPrice: 3000,
        traveledDistance: 0,
        destinationLocation: newDestination,
      ),
    );

    // Request route to destination
    _requestRouteToDestination();

    // Start distance tracking (price updates based on distance)
    _startDistanceTracking();
  }

  // Request route to destination after picking up client
  Future<void> _requestRouteToDestination() async {
    if (state.currentLocation == null || state.destinationLocation == null) {
      return;
    }

    print('🔍 Generating route to destination...');
    print(
      '📍 From: ${state.currentLocation!.latitude}, ${state.currentLocation!.longitude}',
    );
    print(
      '📍 To: ${state.destinationLocation!.latitude}, ${state.destinationLocation!.longitude}',
    );

    try {
      // Try Mapbox first (100k bepul/oy, duration & distance included)
      print('🌐 Requesting Mapbox route...');
      final routeData = await MapboxRouteService.getRoute(
        state.currentLocation!,
        state.destinationLocation!,
        mode: 'driving',
      );

      if (routeData['points'] != null &&
          (routeData['points'] as List).isNotEmpty) {
        print(
          '✅ Mapbox yo\'l olindi: ${(routeData['points'] as List).length} nuqta 🛣️',
        );
        emit(
          state.copyWith(
            routeGeometry: routeData['points'],
            currentRouteIndex: 0,
            routeDurationMinutes: routeData['durationMinutes'],
            routeDistanceKm: routeData['distanceKm'],
          ),
        );
        return;
      }
    } catch (e) {
      print('⚠️ Mapbox API xatosi: $e');
      print('🔄 Fallback: OSRM ishlatilmoqda...');
    }

    try {
      // Fallback to OSRM (bepul, lekin duration yo'q)
      final routeGeometry = await YandexRouteDrawer.getRoute(
        state.currentLocation!,
        state.destinationLocation!,
        mode: 'driving',
      );

      if (routeGeometry.isNotEmpty) {
        print('✅ OSRM yo\'l olindi: ${routeGeometry.length} nuqta 🛣️');
        emit(
          state.copyWith(routeGeometry: routeGeometry, currentRouteIndex: 0),
        );
        return;
      }
    } catch (e) {
      print('⚠️ OSRM API xatosi: $e');
      print('🔄 Fallback: Interpolatsiya ishlatilmoqda...');
    }

    // Last fallback: Generate smooth interpolated route
    final routeGeometry = _generateInterpolatedRoute(
      state.currentLocation!,
      state.destinationLocation!,
      200,
    );

    print('✅ Fallback yo\'l: ${routeGeometry.length} points 🛣️');
    emit(state.copyWith(routeGeometry: routeGeometry, currentRouteIndex: 0));
  }

  void completeOrder() async {
    _hasShownArrivalNotification = false;
    _hasShownNearbyNotification = false;
    _stopWaitingTimer();
    _stopDistanceTracking();
    _stopUserMovementSimulation();

    // Save completed order to storage
    if (state.currentOrder != null) {
      final completedOrder = OrderModel(
        id: state.currentOrder!.id,
        clientName: state.currentOrder!.clientName,
        clientPhone: state.currentOrder!.clientPhone,
        pickupLocation: state.currentOrder!.pickupLocation,
        destinationLocation: state.currentOrder!.destinationLocation,
        pickupAddress: state.currentOrder!.pickupAddress,
        destinationAddress: state.currentOrder!.destinationAddress,
        distance: state.traveledDistance,
        price: state.currentPrice.toDouble(), // Already calculated and rounded
        createdAt: state.currentOrder!.createdAt,
        status: OrderStatusType.completed,
      );

      // Save to storage (will be used in orders page)
      await _saveCompletedOrder(completedOrder);
    }

    emit(state.copyWith(status: OrderStatus.completed));

    // Clear route immediately to remove line from map
    emit(state.copyWith(routePoints: [], routeGeometry: null));

    // Restart real location updates after simulation (both timer and stream)
    print('✅ Restarting real location tracking...');
    _startPeriodicLocationUpdates();
    _startLocationTracking();

    // Reset immediately to initial state (no waiting)
    emit(
      state.copyWith(
        status: OrderStatus.initial,
        currentOrder: null,
        destinationLocation: null,
        routePoints: [],
        routeGeometry: null,
        currentRouteIndex: 0,
        distanceToClient: null,
        clientPickedUp: false,
        waitingSeconds: 0,
        currentPrice: 0,
        traveledDistance: 0,
        isWaitingTimerActive: false,
        routeDurationMinutes: null,
        routeDistanceKm: null,
      ),
    );

    // Start new order simulation after 10 seconds if still online
    if (state.isOnline) {
      Future.delayed(const Duration(seconds: 10), () {
        if (state.isOnline && state.status == OrderStatus.initial) {
          _simulateOrderArrival();
        }
      });
    }
  }

  // Movement simulation - moves user location by 200m towards destination
  void _startUserMovementSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Continue during goingToClient and inProgress (not waitingForClient)
      if (state.status != OrderStatus.goingToClient &&
          state.status != OrderStatus.inProgress) {
        timer.cancel();
        print('⏹️ Simulation timer stopped - Status: ${state.status}');
        return;
      }

      if (state.currentLocation != null) {
        Point? newLocation;
        Point? targetLocation;

        // Determine target based on status
        if (state.status == OrderStatus.goingToClient &&
            state.currentOrder?.pickupLocation != null) {
          targetLocation = state.currentOrder!.pickupLocation;
        } else if (state.status == OrderStatus.inProgress &&
            state.destinationLocation != null) {
          targetLocation = state.destinationLocation!;
        }

        // Debug: Log current state
        print('🚗 Simulation tick - Status: ${state.status}');
        print(
          '📍 Current: ${state.currentLocation?.latitude}, ${state.currentLocation?.longitude}',
        );
        print(
          '🎯 Target: ${targetLocation?.latitude}, ${targetLocation?.longitude}',
        );
        print('🛣️ Route points: ${state.routeGeometry?.length ?? 0}');

        // If we have real route geometry, follow it
        if (state.routeGeometry != null && state.routeGeometry!.length >= 2) {
          print('✅ Following route geometry...');
          newLocation = _moveAlongRoute(0.1); // Move 100m along route
          if (newLocation != null) {
            print(
              '✅ Moved along route to: ${newLocation.latitude}, ${newLocation.longitude}',
            );
          } else {
            print('⚠️ _moveAlongRoute returned null!');
          }
        }

        // Fallback: if no route or route ended, move directly to target
        if (newLocation == null && targetLocation != null) {
          print('⚠️ No route or route ended, using direct movement...');
          final currentDistance = _calculateDistance(
            state.currentLocation!,
            targetLocation,
          );
          print(
            '📏 Distance to target: ${(currentDistance * 1000).toStringAsFixed(0)}m',
          );

          // Always move towards target, no minimum threshold
          if (currentDistance > 0.001) {
            // 1m threshold
            newLocation = _moveTowards(
              state.currentLocation!,
              targetLocation,
              0.1, // 100m in km
            );
            print(
              '✅ Moved directly to: ${newLocation.latitude}, ${newLocation.longitude}',
            );
          } else {
            print('✅ Already at target!');
            newLocation = targetLocation;
          }
        }

        // Safety check: if still no location, skip this iteration
        if (newLocation == null) {
          print('❌ ERROR: No new location calculated! Skipping...');
          return;
        }

        // Check if within 100m of destination during inProgress
        if (state.status == OrderStatus.inProgress &&
            state.destinationLocation != null) {
          final distanceToDestination = _calculateDistance(
            state.currentLocation!,
            state.destinationLocation!,
          );

          // Auto-complete when within 50m of destination
          if (distanceToDestination <= 0.05) {
            print(
              '✅ Arrived at destination! Distance: ${(distanceToDestination * 1000).toStringAsFixed(0)}m',
            );

            // Stop all tracking
            _stopUserMovementSimulation();
            _stopDistanceTracking();
            _stopWaitingTimer();

            emit(
              state.copyWith(
                currentLocation: newLocation ?? state.currentLocation,
                status: OrderStatus.completed,
              ),
            );

            // Show notification
            NotificationService().showNotification(
              title: '🎉 Safar tugadi!',
              body:
                  'Manzilga yetib keldingiz. Jami: ${state.currentPrice} so\'m',
              playSound: true,
            );

            // Auto-complete after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (state.status == OrderStatus.completed) {
                completeOrder();
              }
            });

            return; // Exit timer callback
          }

          // Show notification when within 100m
          if (distanceToDestination <= 0.1 && !_hasShownNearbyNotification) {
            _hasShownNearbyNotification = true;
            NotificationService().showNotification(
              title: '📍 Manzilga yetib kelmoqdasiz',
              body: 'Siz manzilga 100 metr yaqinlashdingiz!',
              playSound: true,
            );
          }
        }

        if (newLocation != null) {
          // Calculate heading for rotation based on next route point
          double heading;

          if (state.routeGeometry != null && state.routeGeometry!.length > 1) {
            // Use next point on route for accurate heading
            heading = _calculateHeading(
              newLocation,
              state.routeGeometry![0], // Next point on route
            );
          } else {
            // Fallback to direct heading
            Point? targetLocation;
            if (state.status == OrderStatus.goingToClient &&
                state.currentOrder?.pickupLocation != null) {
              targetLocation = state.currentOrder!.pickupLocation;
            } else if (state.destinationLocation != null) {
              targetLocation = state.destinationLocation!;
            }

            heading = targetLocation != null
                ? _calculateHeading(state.currentLocation!, targetLocation)
                : state.heading;
          }

          // Calculate distance to client if going to client
          double? distanceToClient;
          if (state.status == OrderStatus.goingToClient &&
              state.currentOrder?.pickupLocation != null) {
            distanceToClient =
                _calculateDistance(
                  newLocation,
                  state.currentOrder!.pickupLocation,
                ) *
                1000; // Convert km to meters

            // Auto-arrive when within 50m of client
            if (distanceToClient <= 50) {
              print(
                '✅ Arrived at client location! Distance: ${distanceToClient.toStringAsFixed(0)}m',
              );
              print('🛑 Stopping simulation timer...');

              // Stop simulation and switch to waiting status
              _stopUserMovementSimulation();

              print('📢 Showing notification...');
              // Show notification
              NotificationService().showNotification(
                title: '📍 Mijoz oldida',
                body: 'Siz mijoz oldiga yetib keldingiz. Kutish boshlandi.',
                playSound: true,
              );

              print('✅ Emitting waitingForClient status...');
              emit(
                state.copyWith(
                  currentLocation: newLocation,
                  heading: heading,
                  distanceToClient: 0,
                  status: OrderStatus.waitingForClient,
                  currentPrice: 3000, // Keep base price at 3000
                ),
              );
              print('✅ Status changed to: ${state.status}');

              // Auto-start waiting timer when arrived at client
              _startWaitingTimer();
              print('⏱️ Waiting timer auto-started');

              return; // Exit timer callback - don't emit again
            }
          }

          emit(
            state.copyWith(
              currentLocation: newLocation,
              heading: heading,
              distanceToClient: distanceToClient,
            ),
          );
          _previousLocation = newLocation;
        }
      }
    });
  }

  void _stopUserMovementSimulation() {
    print('🛑 Stopping user movement simulation...');
    _simulationTimer?.cancel();
    _simulationTimer = null;
    print('✅ Simulation timer stopped and nulled');
  }

  Point _moveTowards(Point from, Point to, double distanceKm) {
    final totalDistance = _calculateDistance(from, to);

    // If very close to target (less than 10m), arrive at target
    if (totalDistance < 0.01) {
      return to; // Arrive at destination
    }

    // If remaining distance is less than movement distance, just arrive
    if (totalDistance <= distanceKm) {
      return to; // Complete the journey
    }

    // Move exactly distanceKm (100m) towards target
    final ratio = distanceKm / totalDistance;
    final lat = from.latitude + (to.latitude - from.latitude) * ratio;
    final lon = from.longitude + (to.longitude - from.longitude) * ratio;

    return Point(latitude: lat, longitude: lon);
  }

  // Move along the real route geometry by specified distance
  Point? _moveAlongRoute(double distanceKm) {
    if (state.routeGeometry == null || state.routeGeometry!.isEmpty) {
      return null;
    }

    final routePoints = state.routeGeometry!;

    // Start from current location, not from route index
    Point currentPoint = state.currentLocation ?? routePoints.first;
    double remainingDistance = distanceKm;
    int pointsToRemove = 0;

    // Find closest point on route to current location
    int startIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final dist = _calculateDistance(currentPoint, routePoints[i]);
      if (dist < minDistance) {
        minDistance = dist;
        startIndex = i;
      }
    }

    // Move through route points until we've covered the desired distance
    for (
      int i = startIndex;
      i < routePoints.length - 1 && remainingDistance > 0;
      i++
    ) {
      final nextPoint = routePoints[i + 1];
      final segmentDistance = _calculateDistance(currentPoint, nextPoint);

      if (segmentDistance <= remainingDistance) {
        // Move to next point completely
        remainingDistance -= segmentDistance;
        currentPoint = nextPoint;
        pointsToRemove = i + 1;
      } else {
        // Move partially to next point
        final ratio = remainingDistance / segmentDistance;
        currentPoint = Point(
          latitude:
              currentPoint.latitude +
              (nextPoint.latitude - currentPoint.latitude) * ratio,
          longitude:
              currentPoint.longitude +
              (nextPoint.longitude - currentPoint.longitude) * ratio,
        );
        remainingDistance = 0;
        pointsToRemove = i;
      }
    }

    // Trim passed route points (keep only future points)
    if (pointsToRemove > 0 && pointsToRemove < routePoints.length) {
      final remainingRoute = routePoints.sublist(pointsToRemove);

      // Only update if we actually moved
      if (currentPoint.latitude != state.currentLocation?.latitude ||
          currentPoint.longitude != state.currentLocation?.longitude) {
        print(
          '📍 Route progress: ${pointsToRemove}/${routePoints.length} points passed',
        );

        emit(
          state.copyWith(
            routeGeometry: remainingRoute,
            currentRouteIndex: 0, // Reset to 0 since we trimmed
          ),
        );
      }
    }

    return currentPoint;
  }

  // Waiting timer - starts when arrived at client (2 minutes free)
  void _startWaitingTimer() {
    _waitingTimer?.cancel();

    print('⏱️ Starting waiting timer...');
    emit(state.copyWith(isWaitingTimerActive: true, waitingSeconds: 0));

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Work during both waiting and in-progress statuses
      if (state.status != OrderStatus.waitingForClient &&
          state.status != OrderStatus.inProgress) {
        print('⏹️ Waiting timer stopped - Status: ${state.status}');
        timer.cancel();
        return;
      }

      final newWaitingSeconds = state.waitingSeconds + 1;
      print(
        '⏱️ Waiting: ${newWaitingSeconds}s (Status: ${state.status}) | Current price: ${state.currentPrice} som',
      );
      emit(state.copyWith(waitingSeconds: newWaitingSeconds));

      // After 2 minutes (120 seconds), start charging EVEN while waiting for client
      if (newWaitingSeconds > 120) {
        print('⚠️ Over 120 seconds! Calculating waiting charge...');
        final minutesOver = (newWaitingSeconds - 120) / 60.0;
        final waitingCharge = (minutesOver * 1000).round();
        print(
          '⏰ Minutes over: ${minutesOver.toStringAsFixed(2)}, Charge: $waitingCharge som',
        );

        // During waitingForClient: only waiting charge (no road cost yet)
        // During inProgress: distance tracking handles full price calculation
        if (state.status == OrderStatus.waitingForClient) {
          final totalPrice = 3000 + waitingCharge;
          final roundedPrice = ((totalPrice / 500).round() * 500).toInt();
          print(
            '💰 UPDATING PRICE: 3000 + $waitingCharge = $totalPrice → $roundedPrice som',
          );
          emit(state.copyWith(currentPrice: roundedPrice));
          print('✅ Price updated to: ${state.currentPrice} som');
        } else {
          print('ℹ️ InProgress status - distance tracking handles price');
        }
        // During inProgress, distance tracking handles price updates
      } else {
        print(
          '✅ Still in free 2 minutes (${120 - newWaitingSeconds}s remaining)',
        );
      }
    });
  }

  void _stopWaitingTimer() {
    print('🛑 Stopping waiting timer...');
    _waitingTimer?.cancel();
    _waitingTimer = null;
    emit(state.copyWith(isWaitingTimerActive: false, waitingSeconds: 0));
    print('✅ Waiting timer stopped and reset');
  }

  // Manual toggle waiting timer (user action - start or stop)
  void toggleWaitingTimer() {
    if (state.waitingSeconds == 0) {
      print('👤 User manually started waiting timer');
      _startWaitingTimer();
    } else {
      print('👤 User manually stopped waiting timer');
      _stopWaitingTimer();
    }
  }

  // Toggle timeout charging on/off
  void toggleTimeout() {
    emit(state.copyWith(isTimeoutEnabled: !state.isTimeoutEnabled));
  }

  // Distance tracking - simulates distance traveled during trip
  void _startDistanceTracking() {
    _distanceTimer?.cancel();

    print('🚗 Starting distance tracking...');

    _distanceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.status != OrderStatus.inProgress) {
        print('⏹️ Distance tracking stopped - Status: ${state.status}');
        timer.cancel();
        return;
      }

      // Add exactly 0.1 km (100m) every 5 seconds to match movement simulation
      final additionalDistance = 0.1;
      final newDistance = state.traveledDistance + additionalDistance;

      // Calculate price: 3000 base + 2500 per km + waiting charge (if applicable)
      final roadCost = (newDistance * 2500).round();

      // Calculate waiting charge (after 2 minutes, ALWAYS if timer is running)
      int waitingCharge = 0;
      if (state.waitingSeconds > 120) {
        final minutesOver = (state.waitingSeconds - 120) / 60.0;
        waitingCharge = (minutesOver * 1000).round();
        print(
          '💰 Waiting charge: $waitingCharge som (${state.waitingSeconds}s)',
        );
      }

      final totalPrice = 3000 + roadCost + waitingCharge;

      // Round to nearest 500 (2500, 3000, 3500, etc.)
      final roundedPrice = ((totalPrice / 500).round() * 500).toInt();

      print(
        '💵 Price update: Distance=${newDistance.toStringAsFixed(2)}km ($roadCost som) + Waiting=$waitingCharge som = $roundedPrice som',
      );

      emit(
        state.copyWith(
          traveledDistance: newDistance,
          currentPrice: roundedPrice,
        ),
      );
    });
  }

  void _stopDistanceTracking() {
    _distanceTimer?.cancel();
    _distanceTimer = null;
  }

  Future<void> _saveCompletedOrder(OrderModel order) async {
    try {
      // Get existing orders
      final ordersJson =
          await StorageHelper.getString('completed_orders') ?? '[]';
      final List<dynamic> ordersList = jsonDecode(ordersJson);

      // Add new order
      ordersList.insert(0, {
        'id': order.id,
        'clientName': order.clientName,
        'clientPhone': order.clientPhone,
        'pickupAddress': order.pickupAddress,
        'destinationAddress': order.destinationAddress,
        'distance': order.distance,
        'price': order.price,
        'createdAt': order.createdAt.toIso8601String(),
        'status': 'completed',
      });

      // Keep only last 50 orders
      if (ordersList.length > 50) {
        ordersList.removeRange(50, ordersList.length);
      }

      // Save back to storage
      await StorageHelper.saveString(
        'completed_orders',
        jsonEncode(ordersList),
      );
    } catch (e) {
      print('Error saving completed order: $e');
    }
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
    _waitingTimer?.cancel();
    _simulationTimer?.cancel();
    _distanceTimer?.cancel();
    return super.close();
  }
}
