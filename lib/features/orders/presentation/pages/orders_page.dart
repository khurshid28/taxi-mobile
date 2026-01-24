import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/mock_data.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/storage_helper.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  List<OrderModel> _orders = [];
  List<OrderModel> _filteredOrders = [];
  OrderStatusType? _selectedFilter;
  late AnimationController _animationController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    // Load orders from both mock data and storage
    final mockOrders = MockData.getOrders();
    final storedOrders = await _loadStoredOrders();

    setState(() {
      _orders = [...storedOrders, ...mockOrders];
      _filteredOrders = _orders;
      _isLoading = false;
    });
    _animationController.forward();
  }

  Future<List<OrderModel>> _loadStoredOrders() async {
    try {
      final ordersJson =
          await StorageHelper.getString('completed_orders') ?? '[]';
      final List<dynamic> ordersList = jsonDecode(ordersJson);

      return ordersList.map((json) {
        return OrderModel(
          id: json['id'],
          clientName: json['clientName'],
          clientPhone: json['clientPhone'],
          pickupLocation: const Point(
            latitude: 41.2995,
            longitude: 69.2401,
          ), // Default location
          destinationLocation: const Point(
            latitude: 41.3111,
            longitude: 69.2797,
          ), // Default location
          pickupAddress: json['pickupAddress'],
          destinationAddress: json['destinationAddress'],
          distance: (json['distance'] as num).toDouble(),
          price: (json['price'] as num).toDouble(),
          createdAt: DateTime.parse(json['createdAt']),
          status: json['status'] == 'completed'
              ? OrderStatusType.completed
              : OrderStatusType.inProgress,
        );
      }).toList();
    } catch (e) {
      print('Error loading stored orders: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _filterOrders(OrderStatusType? status) {
    setState(() {
      _selectedFilter = status;
      if (status == null) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders
            .where((order) => order.status == status)
            .toList();
      }
      _animationController.reset();
      _animationController.forward();
    });
  }

  Future<void> _refreshOrders() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    // Reload from both sources
    final mockOrders = MockData.getOrders();
    final storedOrders = await _loadStoredOrders();

    setState(() {
      _orders = [...storedOrders, ...mockOrders];
      _filterOrders(_selectedFilter);
      _isLoading = false;
    });
  }

  Color _getStatusColor(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.completed:
        return Colors.green;
      case OrderStatusType.cancelled:
        return Colors.red;
      case OrderStatusType.inProgress:
        return Colors.orange;
      case OrderStatusType.accepted:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(OrderStatusType status) {
    switch (status) {
      case OrderStatusType.completed:
        return 'Tugatilgan';
      case OrderStatusType.cancelled:
        return 'Bekor qilingan';
      case OrderStatusType.inProgress:
        return 'Jarayonda';
      case OrderStatusType.accepted:
        return 'Qabul qilingan';
      default:
        return 'Kutilmoqda';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Buyurtmalar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<OrderStatusType?>(
            icon: SvgPicture.asset(
              'assets/icons/filter.svg',
              width: 24.w,
              height: 24.h,
              colorFilter: ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            onSelected: _filterOrders,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Hammasi')),
              const PopupMenuItem(
                value: OrderStatusType.completed,
                child: Text('Tugatilgan'),
              ),
              const PopupMenuItem(
                value: OrderStatusType.cancelled,
                child: Text('Bekor qilingan'),
              ),
              const PopupMenuItem(
                value: OrderStatusType.inProgress,
                child: Text('Jarayonda'),
              ),
            ],
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        color: AppColors.primary,
        child: _isLoading
            ? _buildShimmerLoading()
            : _filteredOrders.isEmpty
            ? _buildEmptyState()
            : AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _animationController,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          builder: (context, double value, child) {
                            return Transform.translate(
                              offset: Offset(0, 50 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: _buildOrderCard(_filteredOrders[index]),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 16.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              width: 120.w,
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 70.w,
                        height: 24.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Container(
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Container(
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 60.w,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            'Buyurtmalar yo\'q',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Hozircha buyurtmalar mavjud emas',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withOpacity(0.15), width: 2.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15.r,
            offset: Offset(0.w, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: () => _showOrderDetails(order),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 12.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/user_duotone.svg',
                          width: 28.w,
                          height: 28.h,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.clientName,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/phone_duotone.svg',
                                width: 14.w,
                                height: 14.h,
                                colorFilter: ColorFilter.mode(
                                  Colors.grey[500]!,
                                  BlendMode.srcIn,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                order.clientPhone,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.15),
                            statusColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1.5.w,
                        ),
                      ),
                      child: Text(
                        _getStatusText(order.status),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.grey[200]!, width: 1.w),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.h,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              order.pickupAddress,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.h,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              order.destinationAddress,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1.w,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/route_duotone.svg',
                            width: 14.w,
                            height: 14.h,
                            colorFilter: ColorFilter.mode(
                              Colors.grey[600]!,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '${order.distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1.w,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/clock_duotone.svg',
                            width: 14.w,
                            height: 14.h,
                            colorFilter: ColorFilter.mode(
                              Colors.grey[600]!,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            dateFormat.format(order.createdAt),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5.w,
                        ),
                      ),
                      child: Text(
                        NumberFormatter.formatPrice(order.price),
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border(
            top: BorderSide(color: AppColors.primary, width: 3.w),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40.r,
              offset: Offset(0, -10.h),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 70.w,
                          height: 70.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getStatusColor(order.status),
                                _getStatusColor(order.status).withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(
                                  order.status,
                                ).withOpacity(0.4),
                                blurRadius: 15.r,
                                offset: Offset(0, 6.h),
                              ),
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/user_duotone.svg',
                              width: 40.w,
                              height: 40.h,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.clientName,
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/phone_duotone.svg',
                                    width: 16.w,
                                    height: 16.h,
                                    colorFilter: ColorFilter.mode(
                                      Colors.grey[600]!,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    order.clientPhone,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getStatusColor(order.status).withOpacity(0.15),
                            _getStatusColor(order.status).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: _getStatusColor(order.status).withOpacity(0.3),
                          width: 2.w,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10.w,
                            height: 10.h,
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(
                                    order.status,
                                  ).withOpacity(0.5),
                                  blurRadius: 8.r,
                                  spreadRadius: 2.r,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            _getStatusText(order.status),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(order.status),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28.h),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: const Color(0xFF2196F3).withOpacity(0.3),
                                width: 2.w,
                              ),
                            ),
                            child: Column(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/route_duotone.svg',
                                  width: 32.w,
                                  height: 32.h,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF2196F3),
                                    BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'Masofa',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '${order.distance.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                width: 2.w,
                              ),
                            ),
                            child: Column(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/wallet_duotone.svg',
                                  width: 32.w,
                                  height: 32.h,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF4CAF50),
                                    BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'Narx',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  NumberFormatter.formatPrice(order.price),
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 28.h),
                    Text(
                      'Manzillar',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                          width: 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 12.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 20.w,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Boshlanish',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  order.pickupAddress,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.2),
                          width: 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            blurRadius: 12.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF44336), Color(0xFFD32F2F)],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.flag_rounded,
                              color: Colors.white,
                              size: 20.w,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tugatish',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 5.h),
                                Text(
                                  order.destinationAddress,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1.5.w,
                        ),
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/clock_duotone.svg',
                            width: 20.w,
                            height: 20.h,
                            colorFilter: ColorFilter.mode(
                              Colors.grey[600]!,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            dateFormat.format(order.createdAt),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
