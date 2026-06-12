import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/storage_helper.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _navigateToNext();
  }

  void _initAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Splash ochilgandan keyin location ruxsatini so'rab olamiz.
    await _requestLocationPermission();

    if (!mounted) return;

    // Check if onboarding was shown
    final onboardingShown =
        await StorageHelper.getBool(AppConstants.keyOnboardingShown) ?? false;

    if (!onboardingShown) {
      await StorageHelper.saveBool(AppConstants.keyOnboardingShown, true);
      context.go('/onboarding');
      return;
    }

    // Check authentication status
    final isLoggedIn =
        await StorageHelper.getBool(AppConstants.keyIsLoggedIn) ?? false;

    if (isLoggedIn) {
      // Backend'da profil/registration yo'q - to'g'ridan-to'g'ri home'ga
      context.go('/home');
    } else {
      context.go('/phone');
    }
  }

  /// Splash'dan keyin location ruxsatini so'raydi. Rad etilsa ham
  /// navigatsiyani to'xtatmaymiz — home keyinroq qayta tekshiradi.
  Future<void> _requestLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // Ruxsat oqibatlari home_cubit ichida qayta boshqariladi.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yumshoq gradient fon. Logo bevosita fon ustida (oq karta yo'q) — shu
    // sababli logo orqa foni va fon o'rtasida "sezilib qoladigan" chegara
    // umuman bo'lmaydi.
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color.lerp(AppColors.primary, Colors.black, 0.22)!,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo to'g'ridan-to'g'ri gradient ustida — chegarasiz.
                Image.asset(
                  'assets/images/taxi_logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                const Text(
                  'Taxi Mobile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tez va qulay taxi xizmati',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
