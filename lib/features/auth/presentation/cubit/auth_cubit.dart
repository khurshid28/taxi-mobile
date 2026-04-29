import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/error_mapper.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../injection_container.dart';
import '../../data/auth_service.dart';
import '../../../profile/data/driver_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  String? _carNumber;

  /// 1-bosqich: mashina raqamini saqlab, parol sahifasiga o'tish.
  void enterCarNumber(String carNumber) {
    final normalized = carNumber.trim().toLowerCase().replaceAll(' ', '');
    if (normalized.isEmpty) {
      emit(const AuthError('Mashina raqamini kiriting'));
      return;
    }
    _carNumber = normalized;
    emit(CarNumberEntered(normalized));
  }

  /// 2-bosqich: parol bilan real backend'ga login.
  Future<void> login(String password) async {
    if (_carNumber == null || _carNumber!.isEmpty) {
      emit(const AuthError('Avval mashina raqamini kiriting'));
      return;
    }
    if (password.trim().isEmpty) {
      emit(const AuthError('Parolni kiriting'));
      return;
    }
    emit(AuthLoading());
    try {
      final auth = sl<AuthService>();
      final driver = sl<DriverService>();

      await auth.login(
        carNumber: _carNumber!,
        password: password.trim(),
      );

      // Profil va kompaniya ma'lumotlarini keshlaymiz.
      try {
        await driver.aboutMe();
      } catch (_) {}
      try {
        await driver.aboutMyData();
      } catch (_) {}

      await StorageHelper.saveBool(AppConstants.keyIsLoggedIn, true);

      emit(AuthSuccess());
    } catch (e) {
      emit(AuthError(ErrorMapper.map(e)));
    }
  }
}
