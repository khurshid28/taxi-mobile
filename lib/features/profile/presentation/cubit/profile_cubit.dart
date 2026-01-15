import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/storage_helper.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileInitial());

  void updatePassportImage(File image) {
    emit(ProfileImageSelected(image));
  }

  void completeProfile({
    required String name,
    required String fullname,
    String? email,
  }) async {
    emit(ProfileLoading());

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // In real app, upload image and save profile data to backend
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
