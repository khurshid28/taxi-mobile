/// `/api/order_types` (OrderTypes) — buyurtma tarifi va narx parametrlari.
///
/// Backend tuzilishi (Hydra collection `member` ichida):
/// ```json
/// {
///   "@id": "/api/order_types/1",
///   "@type": "OrderTypes",
///   "id": 1,
///   "name": "Start",
///   "minPrice": 2500,   // boshlang'ich (base) narx
///   "kmPrice": 2000,    // har km uchun
///   "waitTime": 2,      // bepul kutish (daqiqa)
///   "waitPrice": 500,   // bepul vaqtdan keyin har daqiqaga
///   "status": true
/// }
/// ```
class OrderTypeModel {
  final int? id;
  final String name;
  final double minPrice;
  final double kmPrice;
  final int waitTime; // bepul kutish daqiqalari
  final double waitPrice; // waitTime dan keyin har daqiqa narxi
  final bool status;

  const OrderTypeModel({
    this.id,
    required this.name,
    required this.minPrice,
    required this.kmPrice,
    required this.waitTime,
    required this.waitPrice,
    this.status = true,
  });

  /// Narx maydonlari mavjudmi (order ichida embed bo'lsa ba'zan faqat `name`
  /// keladi — bunda `false` qaytadi va to'liq tarif ro'yxatdan qidiriladi).
  bool get hasPricing => minPrice > 0 || kmPrice > 0;

  factory OrderTypeModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    int? parseId() {
      final raw = json['id'] ?? json['@id'];
      if (raw is int) return raw;
      if (raw is String) {
        // "/api/order_types/1" -> 1
        final last = raw.split('/').last;
        return int.tryParse(last);
      }
      return null;
    }

    return OrderTypeModel(
      id: parseId(),
      name: (json['name'] ?? '').toString(),
      minPrice: toDouble(json['minPrice']),
      kmPrice: toDouble(json['kmPrice']),
      waitTime: toInt(json['waitTime']),
      waitPrice: toDouble(json['waitPrice']),
      status: json['status'] is bool ? json['status'] as bool : true,
    );
  }
}
