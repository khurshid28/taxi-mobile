import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/utils/number_formatter.dart';

/// Yangi buyurtma kelganda chiqadigan pastki varaq.
/// Toza, gradientsiz, silliq dizayn. Timer animatsiya orqali silliq sanaydi
/// va vaqt tugasa avtomatik rad qiladi. Qabul qilish — oddiy bitta bosishli
/// tugma (eski "surib qabul qilish" o'rniga).
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
  static const int _totalSeconds = 15;

  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  late final AnimationController _timer;

  bool _isAccepted = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

    // Silliq sanaydigan timer — alohida Timer.periodic kerak emas. UI uni
    // AnimatedBuilder orqali kuzatadi, vaqt tugasa avtomatik rad qiladi.
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _autoReject();
      })
      ..forward();
  }

  void _autoReject() {
    if (!mounted || _isClosing || _isAccepted) return;
    _isClosing = true;
    widget.onReject();
  }

  void _accept() {
    if (_isAccepted) return;
    setState(() => _isAccepted = true);
    _timer.stop();
    widget.onAccept();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _timer.dispose();
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
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
            boxShadow: AppColors.floatingShadow,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                // Drag handle
                Container(
                  width: 44.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),
                SizedBox(height: 16.h),
                _buildTimerBar(),
                SizedBox(height: 18.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      _buildClientRow(),
                      if (widget.order.tariff != null &&
                          widget.order.tariff!.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildTariffBadge(widget.order.tariff!),
                      ],
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Iconsax.routing,
                              title: 'Masofa',
                              value:
                                  '${widget.order.distance.toStringAsFixed(1)} km',
                              color: AppColors.info,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Iconsax.wallet_3,
                              title: 'Narx',
                              value: NumberFormatter.formatPriceWithCurrency(
                                widget.order.price,
                              ),
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildAddressRow(
                        isStart: true,
                        label: 'Boshlanish',
                        address: widget.order.pickupAddress,
                      ),
                      SizedBox(height: 10.h),
                      _buildAddressRow(
                        isStart: false,
                        label: 'Tugatish',
                        address: widget.order.destinationAddress,
                      ),
                      SizedBox(height: 22.h),
                      _buildActions(),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBar() {
    return AnimatedBuilder(
      animation: _timer,
      builder: (context, _) {
        final remaining =
            (_totalSeconds * (1 - _timer.value)).ceil().clamp(0, _totalSeconds);
        final danger = remaining <= 5;
        final accent = danger ? AppColors.error : AppColors.primary;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Iconsax.clock, color: accent, size: 18.w),
                  SizedBox(width: 8.w),
                  Text(
                    'Yangi buyurtma',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$remaining s',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(99.r),
                child: LinearProgressIndicator(
                  value: 1 - _timer.value,
                  minHeight: 6.h,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientRow() {
    return Row(
      children: [
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Icon(Iconsax.user, size: 28.w, color: AppColors.primary),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.order.clientName,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                widget.order.clientPhone.isEmpty
                    ? 'Telefon raqami yo\'q'
                    : widget.order.clientPhone,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (widget.order.clientPhone.isNotEmpty)
          GestureDetector(
            onTap: _callClient,
            child: Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(Iconsax.call, color: Colors.white, size: 22.w),
            ),
          ),
      ],
    );
  }

  Widget _buildTariffBadge(String tariff) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.car, color: AppColors.primary, size: 16.w),
            SizedBox(width: 6.w),
            Text(
              tariff.toUpperCase(),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 22.w, color: color),
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
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

  Widget _buildAddressRow({
    required bool isStart,
    required String label,
    required String address,
  }) {
    final color = isStart ? AppColors.success : AppColors.error;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(
              isStart ? Iconsax.location : Iconsax.flag,
              color: color,
              size: 19.w,
            ),
          ),
          SizedBox(width: 12.w),
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
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  address.isEmpty ? 'Manzil aniqlanmagan' : address,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

  Widget _buildActions() {
    return Row(
      children: [
        // Rad etish — ixcham, faqat ikonka
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _isClosing ? null : widget.onReject,
            child: Container(
              height: 56.h,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Center(
                child: Icon(
                  Iconsax.close_circle,
                  color: AppColors.error,
                  size: 26.w,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        // Qabul qilish — oddiy bitta bosishli katta tugma
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: _isAccepted ? null : _accept,
            child: Container(
              height: 56.h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16.r,
                    offset: Offset(0, 6.h),
                    spreadRadius: -2.w,
                  ),
                ],
              ),
              child: Center(
                child: _isAccepted
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.tick_circle,
                              color: Colors.white, size: 22.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Qabul qilish',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
