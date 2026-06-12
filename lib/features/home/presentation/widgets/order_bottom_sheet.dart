import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/utils/number_formatter.dart';

/// Yangi buyurtma kelganda chiqadigan pastki varaq.
/// Toza, gradientsiz, silliq dizayn. Timer sekundlik sanaydi va vaqt tugasa
/// avtomatik rad qiladi. Qabul qilish — oddiy bitta bosishli tugma.
///
/// MUHIM (performance): bu varaq native YandexMap (platform view) ustida
/// chiziladi. Android'da xarita ustidagi har bir Flutter kadri qimmat
/// "hybrid composition" qiladi. Shu sababli bu yerda UZLUKSIZ 60fps animatsiya
/// ISHLATILMAYDI — timer sekundiga bir marta yangilanadi (app qotmaydi).
class OrderBottomSheet extends StatefulWidget {
  final OrderModel order;

  /// Tarif asosidagi boshlang'ich (fix) narx — qabul qilishda shu ko'rinadi.
  final int price;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OrderBottomSheet({
    super.key,
    required this.order,
    required this.price,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<OrderBottomSheet> createState() => _OrderBottomSheetState();
}

class _OrderBottomSheetState extends State<OrderBottomSheet> {
  static const int _totalSeconds = 10;

  Timer? _ticker;
  // Faqat shu qiymat har sekund o'zgaradi. ValueNotifier orqali FAQAT timer
  // chizig'i yangilanadi — butun varaq (mijoz, narx, tugmalar) qayta qurilmaydi.
  final ValueNotifier<int> _remaining = ValueNotifier<int>(_totalSeconds);

  bool _isAccepted = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    // Sekundlik timer — setState YO'Q, faqat ValueNotifier yangilanadi (yengil).
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final next = _remaining.value - 1;
      _remaining.value = next;
      if (next <= 0) {
        t.cancel();
        _autoReject();
      }
    });
  }

  void _autoReject() {
    if (!mounted || _isClosing || _isAccepted) return;
    _isClosing = true;
    widget.onReject();
  }

  void _accept() {
    if (_isAccepted) return;
    setState(() => _isAccepted = true);
    _ticker?.cancel();
    widget.onAccept();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _remaining.dispose();
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
    return RepaintBoundary(
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
                      SizedBox(height: 18.h),
                      _buildPriceCard(),
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
    );
  }

  Widget _buildTimerBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      // Faqat shu builder har sekund qayta ishlaydi — qolgan varaq tinch turadi.
      child: ValueListenableBuilder<int>(
        valueListenable: _remaining,
        builder: (context, value, _) {
          final remaining = value.clamp(0, _totalSeconds);
          final danger = remaining <= 3;
          final accent = danger ? AppColors.error : AppColors.primary;
          return Row(
            children: [
              // Aylana hisoblagich — raqam markazda. Qiymat soniyada bir marta
              // o'zgaradi (uzluksiz 60fps emas), shuning uchun native xarita
              // ustida qotmaydi.
              SizedBox(
                width: 54.w,
                height: 54.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 54.w,
                      height: 54.w,
                      child: CircularProgressIndicator(
                        value: remaining / _totalSeconds,
                        strokeWidth: 4.w,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$remaining',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 7.w),
                        Text(
                          'Yangi buyurtma',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      danger
                          ? 'Tezroq qaror qiling!'
                          : 'Javob berish uchun $remaining soniya',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: danger ? AppColors.error : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
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

  Widget _buildPriceCard() {
    final tariff = widget.order.tariff;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(Iconsax.wallet_3, color: AppColors.primary, size: 24.w),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Narx',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  NumberFormatter.formatPriceWithCurrency(widget.price),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (tariff != null && tariff.isNotEmpty) _buildTariffChip(tariff),
        ],
      ),
    );
  }

  Widget _buildTariffChip(String tariff) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.car, color: AppColors.primary, size: 15.w),
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
