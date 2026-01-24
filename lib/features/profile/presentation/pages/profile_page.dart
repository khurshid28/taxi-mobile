import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/number_formatter.dart';
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
    await Future.delayed(const Duration(milliseconds: 500));

    final name = await StorageHelper.getString('user_name') ?? 'Haydovchi';
    final phone =
        await StorageHelper.getString(AppConstants.keyUserPhone) ?? '';
    final rating = await StorageHelper.getInt('driver_rating') ?? 50;
    final balance = await StorageHelper.getDouble('driver_balance') ?? 295000;
    final trips = await StorageHelper.getInt('total_trips') ?? 6;

    setState(() {
      _name = name;
      _phone = phone;
      _rating = rating;
      _balance = balance;
      _totalTrips = trips;
      _isLoading = false;
    });
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Balansni to\'ldirish',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAmountChip('50,000', amountController),
                  _buildAmountChip('100,000', amountController),
                  _buildAmountChip('200,000', amountController),
                  _buildAmountChip('500,000', amountController),
                ],
              ),
              SizedBox(height: 24.h),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Miqdor (so\'m)',
                  hintText: 'Miqdorni kiriting',
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 2.w,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(
                    amountController.text.replaceAll(',', ''),
                  );
                  if (amount != null && amount > 0) {
                    final newBalance = _balance + amount;
                    await StorageHelper.setDouble('driver_balance', newBalance);
                    setState(() {
                      _balance = newBalance;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Balans muvaffaqiyatli to\'ldirildi!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'To\'ldirish',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountChip(String amount, TextEditingController controller) {
    return InkWell(
      onTap: () {
        controller.text = amount.replaceAll(',', '');
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          amount,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
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
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.h,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 16.h),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10.r,
                              offset: Offset(0.w, 4.h),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 42.r,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person_rounded,
                            size: 48.sp,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _name,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _phone,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 18.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Reyting: $_rating',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: _showTopUpDialog,
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
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
                          icon: Icons.local_taxi,
                          title: 'Safar',
                          value: _totalTrips.toString(),
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.star,
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
                    svgIcon: 'assets/icons/user_duotone.svg',
                    title: 'Profil tahrirlash',
                    onTap: () {
                      // Navigate to edit profile
                    },
                  ),
                  _buildMenuItem(
                    svgIcon: 'assets/icons/history_duotone.svg',
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
                    svgIcon: 'assets/icons/settings_duotone.svg',
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
                    svgIcon: 'assets/icons/info_duotone.svg',
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
                    svgIcon: 'assets/icons/phone_duotone.svg',
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
                    icon: Icons.logout,
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
    IconData? icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    String? svgIcon,
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
                    child: svgIcon != null
                        ? SvgPicture.asset(
                            svgIcon,
                            width: 24.w,
                            height: 24.h,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          )
                        : Icon(icon, color: Colors.white, size: 24.w),
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
                  Icons.chevron_right_rounded,
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
          expandedHeight: 280,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20.h),
                    Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(0.3),
                      highlightColor: Colors.white.withOpacity(0.5),
                      child: Container(
                        width: 100.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(0.3),
                      highlightColor: Colors.white.withOpacity(0.5),
                      child: Container(
                        width: 150.w,
                        height: 24.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(0.3),
                      highlightColor: Colors.white.withOpacity(0.5),
                      child: Container(
                        width: 100.w,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7.r),
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
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
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
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
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
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
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
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
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
