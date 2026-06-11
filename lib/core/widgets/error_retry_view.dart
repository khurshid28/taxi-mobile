import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

/// Reusable full-area error state with a retry button. Used on data screens
/// when a fetch fails so the user can recover without restarting the app.
class ErrorRetryView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorRetryView({
    super.key,
    required this.onRetry,
    this.title = 'Xatolik yuz berdi',
    this.message =
        'Ma\'lumotni yuklab bo\'lmadi. Internetni tekshirib, qayta urinib ko\'ring.',
    this.icon = Iconsax.warning_2,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52.w, color: AppColors.error),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Iconsax.refresh, size: 18.sp),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline error banner with a retry action. Used on screens that can
/// still show cached content while signalling that a refresh failed.
class ErrorRetryBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryBanner({
    super.key,
    required this.onRetry,
    this.message = 'Ma\'lumotni yangilab bo\'lmadi',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.warning_2, color: AppColors.error, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}
