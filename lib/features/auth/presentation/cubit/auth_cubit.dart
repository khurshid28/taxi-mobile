import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/storage_helper.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  String? _phoneNumber;

  void sendOtp(String phoneNumber) async {
    emit(AuthLoading());

    try {
      _phoneNumber = phoneNumber;
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // In real app, call API to send OTP
      emit(OtpSent(phoneNumber));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  void verifyOtp(String otp) async {
    emit(AuthLoading());

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // In real app, verify OTP with backend
      if (otp == '123456') {
        // Save login state
        await StorageHelper.saveBool(AppConstants.keyIsLoggedIn, true);
        await StorageHelper.saveString(AppConstants.keyUserPhone, _phoneNumber ?? '');

        emit(AuthSuccess());
      } else {
        emit(const AuthError('Noto\'g\'ri kod kiritildi'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  void resendOtp() async {
    if (_phoneNumber != null) {
      sendOtp(_phoneNumber!);
    }
  }
}
