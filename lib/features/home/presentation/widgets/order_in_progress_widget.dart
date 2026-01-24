import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';

class OrderInProgressWidget extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onOpenMaps;
  final VoidCallback onCancel;
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
  final bool isWaitingForClient;
  final bool isGoingToClient;
  final bool isTimeoutEnabled;
  final int? routeDurationMinutes;
  final String? routeDistanceKm;

  const OrderInProgressWidget({
    super.key,
    required this.onComplete,
    required this.onOpenMaps,
    required this.onCancel,
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
    this.isWaitingForClient = false,
    this.isGoingToClient = false,
    this.isTimeoutEnabled = true,
    this.routeDurationMinutes,
    this.routeDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: print received data
    debugPrint(
      'OrderInProgressWidget - clientName: $clientName, clientPhone: $clientPhone',
    );
    debugPrint(
      'OrderInProgressWidget - pickup: $pickupAddress, destination: $destinationAddress',
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.2,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20.r,
                offset: Offset(0, -5.h),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 10.h),
                  width: 40.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.only(
                  left: 20.w,
                  right: 20.w,
                  bottom: 150
                      .h, // FAB uchun padding - increased to prevent overflow
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status header
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isWaitingForClient
                                ? [Color(0xFFFF9800), Color(0xFFF57C00)]
                                : [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isWaitingForClient
                                          ? Colors.orange
                                          : Colors.purple)
                                      .withOpacity(0.3),
                              blurRadius: 8.r,
                              offset: Offset(0, 3.h),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWaitingForClient
                                  ? Icons.timer_outlined
                                  : Icons.local_shipping_outlined,
                              color: Colors.white,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              isWaitingForClient ? 'Kutilmoqda' : 'Yo\'lda',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Client info section (blue container)
                    if (clientName != null || clientPhone != null)
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2196F3).withOpacity(0.15),
                              Color(0xFF1976D2).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Color(0xFF2196F3).withOpacity(0.3),
                            width: 1.w,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Color(0xFF1976D2),
                                  size: 20.w,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Mijoz ma\'lumoti',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                              ],
                            ),
                            if (clientName != null || clientPhone != null) ...[
                              SizedBox(height: 10.h),
                              if (clientName != null)
                                _buildInfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Ism',
                                  value: clientName!,
                                  color: Color(0xFF1976D2),
                                ),
                              if (clientName != null && clientPhone != null)
                                SizedBox(height: 8.h),
                              if (clientPhone != null)
                                _buildInfoRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Telefon',
                                  value: clientPhone!,
                                  color: Color(0xFF1976D2),
                                ),
                            ],
                          ],
                        ),
                      ),

                    // Addresses section (purple container)
                    if (pickupAddress != null ||
                        destinationAddress != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF9C27B0).withOpacity(0.15),
                              Color(0xFF7B1FA2).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Color(0xFF9C27B0).withOpacity(0.3),
                            width: 1.w,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Color(0xFF7B1FA2),
                                  size: 20.w,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Manzillar',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B1FA2),
                                  ),
                                ),
                              ],
                            ),
                            if (pickupAddress != null ||
                                destinationAddress != null) ...[
                              SizedBox(height: 10.h),
                              if (pickupAddress != null)
                                _buildInfoRow(
                                  icon: Icons.trip_origin,
                                  label: 'Qayerdan',
                                  value: pickupAddress!,
                                  color: Color(0xFF7B1FA2),
                                ),
                              if (pickupAddress != null &&
                                  destinationAddress != null)
                                SizedBox(height: 8.h),
                              if (destinationAddress != null)
                                _buildInfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Qayerga',
                                  value: destinationAddress!,
                                  color: Color(0xFF7B1FA2),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 12.h),

                    // Price and distance info
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoItem(
                            icon: Icons.attach_money,
                            label: 'Narx',
                            value: NumberFormatter.formatPriceWithCurrency(
                              currentPrice,
                            ),
                            color: AppColors.orderActive,
                          ),
                          Container(
                            width: 1.w,
                            height: 40.h,
                            color: AppColors.divider,
                          ),
                          _buildInfoItem(
                            icon: Icons.route,
                            label: 'Masofa',
                            value: '${traveledDistance.toStringAsFixed(2)} km',
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),

                    // Waiting time (show when waiting for client OR during trip with active timer)
                    if (waitingSeconds > 0 &&
                        (isWaitingForClient ||
                            (!isWaitingForClient && !isGoingToClient))) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: waitingSeconds > 120
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: waitingSeconds > 120
                                ? Colors.orange
                                : Colors.green,
                            width: 1.w,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: waitingSeconds > 120
                                  ? Colors.orange
                                  : Colors.green,
                              size: 24.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kutish: ${_formatWaitingTime(waitingSeconds)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15.sp,
                                      color: waitingSeconds > 120
                                          ? Colors.orange[900]
                                          : Colors.green[900],
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  if (waitingSeconds <= 120)
                                    Text(
                                      '2 daqiqa bepul',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.green[700],
                                      ),
                                    )
                                  else
                                    Text(
                                      isTimeoutEnabled
                                          ? 'Hisoblanyapti: 1000 so\'m/daqiqa'
                                          : 'Timeout o\'chirilgan',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: isTimeoutEnabled
                                            ? Colors.orange[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // "Kutishni boshlash/tugatish" toggle button - show only during inProgress (after "Qani ketdik")
                    // Don't show during goingToClient or waitingForClient
                    if (!isWaitingForClient &&
                        !isGoingToClient &&
                        onToggleWaitingTimer != null)
                      Padding(
                        padding: EdgeInsets.only(top: 12.h),
                        child: Container(
                          height: 60.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: waitingSeconds > 0
                                  ? [
                                      const Color(0xFFE53935),
                                      const Color(0xFFC62828),
                                    ]
                                  : [
                                      const Color(0xFFFF9800),
                                      const Color(0xFFF57C00),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(30.r),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (waitingSeconds > 0
                                            ? Colors.red
                                            : Colors.orange)
                                        .withOpacity(0.3),
                                blurRadius: 8.r,
                                offset: Offset(0, 3.h),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onToggleWaitingTimer,
                              borderRadius: BorderRadius.circular(30.r),
                              child: Center(
                                child: Text(
                                  waitingSeconds > 0
                                      ? 'Kutishni tugatish ⏹️'
                                      : 'Kutishni boshlash ⏱️',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: 16.h),

                    // Action buttons - 2x2 Grid
                    // Row 1: Call + Maps
                    Row(
                      children: [
                        // Call button
                        Expanded(
                          child: Container(
                            height: 52.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8.r,
                                  offset: Offset(0, 3.h),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: clientPhone != null
                                    ? () => _makePhoneCall(clientPhone!)
                                    : null,
                                borderRadius: BorderRadius.circular(12.r),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      color: Colors.white,
                                      size: 22.w,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Qo\'ng\'iroq',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),

                        // Maps button
                        Expanded(
                          child: Container(
                            height: 52.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8.r,
                                  offset: Offset(0, 3.h),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onOpenMaps,
                                borderRadius: BorderRadius.circular(12.r),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.map,
                                      color: Colors.white,
                                      size: 22.w,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Xarita',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
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

                    SizedBox(height: 10.h),

                    // ETA va masofa (Mapbox dan)
                    if (routeDurationMinutes != null && routeDistanceKm != null)
                      Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.route_rounded,
                              color: Colors.blue.shade700,
                              size: 24.r,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Taxminiy vaqt',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '$routeDurationMinutes daqiqa • $routeDistanceKm km',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // "Qani ketdik" slider - show only when waiting for client
                    if (isWaitingForClient && onPickupClient != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: SlideAction(
                          height: 60.h,
                          sliderButtonIconSize: 22.r,
                          sliderButtonIconPadding: 14.r,
                          borderRadius: 30.r,
                          innerColor: Colors.white,
                          outerColor: Colors.green,
                          sliderRotate: false,
                          animationDuration: const Duration(milliseconds: 300),
                          text: 'Qani ketdik 🚀',
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          sliderButtonIcon: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.green,
                            size: 22.r,
                          ),
                          onSubmit: () {
                            onPickupClient!();
                            return null;
                          },
                        ),
                      ),

                    // Action buttons row
                    Row(
                      children: [
                        // Cancel button - always visible
                        Expanded(
                          child: Container(
                            height: 52.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.red, width: 2.w),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onCancel,
                                borderRadius: BorderRadius.circular(12.r),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 22.w,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Bekor qilish',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Spacing between buttons if complete button exists
                        if (!isGoingToClient && !isWaitingForClient)
                          SizedBox(width: 10.w),

                        // Complete button - show only during inProgress (after pickup, not waiting)
                        if (!isGoingToClient && !isWaitingForClient)
                          Expanded(
                            child: Container(
                              height: 52.h,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF388E3C),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 8.r,
                                    offset: Offset(0, 3.h),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onComplete,
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.flag_rounded,
                                        color: Colors.white,
                                        size: 22.w,
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Tugatish',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
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

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  String _formatWaitingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Try with platformDefault mode
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // Last attempt with system default
      try {
        await launchUrl(uri);
      } catch (e2) {
        debugPrint('Failed to make phone call: $e2');
      }
    }
  }
}
