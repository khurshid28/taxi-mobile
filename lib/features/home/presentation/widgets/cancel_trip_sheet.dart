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
    // Balandlik cheklangan: kontent katta bo'lsa ham sheet ekran tepasigacha
    // ko'tarilib ketmaydi (sabablar kerak bo'lsa ichida scroll bo'ladi).
    return Container(
      constraints: BoxConstraints(maxHeight: 0.6.sh),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 12.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(99.r),
                ),
              ),
              SizedBox(height: 18.h),

              // Ixcham header: belgi + sarlavha/izoh yonma-yon (baland ustun emas)
              Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.close_circle,
                      size: 26.w,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Safarni bekor qilish',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'Bekor qilish sababini tanlang',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // Sabablar — scroll qilinadi, shuning uchun sheet hech qachon
              // o'lchamidan oshib ketmaydi.
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _reasons.asMap().entries.map((entry) {
                      final index = entry.key;
                      final reason = entry.value;
                      final selected = _selectedReason == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedReason = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          margin: EdgeInsets.only(bottom: 9.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 13.h,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.red.withOpacity(0.06)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: selected ? Colors.red : AppColors.divider,
                              width: 1.5.w,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22.w,
                                height: 22.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.red
                                        : AppColors.textHint,
                                    width: 2.w,
                                  ),
                                  color: selected
                                      ? Colors.red
                                      : Colors.transparent,
                                ),
                                child: selected
                                    ? Icon(Icons.check,
                                        size: 14.w, color: Colors.white)
                                    : null,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14.5.sp,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? Colors.red[900]
                                        : AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Pastga mahkamlangan amal tugmalari
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Ortga',
                        style: TextStyle(
                          fontSize: 15.5.sp,
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
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        backgroundColor: Colors.red,
                        disabledBackgroundColor: AppColors.divider,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Bekor qilish',
                        style: TextStyle(
                          fontSize: 15.5.sp,
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
      ),
    );
  }
}
