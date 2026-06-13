import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_messenger.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/network/mercure_service.dart';
import '../../../../injection_container.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/order_bottom_sheet.dart';
import '../widgets/order_in_progress_widget.dart';
import '../widgets/collapsible_sheet.dart';
import '../widgets/cancel_trip_sheet.dart';
import '../widgets/trip_complete_dialog.dart';
import '../widgets/slide_to_online_button.dart';
import 'no_internet_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];
  bool _hasMovedToInitialLocation = false;
  Point? _lastMarkerLocation; // Track last GPS marker position
  // Mijozga yo'l olishda kamerani (haydovchi + mijoz) bir marta moslash uchun.
  String? _fittedClientOrderId;

  // Marshrut chizig'i (polyline) geometriyasining OXIRGI havolasi. Polyline'ni
  // FAQAT geometriya o'zgarganda qayta quramiz — har lokatsiya yangilanishida
  // (har 10s) emas. Aks holda uzun marshrutni native xarita har safar qayta
  // tessellatsiya qilib (qayta chizib) app QOTARDI. Mijozga yo'l olishda
  // marshrut bir marta yuklanadi, keyin o'zgarmaydi — shuning uchun bir marta
  // chizilib, keyin tegilmaydi.
  List<Point>? _lastRouteGeometryRef;

  // Xarita obyektlari (marker/polyline) faqat O'ZI yangilanishi uchun.
  // Bu o'zgarsa butun sahifa emas, faqat YandexMap o'ralgan
  // ValueListenableBuilder qayta quriladi (silliq, qotmaydi).
  final ValueNotifier<List<MapObject>> _mapObjectsListenable =
      ValueNotifier<List<MapObject>>(const []);

  // Marker rasmlari (PNG) bir marta chizilib keshlanadi. PNG kodlash qimmat —
  // har yangilanishda qayta chizilsa xarita qotadi. Faqat point o'zgaradi.
  Uint8List? _userMarkerBitmap;
  Uint8List? _clientMarkerBitmap;

  // Connectivity
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  // Mercure real-time ulanish holati (banner uchun).
  MercureStatus _mercureStatus = MercureStatus.disconnected;
  VoidCallback? _mercureStatusListener;
  bool _hadDisconnect = false; // online paytida aloqa uzilganmi
  bool _showReconnected = false; // "Aloqa tiklandi" ni qisqa ko'rsatish
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().initialize();

    // Marker rasmlarini oldindan bir marta tayyorlab keshlaymiz — safar
    // boshlangach birinchi yangilanish ham darhol, qotmasdan ko'rinadi.
    _prewarmMarkers();

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

    // Mercure ulanish holatini kuzatamiz: uzilsa banner, tiklansa qisqa tasdiq.
    final svc = sl<MercureService>();
    _mercureStatus = svc.status.value;
    _mercureStatusListener = () {
      if (!mounted) return;
      final s = svc.status.value;
      final online = context.read<HomeCubit>().state.isOnline;
      if (!online) {
        _hadDisconnect = false;
      } else if (s == MercureStatus.disconnected) {
        _hadDisconnect = true;
      } else if (s == MercureStatus.connected && _hadDisconnect) {
        _hadDisconnect = false;
        _showReconnected = true;
        _reconnectedTimer?.cancel();
        _reconnectedTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showReconnected = false);
        });
      }
      setState(() => _mercureStatus = s);
    };
    svc.status.addListener(_mercureStatusListener!);
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
        // Xarita obyektlarini (marker/polyline) YANGILASH qimmat (canvas bilan
        // PNG chizish). Uni faqat XARITAGA taalluqli maydon o'zgarganda
        // bajaramiz. Aks holda safar vaqti / kutish hisoblagichi har sekund
        // state emit qilgani uchun har sekund qayta chizilib app qotardi.
        listenWhen: (prev, curr) =>
            prev.error != curr.error ||
            prev.currentLocation != curr.currentLocation ||
            prev.routeGeometry != curr.routeGeometry ||
            prev.status != curr.status ||
            prev.isOnline != curr.isOnline ||
            prev.currentOrder?.id != curr.currentOrder?.id,
        listener: (context, state) {
          if (state.error != null) {
            AppMessenger.error(context, state.error!);
            // Xatoni DARHOL tozalaymiz — aks holda har lokatsiya yangilanishida
            // (har ~10s) listener qayta ishlab, toast qayta-qayta chiqib
            // (yo'qolmay) xarita ustida qotardi. Bir marta ko'rsatib, tozalaymiz.
            context.read<HomeCubit>().clearError();
          }

          // Move to initial location automatically when first determined
          if (state.currentLocation != null &&
              !_hasMovedToInitialLocation &&
              _mapController != null) {
            _moveToLocation(state.currentLocation!);
            _hasMovedToInitialLocation = true;
          }

          // Mijozga yo'l olishda — haydovchi va mijozni bitta ekranga sig'dirib
          // ko'rsatamiz (har buyurtma uchun bir marta; keyin haydovchi o'zi
          // suradi/zumlaydi). Shunda mijoz markeri va yo'l darhol ko'rinadi.
          final fitOrder = state.currentOrder;
          if (fitOrder != null &&
              state.status == OrderStatus.goingToClient &&
              state.currentLocation != null &&
              _mapController != null &&
              _fittedClientOrderId != fitOrder.id) {
            _fittedClientOrderId = fitOrder.id;
            _fitTwoPoints(state.currentLocation!, fitOrder.pickupLocation);
          }
          if (state.status == OrderStatus.initial) {
            _fittedClientOrderId = null;
          }

          // Update map objects when state changes (no setState needed)
          _updateMapObjects(state);
        },
        // Butun sahifani (xarita + ustki kartalar) faqat TUZILMAVIY o'zgarishda
        // qayta quramiz. Safar/kutish hisoblagichi har sekund state emit qiladi,
        // lekin u faqat soniya/narx/masofani o'zgartiradi — shu sabab bu yerga
        // KIRMAYDI. Aks holda har sekund native xarita qayta qurilib app qotardi.
        // Butun sahifa faqat TUZILMAVIY o'zgarishda quriladi (status/online/
        // buyurtma). Joylashuv (currentLocation) va marshrut (routeGeometry)
        // bu yerda YO'Q — ular xaritani _mapObjectsListenable orqali alohida
        // yangilaydi, butun sahifani emas. Shu sabab Yo'lda payti qotmaydi.
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.isOnline != curr.isOnline ||
            prev.currentOrder?.id != curr.currentOrder?.id,
        builder: (context, state) {
          // Mercure banner: online bo'lib, ulanish hali tiklanmagan bo'lsa
          // (yoki endigina tiklangan bo'lsa) tepada ko'rsatamiz.
          final showReconnecting =
              state.isOnline && _mercureStatus != MercureStatus.connected;
          final showReconnected = state.isOnline &&
              _showReconnected &&
              _mercureStatus == MercureStatus.connected;
          final bannerVisible = showReconnecting || showReconnected;
          final topInset = MediaQuery.of(context).padding.top + 10.h;

          return Stack(
            children: [
              // Yandex Map — faqat O'ZI yangilanadi (ValueListenableBuilder).
              // Xarita obyektlari o'zgarsa butun sahifa emas, shu blok quriladi.
              ValueListenableBuilder<List<MapObject>>(
                valueListenable: _mapObjectsListenable,
                builder: (context, mapObjects, _) => YandexMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    final loc =
                        context.read<HomeCubit>().state.currentLocation;
                    if (loc != null) _moveToLocation(loc);
                  },
                  mapObjects: mapObjects,
                  onCameraPositionChanged:
                      (cameraPosition, reason, finished) {},
                  onMapTap: (point) {
                    if (context.read<HomeCubit>().state.status ==
                        OrderStatus.initial) {
                      context.read<HomeCubit>().setDestination(point);
                    }
                  },
                  logoAlignment: const MapAlignment(
                    horizontal: HorizontalAlignment.right,
                    vertical: VerticalAlignment.bottom,
                  ),
                ),
              ),

              // Top controls - active order states only (initial/online-idle
              // uses the dedicated Liniya card below). Hidden while going to client.
              if (state.status != OrderStatus.goingToClient &&
                  state.status != OrderStatus.initial &&
                  state.status != OrderStatus.completed)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10.h,
                  left: 16.w,
                  right: 16.w,
                  // Narx/holat matni jonli bo'lsin, lekin xaritani qurmasin.
                  child: BlocBuilder<HomeCubit, HomeState>(
                    builder: (context, state) => _buildTopControls(state),
                  ),
                ),

              // Online (Liniya) status card — single clean header with Chiqish
              if (state.isOnline && state.status == OrderStatus.initial)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: topInset + (bannerVisible ? 56.h : 0),
                  left: 16.w,
                  right: 16.w,
                  child: _buildOnlineIdleCard(context),
                ),

              // Go online button - show when driver is offline and not in order
              if (!state.isOnline && state.status == OrderStatus.initial)
                Positioned(
                  bottom: 40.h,
                  left: 20.w,
                  right: 20.w,
                  child: _buildGoOnlineButton(context),
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
                    price: context
                        .read<HomeCubit>()
                        .resolveOrderBasePrice(state.currentOrder!),
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
                  // Faqat pastga mahkamlanadi (top YO'Q) — aks holda top:0+bottom:0
                  // qattiq to'liq balandlik berib, varaqning maxHeight:0.74.sh
                  // cheklovini bekor qilardi va u butun ekranni qoplab qotardi.
                  bottom: 0,
                  left: 0,
                  right: 0,
                  // Timer/narx/masofa matni shu ichki BlocBuilder orqali har
                  // sekund yangilanadi — tashqi builder (xarita) qayta qurilmaydi.
                  child: BlocBuilder<HomeCubit, HomeState>(
                    builder: (context, state) => CollapsibleSheet(
                      child: OrderInProgressWidget(
                    clientPhone: state.currentOrder?.clientPhone,
                    clientName: state.currentOrder?.clientName,
                    pickupAddress: state.currentOrder?.pickupAddress,
                    destinationAddress: state.currentOrder?.destinationAddress,
                    currentPrice: state.currentPrice,
                    traveledDistance: state.traveledDistance,
                    waitingSeconds: state.waitingSeconds,
                    tripSeconds: state.tripSeconds,
                    isWaitingTimerActive: state.isWaitingTimerActive,
                    distanceToClient: state.distanceToClient,
                    isWaitingForClient:
                        state.status == OrderStatus.waitingForClient,
                    isGoingToClient: state.status == OrderStatus.goingToClient,
                    isTimeoutEnabled: state.isTimeoutEnabled,
                    routeDurationMinutes: state.routeDurationMinutes,
                    routeDistanceKm: state.routeDistanceKm,
                    onComplete: () => _showCompleteDialog(state),
                    onCancel: () => _showCancelSheet(context),
                    onOpenMaps: state.currentOrder != null
                        ? () => _openClientInMaps(
                            state.currentOrder!.pickupLocation)
                        : null,
                    onArrived: () {
                      context.read<HomeCubit>().arrivedAtClient();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mijoz oldiga yetib keldingiz 📍'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    onToggleTimeout: () {
                      context.read<HomeCubit>().toggleTimeout();
                    },
                    onToggleWaitingTimer: () {
                      final cubit = context.read<HomeCubit>();
                      final isStarting = !cubit.state.isWaitingTimerActive;

                      cubit.toggleWaitingTimer();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isStarting
                                ? '⏱️ Kutish boshlandi'
                                : '⏹️ Kutish to\'xtatildi',
                          ),
                          duration: const Duration(seconds: 2),
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
                  ),
                ),

              // Floating Action Button - visible except when order received
              if (state.status != OrderStatus.orderReceived)
                Positioned(
                  bottom: 120.h,
                  right: 16.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // My location button
                      Container(
                        width: 54.w,
                        height: 54.w,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.18),
                            width: 1.5.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.18),
                              blurRadius: 16.r,
                              offset: Offset(0, 6.h),
                              spreadRadius: -2.w,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              final loc = context
                                  .read<HomeCubit>()
                                  .state
                                  .currentLocation;
                              if (loc != null && _mapController != null) {
                                _moveToLocation(loc);
                              }
                            },
                            child: Center(
                              child: Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                                size: 25.w,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Mercure ulanish banneri (eng ustda chiziladi)
              if (state.status == OrderStatus.initial ||
                  state.status == OrderStatus.orderReceived)
                Positioned(
                  top: topInset,
                  left: 16.w,
                  right: 16.w,
                  child: IgnorePointer(
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      offset: bannerVisible ? Offset.zero : Offset(0, -1.6),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: bannerVisible ? 1 : 0,
                        child: _buildMercureBanner(reconnecting: showReconnecting),
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

  /// Mercure real-time ulanish banneri. Aloqa uzilganda (yoki qayta ulanayotganda)
  /// to'q sariq, endigina tiklanganda yashil ko'rinadi. Avtomatik qayta ulanish
  /// MercureService ichida bo'ladi — bu faqat haydovchiga holatni bildiradi.
  Widget _buildMercureBanner({required bool reconnecting}) {
    final color = reconnecting ? AppColors.warning : AppColors.success;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 16.r,
            offset: Offset(0, 6.h),
            spreadRadius: -2.w,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20.w,
            height: 20.w,
            child: reconnecting
                ? Icon(Iconsax.refresh, color: Colors.white, size: 20.w)
                : Icon(Iconsax.tick_circle, color: Colors.white, size: 20.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              reconnecting
                  ? 'Aloqa uzildi — qayta ulanmoqda…'
                  : 'Aloqa tiklandi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Icon(
            reconnecting ? Iconsax.wifi : Iconsax.wifi_square,
            color: Colors.white.withOpacity(0.9),
            size: 18.w,
          ),
        ],
      ),
    );
  }

  /// Liniyada (online) va buyurtma kutilayotgan holatdagi yagona, toza karta.
  /// Status ikonkasi + "Liniyadasiz" + "Hozircha buyurtma yo'q" + Chiqish tugmasi.
  Widget _buildOnlineIdleCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Icon(
              Iconsax.tick_circle,
              color: Colors.white,
              size: 22.w,
            ),
          ),
          SizedBox(width: 12.w),
          // Title + subtitle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liniyadasiz',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Hozircha buyurtma yo\'q',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Chiqish (go offline) button
          Material(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () => context.read<HomeCubit>().toggleOnline(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
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
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Liniyaga chiqish uchun silliq surish tugmasi.
  Widget _buildGoOnlineButton(BuildContext context) {
    return SlideToOnlineButton(
      text: 'Liniyaga chiqish',
      onConfirmed: () => context.read<HomeCubit>().toggleOnline(),
    );
  }

  Widget _buildTopControls(HomeState state) {
    final statusColor = _getStatusColor(state.status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 27.5.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
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
                color: AppColors.textSecondary,
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
        return Iconsax.tick_circle;
      case OrderStatus.waitingForOrder:
        return Iconsax.clock;
      case OrderStatus.orderReceived:
        return Iconsax.notification_bing;
      case OrderStatus.orderAccepted:
      case OrderStatus.goingToClient:
        return Iconsax.car;
      case OrderStatus.waitingForClient:
        return Iconsax.location;
      case OrderStatus.inProgress:
        return Iconsax.gps;
      case OrderStatus.completed:
        return Iconsax.tick_circle;
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
    // Always show the real GPS location marker and update it when the
    // driver actually moves (no simulation / no camera auto-follow).
    final loc = state.currentLocation;
    if (loc != null &&
        (_lastMarkerLocation == null ||
            _lastMarkerLocation!.latitude != loc.latitude ||
            _lastMarkerLocation!.longitude != loc.longitude)) {
      // Marker rasmini avval tayyorlab, keyin eski->yangi atomik almashtiramiz
      // (rasm tayyorlangunча eski marker ro'yxatda qoladi => o'chib-yonmaydi).
      await _addUserLocationMarker(loc, state.heading);
      _lastMarkerLocation = loc;
    }

    // Marshrut chizig'i (polyline) — FAQAT geometriya O'ZGARGANDA qayta
    // quramiz. Har lokatsiya yangilanishida (har 10s) qayta yaratsak, uzun
    // marshrutni native xarita har safar qayta tessellatsiya qilib QOTARDI.
    // `identical` bilan havolani solishtiramiz: yangi marshrut yuklansa yoki
    // tozalansa (null/[]) havola o'zgaradi — faqat shunda qayta quramiz.
    if (!identical(state.routeGeometry, _lastRouteGeometryRef)) {
      _lastRouteGeometryRef = state.routeGeometry;
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'route_polyline');
      if (state.routeGeometry != null && state.routeGeometry!.isNotEmpty) {
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
      }
    }

    // Remove client marker if order completed, initial state, when going offline, or client picked up
    // Also remove during inProgress to clean up after "Qani ketdik"
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

    // Manzil markeri (finish flag) endi chizilmaydi — boradigan manzil aniq
    // emas. Haydovchi borib yetgach "Tugatish" tugmasi bilan yakunlaydi.
    // (Eski marker qolib ketgan bo'lsa, tozalab qo'yamiz.)
    _mapObjects.removeWhere((obj) => obj.mapId.value == 'destination');

    // Yangilangan obyektlarni xaritaga e'lon qilamiz — faqat YandexMap
    // o'ralgan ValueListenableBuilder qayta quriladi, butun sahifa emas.
    _mapObjectsListenable.value = List.of(_mapObjects);
  }

  /// Marker rasmlarini oldindan keshlash (PNG kodlash bir marta bo'ladi).
  Future<void> _prewarmMarkers() async {
    await _userMarkerBytes();
    await _clientMarkerBytes();
  }

  Future<void> _addUserLocationMarker(Point location, double heading) async {
    final buffer = await _userMarkerBytes();
    final marker = PlacemarkMapObject(
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
    );

    // Rasm tayyor bo'lgach, eski markerni o'chirib yangisini qo'shamiz.
    // Shu tartibda marker hech qachon ro'yxatdan yo'qolmaydi (blink yo'q).
    _mapObjects.removeWhere(
      (obj) =>
          obj.mapId.value == 'current_location' ||
          obj.mapId.value.toString().startsWith('current_location_'),
    );
    _mapObjects.add(marker);
  }

  /// Haydovchi joylashuvi markeri rasmi — bir marta chizilib keshlanadi.
  Future<Uint8List> _userMarkerBytes() async {
    if (_userMarkerBitmap != null) return _userMarkerBitmap!;
    // Create a red circle marker with light red outer ring
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 80.0; // Larger for outer ring

    final center = Offset(size / 2, size / 2);
    final radius = size / 5;

    // Draw outer light red circle (wider)
    final outerRingPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 2.2, outerRingPaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 3, borderPaint);

    // Draw inner circle (red)
    final innerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, innerPaint);

    // Draw white dot in center
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius / 3, dotPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    _userMarkerBitmap = byteData!.buffer.asUint8List();
    return _userMarkerBitmap!;
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

  /// Ikki nuqtani (haydovchi + mijoz) bitta ekranga sig'dirib ko'rsatadi.
  void _fitTwoPoints(Point a, Point b) {
    final south = math.min(a.latitude, b.latitude);
    final north = math.max(a.latitude, b.latitude);
    final west = math.min(a.longitude, b.longitude);
    final east = math.max(a.longitude, b.longitude);
    final latPad = (north - south).abs() * 0.35 + 0.0025;
    final lngPad = (east - west).abs() * 0.35 + 0.0025;
    _mapController?.moveCamera(
      CameraUpdate.newBounds(
        BoundingBox(
          southWest: Point(latitude: south - latPad, longitude: west - lngPad),
          northEast: Point(latitude: north + latPad, longitude: east + lngPad),
        ),
      ),
      animation:
          const MapAnimation(type: MapAnimationType.smooth, duration: 0.6),
    );
  }

  /// Mijoz nuqtasiga tashqi navigatsiya (xarita ilovasi) ochadi. Mijoz
  /// koordinatasi aniq bo'lgani uchun bu bosqichda foydali.
  Future<void> _openClientInMaps(Point p) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${p.latitude},${p.longitude}&travelmode=driving',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _addClientLocationMarker(Point location) async {
    final buffer = await _clientMarkerBytes();
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

  /// Mijoz markeri rasmi — bir marta chizilib keshlanadi.
  Future<Uint8List> _clientMarkerBytes() async {
    if (_clientMarkerBitmap != null) return _clientMarkerBitmap!;
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
    _clientMarkerBitmap = byteData!.buffer.asUint8List();
    return _clientMarkerBitmap!;
  }

  void _showCancelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => CancelTripSheet(
        onCancel: () {
          // Bekor qilish = buyurtmani RAD etish (tugatish EMAS). Avval
          // xatolik bor edi: completeOrder() chaqirilardi va safar yakunlangan
          // deb hisoblanardi.
          context.read<HomeCubit>().rejectOrder();
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
    // Haqiqiy safar davomiyligi (daqiqa) - tripSeconds asosida
    int duration = (state.tripSeconds / 60).round();
    if (duration < 1) duration = 1;

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
    _reconnectedTimer?.cancel();
    if (_mercureStatusListener != null) {
      sl<MercureService>().status.removeListener(_mercureStatusListener!);
    }
    _mapObjectsListenable.dispose();
    super.dispose();
  }
}
