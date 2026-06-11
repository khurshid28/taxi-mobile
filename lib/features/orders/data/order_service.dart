import '../../../../core/models/order_type_model.dart';
import '../../../../core/network/dio_client.dart';

class OrderService {
  OrderService(this._client);

  final DioClient _client;

  /// `GET /api/order_types` — tarif ro'yxati (narx parametrlari bilan).
  /// Hydra collection: javob `member` (yoki `hydra:member`) ichida keladi.
  Future<List<OrderTypeModel>> fetchOrderTypes() async {
    final res = await _client.get('order_types');
    final data = res.data;
    final members = data is Map
        ? (data['member'] ?? data['hydra:member'])
        : (data is List ? data : null);
    if (members is List) {
      return members
          .whereType<Map>()
          .map((e) => OrderTypeModel.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// `POST /api/orders/{id}/{driverId}/accept`
  Future<Map<String, dynamic>> accept({
    required String orderId,
    required int driverId,
  }) async {
    final res = await _client.post('orders/$orderId/$driverId/accept');
    return _asMap(res.data);
  }

  /// `POST /api/orders/{id}/on_the_way` - haydovchi mijoz oldiga keldi.
  Future<Map<String, dynamic>> onTheWay(String orderId) async {
    final res = await _client.post('orders/$orderId/on_the_way');
    return _asMap(res.data);
  }

  /// `POST /api/orders/{id}/canceled/driver` - olingan, hali borilmagan
  /// buyurtmani bekor qilish (qayta boshqalarga yuboriladi).
  Future<Map<String, dynamic>> cancelByDriver(String orderId) async {
    final res = await _client.post('orders/$orderId/canceled/driver');
    return _asMap(res.data);
  }

  /// `POST /api/orders/{id}/completed`
  Future<Map<String, dynamic>> complete({
    required String orderId,
    required double distance,
    required int minut,
    required double price,
    required String adress,
    required double startLat,
    required double startLng,
  }) async {
    final res = await _client.post(
      'orders/$orderId/completed',
      data: {
        'distance': distance,
        'minut': minut,
        'price': price,
        'adress': adress,
        'startLat': startLat,
        'startLng': startLng,
      },
    );
    return _asMap(res.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
