import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/order_bottom_sheet.dart';
import '../widgets/order_in_progress_widget.dart';

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

              if (state.status == OrderStatus.inProgress)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: OrderInProgressWidget(
                    onComplete: () {
                      context.read<HomeCubit>().completeOrder();
                    },
                    onOpenMaps: () {
                      _openGoogleMaps(state);
                    },
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
      case OrderStatus.inProgress:
        return 'Yo\'lda';
      case OrderStatus.completed:
        return 'Tugatildi!';
    }
  }

  void _updateMapObjects(HomeState state) {
    _mapObjects.clear();

    // Add current location marker
    if (state.currentLocation != null) {
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('current_location'),
          point: state.currentLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/icons/car.png'),
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
}
