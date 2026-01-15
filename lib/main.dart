import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'features/splash/presentation/splash_page.dart';
import 'features/auth/presentation/pages/phone_page.dart';
import 'features/auth/presentation/pages/verify_otp_page.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/profile/presentation/pages/complete_profile_page.dart';
import 'features/profile/presentation/cubit/profile_cubit.dart';
import 'features/home/presentation/pages/main_wrapper.dart';
import 'features/home/presentation/cubit/home_cubit.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => ProfileCubit()),
        BlocProvider(create: (_) => HomeCubit()),
      ],
      child: MaterialApp(
        title: 'Taxi Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.splash:
              return MaterialPageRoute(builder: (_) => const SplashPage());
            case AppRoutes.phone:
              return MaterialPageRoute(builder: (_) => const PhonePage());
            case AppRoutes.verifyOtp:
              final phoneNumber = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => VerifyOtpPage(phoneNumber: phoneNumber),
              );
            case AppRoutes.completeProfile:
              return MaterialPageRoute(
                builder: (_) => const CompleteProfilePage(),
              );
            case AppRoutes.home:
              return MaterialPageRoute(builder: (_) => const MainWrapper());
            default:
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Page not found')),
                ),
              );
          }
        },
      ),
    );
  }
}
