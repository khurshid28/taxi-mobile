import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';

class OrderInProgressWidget extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onOpenMaps;
  final VoidCallback onCancel;
  final String? clientPhone;
  final int currentPrice;
  final double traveledDistance;
  final int waitingSeconds;
  final bool isWaitingForClient;

  const OrderInProgressWidget({
    super.key,
    required this.onComplete,
    required this.onOpenMaps,
    required this.onCancel,
    this.clientPhone,
    this.currentPrice = 0,
    this.traveledDistance = 0,
    this.waitingSeconds = 0,
    this.isWaitingForClient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20.r,
            offset: Offset(0.w, -5.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          // Status header
          Row(
            children: [
              Icon(
                isWaitingForClient
                    ? Icons.hourglass_empty
                    : Icons.directions_car,
                color: AppColors.orderActive,
                size: 28.w,
              ),
              SizedBox(width: 12.w),
              Text(
                isWaitingForClient ? 'Kutilmoqda' : 'Yo\'lda',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

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
                  value: NumberFormatter.formatPriceWithCurrency(currentPrice),
                  color: AppColors.orderActive,
                ),
                Container(width: 1.w, height: 40.h, color: AppColors.divider),
                _buildInfoItem(
                  icon: Icons.route,
                  label: 'Masofa',
                  value: '${traveledDistance.toStringAsFixed(2)} km',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),

          // Waiting time (if waiting for client)
          if (isWaitingForClient) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: waitingSeconds > 120
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: waitingSeconds > 120 ? Colors.orange : Colors.green,
                  width: 1.w,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: waitingSeconds > 120 ? Colors.orange : Colors.green,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kutish vaqti: ${_formatWaitingTime(waitingSeconds)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: waitingSeconds > 120
                                ? Colors.orange[900]
                                : Colors.green[900],
                          ),
                        ),
                        if (waitingSeconds <= 120)
                          Text(
                            '${120 - waitingSeconds}s bepul qoldi',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.green[700],
                            ),
                          )
                        else
                          Text(
                            'Hisoblanyapti: 1500 so\'m/daqiqa',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.orange[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 20.h),

          // Action buttons
          Row(
            children: [
              // Call button
              if (clientPhone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(clientPhone!),
                    icon: Icon(Icons.phone, size: 20.w),
                    label: const Text('Qo\'ng\'iroq'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              if (clientPhone != null) SizedBox(width: 12.w),

              // Maps button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenMaps,
                  icon: Icon(Icons.map, size: 20.w),
                  label: const Text('Xarita'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Cancel button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: Icon(Icons.cancel, size: 20.w),
                  label: const Text('Bekor'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Complete button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: Icon(Icons.check_circle, size: 20.w),
                  label: const Text('Tugatish'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  String _formatWaitingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
