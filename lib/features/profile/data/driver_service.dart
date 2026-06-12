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
    // Kompaniya ID shu yerda (userCompany IRI) keladi - cache'ga saqlaymiz,
    // shunda Mercure uchun qayta-qayta so'rov bermaymiz.
    if (profile.companyId != null) {
      await StorageHelper.saveInt(
          AppConstants.keyCompanyId, profile.companyId!);
    }
    if (profile.phone.isNotEmpty) {
      await StorageHelper.saveString(
          AppConstants.keyUserPhone, profile.phone);
    }
    // ignore: avoid_print
    print('\ud83d\udc64 aboutMe \u2192 driverId=${profile.id}, '
        'companyId=${profile.companyId}, phone=${profile.phone}');
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
    // ignore: avoid_print
    print('\ud83c\udfe2 aboutMyData \u2192 company raw=${data['company']}, '
        'companyId=${model.companyId}, tariffs=${model.tariffs}, '
        'balance raw=${data['balance']} \u2192 ${model.balance}');
    return model;
  }

  /// `POST /api/drivers/location` - haydovchi joylashuvi va tariflar.
  ///
  /// Safar davomida (on_the_way) qo'shimcha `orderId`, `distance` (km),
  /// `price` va `status` ham yuboriladi — backend real vaqt narxini ko'radi.
  Future<void> updateLocation({
    required int driverId,
    required int companyId,
    required List<String> tariff,
    required double lat,
    required double lng,
    String? orderId,
    double? distance,
    double? price,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'driverId': driverId,
      'companyId': companyId,
      'tariff': tariff,
      'lat': lat,
      'lng': lng,
    };
    if (orderId != null) body['orderId'] = orderId;
    if (distance != null) body['distance'] = distance;
    if (price != null) body['price'] = price;
    if (status != null) body['status'] = status;
    await _client.post('drivers/location', data: body);
  }
}
