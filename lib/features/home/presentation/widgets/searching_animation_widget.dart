import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

class SearchingAnimationWidget extends StatefulWidget {
  final String text;
  final IconData icon;

  const SearchingAnimationWidget({
    super.key,
    required this.text,
    this.icon = Icons.search,
  });

  @override
  State<SearchingAnimationWidget> createState() =>
      _SearchingAnimationWidgetState();
}

class _SearchingAnimationWidgetState extends State<SearchingAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: const Offset(0.3, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 15.r,
            offset: Offset(0.w, 5.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 48.w, color: AppColors.primary),
          SizedBox(height: 16.h),
          Shimmer.fromColors(
            baseColor: AppColors.textPrimary,
            highlightColor: AppColors.primary,
            period: const Duration(milliseconds: 1500),
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20.h),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: 100.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
