/// `/api/driver_datas/about_me` javobi (vehicle/balance/etc.).
/// Backend Hydra (application/ld+json) qaytaradi - schema toliq emas,
/// shu sabab xom Map saqlanadi va kerakli maydonlar getterlar bilan o'qiladi.
class DriverDataModel {
  final Map<String, dynamic> raw;

  const DriverDataModel(this.raw);

  factory DriverDataModel.fromJson(Map<String, dynamic> json) =>
      DriverDataModel(json);

  /// Bitta `company` qiymatini (int / IRI string `/api/companies/2` / obyekt)
  /// raqamga aylantiradi.
  static int? _parseCompany(dynamic c) {
    if (c is int) return c;
    if (c is num) return c.toInt();
    if (c is String) {
      // /api/companies/2 -> 2 (yoki to'g'ridan-to'g'ri "2")
      final last = c.split('/').last;
      return int.tryParse(last);
    }
    if (c is Map) {
      final id = c['id'] ?? c['@id'];
      return _parseCompany(id);
    }
    return null;
  }

  /// Kompaniya ID. Backend javob shakli har xil bo'lishi mumkin, shuning uchun
  /// bir nechta joydan qidiramiz:
  ///   - to'g'ridan-to'g'ri `company` / `userCompany`
  ///   - ichki `driver` obyekti ichidagi `company` / `userCompany`
  ///   - Hydra collection bo'lsa `member[0]` / `hydra:member[0]` ichidan.
  int? get companyId {
    int? fromMap(Map src) {
      final direct =
          _parseCompany(src['company'] ?? src['userCompany'] ?? src['companyId']);
      if (direct != null) return direct;
      final driver = src['driver'];
      if (driver is Map) {
        return _parseCompany(
            driver['company'] ?? driver['userCompany'] ?? driver['companyId']);
      }
      return null;
    }

    final top = fromMap(raw);
    if (top != null) return top;

    // Hydra collection: { "member": [ {...} ] } yoki "hydra:member".
    final member = raw['member'] ?? raw['hydra:member'];
    if (member is List && member.isNotEmpty) {
      final first = member.first;
      if (first is Map) return fromMap(first);
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
