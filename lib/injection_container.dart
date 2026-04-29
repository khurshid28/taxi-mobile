import 'package:get_it/get_it.dart';
import 'core/network/dio_client.dart';
import 'core/network/mercure_service.dart';
import 'features/auth/data/auth_service.dart';
import 'features/orders/data/order_service.dart';
import 'features/profile/data/driver_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core
  sl.registerLazySingleton<DioClient>(() => DioClient());
  sl.registerLazySingleton<MercureService>(() => MercureService());

  // Services
  sl.registerLazySingleton<AuthService>(() => AuthService(sl<DioClient>()));
  sl.registerLazySingleton<DriverService>(() => DriverService(sl<DioClient>()));
  sl.registerLazySingleton<OrderService>(() => OrderService(sl<DioClient>()));
}
