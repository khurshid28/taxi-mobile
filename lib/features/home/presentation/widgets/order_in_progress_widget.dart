import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';

/// Aktiv safar varag'i (Yo'lda / Kutilmoqda / Safar).
///
/// MUHIM: bu varaq native YandexMap (platform view) ustida chiziladi.
/// Android hybrid composition'da xarita ustidagi har bir Flutter kadri qimmat,
/// shuning uchun:
///  * `DraggableScrollableSheet` ishlatilmaydi (u butun xaritani qoplaydigan,
///    har drag'da qayta kompozitsiya qiladigan og'ir overlay edi — qotardi);
///  * varaq pastga o'rnatilgan, balandligi cheklangan va `RepaintBoundary`
///    ichida — uning qayta chizilishi xarita qatlamiga tegmaydi;
///  * uzluksiz (60fps) animatsiya yo'q.
///
/// Har bosqichda haydovchiga aniq bitta asosiy amal + doim "Bekor qilish":
///  * goingToClient    → "Yetib keldim" (GPS kutmasdan qo'lda o'tish)
///  * waitingForClient → "Qani ketdik" (safarni boshlash)
///  * inProgress       → "Tugatish" (safarni yakunlash)
class OrderInProgressWidget extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onOpenMaps;
  final VoidCallback onCancel;

  /// goingToClient bosqichida "Yetib keldim" bosilganda.
  final VoidCallback? onArrived;

  /// waitingForClient bosqichida "Qani ketdik" surilganda.
  final VoidCallback? onPickupClient;
  final VoidCallback? onToggleTimeout;
  final VoidCallback? onToggleWaitingTimer;

  final double? distanceToClient;
  final String? clientPhone;
  final String? clientName;
  final String? pickupAddress;
  final String? destinationAddress;
  final int currentPrice;
  final double traveledDistance;
  final int waitingSeconds;
  final int tripSeconds;
  final bool isWaitingForClient;
  final bool isGoingToClient;
  final bool isWaitingTimerActive;
  final bool isTimeoutEnabled;
  final int? routeDurationMinutes;
  final String? routeDistanceKm;

  const OrderInProgressWidget({
    super.key,
    required this.onComplete,
    required this.onOpenMaps,
    required this.onCancel,
    this.onArrived,
    this.onPickupClient,
    this.onToggleTimeout,
    this.onToggleWaitingTimer,
    this.distanceToClient,
    this.clientPhone,
    this.clientName,
    this.pickupAddress,
    this.destinationAddress,
    this.currentPrice = 0,
    this.traveledDistance = 0,
    this.waitingSeconds = 0,
    this.tripSeconds = 0,
    this.isWaitingForClient = false,
    this.isGoingToClient = false,
    this.isWaitingTimerActive = false,
    this.isTimeoutEnabled = true,
    this.routeDurationMinutes,
    this.routeDistanceKm,
  });

  bool get _isInProgress => !isWaitingForClient && !isGoingToClient;

  // Bo'sh / placeholder ma'lumotlarni yashirish uchun yordamchilar.
  // Backend ism yubormasa model 'Mijoz' qo'yadi, manzil bo'sh ('') bo'ladi —
  // bunday hollarda satr ko'rsatilmaydi (bo'sh karta chiqmasin).
  bool get _hasClientName =>
      clientName != null &&
      clientName!.trim().isNotEmpty &&
      clientName!.trim() != 'Mijoz';
  bool get _hasClientPhone =>
      clientPhone != null && clientPhone!.trim().isNotEmpty;
  bool get _hasClient => _hasClientName || _hasClientPhone;
  bool get _hasPickup =>
      pickupAddress != null && pickupAddress!.trim().isNotEmpty;
  bool get _hasDestination =>
      destinationAddress != null && destinationAddress!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Color accent = isWaitingForClient
        ? AppColors.warning
        : (isGoingToClient ? AppColors.info : AppColors.primary);

    // Bosqichlar orasida silliq o'tish: balandlik BIR MARTALIK (one-shot)
    // animatsiya bilan o'zgaradi — uzluksiz 60fps emas, shuning uchun native
    // xarita qotmaydi, ammo o'tish silliq ko'rinadi.
    return RepaintBoundary(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: 0.76.sh),
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
                // Drag handle (faqat bezak — varaq sudralmaydi)
                Container(
                  margin: EdgeInsets.only(top: 10.h, bottom: 12.h),
                  width: 40.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),

                // Sarlavha: bosqich ikonkasi + nomi + izoh
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _header(accent),
                ),
                SizedBox(height: 16.h),

                // Bosqich indikatori (Yo'lda → Kutish → Safar)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _progressStepper(accent),
                ),
                SizedBox(height: 14.h),

                // Skroll qilinadigan ma'lumot qismi
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_hasClient) ...[
                          _clientCard(),
                          SizedBox(height: 10.h),
                        ],
                        if (_hasPickup || _hasDestination) ...[
                          _addressCard(),
                          SizedBox(height: 10.h),
                        ],
                        _metricsCard(),
                        if (_isInProgress) ...[
                          SizedBox(height: 10.h),
                          _tripTimeRow(),
                        ],
                        if (waitingSeconds > 0 &&
                            (isWaitingForClient || isWaitingTimerActive)) ...[
                          SizedBox(height: 10.h),
                          _waitingRow(),
                        ],
                        if (isGoingToClient &&
                            routeDurationMinutes != null &&
                            routeDistanceKm != null) ...[
                          SizedBox(height: 10.h),
                          _etaRow(),
                        ],
                        SizedBox(height: 12.h),
                        _callMapsRow(),
                        if (_isInProgress && onToggleWaitingTimer != null) ...[
                          SizedBox(height: 10.h),
                          _waitingToggleButton(),
                        ],
                        SizedBox(height: 6.h),
                      ],
                    ),
                  ),
                ),

                // Pastga mahkamlangan asosiy amal + bekor qilish
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
                  child: _bottomActions(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== Sarlavha + bosqich indikatori =====================

  String get _stageTitle => isWaitingForClient
      ? 'Mijozni kutmoqdamiz'
      : (isGoingToClient ? 'Mijoz oldiga' : 'Safar davom etmoqda');

  String get _stageSubtitle => isWaitingForClient
      ? 'Mijoz chiqishini kuting'
      : (isGoingToClient
          ? 'Mijozni olib ketishga yo\'l oling'
          : 'Manzilga yetganda yakunlang');

  IconData get _stageIcon => isWaitingForClient
      ? Iconsax.timer_1
      : (isGoingToClient ? Iconsax.routing : Iconsax.car);

  Widget _header(Color accent) {
    return Row(
      children: [
        Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Icon(_stageIcon, color: accent, size: 24.w),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _stageTitle,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                _stageSubtitle,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 3 bosqichli indikator: Yo'lda → Kutish → Safar. Joriy bosqich yoritiladi,
  /// o'tilgan bosqichlar belgilanadi. O'tish bir martalik animatsiya bilan.
  Widget _progressStepper(Color accent) {
    final int current = isGoingToClient ? 0 : (isWaitingForClient ? 1 : 2);
    const titles = ['Yo\'lda', 'Kutish', 'Safar'];
    const icons = [Iconsax.routing, Iconsax.timer_1, Iconsax.flag];

    final List<Widget> row = [];
    for (int i = 0; i < 3; i++) {
      final bool done = i < current;
      final bool active = i == current;
      row.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: active
                    ? accent
                    : (done
                        ? accent.withOpacity(0.15)
                        : AppColors.surfaceVariant),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (done || active) ? accent : AppColors.divider,
                  width: 2.w,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: accent.withOpacity(0.3),
                          blurRadius: 10.r,
                          offset: Offset(0, 3.h),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                done ? Iconsax.tick_circle : icons[i],
                size: 17.w,
                color: active
                    ? Colors.white
                    : (done ? accent : AppColors.textHint),
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              titles[i],
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
      if (i < 2) {
        row.add(
          Expanded(
            child: Container(
              height: 3.h,
              margin: EdgeInsets.only(top: 16.h, left: 3.w, right: 3.w),
              decoration: BoxDecoration(
                color: i < current ? accent : AppColors.divider,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
        );
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
  }

  Widget _clientCard() {
    final String title = _hasClientName ? clientName!.trim() : 'Mijoz';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.user, color: AppColors.info, size: 20.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_hasClientPhone) ...[
                  SizedBox(height: 2.h),
                  Text(
                    clientPhone!.trim(),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasPickup)
            _buildInfoRow(
              icon: Iconsax.gps,
              label: 'Qayerdan',
              value: pickupAddress!.trim(),
              color: AppColors.primary,
            ),
          if (_hasPickup && _hasDestination) SizedBox(height: 8.h),
          if (_hasDestination)
            _buildInfoRow(
              icon: Iconsax.location,
              label: 'Qayerga',
              value: destinationAddress!.trim(),
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _metricsCard() {
    // Masofa: safar davomida — bosib o'tilgan km; aks holda — yo'l masofasi
    // (rejalashtirilgan), agar mavjud bo'lsa.
    final String distanceText = _isInProgress
        ? '${traveledDistance.toStringAsFixed(1)} km'
        : (routeDistanceKm != null
            ? '$routeDistanceKm km'
            : '${traveledDistance.toStringAsFixed(1)} km');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: Iconsax.dollar_circle,
            label: _isInProgress ? 'Narx' : 'Taxminiy narx',
            value: NumberFormatter.formatPriceWithCurrency(currentPrice),
            color: AppColors.orderActive,
          ),
          Container(width: 1.w, height: 40.h, color: AppColors.divider),
          _buildInfoItem(
            icon: Iconsax.routing,
            label: _isInProgress ? 'Bosib o\'tildi' : 'Masofa',
            value: distanceText,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _tripTimeRow() {
    return _infoBanner(
      icon: Iconsax.clock,
      color: AppColors.primary,
      child: Text(
        'Safar vaqti: ${_formatMinutes(tripSeconds)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15.sp,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _waitingRow() {
    final bool over = waitingSeconds > 120;
    final Color c = over ? AppColors.warning : AppColors.success;
    return _infoBanner(
      icon: Iconsax.timer_1,
      color: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kutish: ${_formatTime(waitingSeconds)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15.sp,
              color: c,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            over
                ? (isTimeoutEnabled
                    ? 'Hisoblanyapti: 1000 so\'m/daqiqa'
                    : 'Timeout o\'chirilgan')
                : '2 daqiqa bepul',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _etaRow() {
    return _infoBanner(
      icon: Iconsax.routing,
      color: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taxminiy vaqt',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$routeDurationMinutes daqiqa • $routeDistanceKm km',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppColors.info,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _callMapsRow() {
    return Row(
      children: [
        Expanded(
          child: _flatButton(
            icon: Iconsax.call,
            label: 'Qo\'ng\'iroq',
            color: AppColors.success,
            onTap:
                clientPhone != null ? () => _makePhoneCall(clientPhone!) : null,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _flatButton(
            icon: Iconsax.map,
            label: 'Xarita',
            color: AppColors.primary,
            onTap: onOpenMaps,
          ),
        ),
      ],
    );
  }

  Widget _waitingToggleButton() {
    final bool active = isWaitingTimerActive;
    final Color c = active ? AppColors.error : AppColors.warning;
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: Material(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onToggleWaitingTimer,
          borderRadius: BorderRadius.circular(14.r),
          child: Center(
            child: Text(
              active ? 'Kutishni tugatish' : 'Kutishni boshlash',
              style: TextStyle(
                color: c,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== Pastki amallar =====================

  Widget _bottomActions() {
    // waitingForClient: "Qani ketdik" surilma + ostida bekor qilish.
    if (isWaitingForClient && onPickupClient != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SlideAction(
            height: 58.h,
            sliderButtonIconSize: 22.r,
            sliderButtonIconPadding: 14.r,
            borderRadius: 16.r,
            innerColor: Colors.white,
            outerColor: AppColors.primary,
            sliderRotate: false,
            animationDuration: const Duration(milliseconds: 300),
            text: 'Qani ketdik',
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
            sliderButtonIcon: Icon(
              Iconsax.arrow_right_3,
              color: AppColors.primary,
              size: 22.r,
            ),
            onSubmit: () {
              onPickupClient!();
              return null;
            },
          ),
          SizedBox(height: 10.h),
          _cancelButton(expanded: true),
        ],
      );
    }

    // goingToClient → "Yetib keldim", inProgress → "Tugatish".
    final bool isArrive = isGoingToClient;
    return Row(
      children: [
        _cancelButton(),
        SizedBox(width: 12.w),
        Expanded(
          child: _primaryButton(
            icon: isArrive ? Iconsax.location_tick : Iconsax.flag,
            label: isArrive ? 'Yetib keldim' : 'Tugatish',
            onTap: isArrive ? (onArrived ?? () {}) : onComplete,
          ),
        ),
      ],
    );
  }

  Widget _cancelButton({bool expanded = false}) {
    final btn = SizedBox(
      height: 56.h,
      child: Material(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onCancel,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.close_circle, color: AppColors.error, size: 20.w),
                SizedBox(width: 8.w),
                Text(
                  'Bekor qilish',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56.h,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20.w),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Kichik yordamchilar =====================

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.4), width: 1.w),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22.w),
          SizedBox(width: 12.w),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _flatButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null;
    return SizedBox(
      height: 52.h,
      child: Material(
        color: color.withOpacity(enabled ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: enabled ? color : AppColors.textSecondary,
                  size: 20.w),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? color : AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24.w),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18.w),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Soniyalarni daqiqa ko'rinishida ko'rsatadi (safar vaqti uchun).
  String _formatMinutes(int seconds) {
    final m = seconds ~/ 60;
    return '$m daqiqa';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(uri);
      } catch (e2) {
        debugPrint('Failed to make phone call: $e2');
      }
    }
  }
}
