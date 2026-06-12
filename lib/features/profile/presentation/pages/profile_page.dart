import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../injection_container.dart';
import '../../data/driver_service.dart';
import 'activity_page.dart';
import 'settings_page.dart';
import 'info_page.dart';
import '../../../../core/widgets/error_retry_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = '';
  String _phone = '';
  int _rating = 50;
  double _balance = 0.0;
  int _totalTrips = 0;
  bool _isLoading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });

    // Keshlangan ma'lumotlar (server javobigacha ko'rsatiladi)
    var name = await StorageHelper.getString('user_name') ?? 'Haydovchi';
    var phone =
        await StorageHelper.getString(AppConstants.keyUserPhone) ?? '';

    try {
      // Serverdan real profil ma'lumotlari
      final profile = await sl<DriverService>().aboutMe();
      if (profile.name.isNotEmpty) name = profile.name;
      if (profile.phone.isNotEmpty) phone = profile.phone;
      if (!mounted) return;
      setState(() {
        _name = name;
        _phone = phone;
        _rating = profile.rating;
        _balance = profile.balance;
        _totalTrips = profile.totalTrips;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _name = name;
        _phone = phone;
        _loadError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(
                    AppColors.isDark ? 0.18 : 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.logout,
                  color: AppColors.error,
                  size: 30.w,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Hisobdan chiqish',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Rostdan ham hisobingizdan chiqmoqchimisiz?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50.h,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          'Bekor qilish',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: SizedBox(
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          'Chiqish',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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

    if (confirmed == true) {
      await StorageHelper.clear();
      if (mounted) {
        context.go('/');
      }
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 80) return Colors.green;
    if (rating >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceVariant,
        body: _buildShimmerLoading(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.h,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            title: Text(
              'Profil',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.surface,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 36.h),
                      Container(
                        width: 84.w,
                        height: 84.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.10),
                        ),
                        child: Icon(
                          Iconsax.user,
                          size: 44.sp,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _phone,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.star_1,
                              color: AppColors.warning,
                              size: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Reyting: $_rating',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  if (_loadError)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: ErrorRetryBanner(onRetry: _loadUserData),
                    ),
                  // Balance Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 24.r,
                          offset: Offset(0.w, 10.h),
                          spreadRadius: -4.w,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Balans',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: _balance,
                                    ),
                                    duration: const Duration(
                                      milliseconds: 1000,
                                    ),
                                    curve: Curves.easeOut,
                                    builder: (context, double value, child) {
                                      return Text(
                                        NumberFormatter.formatPriceWithCurrency(
                                          value,
                                        ),
                                        style: TextStyle(
                                          fontSize: 28.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Iconsax.wallet,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Iconsax.car,
                          title: 'Safar',
                          value: _totalTrips.toString(),
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          icon: Iconsax.star_1,
                          title: 'Reyting',
                          value: _rating.toString(),
                          color: _getRatingColor(_rating),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  // Menu Items
                  _buildMenuItem(
                    icon: Iconsax.user,
                    title: 'Profil tahrirlash',
                    onTap: () {
                      // Navigate to edit profile
                    },
                  ),
                  _buildMenuItem(
                    icon: Iconsax.activity,
                    title: 'Aktivligim',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ActivityPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Iconsax.setting_2,
                    title: 'Sozlamalar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Iconsax.info_circle,
                    title: 'Ma\'lumotlar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InfoPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Iconsax.call,
                    title: 'Yordam',
                    onTap: () async {
                      final Uri phoneUri = Uri(
                        scheme: 'tel',
                        path: '+998901234567',
                      );
                      if (await canLaunchUrl(phoneUri)) {
                        await launchUrl(phoneUri);
                      }
                    },
                  ),
                  SizedBox(height: 16.h),
                  _buildMenuItem(
                    icon: Iconsax.logout,
                    title: 'Chiqish',
                    onTap: _logout,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10.r,
            offset: Offset(0.w, 4.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28.w),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color accent = isDestructive ? AppColors.error : AppColors.primary;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider, width: 1.w),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(AppColors.isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: Icon(icon, color: accent, size: 22.w),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  color: AppColors.textHint,
                  size: 20.w,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppColors.surface,
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 36.h),
                    Shimmer.fromColors(
                      baseColor: AppColors.divider,
                      highlightColor: AppColors.surfaceVariant,
                      child: Container(
                        width: 84.w,
                        height: 84.w,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Shimmer.fromColors(
                      baseColor: AppColors.divider,
                      highlightColor: AppColors.surfaceVariant,
                      child: Container(
                        width: 140.w,
                        height: 18.h,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Shimmer.fromColors(
                      baseColor: AppColors.divider,
                      highlightColor: AppColors.surfaceVariant,
                      child: Container(
                        width: 100.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Shimmer.fromColors(
                baseColor: AppColors.divider,
                highlightColor: AppColors.surfaceVariant,
                child: Container(
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: Shimmer.fromColors(
                      baseColor: AppColors.divider,
                      highlightColor: AppColors.surfaceVariant,
                      child: Container(
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Shimmer.fromColors(
                      baseColor: AppColors.divider,
                      highlightColor: AppColors.surfaceVariant,
                      child: Container(
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              ...List.generate(
                4,
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Shimmer.fromColors(
                    baseColor: AppColors.divider,
                    highlightColor: AppColors.surfaceVariant,
                    child: Container(
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
