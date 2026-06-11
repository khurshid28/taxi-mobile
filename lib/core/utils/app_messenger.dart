import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

enum AppMessageType { error, success, info, warning }

class AppMessenger {
  static void error(BuildContext context, String message) =>
      _show(context, message, AppMessageType.error);

  static void success(BuildContext context, String message) =>
      _show(context, message, AppMessageType.success);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppMessageType.info);

  static void warning(BuildContext context, String message) =>
      _show(context, message, AppMessageType.warning);

  static void _show(
    BuildContext context,
    String message,
    AppMessageType type,
  ) {
    final scheme = _scheme(type);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.color.withOpacity(0.25)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: scheme.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(scheme.icon, color: scheme.color, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _Scheme _scheme(AppMessageType t) {
    switch (t) {
      case AppMessageType.error:
        return const _Scheme(AppColors.error, Iconsax.danger);
      case AppMessageType.success:
        return const _Scheme(
            AppColors.success, Iconsax.tick_circle);
      case AppMessageType.info:
        return const _Scheme(AppColors.info, Iconsax.info_circle);
      case AppMessageType.warning:
        return const _Scheme(
            AppColors.warning, Iconsax.warning_2);
    }
  }
}

class _Scheme {
  final Color color;
  final IconData icon;
  const _Scheme(this.color, this.icon);
}
