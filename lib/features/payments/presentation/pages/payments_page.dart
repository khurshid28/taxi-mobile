import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../profile/data/driver_service.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/utils/number_formatter.dart';

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
    setState(() => _isLoading = true);
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
      // Balansni olishda xatolik bo'lsa, 0 ko'rsatiladi.
    }
  }

  Future<void> _refreshPayments() async {
    setState(() => _isLoading = true);
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

  String _getPaymentIconPath(PaymentType type) {
    switch (type) {
      case PaymentType.topUp:
        return 'assets/icons/wallet_duotone.svg';
      case PaymentType.earning:
        return 'assets/icons/payment_duotone.svg';
      case PaymentType.withdrawal:
        return 'assets/icons/card_duotone.svg';
      case PaymentType.bonus:
        return 'assets/icons/check_duotone.svg';
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
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        'To\'lovlar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                        ),
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
                              color: Colors.white,
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
                                  color: Colors.black.withOpacity(0.04),
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
                                          : Colors.grey[600],
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
                                              color: Colors.white,
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
                                        : Colors.grey[700],
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
              child: SvgPicture.asset(
                'assets/icons/payment_duotone.svg',
                width: 52.w,
                height: 52.w,
                colorFilter: ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
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
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.15), width: 2.w),
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
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 12.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      _getPaymentIconPath(payment.type),
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
                          SvgPicture.asset(
                            'assets/icons/clock_duotone.svg',
                            width: 14.w,
                            height: 14.h,
                            colorFilter: ColorFilter.mode(
                              Colors.grey[500]!,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            dateFormat.format(payment.createdAt),
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
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isNegative
                          ? [
                              Colors.red.withOpacity(0.15),
                              Colors.red.withOpacity(0.05),
                            ]
                          : [
                              Colors.green.withOpacity(0.15),
                              Colors.green.withOpacity(0.05),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isNegative
                          ? Colors.red.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                      width: 1.5.w,
                    ),
                  ),
                  child: Text(
                    '${isNegative ? '' : '+'}${NumberFormatter.formatPrice(payment.amount)}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                      color: isNegative ? Colors.red[700] : Colors.green[700],
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
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'To\'lovlar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
              ),
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
                    color: Colors.white,
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
                                width: 100.w,
                                height: 12.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
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
                            color: Colors.white,
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border(
            top: BorderSide(color: color, width: 3.w),
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
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.r),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 25.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  _getPaymentIconPath(payment.type),
                  width: 50.w,
                  height: 50.h,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
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
                gradient: LinearGradient(
                  colors: isNegative
                      ? [
                          Colors.red.withOpacity(0.15),
                          Colors.red.withOpacity(0.05),
                        ]
                      : [
                          Colors.green.withOpacity(0.15),
                          Colors.green.withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isNegative
                      ? Colors.red.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                  width: 2.w,
                ),
              ),
              child: Text(
                '${isNegative ? '' : '+'}${NumberFormatter.formatPriceWithCurrency(payment.amount)}',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w900,
                  color: isNegative ? Colors.red[700] : Colors.green[700],
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
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
                        Divider(color: Colors.grey[200], height: 1.h),
                        SizedBox(height: 16.h),
                        _buildDetailRow(
                          'Sana',
                          dateFormat.format(payment.createdAt),
                          Colors.grey[700]!,
                        ),
                        SizedBox(height: 16.h),
                        Divider(color: Colors.grey[200], height: 1.h),
                        SizedBox(height: 16.h),
                        _buildDetailRow('ID', payment.id, Colors.grey[700]!),
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
            color: Colors.grey[600],
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
            color: Colors.white,
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
                    color: Colors.grey[300],
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
                    color: Colors.grey[50],
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
                            : Colors.grey[600],
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
                                : Colors.grey[600],
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
                          color: Colors.grey[700],
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
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.03),
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
