/// `/api/driver_datas/about_me` javobi (vehicle/balance/etc.).
/// Backend Hydra (application/ld+json) qaytaradi - schema toliq emas,
/// shu sabab xom Map saqlanadi va kerakli maydonlar getterlar bilan o'qiladi.
class DriverDataModel {
  final Map<String, dynamic> raw;

  const DriverDataModel(this.raw);

  factory DriverDataModel.fromJson(Map<String, dynamic> json) =>
      DriverDataModel(json);

  int? get companyId {
    final c = raw['company'];
    if (c is int) return c;
    if (c is String) {
      // /api/companies/2 -> 2
      final parts = c.split('/');
      final last = parts.isNotEmpty ? parts.last : '';
      return int.tryParse(last);
    }
    if (c is Map<String, dynamic>) {
      final id = c['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    }
    return null;
  }

  List<String> get tariffs {
    final t = raw['tariff'] ?? raw['tariffs'];
    if (t is List) {
      return t.map((e) => e.toString()).toList();
    }
    if (t is String) return [t];
    return const ['Start'];
  }

  String? get carNumber => raw['carNumber'] as String?;
  String? get carModel => raw['carModel'] as String?;
  double? get balance {
    final b = raw['balance'];
    if (b is num) return b.toDouble();
    if (b is String) return double.tryParse(b);
    return null;
  }
}
