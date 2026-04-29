import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/driver_data_model.dart';
import '../../../../core/models/driver_profile_model.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../injection_container.dart';
import '../../data/driver_service.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileInitial());

  void updatePassportImage(File image) {
    emit(ProfileImageSelected(image));
  }

  /// Backend'dan haydovchi va uning data'sini yuklaydi.
  Future<void> loadDriverProfile() async {
    emit(ProfileLoading());
    try {
      final svc = sl<DriverService>();
      final profile = await svc.aboutMe();
      DriverDataModel? data;
      try {
        data = await svc.aboutMyData();
      } catch (_) {}
      emit(ProfileLoaded(profile: profile, data: data));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  void completeProfile({
    required String name,
    required String fullname,
    String? email,
  }) async {
    emit(ProfileLoading());

    try {
      // Hozircha backend'da profil to'ldirish endpoint'i yo'q,
      // shuning uchun lokal flag'ni saqlaymiz.
      await StorageHelper.saveBool(AppConstants.keyProfileCompleted, true);
      await StorageHelper.saveString('user_name', name);
      await StorageHelper.saveString('user_fullname', fullname);
      if (email != null && email.isNotEmpty) {
        await StorageHelper.saveString('user_email', email);
      }

      emit(ProfileCompleted());
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
