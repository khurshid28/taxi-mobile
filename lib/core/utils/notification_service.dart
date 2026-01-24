import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'sound_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    bool playSound = true,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'taxi_channel',
      'Taxi Notifications',
      channelDescription: 'Taxi order notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(DateTime.now().millisecond, title, body, details);

    // Play custom sound through SoundService
    if (playSound) {
      await SoundService().playNewOrderSound();
    }
  }

  Future<void> showNewOrderNotification() async {
    await showNotification(
      title: '🚕 Yangi buyurtma!',
      body: 'Yangi buyurtma keldi. Qabul qilish uchun bosing',
      playSound: true,
    );
  }
}
