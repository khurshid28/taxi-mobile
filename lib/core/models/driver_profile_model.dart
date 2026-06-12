class DriverProfileModel {
  final int? id;
  final int? companyId;
  final String name;
  final String fullname;
  final String email;
  final String phone;
  final String? passportImage;
  final double balance;
  final int rating;
  final int totalTrips;
  final double totalEarnings;

  DriverProfileModel({
    this.id,
    this.companyId,
    required this.name,
    required this.fullname,
    required this.email,
    required this.phone,
    this.passportImage,
    this.balance = 0.0,
    this.rating = 50,
    this.totalTrips = 0,
    this.totalEarnings = 0.0,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    int? id() {
      final v = json['id'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      // Hydra @id: /api/drivers/5
      final iri = json['@id'];
      if (iri is String) {
        final last = iri.split('/').last;
        return int.tryParse(last);
      }
      return null;
    }

    // Kompaniya ID: drivers/about_me -> userCompany: "/api/user_companies/2"
    // (yoki company: "/api/companies/2"). IRI dan oxirgi raqamni olamiz.
    int? company() {
      final v = json['company'] ?? json['userCompany'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final last = v.split('/').last;
        return int.tryParse(last);
      }
      if (v is Map) {
        final cid = v['id'];
        if (cid is int) return cid;
        if (cid is String) return int.tryParse(cid);
      }
      return null;
    }

    double d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int i(dynamic v, [int def = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? def;
      return def;
    }

    return DriverProfileModel(
      id: id(),
      companyId: company(),
      name: (json['name'] ?? json['firstName'] ?? '').toString(),
      fullname:
          (json['fullname'] ?? json['fullName'] ?? json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? json['phoneNumber'] ?? '').toString(),
      passportImage: json['passportImage']?.toString(),
      balance: d(json['balance']),
      rating: i(json['rating'], 50),
      totalTrips: i(json['totalTrips']),
      totalEarnings: d(json['totalEarnings']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'name': name,
        'fullname': fullname,
        'email': email,
        'phone': phone,
        'passportImage': passportImage,
        'balance': balance,
        'rating': rating,
        'totalTrips': totalTrips,
        'totalEarnings': totalEarnings,
      };

  DriverProfileModel copyWith({
    int? id,
    int? companyId,
    String? name,
    String? fullname,
    String? email,
    String? phone,
    String? passportImage,
    double? balance,
    int? rating,
    int? totalTrips,
    double? totalEarnings,
  }) {
    return DriverProfileModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      passportImage: passportImage ?? this.passportImage,
      balance: balance ?? this.balance,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      totalEarnings: totalEarnings ?? this.totalEarnings,
    );
  }
}
