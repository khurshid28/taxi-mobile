import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

class TripCompleteDialog extends StatefulWidget {
  final int totalPrice;
  final double distance;
  final int duration; // in minutes

  const TripCompleteDialog({
    super.key,
    required this.totalPrice,
    required this.distance,
    required this.duration,
  });

  @override
  State<TripCompleteDialog> createState() => _TripCompleteDialogState();
}

class _TripCompleteDialogState extends State<TripCompleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<int> _counterAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _counterAnimation = IntTween(begin: 0, end: widget.totalPrice).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.r)),
      child: Container(
        padding: EdgeInsets.all(32.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 40.r,
              offset: Offset(0.w, 20.h),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon with animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Container(
                      width: 100.w,
                      height: 100.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 30.r,
                            offset: Offset(0.w, 10.h),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/success_duotone.svg',
                          width: 60.w,
                          height: 60.h,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 24.h),

            Text(
              'Safar tugadi!',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -1.2,
                height: 1.1,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Muvaffaqiyatli yakunlandi',
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 32.h),

            // Total price with animation
            Container(
              padding: EdgeInsets.all(28.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 20.r,
                    offset: Offset(0.w, 4.h),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Jami summa',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  AnimatedBuilder(
                    animation: _counterAnimation,
                    builder: (context, child) {
                      final isCompleted =
                          _counterAnimation.status == AnimationStatus.completed;
                      final priceText =
                          '${_counterAnimation.value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so\'m';

                      return isCompleted
                          ? Shimmer.fromColors(
                              baseColor: AppColors.primary,
                              highlightColor: AppColors.primary.withOpacity(
                                0.6,
                              ),
                              period: const Duration(milliseconds: 1500),
                              child: Text(
                                priceText,
                                style: TextStyle(
                                  fontSize: 40.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: -1.5,
                                  height: 1.h,
                                ),
                              ),
                            )
                          : Text(
                              priceText,
                              style: TextStyle(
                                fontSize: 40.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -1.5,
                                height: 1.h,
                              ),
                            );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Trip details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailItem(
                  icon: Icons.route,
                  label: 'Masofa',
                  value: '${widget.distance.toStringAsFixed(1)} km',
                ),
                Container(width: 1.w, height: 40.h, color: AppColors.divider),
                _buildDetailItem(
                  icon: Icons.timer,
                  label: 'Vaqt',
                  value: '${widget.duration} min',
                ),
              ],
            ),

            SizedBox(height: 32.h),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Yopish',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28.w),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
