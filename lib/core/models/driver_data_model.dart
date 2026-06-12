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

  /// Tarif ro'yxati. Backend endi obyekt qaytaradi:
  /// `[{id: 1, name: "Start", active: true}, {id: 2, name: "Kamfort", active: false}]`.
  /// Faqat `active: true` bo'lgan tariflar nomi (filtr va location uchun) olinadi.
  List<String> get tariffs {
    final t = raw['tariff'] ?? raw['tariffs'];
    if (t is List) {
      final names = <String>[];
      for (final e in t) {
        if (e is Map) {
          if (e['active'] == false) continue; // faqat aktiv tariflar
          final name = e['name'];
          if (name != null && name.toString().isNotEmpty) {
            names.add(name.toString());
          }
        } else if (e != null && e.toString().isNotEmpty) {
          names.add(e.toString());
        }
      }
      return names.isEmpty ? const ['Start'] : names;
    }
    if (t is String && t.isNotEmpty) return [t];
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
