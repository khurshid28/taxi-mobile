import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/order_bottom_sheet.dart';
import '../widgets/order_in_progress_widget.dart';
import '../widgets/searching_animation_widget.dart';
import '../widgets/cancel_trip_sheet.dart';
import '../widgets/trip_complete_dialog.dart';
import '../widgets/home_shimmer_loading.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return FloatingActionButton(
            onPressed: () {
              if (state.currentLocation != null && _mapController != null) {
                _moveToLocation(state.currentLocation!);
              }
            },
            backgroundColor: AppColors.primary,
            child: Icon(Icons.my_location, color: Colors.white, size: 28.w),
          );
        },
      ),
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

          // Update map objects when state changes
          if (state.currentLocation != null) {
            _updateMapObjects(state);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: HomeShimmerLoading(),
            );
          }

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
              ),

              // Top controls
              Positioned(
                top: MediaQuery.of(context).padding.top + 16.h,
                left: 16.w,
                right: 16.w,
                child: _buildTopControls(state),
              ),

              // Waiting for order animation
              if (state.status == OrderStatus.waitingForOrder)
                const Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: SearchingAnimationWidget(
                    text: 'Buyurtma kutilmoqda...',
                    icon: Icons.hourglass_empty,
                  ),
                ),

              // Going to client animation
              if (state.status == OrderStatus.goingToClient)
                const Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: SearchingAnimationWidget(
                    text: 'Clientga qarab ketilmoqda...',
                    icon: Icons.directions_car,
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

              // Order in progress or waiting for client widget
              if (state.status == OrderStatus.inProgress ||
                  state.status == OrderStatus.waitingForClient)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: OrderInProgressWidget(
                    clientPhone: state.currentOrder?.clientPhone,
                    currentPrice: state.currentPrice,
                    traveledDistance: state.traveledDistance,
                    waitingSeconds: state.waitingSeconds,
                    isWaitingForClient:
                        state.status == OrderStatus.waitingForClient,
                    onComplete: () => _showCompleteDialog(state),
                    onCancel: () => _showCancelSheet(context),
                    onOpenMaps: () {
                      _openGoogleMaps(state);
                    },
                  ),
                ),

              // Show client pickup button when close to client
              if (state.distanceToClient != null &&
                  state.distanceToClient! <= 50 &&
                  !state.clientPickedUp &&
                  state.status == OrderStatus.goingToClient)
                Positioned(
                  bottom: 220.h,
                  left: 20.w,
                  right: 20.w,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<HomeCubit>().markClientPickedUp();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Client ni oldim'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Client ni oldim',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Waiting indicator
              if (state.status == OrderStatus.waitingForOrder)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: _buildWaitingIndicator(),
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
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 2.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.3),
                  blurRadius: 12.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Icon(
              _getStatusIcon(state.status),
              color: Colors.white,
              size: 24.w,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(state.status),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (state.status == OrderStatus.inProgress &&
                    state.currentPrice > 0) ...[
                  SizedBox(height: 4.h),
                  Text(
                    NumberFormatter.formatPriceWithCurrency(state.currentPrice),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (state.status == OrderStatus.waitingForOrder)
            SizedBox(
              width: 20.w,
              height: 20.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.5.w,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
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

  Widget _buildWaitingIndicator() {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24.w,
                height: 24.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              SizedBox(width: 16.w),
              Text(
                'Buyurtma kutilmoqda...',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.initial:
        return 'Hozirda buyurtma yo\'q';
      case OrderStatus.drawingRoute:
        return 'Yo\'l chizilmoqda...';
      case OrderStatus.waitingForOrder:
        return 'Buyurtma kutilmoqda...';
      case OrderStatus.orderReceived:
        return 'Yangi buyurtma!';
      case OrderStatus.orderAccepted:
        return 'Buyurtma qabul qilindi';
      case OrderStatus.goingToClient:
        return 'Clientga ketilmoqda';
      case OrderStatus.waitingForClient:
        return 'Client kutilmoqda';
      case OrderStatus.inProgress:
        return 'Yo\'lda';
      case OrderStatus.completed:
        return 'Tugatildi!';
    }
  }

  void _updateMapObjects(HomeState state) {
    _mapObjects.clear();

    // Add current location marker (user) with rotation - navigation arrow
    if (state.currentLocation != null) {
      _addUserLocationMarker(state.currentLocation!, state.heading);
    }

    // Add client location marker if order exists
    if (state.currentOrder != null) {
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('client_location'),
          point: state.currentOrder!.pickupLocation,
          opacity: 0.9,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                'assets/icons/location.png',
              ),
              scale: 0.5,
            ),
          ),
        ),
      );
    }

    // Add destination marker
    if (state.destinationLocation != null) {
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('destination'),
          point: state.destinationLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/icons/pin.png'),
              scale: 0.5,
            ),
          ),
        ),
      );
    }

    // Add route polyline
    if (state.routePoints.isNotEmpty) {
      _mapObjects.add(
        PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: state.routePoints),
          strokeColor: AppColors.primary,
          strokeWidth: 4,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _addUserLocationMarker(Point location, double heading) async {
    // Create a simple canvas-based marker with the primary color
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 48.0;

    // Save canvas state
    canvas.save();

    // Move to center and rotate
    canvas.translate(size / 2, size / 2);
    canvas.rotate(heading * 3.14159 / 180); // Convert degrees to radians
    canvas.translate(-size / 2, -size / 2);

    // Draw navigation arrow shape
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size / 2, size * 0.2) // Top point
      ..lineTo(size * 0.3, size * 0.8) // Bottom left
      ..lineTo(size / 2, size * 0.65) // Center bottom
      ..lineTo(size * 0.7, size * 0.8) // Bottom right
      ..close();

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);

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
            scale: 1.0,
            rotationType:
                RotationType.noRotation, // We handle rotation ourselves
          ),
        ),
      ),
    );
  }

  void _moveToLocation(Point point) {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 15)),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1),
    );
  }

  Future<void> _openGoogleMaps(HomeState state) async {
    if (state.currentLocation != null && state.destinationLocation != null) {
      final url =
          'https://www.google.com/maps/dir/?api=1'
          '&origin=${state.currentLocation!.latitude},${state.currentLocation!.longitude}'
          '&destination=${state.destinationLocation!.latitude},${state.destinationLocation!.longitude}'
          '&travelmode=driving';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
}
