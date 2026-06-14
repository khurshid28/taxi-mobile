import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../injection_container.dart';
import '../../../profile/data/driver_service.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/error_retry_view.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with SingleTickerProviderStateMixin {
  List<PaymentModel> _payments = [];
  List<PaymentModel> _filteredPayments = [];
  double _balance = 0;
  late AnimationController _animationController;
  bool _isLoading = true;
  bool _hasError = false;

  // Filter parameters
  DateTimeRange? _dateRange;
  List<PaymentType> _selectedTypes = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _filteredPayments = [];
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _payments = [];
    _filterPayments();
    await _loadBalance();
    if (mounted) setState(() => _isLoading = false);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final data = await sl<DriverService>().aboutMyData();
      if (mounted) setState(() => _balance = data.balance ?? 0);
    } catch (_) {
      // `driver_datas/about_me` server xatosi (500) bo'lsa — sahifani
      // bloklamaymiz, oxirgi keshlangan balansni ko'rsatamiz.
      final cached =
          await StorageHelper.getDouble(AppConstants.keyBalance) ?? 0;
      if (mounted) setState(() => _balance = cached);
    }
  }

  Future<void> _refreshPayments() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _loadBalance();
    if (!mounted) return;
    setState(() {
      _payments = [];
      _filterPayments();
      _isLoading = false;
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _filterPayments() {
    _filteredPayments = _payments.where((payment) {
      // Date filter
      if (_dateRange != null) {
        if (payment.createdAt.isBefore(_dateRange!.start) ||
            payment.createdAt.isAfter(_dateRange!.end.add(Duration(days: 1)))) {
          return false;
        }
      }

      // Type filter
      if (_selectedTypes.isNotEmpty) {
        if (!_selectedTypes.contains(payment.type)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Color _getPaymentColor(PaymentType type) {
    switch (type) {
      case PaymentType.topUp:
        return const Color(0xFF2196F3);
      case PaymentType.earning:
        return AppColors.primary;
      case PaymentType.withdrawal:
        return const Color(0xFFFF9800);
      case PaymentType.bonus:
        return const Color(0xFF9C27B0);
    }
  }

  IconData _getPaymentIcon(PaymentType type) {
    switch (type) {
      case PaymentType.topUp:
        return Iconsax.wallet;
      case PaymentType.earning:
        return Iconsax.money;
      case PaymentType.withdrawal:
        return Iconsax.card;
      case PaymentType.bonus:
        return Iconsax.tick_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refreshPayments,
        color: AppColors.primary,
        child: _isLoading
            ? _buildShimmerLoading()
            : _hasError
            ? ErrorRetryView(onRetry: _loadData)
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        'To\'lovlar',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      background: Container(
                        color: AppColors.primary,
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.all(24.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Balans',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: _balance),
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.easeOut,
                                  builder: (context, double value, child) {
                                    return Text(
                                      NumberFormatter.formatPriceWithCurrency(
                                        value,
                                      ),
                                      style: TextStyle(
                                        fontSize: 32.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 60.h),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16.h, top: 8.h),
                        child: GestureDetector(
                          onTap: _showFilterModal,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 14.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color:
                                    (_dateRange != null ||
                                        _selectedTypes.isNotEmpty)
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: 2.w,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 12.r,
                                  offset: Offset(0, 3.h),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    Icon(
                                      Iconsax.filter,
                                      color:
                                          (_dateRange != null ||
                                              _selectedTypes.isNotEmpty)
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 22.sp,
                                    ),
                                    if (_dateRange != null ||
                                        _selectedTypes.isNotEmpty)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 8.w,
                                          height: 8.h,
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.surface,
                                              width: 1.5.w,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'Filter',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        (_dateRange != null ||
                                            _selectedTypes.isNotEmpty)
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_filteredPayments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.all(16.w),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: Duration(
                              milliseconds: 300 + (index * 100),
                            ),
                            builder: (context, double value, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: _buildPaymentCard(_filteredPayments[index]),
                          );
                        }, childCount: _filteredPayments.length),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110.w,
            height: 110.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Iconsax.empty_wallet,
                size: 52.w,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Hozircha tranzaksiyalar yo\'q',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'To\'lovlar tarixi shu yerda ko\'rinadi',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final color = _getPaymentColor(payment.type);
    final isNegative = payment.amount < 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.15), width: 2.w),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 15.r,
            offset: Offset(0.w, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPaymentDetails(payment),
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: color.withOpacity(AppColors.isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: Icon(
                      _getPaymentIcon(payment.type),
                      size: 28.w,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.title,
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
                          Icon(
                            Iconsax.clock,
                            size: 14.w,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            dateFormat.format(payment.createdAt),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
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
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: (isNegative ? AppColors.error : AppColors.success)
                        .withOpacity(AppColors.isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${isNegative ? '' : '+'}${NumberFormatter.formatPrice(payment.amount)}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                      color: isNegative ? AppColors.error : AppColors.success,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'To\'lovlar',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            background: Container(
              color: AppColors.primary,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balans',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Shimmer.fromColors(
                        baseColor: Colors.white.withOpacity(0.3),
                        highlightColor: Colors.white.withOpacity(0.5),
                        child: Container(
                          width: 200.w,
                          height: 36.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 60.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Shimmer.fromColors(
                baseColor: AppColors.divider,
                highlightColor: AppColors.surfaceVariant,
                child: Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
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
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                width: 100.w,
                                height: 12.h,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 80.w,
                          height: 16.h,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }, childCount: 6),
          ),
        ),
      ],
    );
  }

  void _showPaymentDetails(PaymentModel payment) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final color = _getPaymentColor(payment.type);
    final isNegative = payment.amount < 0;

    String getPaymentTypeText(PaymentType type) {
      switch (type) {
        case PaymentType.topUp:
          return 'Balans to\'ldirish';
        case PaymentType.earning:
          return 'Daromad';
        case PaymentType.withdrawal:
          return 'Pul yechish';
        case PaymentType.bonus:
          return 'Bonus';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border(
            top: BorderSide(color: color, width: 3.w),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
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
                color: color,
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            Container(
              width: 90.w,
              height: 90.h,
              decoration: BoxDecoration(
                color: color.withOpacity(AppColors.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(28.r),
              ),
              child: Center(
                child: Icon(
                  _getPaymentIcon(payment.type),
                  size: 50.w,
                  color: color,
                ),
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              payment.title,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: (isNegative ? AppColors.error : AppColors.success)
                    .withOpacity(AppColors.isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '${isNegative ? '' : '+'}${NumberFormatter.formatPriceWithCurrency(payment.amount)}',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w900,
                  color: isNegative ? AppColors.error : AppColors.success,
                  letterSpacing: -1,
                ),
              ),
            ),
            SizedBox(height: 32.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 15.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Turi',
                          getPaymentTypeText(payment.type),
                          color,
                        ),
                        SizedBox(height: 16.h),
                        Divider(color: AppColors.divider, height: 1.h),
                        SizedBox(height: 16.h),
                        _buildDetailRow(
                          'Sana',
                          dateFormat.format(payment.createdAt),
                          AppColors.textSecondary,
                        ),
                        SizedBox(height: 16.h),
                        Divider(color: AppColors.divider, height: 1.h),
                        SizedBox(height: 16.h),
                        _buildDetailRow(
                          'ID',
                          payment.id,
                          AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showFilterModal() {
    DateTimeRange? tempDateRange = _dateRange;
    List<PaymentType> tempTypes = List.from(_selectedTypes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Title
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24.h),

              // Date Range Section
              Text(
                'Sana oralig\'i',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: tempDateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.primary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setModalState(() => tempDateRange = picked);
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: tempDateRange != null
                          ? AppColors.primary
                          : AppColors.divider,
                      width: 2.w,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.calendar,
                        color: tempDateRange != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          tempDateRange == null
                              ? 'Sanani tanlang'
                              : '${DateFormat('dd.MM.yyyy').format(tempDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(tempDateRange!.end)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: tempDateRange != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (tempDateRange != null)
                        IconButton(
                          icon: Icon(Iconsax.close_circle, size: 20.sp),
                          onPressed: () {
                            setModalState(() => tempDateRange = null);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Payment Type Section
              Text(
                'To\'lov turi',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _buildTypeChip(
                    'To\'ldirish',
                    const Color(0xFF2196F3),
                    tempTypes.contains(PaymentType.topUp),
                    () {
                      setModalState(() {
                        if (tempTypes.contains(PaymentType.topUp)) {
                          tempTypes.remove(PaymentType.topUp);
                        } else {
                          tempTypes.add(PaymentType.topUp);
                        }
                      });
                    },
                  ),
                  _buildTypeChip(
                    'Daromad',
                    AppColors.primary,
                    tempTypes.contains(PaymentType.earning),
                    () {
                      setModalState(() {
                        if (tempTypes.contains(PaymentType.earning)) {
                          tempTypes.remove(PaymentType.earning);
                        } else {
                          tempTypes.add(PaymentType.earning);
                        }
                      });
                    },
                  ),
                  _buildTypeChip(
                    'Yechish',
                    const Color(0xFFFF9800),
                    tempTypes.contains(PaymentType.withdrawal),
                    () {
                      setModalState(() {
                        if (tempTypes.contains(PaymentType.withdrawal)) {
                          tempTypes.remove(PaymentType.withdrawal);
                        } else {
                          tempTypes.add(PaymentType.withdrawal);
                        }
                      });
                    },
                  ),
                  _buildTypeChip(
                    'Bonus',
                    const Color(0xFF9C27B0),
                    tempTypes.contains(PaymentType.bonus),
                    () {
                      setModalState(() {
                        if (tempTypes.contains(PaymentType.bonus)) {
                          tempTypes.remove(PaymentType.bonus);
                        } else {
                          tempTypes.add(PaymentType.bonus);
                        }
                      });
                    },
                  ),
                ],
              ),
              Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _dateRange = null;
                          _selectedTypes = [];
                          _filterPayments();
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        side: BorderSide(color: AppColors.divider, width: 2.w),
                      ),
                      child: Text(
                        'Tozalash',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dateRange = tempDateRange;
                          _selectedTypes = tempTypes;
                          _filterPayments();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Qo\'llash',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.2) : AppColors.shadow,
              blurRadius: isSelected ? 12.r : 8.r,
              offset: Offset(0, isSelected ? 4.h : 2.h),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
