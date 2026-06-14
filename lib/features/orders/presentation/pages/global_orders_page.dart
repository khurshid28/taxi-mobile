// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../home/presentation/cubit/home_cubit.dart';
import '../../../home/presentation/cubit/home_state.dart';

/// "Global buyurtmalar" ko'rinishi — "Buyurtmalar" oynasidagi "Global" tab
/// ichida ko'rsatiladi (alohida sahifa emas).
///
/// Hech bir haydovchi 2 urinishda olmagan buyurtma kompaniya bo'yicha BARCHA
/// online haydovchilarga yuboriladi. Ular shu yerda ro'yxat bo'lib turadi —
/// istalgan haydovchi "Olish" tugmasi bilan oladi (birinchi olgan yutadi).
/// Boshqa haydovchi olsa yoki buyurtma bekor qilinsa — ro'yxat JIM yangilanadi
/// (Mercure `GLOBAL_ORDER_ACCEPTED` / `GLOBAL_ORDER_CANCELED`).
class GlobalOrdersView extends StatefulWidget {
  /// Buyurtma olingach asosiy (xarita) oynaga o'tish uchun.
  final VoidCallback? onGoHome;

  /// Pastga tortib yangilaganda chaqiriladi. Berilmasa — faqat global
  /// buyurtmalar yangilanadi. ("Buyurtmalar" oynasi bu yerga HAMMA bo'limni
  /// yangilaydigan funksiyani uzatadi.)
  final Future<void> Function()? onRefresh;

  const GlobalOrdersView({super.key, this.onGoHome, this.onRefresh});

  @override
  State<GlobalOrdersView> createState() => _GlobalOrdersViewState();
}

class _GlobalOrdersViewState extends State<GlobalOrdersView> {
  // Hozir qaysi buyurtma olinmoqda (tugmada spinner ko'rsatish uchun).
  String? _acceptingId;

  @override
  void initState() {
    super.initState();
    // "Global" bo'limi ochilganda REST orqali ham yuklaymiz (liniyaga chiqish
    // shart emas). Mercure real-vaqt bilan id bo'yicha dedup qilinadi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeCubit>().loadGlobalOrders();
    });
  }

  // Hozir faol (xaritadagi + navbatdagi) buyurtmalar soni. Maksimal 2.
  int _activeCount(HomeState s) {
    final hasCurrent =
        s.currentOrder != null && s.status != OrderStatus.initial;
    return (hasCurrent ? 1 : 0) + s.queuedOrders.length;
  }

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
    if (st.currentOrder?.id == order.id && st.status != OrderStatus.initial) {
      widget.onGoHome?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) => _body(context, state),
    );
  }

  Widget _body(BuildContext context, HomeState state) {
    final onRefresh =
        widget.onRefresh ?? context.read<HomeCubit>().loadGlobalOrders;
    if (state.globalOrders.isEmpty) {
      // Bo'sh holatda ham pull-to-refresh ishlashi uchun — viewport balandligini
      // egallaydigan scrollable ListView ichida markazlashtiramiz.
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _empty(
                  icon: Iconsax.box_search,
                  title: 'Hozircha global buyurtma yo\'q',
                  subtitle:
                      'Hech kim olmagan buyurtma kelsa, shu yerda paydo bo\'ladi',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Haydovchi 2 tagacha faol buyurtma olishi mumkin. To'lgan (2) bo'lsa —
    // yangi global buyurtma olib bo'lmaydi (tugma o'chadi + ogohlantirish).
    final full = _activeCount(state) >= 2;
    final loc = state.currentLocation;

    // 1) Buyurtmalarni 2 guruhga ajratamiz: yaqinda berilgan (<2 soat) va
    //    eskirgan (>=2 soat).
    final recent = <OrderModel>[];
    final older = <OrderModel>[];
    for (final o in state.globalOrders) {
      (_isOld(o) ? older : recent).add(o);
    }
    // 2) Har bir guruhni OLISH nuqtasigacha masofa bo'yicha tartiblaymiz —
    //    eng yaqini birinchi.
    recent.sort((a, b) => _byKm(a, b, loc));
    older.sort((a, b) => _byKm(a, b, loc));

    // 3) Ko'rsatiladigan elementlar: avval yaqinlar, so'ng eskilar (sarlavha
    //    bilan ajratiladi).
    final items = <Widget>[];
    if (full) items.add(_activeHint());
    for (final o in recent) {
      items.add(_orderCard(context, o, disabled: full, currentLocation: loc));
    }
    if (older.isNotEmpty) {
      if (recent.isNotEmpty) {
        items.add(_sectionHeader('Ancha vaqt oldin berilgan'));
      }
      for (final o in older) {
        items.add(
          _orderCard(
            context,
            o,
            disabled: full,
            currentLocation: loc,
            isOld: true,
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
        children: items,
      ),
    );
  }

  // Buyurtma "eskirgan"mi (2 soatdan oshgan)? createdAt UTC bo'yicha.
  bool _isOld(OrderModel o) =>
      DateTime.now().toUtc().difference(o.createdAt.toUtc()) >=
      const Duration(hours: 2);

  // Haydovchidan OLISH nuqtasigacha masofa (km). Aniqlab bo'lmasa null.
  double? _pickupKm(OrderModel o, Point? loc) {
    if (loc == null) return null;
    final p = o.pickupLocation;
    if (p.latitude == 0 && p.longitude == 0) return null;
    return Geolocator.distanceBetween(
          loc.latitude,
          loc.longitude,
          p.latitude,
          p.longitude,
        ) /
        1000;
  }

  // Masofa bo'yicha taqqoslash — eng yaqini birinchi; noma'lum masofa oxirida.
  int _byKm(OrderModel a, OrderModel b, Point? loc) {
    final ka = _pickupKm(a, loc);
    final kb = _pickupKm(b, loc);
    if (ka == null && kb == null) return b.createdAt.compareTo(a.createdAt);
    if (ka == null) return 1;
    if (kb == null) return -1;
    return ka.compareTo(kb);
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 12.h),
      child: Row(
        children: [
          Icon(Iconsax.clock, size: 15.w, color: AppColors.textHint),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
        ],
      ),
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
              'Sizda 2 ta faol buyurtma bor. Birini yakunlagach yana global '
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

  Widget _orderCard(
    BuildContext context,
    OrderModel order, {
    required bool disabled,
    Point? currentLocation,
    bool isOld = false,
  }) {
    final accent = AppColors.primary;
    final basePrice = context.read<HomeCubit>().resolveOrderBasePrice(order);
    final hasPickup = order.pickupAddress.trim().isNotEmpty;
    final hasDest = order.destinationAddress.trim().isNotEmpty;
    final tariff = (order.tariff ?? '').trim();
    final isAccepting = _acceptingId == order.id;

    // Haydovchidan buyurtmani OLISH joyigacha (pickup) masofa.
    final double? pickupKm = _pickupKm(order, currentLocation);

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
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
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
                  Icon(Iconsax.location, size: 16.w, color: AppColors.textHint),
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
            // Masofa + vaqt (joy yetmasa keyingi qatorga o'tadi — overflow yo'q)
            Wrap(
              spacing: 14.w,
              runSpacing: 6.h,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (pickupKm != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.gps, size: 15.w, color: accent),
                      SizedBox(width: 5.w),
                      Text(
                        'Sizdan ${pickupKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                if (order.distance > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.routing,
                        size: 15.w,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        '${order.distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.clock,
                      size: 15.w,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      DateFormat('HH:mm').format(order.createdAtUz),
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isOld) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(7.r),
                        ),
                        child: Text(
                          'Ancha bo\'lgan',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
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
      child: Container(width: 1.5.w, height: 14.h, color: AppColors.divider),
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
