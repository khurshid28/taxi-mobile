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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

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
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Chiqish'),
        content: const Text('Hisobingizdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Yo\'q',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: const Text('Ha', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        backgroundColor: Colors.grey[50],
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
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
                  // Balance Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15.r,
                          offset: Offset(0.w, 8.h),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            (isDestructive ? Colors.red : AppColors.primary).withOpacity(0.01),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: (isDestructive ? Colors.red : AppColors.primary).withOpacity(
            0.1,
          ),
          width: 2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12.r,
            offset: Offset(0.w, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (isDestructive ? Colors.red : AppColors.primary),
                        (isDestructive ? Colors.red : AppColors.primary)
                            .withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: (isDestructive ? Colors.red : AppColors.primary)
                            .withOpacity(0.3),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 24.w),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? Colors.red[700]
                          : AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  color: Colors.grey[400],
                  size: 28.w,
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
                        decoration: const BoxDecoration(
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
                    color: Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
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
                        color: Colors.white,
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
