class DriverProfileModel {
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

  DriverProfileModel copyWith({
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
