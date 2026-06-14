// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_rebuilder.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../payments/presentation/pages/payments_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ThemeRebuilder(builder: (_) => HomePage()),
      ThemeRebuilder(builder: (_) => OrdersPage(onGoHome: () => _goToTab(0))),
      ThemeRebuilder(builder: (_) => PaymentsPage()),
      ThemeRebuilder(builder: (_) => ProfilePage()),
    ];
  }

  void _goToTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BlocBuilder<HomeCubit, HomeState>(
        // Faol safar yoki global buyurtma o'zgarganda qayta quramiz (amber
        // belgi "Buyurtma" ustida ko'rinishi uchun).
        buildWhen: (p, c) =>
            p.globalOrders.length != c.globalOrders.length ||
            p.currentOrder?.id != c.currentOrder?.id ||
            p.status != c.status,
        builder: (context, state) {
          final globalCount = state.globalOrders.length;
          final hasActive = _isActiveTrip(state);
          return BottomNavigationBar(
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
              fontSize: 11.sp,
            ),
            unselectedLabelStyle: TextStyle(fontSize: 11.sp),
            items: [
              BottomNavigationBarItem(
                icon: Icon(Iconsax.home_2,
                    size: 24.w, color: AppColors.textSecondary),
                activeIcon: Icon(Iconsax.home_2,
                    size: 26.w, color: AppColors.primary),
                label: 'Asosiy',
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Iconsax.box,
                    size: 24.w,
                    color: AppColors.textSecondary,
                    count: globalCount,
                    dot: hasActive),
                activeIcon: _navIcon(Iconsax.box,
                    size: 26.w,
                    color: AppColors.primary,
                    count: globalCount,
                    dot: hasActive),
                label: 'Buyurtma',
              ),
              BottomNavigationBarItem(
                icon: Icon(Iconsax.wallet,
                    size: 24.w, color: AppColors.textSecondary),
                activeIcon: Icon(Iconsax.wallet,
                    size: 26.w, color: AppColors.primary),
                label: 'To\'lov',
              ),
              BottomNavigationBarItem(
                icon: Icon(Iconsax.profile_circle,
                    size: 24.w, color: AppColors.textSecondary),
                activeIcon: Icon(Iconsax.profile_circle,
                    size: 26.w, color: AppColors.primary),
                label: 'Profil',
              ),
            ],
          );
        },
      ),
    );
  }

  /// Faol (qabul qilingan) safar bormi — footer "Buyurtma" ustidagi amber
  /// belgi shu va global buyurtmalarga qarab ko'rinadi.
  bool _isActiveTrip(HomeState s) =>
      s.currentOrder != null &&
      (s.status == OrderStatus.orderAccepted ||
          s.status == OrderStatus.goingToClient ||
          s.status == OrderStatus.waitingForClient ||
          s.status == OrderStatus.inProgress);

  /// "Buyurtma" nav ikonasi ustidagi AMBER belgi: global buyurtmalar soni
  /// (count > 0) yoki faol safar (dot) bo'lsa ko'rinadi.
  Widget _navIcon(
    IconData icon, {
    required double size,
    required Color color,
    int count = 0,
    bool dot = false,
  }) {
    final iconWidget = Icon(icon, size: size, color: color);
    if (count <= 0 && !dot) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        if (count > 0)
          Positioned(
            right: -8.w,
            top: -5.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              constraints: BoxConstraints(minWidth: 16.w),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.surface, width: 1.5.w),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          )
        else
          // Faqat faol safar (global yo'q) — raqamsiz kichik amber nuqta.
          Positioned(
            right: -3.w,
            top: -2.h,
            child: Container(
              width: 9.w,
              height: 9.w,
              decoration: BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5.w),
              ),
            ),
          ),
      ],
    );
  }
}
