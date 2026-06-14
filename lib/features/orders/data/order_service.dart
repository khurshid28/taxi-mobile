import '../../../../core/models/order_model.dart';
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

  /// `GET /api/orders/{id}` — bitta buyurtmaning to'liq ma'lumoti.
  ///
  /// Mercure faqat "yangi buyurtma keldi" degan xabarni (orderId + tariff)
  /// yetkazadi. Mijoz tel raqami, aniq manzillar va narx kabi to'liq ma'lumot
  /// shu endpoint orqali alohida tortib olinadi.
  Future<OrderModel> getOrder(String orderId) async {
    final res = await _client.get('orders/$orderId');
    return OrderModel.fromJson(_asMap(res.data));
  }

  /// `GET /api/orders` — buyurtmalar ro'yxati (API Platform / Hydra collection).
  ///
  /// Tugatilgan buyurtmalar tarixini backenddan olish uchun. Lokal xotira APK
  /// qayta o'rnatilganda tozalanadi — shuning uchun ro'yxat backenddan
  /// tortiladi. [driverId]/[status] berilsa, server filtri bilan cheklashga
  /// urinadi; natija mijoz tomonida ham filtrlanadi (filtr sozlanmagan bo'lsa).
  Future<List<OrderModel>> fetchOrders({int? driverId, String? status}) async {
    final query = <String, dynamic>{};
    if (driverId != null) query['driver'] = '/api/drivers/$driverId';
    if (status != null && status.isNotEmpty) query['status'] = status;
    final res = await _client.get(
      'orders',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    final members = data is Map
        ? (data['member'] ?? data['hydra:member'])
        : (data is List ? data : null);
    if (members is List) {
      return members
          .whereType<Map>()
          .map((e) => OrderModel.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// `GET /api/orders/driver/{id}/active` — haydovchining O'ZIGA tegishli faol
  /// (qabul qilingan) buyurtmalari. Backend maksimal 2 ta qaytaradi. App qayta
  /// ochilganda yoki BOSHQA qurilmada faol safarni tiklash uchun — lokal
  /// snapshot bo'lmasa shu endpoint orqali backenddan olinadi.
  Future<List<OrderModel>> fetchActiveOrders(int driverId) async {
    final res = await _client.get('orders/driver/$driverId/active');
    final data = res.data;
    final members = data is Map
        ? (data['member'] ?? data['hydra:member'])
        : (data is List ? data : null);
    if (members is List) {
      return members
          .whereType<Map>()
          .map((e) => OrderModel.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    // Ba'zan bitta obyekt ham qaytishi mumkin (collection emas).
    if (data is Map && (data['id'] != null || data['@id'] != null)) {
      return [OrderModel.fromJson(data.cast<String, dynamic>())];
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
  ///
  /// Haydovchi buyurtmani o'zi yakunlaganda yuboriladigan maydonlar
  /// (backend sxemasi): distance(km), minut(safar daqiqasi), waitTime(kutish
  /// daqiqasi), price(hisoblangan narx), adress(manzil), endLat/endLng
  /// (safar tugagan nuqta koordinatalari).
  Future<Map<String, dynamic>> complete({
    required String orderId,
    required double distance,
    required int minut,
    required int waitTime,
    required double price,
    required String adress,
    required double endLat,
    required double endLng,
  }) async {
    final res = await _client.post(
      'orders/$orderId/completed',
      data: {
        'distance': distance,
        'minut': minut,
        'waitTime': waitTime,
        'price': price,
        'adress': adress,
        'endLat': endLat,
        'endLng': endLng,
      },
    );
    return _asMap(res.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
