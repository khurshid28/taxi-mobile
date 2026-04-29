import '../../../../core/auth/auth_events.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/tokens_dto.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/storage_helper.dart';

class AuthService {
  AuthService(this._client);

  final DioClient _client;

  /// `POST /api/drivers/auth` - carNumber + password orqali login.
  Future<TokensDto> login({
    required String carNumber,
    required String password,
  }) async {
    final res = await _client.post(
      'drivers/auth',
      data: {
        'carNumber': carNumber,
        'password': password,
      },
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final tokens = TokensDto.fromJson(data);
    await _saveTokens(tokens);
    return tokens;
  }

  /// `POST /api/drivers/auth/refreshToken`
  Future<TokensDto> refresh(String refreshToken) async {
    final res = await _client.post(
      'drivers/auth/refreshToken',
      data: {'refreshToken': refreshToken},
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final tokens = TokensDto.fromJson(data);
    await _saveTokens(tokens);
    return tokens;
  }

  Future<void> _saveTokens(TokensDto t) async {
    await StorageHelper.saveString(
        AppConstants.keyAccessToken, t.accessToken);
    await StorageHelper.saveString(
        AppConstants.keyRefreshToken, t.refreshToken);
  }

  Future<void> logout() async {
    // Bitta joyda - hamma session storage tozalanadi va router'ga signal ketadi.
    await AuthEvents.instance.notifyExpired();
  }
}
