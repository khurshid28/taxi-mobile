import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/order_bottom_sheet.dart';
import '../widgets/order_in_progress_widget.dart';
import '../widgets/searching_animation_widget.dart';
import '../widgets/cancel_trip_sheet.dart';
import '../widgets/trip_complete_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
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

          // Update map objects when state changes
          if (state.currentLocation != null) {
            _updateMapObjects(state);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
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
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
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
                    isWaitingForClient: state.status == OrderStatus.waitingForClient,
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
                  bottom: 220,
                  left: 20,
                  right: 20,
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Client ni oldim',
                      style: TextStyle(
                        fontSize: 18,
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _getStatusText(state.status),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (state.status == OrderStatus.initial)
              IconButton(
                onPressed: () {
                  context.read<HomeCubit>().startDrawingRoute();
                },
                icon: const Icon(Icons.search, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingIndicator() {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Zakaz kutilmoqda...',
                style: TextStyle(
                  fontSize: 16,
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
        return 'Yo\'nalish tanlang';
      case OrderStatus.drawingRoute:
        return 'Xaritada bosing';
      case OrderStatus.waitingForOrder:
        return 'Zakaz kutilmoqda...';
      case OrderStatus.orderReceived:
        return 'Yangi zakaz!';
      case OrderStatus.orderAccepted:
        return 'Zakaz qabul qilindi';
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
              image: BitmapDescriptor.fromAssetImage('assets/icons/location.png'),
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
            rotationType: RotationType.noRotation, // We handle rotation ourselves
          ),
        ),
      ),
    );
  }

  void _moveToLocation(Point point) {
    _mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: 15),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1),
    );
  }

  Future<void> _openGoogleMaps(HomeState state) async {
    if (state.currentLocation != null && state.destinationLocation != null) {
      final url = 'https://www.google.com/maps/dir/?api=1'
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

