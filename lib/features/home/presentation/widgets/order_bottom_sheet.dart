import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/utils/number_formatter.dart';

class OrderBottomSheet extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OrderBottomSheet({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<OrderBottomSheet> createState() => _OrderBottomSheetState();
}

class _OrderBottomSheetState extends State<OrderBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _timerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _timerAnimation;
  int _remainingSeconds = 10;
  bool _isAutoRejecting = false;
  bool _isAccepted = false; // Flag to prevent auto-reject after accept

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Timer animation for smooth progress
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _timerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _timerController, curve: Curves.linear));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _timerController.forward();
    _startAutoRejectTimer();
  }

  void _startAutoRejectTimer() {
    Future.doWhile(() async {
      if (_remainingSeconds <= 0 || !mounted || _isAccepted) {
        if (mounted && !_isAutoRejecting && !_isAccepted) {
          _isAutoRejecting = true;
          _autoReject();
        }
        return false;
      }
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && !_isAccepted) {
        _remainingSeconds--;
      }
      return !_isAccepted;
    });
  }

  void _autoReject() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buyurtma avtomatik rad qilindi'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
    widget.onReject();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _callClient() async {
    final uri = Uri.parse('tel:${widget.order.clientPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12.h),
                  Container(
                    width: 50.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.5),
                          AppColors.primary,
                        ],
                      ),
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
                  SizedBox(height: 12.h),
                  // Timer display at top
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 24.w),
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 16.w,
                    ),
                    decoration: BoxDecoration(
                      color: _remainingSeconds <= 3
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _remainingSeconds <= 3
                            ? Colors.red
                            : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: _remainingSeconds <= 3
                              ? Colors.red
                              : Colors.blue,
                          size: 24.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '$_remainingSeconds soniya',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds <= 3
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64.w,
                              height: 64.h,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFF7B1FA2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF9C27B0,
                                    ).withOpacity(0.4),
                                    blurRadius: 12.r,
                                    offset: Offset(0, 6.h),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icons/user_duotone.svg',
                                  width: 36.w,
                                  height: 36.h,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.order.clientName,
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
                                        width: 18.w,
                                        height: 18.h,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        widget.order.clientPhone,
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 52.w,
                              height: 52.h,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF388E3C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.4),
                                    blurRadius: 12.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _callClient,
                                icon: Icon(
                                  Icons.phone,
                                  color: Colors.white,
                                  size: 24.w,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                        // Distance and Price
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                iconPath: 'assets/icons/location_duotone.svg',
                                title: 'Masofa',
                                value:
                                    '${widget.order.distance.toStringAsFixed(1)} km',
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildInfoCard(
                                iconPath: 'assets/icons/wallet_duotone.svg',
                                title: 'Narx',
                                value: NumberFormatter.formatPriceWithCurrency(
                                  widget.order.price,
                                ),
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        // Addresses
                        _buildAddressRow(
                          'Boshlanish',
                          widget.order.pickupAddress,
                          Colors.green,
                        ),
                        SizedBox(height: 12.h),
                        _buildAddressRow(
                          'Tugatish',
                          widget.order.destinationAddress,
                          Colors.red,
                        ),
                        SizedBox(height: 24.h),
                        // Action Buttons with Sliders
                        Column(
                          children: [
                            // Accept Order Slider with Timer Animation
                            Stack(
                              children: [
                                // Background - primary color
                                Container(
                                  height: 60.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(30.r),
                                  ),
                                ),
                                // Slider without timer overlay - cleaner and easier to slide
                                SlideAction(
                                  height: 60.h,
                                  sliderButtonIconSize: 22.r,
                                  sliderButtonIconPadding: 14.r,
                                  borderRadius: 30.r,
                                  innerColor: Colors.white,
                                  outerColor: Colors.transparent,
                                  sliderRotate: false,
                                  animationDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  text: 'Qabul qilish',
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                  sliderButtonIcon: Icon(
                                    Icons.arrow_forward_rounded,
                                    color: AppColors.primary,
                                    size: 22.r,
                                  ),
                                  onSubmit: () {
                                    setState(() {
                                      _isAccepted = true;
                                    });
                                    _timerController.stop();
                                    widget.onAccept();
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            // Reject Button with Gradient
                            Container(
                              height: 60.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[400]!, Colors.red[600]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 15.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onReject,
                                  borderRadius: BorderRadius.circular(30.r),
                                  splashColor: Colors.white.withOpacity(0.3),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 24.w,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Rad etish',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String iconPath,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.25), width: 2.w),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50.w,
            height: 50.h,
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
                iconPath,
                width: 28.w,
                height: 28.h,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, String address, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.2), width: 2.w),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Icon(
              label == 'Boshlanish'
                  ? Icons.location_on_rounded
                  : Icons.flag_rounded,
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
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
