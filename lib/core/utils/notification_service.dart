import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'sound_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Ilova hozir ekranda (foreground) ochiqmi?
  /// `lifecycleState` `resumed` bo'lsa — foreground. Ilova endi ishga tushgan
  /// payt (null) ham foreground deb hisoblanadi.
  bool get _isAppInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

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

    // Android 13+ (API 33) uchun runtime bildirishnoma ruxsatini so'raymiz.
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required String title,
    required String body,
    bool playSound = true,
  }) async {
    // 1) Ovoz — KUTMASDAN (fire-and-forget). Audio plagini sekin javob bersa
    //    ham na chaqiruvchi (cubit), na bildirishnoma yo'li bloklanadi. Yangi
    //    buyurtma ovozi haydovchini ogohlantirishi uchun foreground'da ham
    //    ijro etiladi (lekin banner emas).
    if (playSound) {
      // ignore: discarded_futures
      SoundService().playNewOrderSound();
    }

    // 2) Ilova OCHIQ (foreground) bo'lsa — TIZIM bildirishnomasi (banner)
    //    KO'RSATILMAYDI. Buyurtma/holat allaqachon ilova ichidagi UI'da
    //    (bottom sheet / panel) ko'rinadi. Banner + ovoz + xarita qayta
    //    chizilishi bir vaqtda kelganda app qotardi — endi foreground'da
    //    faqat UI yangilanadi (banner platform-chaqiruvi tushib qoladi).
    if (_isAppInForeground) return;

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
  }

  Future<void> showNewOrderNotification() async {
    await showNotification(
      title: '🚕 Yangi buyurtma!',
      body: 'Yangi buyurtma keldi. Qabul qilish uchun bosing',
      playSound: true,
    );
  }
}
