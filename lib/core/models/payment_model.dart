class PaymentModel {
  final String id;
  final String title;
  final double amount;
  final PaymentType type;
  final DateTime createdAt;
  final String? orderId;

  PaymentModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.orderId,
  });
}

enum PaymentType {
  topUp,      // Balans to'ldirish
  earning,    // Zakaz orqali daromad
  withdrawal, // Pul yechish
  bonus,      // Bonus
}
