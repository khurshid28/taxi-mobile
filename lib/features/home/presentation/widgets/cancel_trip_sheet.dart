import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

class CancelTripSheet extends StatefulWidget {
  final VoidCallback onCancel;

  const CancelTripSheet({super.key, required this.onCancel});

  @override
  State<CancelTripSheet> createState() => _CancelTripSheetState();
}

class _CancelTripSheetState extends State<CancelTripSheet> {
  int? _selectedReason;

  final List<String> _reasons = [
    'Client juda uzoq kutmoqda',
    'Yo\'lda muammo yuz berdi',
    'Client bilan aloqa yo\'q',
    'Boshqa sabab',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        border: Border(
          top: BorderSide(color: Colors.red, width: 3.w),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 40.r,
            offset: Offset(0.w, -10.h),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50.w,
            height: 5.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.withOpacity(0.5), Colors.red],
              ),
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8.r,
                  offset: Offset(0.w, 2.h),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.red[100]!],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20.r,
                  offset: Offset(0.w, 8.h),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/close_duotone.svg',
                width: 40.w,
                height: 40.h,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Safarni bekor qilish',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Iltimos, bekor qilish sababini tanlang',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: 24.h),

          // Reasons list
          ..._reasons.asMap().entries.map((entry) {
            final index = entry.key;
            final reason = entry.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedReason = index;
                });
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: _selectedReason == index
                      ? Colors.red[50]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: _selectedReason == index
                        ? Colors.red
                        : Colors.grey[300]!,
                    width: 2.w,
                  ),
                  boxShadow: _selectedReason == index
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.15),
                            blurRadius: 16.r,
                            offset: Offset(0.w, 4.h),
                            spreadRadius: -2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8.r,
                            offset: Offset(0.w, 2.h),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedReason == index
                              ? Colors.red
                              : Colors.grey[400]!,
                          width: 2.w,
                        ),
                        color: _selectedReason == index
                            ? Colors.red
                            : Colors.transparent,
                      ),
                      child: _selectedReason == index
                          ? Icon(Icons.check, size: 16.w, color: Colors.white)
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: _selectedReason == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedReason == index
                              ? Colors.red[900]
                              : AppColors.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          SizedBox(height: 24.h),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Ortga',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedReason != null
                      ? () {
                          Navigator.pop(context);
                          widget.onCancel();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Bekor qilish',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
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
}
