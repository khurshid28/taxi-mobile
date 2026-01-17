import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey[200]!, width: 1.w),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
              size: 18.sp,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Ma\'lumotlar',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // App Info Card
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20.r,
                  offset: Offset(0, 8.h),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    Icons.local_taxi_rounded,
                    size: 48.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Taxi Driver',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Versiya 1.0.0',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Info Sections
          _buildInfoSection(
            'Biz haqimizda',
            'Taxi Driver ilovasi haydovchilarga qulay va tez buyurtmalarni qabul qilish imkonini beradi. Ilova orqali daromadingizni kuzatib boring va mijozlar bilan samarali ishlang.',
            Icons.info_rounded,
          ),
          SizedBox(height: 16.h),

          _buildInfoSection(
            'Aloqa',
            'Muammo yuzaga kelsa yoki savollaringiz bo\'lsa, biz bilan bog\'laning:',
            Icons.contact_support_rounded,
            children: [
              SizedBox(height: 12.h),
              _buildContactItem(
                'Telefon',
                '+998 90 123 45 67',
                Icons.phone_rounded,
                () async {
                  final Uri phoneUri = Uri(
                    scheme: 'tel',
                    path: '+998901234567',
                  );
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  }
                },
              ),
              SizedBox(height: 8.h),
              _buildContactItem(
                'Email',
                'support@taxidriver.uz',
                Icons.email_rounded,
                () async {
                  final Uri emailUri = Uri(
                    scheme: 'mailto',
                    path: 'support@taxidriver.uz',
                  );
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),

          _buildInfoSection(
            'Foydalanish shartlari',
            'Ilovadan foydalanish orqali siz bizning shartlarimizga rozilik bildirasiz. Barcha haydovchilar xavfsizlik qoidalariga rioya qilishlari shart.',
            Icons.gavel_rounded,
          ),
          SizedBox(height: 16.h),

          _buildInfoSection(
            'Maxfiylik siyosati',
            'Biz sizning shaxsiy ma\'lumotlaringizni himoya qilamiz va uchinchi shaxslarga bermаymiz. Ma\'lumotlar faqat xizmat sifatini yaxshilash uchun ishlatiladi.',
            Icons.privacy_tip_rounded,
          ),
          SizedBox(height: 24.h),

          // Copyright
          Center(
            child: Text(
              '© 2026 Taxi Driver\nBarcha huquqlar himoyalangan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    String content,
    IconData icon, {
    List<Widget>? children,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
          if (children != null) ...children,
        ],
      ),
    );
  }

  Widget _buildContactItem(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!, width: 1.w),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20.sp),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16.sp,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
