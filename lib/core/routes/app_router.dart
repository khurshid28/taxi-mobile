// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_rebuilder.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/car_number_page.dart';
import '../../features/auth/presentation/pages/password_page.dart';
import '../../features/profile/presentation/pages/complete_profile_page.dart';
import '../../features/home/presentation/pages/main_wrapper.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeRebuilder(builder: (_) => SplashPage()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeRebuilder(builder: (_) => OnboardingPage()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/phone',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeRebuilder(builder: (_) => CarNumberPage()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/password',
        pageBuilder: (context, state) {
          final carNumber = state.extra as String;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ThemeRebuilder(
              builder: (_) => PasswordPage(carNumber: carNumber),
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/complete-profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeRebuilder(builder: (_) => CompleteProfilePage()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ThemeRebuilder(builder: (_) => MainWrapper()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],
  );
}
