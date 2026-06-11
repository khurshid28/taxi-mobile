import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../payments/presentation/pages/payments_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    OrdersPage(),
    PaymentsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.sp,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12.sp),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Iconsax.home_2,
              size: 26.w,
              color: AppColors.textSecondary,
            ),
            activeIcon: Icon(
              Iconsax.home_2,
              size: 28.w,
              color: AppColors.primary,
            ),
            label: 'Asosiy',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Iconsax.box,
              size: 26.w,
              color: AppColors.textSecondary,
            ),
            activeIcon: Icon(
              Iconsax.box,
              size: 28.w,
              color: AppColors.primary,
            ),
            label: 'Buyurtmalarim',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Iconsax.wallet,
              size: 26.w,
              color: AppColors.textSecondary,
            ),
            activeIcon: Icon(
              Iconsax.wallet,
              size: 28.w,
              color: AppColors.primary,
            ),
            label: 'To\'lovlarim',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Iconsax.profile_circle,
              size: 26.w,
              color: AppColors.textSecondary,
            ),
            activeIcon: Icon(
              Iconsax.profile_circle,
              size: 28.w,
              color: AppColors.primary,
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
