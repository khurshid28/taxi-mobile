import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/order_bottom_sheet.dart';
import '../widgets/order_in_progress_widget.dart';
import '../widgets/cancel_trip_sheet.dart';
import '../widgets/trip_complete_dialog.dart';
import '../widgets/home_shimmer_loading.dart';
import 'no_internet_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];
  Point? _lastCameraPosition;
  bool _hasMovedToInitialLocation = false;

  // Connectivity
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().initialize();

    // Connectivity listener
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      setState(() {
        _hasInternet =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);
      });
    });

    // Check initial connectivity
    Connectivity().checkConnectivity().then((results) {
      setState(() {
        _hasInternet =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show no internet page if no connectivity
    if (!_hasInternet) {
      return NoInternetPage(
        onRetry: () async {
          final results = await Connectivity().checkConnectivity();
          setState(() {
            _hasInternet =
                results.isNotEmpty &&
                !results.contains(ConnectivityResult.none);
          });
        },
      );
    }

    return Scaffold(
      body: BlocConsumer<HomeCubit, HomeState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: AppColors.error,
              ),
            );
          }

          // Move to initial location automatically when first determined
          if (state.currentLocation != null &&
              !_hasMovedToInitialLocation &&
              _mapController != null) {
            _moveToLocation(state.currentLocation!);
            _hasMovedToInitialLocation = true;
          }

          // Update map objects when state changes
          _updateMapObjects(state).then((_) {
            if (mounted) setState(() {});
          });
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Yandex Map
              YandexMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (state.currentLocation != null) {
                    _moveToLocation(state.currentLocation!);
                  }
                },
                mapObjects: _mapObjects,
                onCameraPositionChanged: (cameraPosition, reason, finished) {},
                onMapTap: (point) {
                  if (state.status == OrderStatus.initial) {
                    context.read<HomeCubit>().setDestination(point);
                  }
                },
                logoAlignment: const MapAlignment(
                  horizontal: HorizontalAlignment.right,
                  vertical: VerticalAlignment.bottom,
                ),
              ),

              // Top controls - show when online (and not completed) or in active status, but hide when going to client
              if (state.status != OrderStatus.goingToClient &&
                  ((state.isOnline && state.status != OrderStatus.completed) ||
                      (state.status != OrderStatus.initial &&
                          state.status != OrderStatus.completed)))
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10.h,
                  left: 16.w,
                  right: 16.w,
                  child: _buildTopControls(state),
                ),

              // Online status indicator
              if (state.isOnline && state.status == OrderStatus.initial)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16.h,
                  left: 20.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Liniya',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Online/Offline Slider - show when driver is offline and not in order
              if (!state.isOnline && state.status == OrderStatus.initial)
                Positioned(
                  bottom: 40.h,
                  left: 20.w,
                  right: 20.w,
                  child: SlideAction(
                    height: 60.h,
                    sliderButtonIconSize: 22.r,
                    sliderButtonIconPadding: 14.r,
                    borderRadius: 30.r,
                    innerColor: Colors.white,
                    outerColor: AppColors.primary,
                    sliderRotate: false,
                    animationDuration: const Duration(milliseconds: 300),
                    text: 'Liniyaga chiqish uchun suring',
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                    sliderButtonIcon: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 22.r,
                    ),
                    onSubmit: () {
                      context.read<HomeCubit>().toggleOnline();
                      return null;
                    },
                  ),
                ),

              // Offline Button - show when online
              if (state.isOnline && state.status == OrderStatus.initial)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16.h,
                  right: 20.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => context.read<HomeCubit>().toggleOnline(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.power_settings_new,
                            color: Colors.white,
                            size: 16.w,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Chiqish',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom sheet based on state
              if (state.status == OrderStatus.orderReceived &&
                  state.currentOrder != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: OrderBottomSheet(
                    order: state.currentOrder!,
                    onAccept: () {
                      context.read<HomeCubit>().acceptOrder();
                    },
                    onReject: () {
                      context.read<HomeCubit>().rejectOrder();
                    },
                  ),
                ),

              // Order in progress, waiting for client, or going to client widget
              if (state.status == OrderStatus.inProgress ||
                  state.status == OrderStatus.waitingForClient ||
                  state.status == OrderStatus.goingToClient)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: OrderInProgressWidget(
                    clientPhone: state.currentOrder?.clientPhone,
                    clientName: state.currentOrder?.clientName,
                    pickupAddress: state.currentOrder?.pickupAddress,
                    destinationAddress: state.currentOrder?.destinationAddress,
                    currentPrice: state.currentPrice,
                    traveledDistance: state.traveledDistance,
                    waitingSeconds: state.waitingSeconds,
                    distanceToClient: state.distanceToClient,
                    isWaitingForClient:
                        state.status == OrderStatus.waitingForClient,
                    isGoingToClient: state.status == OrderStatus.goingToClient,
                    isTimeoutEnabled: state.isTimeoutEnabled,
                    routeDurationMinutes: state.routeDurationMinutes,
                    routeDistanceKm: state.routeDistanceKm,
                    onComplete: () => _showCompleteDialog(state),
                    onCancel: () => _showCancelSheet(context),
                    onOpenMaps: () {
                      _openGoogleMaps(state);
                    },
                    onToggleTimeout: () {
                      context.read<HomeCubit>().toggleTimeout();
                    },
                    onStopWaitingTimer: () {
                      context.read<HomeCubit>().stopWaitingTimer();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⏹️ Kutish to\'xtatildi'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    onPickupClient: state.status == OrderStatus.waitingForClient
                        ? () {
                            context.read<HomeCubit>().markClientPickedUp();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Safar boshlandi! 🚗'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  ),
                ),

              // Floating Action Button - visible except when order received
              if (state.status != OrderStatus.orderReceived)
                Positioned(
                  bottom: 120.h,
                  right: 16.w,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16.r),
                    child: FloatingActionButton(
                      onPressed: () {
                        if (state.currentLocation != null &&
                            _mapController != null) {
                          _moveToLocation(state.currentLocation!);
                        }
                      },
                      backgroundColor: AppColors.primary,
                      elevation: 8,
                      child: Transform.rotate(
                        angle: 35 * 3.14159 / 180,
                        child: Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 24.w,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopControls(HomeState state) {
    final statusColor = _getStatusColor(state.status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 27.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.3),
                  blurRadius: 10.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Icon(
              _getStatusIcon(state.status),
              color: Colors.white,
              size: 20.w,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            _getStatusText(state.status),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (state.status == OrderStatus.inProgress &&
              state.currentPrice > 0) ...[
            SizedBox(width: 8.w),
            Text(
              NumberFormatter.formatPriceWithCurrency(state.currentPrice),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.initial:
      case OrderStatus.drawingRoute:
        return AppColors.primary;
      case OrderStatus.waitingForOrder:
        return const Color(0xFFFF9800);
      case OrderStatus.orderReceived:
        return const Color(0xFF2196F3);
      case OrderStatus.orderAccepted:
      case OrderStatus.goingToClient:
        return const Color(0xFF9C27B0);
      case OrderStatus.waitingForClient:
        return const Color(0xFFFF5722);
      case OrderStatus.inProgress:
        return const Color(0xFF4CAF50);
      case OrderStatus.completed:
        return const Color(0xFF00BCD4);
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.initial:
      case OrderStatus.drawingRoute:
        return Icons.check_circle_rounded;
      case OrderStatus.waitingForOrder:
        return Icons.hourglass_empty_rounded;
      case OrderStatus.orderReceived:
        return Icons.notifications_active_rounded;
      case OrderStatus.orderAccepted:
      case OrderStatus.goingToClient:
        return Icons.directions_car_rounded;
      case OrderStatus.waitingForClient:
        return Icons.person_pin_circle_rounded;
      case OrderStatus.inProgress:
        return Icons.navigation_rounded;
      case OrderStatus.completed:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.initial:
        return 'Hozircha buyurtma yo\'q';
      case OrderStatus.drawingRoute:
        return 'Yo\'l chizilmoqda...';
      case OrderStatus.waitingForOrder:
        return 'Hozircha buyurtma yo\'q'; // Won't be used anymore
      case OrderStatus.orderReceived:
        return 'Yangi buyurtma!';
      case OrderStatus.orderAccepted:
        return 'Buyurtma qabul qilindi';
      case OrderStatus.goingToClient:
        return 'Mijozga ketilmoqda';
      case OrderStatus.waitingForClient:
        return 'Mijozni kutmoqda';
      case OrderStatus.inProgress:
        return 'Yo\'lda';
      case OrderStatus.completed:
        return 'Tugatildi!';
    }
  }

  Future<void> _updateMapObjects(HomeState state) async {
    // Remove old objects
    _mapObjects.removeWhere(
      (obj) =>
          obj.mapId.value == 'current_location' ||
          obj.mapId.value.toString().startsWith('current_location_'),
    );

    // Add current location marker (user) with rotation - navigation arrow
    if (state.currentLocation != null) {
      await _addUserLocationMarker(state.currentLocation!, state.heading);
    }

    // Remove old route polyline
    _mapObjects.removeWhere((obj) => obj.mapId.value == 'route_polyline');

    // Add route polyline if we have route geometry
    if (state.routeGeometry != null && state.routeGeometry!.isNotEmpty) {
      print('🗺️ Drawing route: ${state.routeGeometry!.length} points');
      _mapObjects.add(
        PolylineMapObject(
          mapId: const MapObjectId('route_polyline'),
          polyline: Polyline(points: state.routeGeometry!),
          strokeColor: const Color(0xFF2196F3), // Material Blue
          strokeWidth: 5.0,
          outlineColor: Colors.white,
          outlineWidth: 1.5,
          dashLength: 0,
          dashOffset: 0,
          gapLength: 0,
        ),
      );
    } else {
      print('❌ No route geometry available');
    }

    // Remove client marker if order completed, initial state, when going offline, or client picked up
    if (state.status == OrderStatus.completed ||
        state.status == OrderStatus.initial ||
        !state.isOnline ||
        state.currentOrder == null ||
        state.status == OrderStatus.inProgress) {
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'client_location');
    }

    // Add client location marker ONLY if going to client or waiting
    if (state.currentOrder != null &&
        state.isOnline &&
        (state.status == OrderStatus.goingToClient ||
            state.status == OrderStatus.waitingForClient) &&
        !_mapObjects.any((obj) => obj.mapId.value == 'client_location')) {
      await _addClientLocationMarker(state.currentOrder!.pickupLocation);
    }

    // Remove old destination marker
    _mapObjects.removeWhere((obj) => obj.mapId.value == 'destination');

    // Add destination marker (finish flag) when in progress
    if (state.destinationLocation != null &&
        state.status == OrderStatus.inProgress) {
      await _addDestinationMarker(state.destinationLocation!);
    }
  }

  Future<void> _addDestinationMarker(Point location) async {
    // Create custom finish flag marker
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 120.0;

    // Draw flag pole (black)
    final polePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(size * 0.45, size * 0.2, size * 0.08, size * 0.7),
      polePaint,
    );

    // Draw flag (checkered pattern - green and white)
    final flagPaint1 = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    final flagPaint2 = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Checkered flag pattern
    final squareSize = size * 0.08;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final paint = (row + col) % 2 == 0 ? flagPaint1 : flagPaint2;
        canvas.drawRect(
          Rect.fromLTWH(
            size * 0.15 + col * squareSize,
            size * 0.2 + row * squareSize,
            squareSize,
            squareSize,
          ),
          paint,
        );
      }
    }

    // Draw flag border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(size * 0.15, size * 0.2, size * 0.24, size * 0.24),
      borderPaint,
    );

    // Draw shadow circle at base
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size * 0.49, size * 0.9),
      size * 0.15,
      shadowPaint,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    _mapObjects.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('destination'),
        point: location,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromBytes(buffer),
            scale: 1.3,
          ),
        ),
      ),
    );
  }

  Future<void> _addUserLocationMarker(Point location, double heading) async {
    // Create a simple canvas-based marker with the primary color
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 100.0;

    // Save canvas state
    canvas.save();

    // Move to center and rotate
    canvas.translate(size / 2, size / 2);
    canvas.rotate(heading * 3.14159 / 180); // Convert degrees to radians
    canvas.translate(-size / 2, -size / 2);

    // Draw navigation arrow shape
    final paint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size / 2, size * 0.15) // Top point (sharper)
      ..lineTo(size * 0.25, size * 0.85) // Bottom left (wider)
      ..lineTo(size / 2, size * 0.65) // Center bottom
      ..lineTo(size * 0.75, size * 0.85) // Bottom right (wider)
      ..close();

    canvas.drawPath(path, paint);

    // Draw thick white border for visibility
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(path, borderPaint);

    // Draw inner shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, shadowPaint);

    // Restore canvas
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    _mapObjects.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('current_location'),
        point: location,
        opacity: 1.0,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromBytes(buffer),
            scale: 1.2,
            rotationType:
                RotationType.noRotation, // We handle rotation ourselves
          ),
        ),
      ),
    );
  }

  void _moveToLocation(Point point) {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 16)),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.5,
      ),
    );
  }

  Future<void> _addClientLocationMarker(Point location) async {
    // Create custom client marker with bright red pin
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 120.0;

    // Draw red circle with white border
    final circlePaint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 3, circlePaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 3, borderPaint);

    // Draw person icon in center
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw head
    canvas.drawCircle(Offset(size / 2, size / 2.5), size / 10, iconPaint);

    // Draw body (simple rectangle)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size / 2, size / 1.6),
          width: size / 4,
          height: size / 3.5,
        ),
        Radius.circular(size / 20),
      ),
      iconPaint,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    _mapObjects.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('client_location'),
        point: location,
        opacity: 1.0,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromBytes(buffer),
            scale: 1.0,
          ),
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(HomeState state) async {
    if (state.currentLocation == null) return;

    String url;

    // If going to client, show route to pickup location
    if (state.status == OrderStatus.goingToClient &&
        state.currentOrder?.pickupLocation != null) {
      url =
          'https://www.google.com/maps/dir/?api=1'
          '&origin=${state.currentLocation!.latitude},${state.currentLocation!.longitude}'
          '&destination=${state.currentOrder!.pickupLocation.latitude},${state.currentOrder!.pickupLocation.longitude}'
          '&travelmode=driving';
    }
    // If in progress, show full route: current -> destination
    else if (state.destinationLocation != null) {
      // Build waypoints string for better route visualization
      String waypoints = '';
      if (state.currentOrder?.pickupLocation != null) {
        waypoints =
            '&waypoints=${state.currentOrder!.pickupLocation.latitude},${state.currentOrder!.pickupLocation.longitude}';
      }

      url =
          'https://www.google.com/maps/dir/?api=1'
          '&origin=${state.currentLocation!.latitude},${state.currentLocation!.longitude}'
          '&destination=${state.destinationLocation!.latitude},${state.destinationLocation!.longitude}'
          '$waypoints'
          '&travelmode=driving';
    } else {
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Try with platformDefault mode
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // Last attempt: try Android intent URL
      try {
        final intentUrl = url.replaceFirst('https://', 'geo:0,0?q=');
        final intentUri = Uri.parse(intentUrl);
        await launchUrl(intentUri);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Maps ni ochib bo\'lmadi')),
          );
        }
      }
    }
  }

  void _showCancelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CancelTripSheet(
        onCancel: () {
          context.read<HomeCubit>().completeOrder();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Safar bekor qilindi'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }

  void _showCompleteDialog(HomeState state) {
    // Calculate trip duration (mock - in real app this would be tracked)
    final duration = (state.traveledDistance * 3).round(); // ~3 minutes per km

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TripCompleteDialog(
        totalPrice: state.currentPrice,
        distance: state.traveledDistance,
        duration: duration,
      ),
    ).then((_) {
      // Complete the order after dialog closes
      context.read<HomeCubit>().completeOrder();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
