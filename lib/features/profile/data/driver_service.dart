import 'dart:convert';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/driver_data_model.dart';
import '../../../../core/models/driver_profile_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/storage_helper.dart';

class DriverService {
  DriverService(this._client);

  final DioClient _client;

  /// `POST /api/drivers/about_me` - Bearer token kerak.
  Future<DriverProfileModel> aboutMe() async {
    final res = await _client.post('drivers/about_me');
    final data = (res.data as Map).cast<String, dynamic>();
    final profile = DriverProfileModel.fromJson(data);
    if (profile.id != null) {
      await StorageHelper.saveInt(AppConstants.keyDriverId, profile.id!);
    }
    if (profile.phone.isNotEmpty) {
      await StorageHelper.saveString(
          AppConstants.keyUserPhone, profile.phone);
    }
    return profile;
  }

  /// `POST /api/driver_datas/about_me` - mashina/balans/company.
  Future<DriverDataModel> aboutMyData() async {
    final res = await _client.post('driver_datas/about_me');
    final data = (res.data as Map).cast<String, dynamic>();
    final model = DriverDataModel.fromJson(data);
    if (model.companyId != null) {
      await StorageHelper.saveInt(
          AppConstants.keyCompanyId, model.companyId!);
    }
    if (model.tariffs.isNotEmpty) {
      await StorageHelper.saveString(
        AppConstants.keyDriverTariffs,
        jsonEncode(model.tariffs),
      );
    }
    return model;
  }

  /// `POST /api/drivers/location` - haydovchi joylashuvi va tariflar.
  Future<void> updateLocation({
    required int driverId,
    required int companyId,
    required List<String> tariff,
    required double lat,
    required double lng,
  }) async {
    await _client.post(
      'drivers/location',
      data: {
        'driverId': driverId,
        'companyId': companyId,
        'tariff': tariff,
        'lat': lat,
        'lng': lng,
      },
    );
  }
}
