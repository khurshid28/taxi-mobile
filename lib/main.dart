import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/auth/auth_events.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/routes/app_router.dart';
import 'core/utils/notification_service.dart';
import 'core/utils/sound_service.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/profile/presentation/cubit/profile_cubit.dart';
import 'features/home/presentation/cubit/home_cubit.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  // Tema rejimini (yorqin/qorong'i/tizim) yuklab olamiz.
  await ThemeController.instance.load();
  // Bildirishnoma va ovoz servislarini ishga tushiramiz (aks holda
  // notification ko'rinmaydi va ovoz birinchi marta kechikadi).
  await NotificationService().initialize();
  await SoundService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Stream<void> _expired;

  @override
  void initState() {
    super.initState();
    _expired = AuthEvents.instance.onSessionExpired;
    _expired.listen((_) {
      // Tokenlar tozalandi -> login ekraniga
      AppRouter.router.go('/phone');
      final ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Sessiya tugadi. Qayta kiring.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // iPhone X design size (375x812)
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => AuthCubit()),
            BlocProvider(create: (_) => ProfileCubit()),
            BlocProvider(create: (_) => HomeCubit()),
          ],
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, themeMode, _) {
              return MaterialApp.router(
                title: 'Taxi Mobile',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                builder: (context, child) {
                  // Material hal qilgan brightness'ga qarab global dark
                  // flag'ni o'rnatamiz (tizim rejimi ham to'g'ri ishlashi uchun).
                  AppColors.isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return child ?? const SizedBox.shrink();
                },
                routerConfig: AppRouter.router,
              );
            },
          ),
        );
      },
    );
  }
}
