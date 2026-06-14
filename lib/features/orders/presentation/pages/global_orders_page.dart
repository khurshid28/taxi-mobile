// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../home/presentation/cubit/home_cubit.dart';
import '../../../home/presentation/cubit/home_state.dart';

/// "Global buyurtmalar" oynasi.
///
/// Hech bir haydovchi 2 urinishda olmagan buyurtma kompaniya bo'yicha BARCHA
/// online haydovchilarga yuboriladi. Ular shu yerda ro'yxat bo'lib turadi —
/// istalgan haydovchi "Olish" tugmasi bilan oladi (birinchi olgan yutadi).
/// Boshqa haydovchi olsa yoki buyurtma bekor qilinsa — ro'yxat JIM yangilanadi
/// (Mercure `GLOBAL_ORDER_ACCEPTED` / `GLOBAL_ORDER_CANCELED`).
class GlobalOrdersPage extends StatefulWidget {
  /// Buyurtma olingach asosiy (xarita) oynaga o'tish uchun.
  final VoidCallback? onGoHome;
  const GlobalOrdersPage({super.key, this.onGoHome});

  @override
  State<GlobalOrdersPage> createState() => _GlobalOrdersPageState();
}

class _GlobalOrdersPageState extends State<GlobalOrdersPage> {
  // Hozir qaysi buyurtma olinmoqda (tugmada spinner ko'rsatish uchun).
  String? _acceptingId;

  bool _hasActiveOrder(HomeState s) =>
      s.currentOrder != null && s.status != OrderStatus.initial;

  Future<void> _accept(BuildContext context, OrderModel order) async {
    if (_acceptingId != null) return;
    setState(() => _acceptingId = order.id);
    final cubit = context.read<HomeCubit>();
    await cubit.acceptGlobalOrder(order);
    if (!mounted) return;
    setState(() => _acceptingId = null);
    // Muvaffaqiyatli bo'lsa (faol safar boshlandi) — asosiy oynaga o'tamiz.
    // Xato bo'lsa (allaqachon olingan) — asosiy oyna listener'i toast
    // ko'rsatadi, ro'yxatda qolamiz.
    final st = cubit.state;
    if (st.currentOrder?.id == order.id &&
        st.status != OrderStatus.initial) {
      widget.onGoHome?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return Column(
              children: [
                _header(state.globalOrders.length),
                Expanded(child: _body(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int count) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(Iconsax.global, size: 24.w, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global buyurtmalar',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Hammaga ochiq — birinchi olgan yutadi',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, HomeState state) {
    if (!state.isOnline) {
      return _empty(
        icon: Iconsax.flash_slash,
        title: 'Liniyada emassiz',
        subtitle:
            'Global buyurtmalarni ko\'rish va olish uchun avval liniyaga chiqing',
      );
    }
    if (state.globalOrders.isEmpty) {
      return _empty(
        icon: Iconsax.box_search,
        title: 'Hozircha global buyurtma yo\'q',
        subtitle:
            'Hech kim olmagan buyurtma kelsa, shu yerda paydo bo\'ladi',
      );
    }

    final hasActive = _hasActiveOrder(state);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
      itemCount: state.globalOrders.length + (hasActive ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasActive && index == 0) return _activeHint();
        final order = state.globalOrders[hasActive ? index - 1 : index];
        return _orderCard(context, order, disabled: hasActive);
      },
    );
  }

  Widget _activeHint() {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.info_circle, size: 20.w, color: AppColors.warning),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Sizda faol buyurtma bor. Uni yakunlagach yangi global '
              'buyurtma olishingiz mumkin.',
              style: TextStyle(
                fontSize: 12.5.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, OrderModel order,
      {required bool disabled}) {
    final accent = AppColors.primary;
    final basePrice = context.read<HomeCubit>().resolveOrderBasePrice(order);
    final hasPickup = order.pickupAddress.trim().isNotEmpty;
    final hasDest = order.destinationAddress.trim().isNotEmpty;
    final tariff = (order.tariff ?? '').trim();
    final isAccepting = _acceptingId == order.id;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withOpacity(0.30), width: 1.5.w),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarif + boshlang'ich narx
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.car, size: 14.w, color: accent),
                      SizedBox(width: 6.w),
                      Text(
                        tariff.isNotEmpty ? tariff : 'Tarif',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormatter.formatPriceWithCurrency(basePrice),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'boshlang\'ich',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // Manzillar (mavjud bo'lsa)
            if (hasPickup)
              _locationRow(
                color: accent,
                icon: Iconsax.location,
                label: 'Qayerdan',
                value: order.pickupAddress,
              ),
            if (hasPickup && hasDest) _connector(),
            if (hasDest)
              _locationRow(
                color: AppColors.error,
                icon: Iconsax.location_tick,
                label: 'Qayerga',
                value: order.destinationAddress,
              ),
            if (!hasPickup && !hasDest)
              Row(
                children: [
                  Icon(Iconsax.location,
                      size: 16.w, color: AppColors.textHint),
                  SizedBox(width: 8.w),
                  Text(
                    'Manzil aniqlanmoqda...',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            SizedBox(height: 12.h),
            // Masofa + vaqt
            Row(
              children: [
                if (order.distance > 0) ...[
                  Icon(Iconsax.routing,
                      size: 15.w, color: AppColors.textSecondary),
                  SizedBox(width: 5.w),
                  Text(
                    '${order.distance.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 14.w),
                ],
                Icon(Iconsax.clock,
                    size: 15.w, color: AppColors.textSecondary),
                SizedBox(width: 5.w),
                Text(
                  DateFormat('HH:mm').format(order.createdAtUz),
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // Olish tugmasi
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: (disabled || _acceptingId != null)
                    ? null
                    : () => _accept(context, order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor: AppColors.divider,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: isAccepting
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Olinmoqda...',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.tick_circle, size: 20.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Olish',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow({
    required Color color,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9.r),
          ),
          child: Icon(icon, size: 16.w, color: color),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _connector() {
    return Padding(
      padding: EdgeInsets.only(left: 14.5.w, top: 2.h, bottom: 2.h),
      child: Container(
        width: 1.5.w,
        height: 14.h,
        color: AppColors.divider,
      ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44.w, color: AppColors.primary),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
