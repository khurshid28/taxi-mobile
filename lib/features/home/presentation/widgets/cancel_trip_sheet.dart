import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
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
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 14.w,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.w,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Iconsax.close_circle,
                  size: 34.w,
                  color: Colors.red,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Safarni bekor qilish',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Iltimos, bekor qilish sababini tanlang',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 18.h),

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
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: _selectedReason == index
                        ? Colors.red.withOpacity(0.06)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: _selectedReason == index
                          ? Colors.red
                          : AppColors.divider,
                      width: 1.5.w,
                    ),
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
                                : AppColors.textHint,
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
                      side: BorderSide(color: AppColors.divider),
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
                      disabledBackgroundColor: AppColors.divider,
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
      ),
    );
  }
}
