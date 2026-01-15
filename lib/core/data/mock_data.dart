import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';

class MockData {
  // Mock orders
  static List<OrderModel> getOrders() {
    return [
      OrderModel(
        id: 'ORDER001',
        clientName: 'Ali Valiyev',
        clientPhone: '+998901234567',
        pickupLocation: const Point(latitude: 41.2995, longitude: 69.2401),
        destinationLocation: const Point(latitude: 41.3111, longitude: 69.2797),
        pickupAddress: 'Amir Temur ko\'chasi, 12',
        destinationAddress: 'Chilonzor, 9-kvartal',
        distance: 5.2,
        price: 15000,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: OrderStatusType.completed,
      ),
      OrderModel(
        id: 'ORDER002',
        clientName: 'Dilnoza Karimova',
        clientPhone: '+998902345678',
        pickupLocation: const Point(latitude: 41.3050, longitude: 69.2550),
        destinationLocation: const Point(latitude: 41.2850, longitude: 69.2100),
        pickupAddress: 'Yunusobod, 5-mavze',
        destinationAddress: 'Sergeli, Metro bekati',
        distance: 8.7,
        price: 22000,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        status: OrderStatusType.completed,
      ),
      OrderModel(
        id: 'ORDER003',
        clientName: 'Sardor Rashidov',
        clientPhone: '+998903456789',
        pickupLocation: const Point(latitude: 41.3200, longitude: 69.2900),
        destinationLocation: const Point(latitude: 41.3350, longitude: 69.3050),
        pickupAddress: 'Mirzo Ulug\'bek, 100',
        destinationAddress: 'Maksim Gorkiy ko\'chasi',
        distance: 3.5,
        price: 12000,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: OrderStatusType.completed,
      ),
      OrderModel(
        id: 'ORDER004',
        clientName: 'Malika Tursunova',
        clientPhone: '+998904567890',
        pickupLocation: const Point(latitude: 41.2900, longitude: 69.2300),
        destinationLocation: const Point(latitude: 41.3100, longitude: 69.2650),
        pickupAddress: 'Olmozor, 2-mavze',
        destinationAddress: 'Minor, Samarqand darvoza',
        distance: 6.3,
        price: 18000,
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        status: OrderStatusType.completed,
      ),
      OrderModel(
        id: 'ORDER005',
        clientName: 'Jasur Mahmudov',
        clientPhone: '+998905678901',
        pickupLocation: const Point(latitude: 41.3150, longitude: 69.2750),
        destinationLocation: const Point(latitude: 41.2800, longitude: 69.2200),
        pickupAddress: 'Chilonzor, 12-kvartal',
        destinationAddress: 'Qo\'yliq bazaar',
        distance: 10.2,
        price: 28000,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        status: OrderStatusType.completed,
      ),
      OrderModel(
        id: 'ORDER006',
        clientName: 'Nigora Azimova',
        clientPhone: '+998906789012',
        pickupLocation: const Point(latitude: 41.3250, longitude: 69.2850),
        destinationLocation: const Point(latitude: 41.3000, longitude: 69.2400),
        pickupAddress: 'Shayhontohur, 3-mavze',
        destinationAddress: 'Chorsu bozor',
        distance: 4.8,
        price: 14000,
        createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
        status: OrderStatusType.cancelled,
      ),
    ];
  }

  // Mock payments
  static List<PaymentModel> getPayments() {
    return [
      PaymentModel(
        id: 'PAY001',
        title: 'Balans to\'ldirish',
        amount: 100000,
        type: PaymentType.topUp,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      PaymentModel(
        id: 'PAY002',
        title: 'Zakaz #ORDER001',
        amount: 15000,
        type: PaymentType.earning,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        orderId: 'ORDER001',
      ),
      PaymentModel(
        id: 'PAY003',
        title: 'Zakaz #ORDER002',
        amount: 22000,
        type: PaymentType.earning,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        orderId: 'ORDER002',
      ),
      PaymentModel(
        id: 'PAY004',
        title: 'Haftalik bonus',
        amount: 50000,
        type: PaymentType.bonus,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      PaymentModel(
        id: 'PAY005',
        title: 'Zakaz #ORDER003',
        amount: 12000,
        type: PaymentType.earning,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        orderId: 'ORDER003',
      ),
      PaymentModel(
        id: 'PAY006',
        title: 'Balans to\'ldirish',
        amount: 200000,
        type: PaymentType.topUp,
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      ),
      PaymentModel(
        id: 'PAY007',
        title: 'Zakaz #ORDER004',
        amount: 18000,
        type: PaymentType.earning,
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        orderId: 'ORDER004',
      ),
      PaymentModel(
        id: 'PAY008',
        title: 'Karta ga o\'tkazish',
        amount: -150000,
        type: PaymentType.withdrawal,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      PaymentModel(
        id: 'PAY009',
        title: 'Zakaz #ORDER005',
        amount: 28000,
        type: PaymentType.earning,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        orderId: 'ORDER005',
      ),
    ];
  }
}
