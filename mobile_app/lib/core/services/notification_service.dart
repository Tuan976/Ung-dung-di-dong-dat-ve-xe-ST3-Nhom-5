import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(settings: initSettings);
    
    // --- KHỞI TẠO FIREBASE FCM ---
    try {
      await Firebase.initializeApp();
      
      // Xin quyền gửi thông báo (dành cho Android 13+ và iOS)
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      
      // Lấy FCM Token để gửi lên Server
      String? token = await messaging.getToken();
      log("FCM Token: $token");
      
      // Bắt sự kiện khi app đang mở (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Nhận thông báo khi đang mở app: ${message.notification?.title}');
        _notifications.show(
          id: DateTime.now().millisecond,
          title: message.notification?.title,
          body: message.notification?.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'sos_channel',
              'SOS Alerts',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      });
    } catch (e) {
      print("Lỗi khởi tạo Firebase: $e");
    }

    _initialized = true;
  }

  Future<void> showBookingSuccess(String ticketCode) async {
    if (kIsWeb || !_initialized) return;
    await _notifications.show(
      id: 1,
      title: 'Đặt vé thành công! 🎉',
      body: 'Mã vé của bạn: $ticketCode. Vui lòng thanh toán trong 15 phút.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'booking_channel',
          'Đặt vé',
          channelDescription: 'Thông báo đặt vé',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showPaymentSuccess(String ticketCode) async {
    if (kIsWeb || !_initialized) return;
    await _notifications.show(
      id: 2,
      title: 'Thanh toán thành công! ✅',
      body: 'Vé $ticketCode đã được xác nhận.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_channel',
          'Thanh toán',
          channelDescription: 'Thông báo thanh toán',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> scheduleBookingReminder(String ticketCode, DateTime departureTime) async {
    if (kIsWeb || !_initialized) return;
    
    final reminderTime = departureTime.subtract(const Duration(hours: 1));
    if (reminderTime.isBefore(DateTime.now())) return;

    // Calculate delay
    final delay = reminderTime.difference(DateTime.now());
    
    // Use simple delayed notification via Future.delayed (for basic scheduling)
    Future.delayed(delay, () async {
      if (!_initialized) return;
      await _notifications.show(
        id: 3,
        title: 'Nhắc nhở khởi hành 🚌',
        body: 'Chuyến xe của bạn ($ticketCode) sẽ khởi hành sau 1 giờ. Hãy chuẩn bị!',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Nhắc nhở',
            channelDescription: 'Nhắc nhở khởi hành',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> showCancellationNotice(String ticketCode) async {
    if (kIsWeb || !_initialized) return;
    await _notifications.show(
      id: 4,
      title: 'Vé đã được hủy',
      body: 'Vé $ticketCode đã bị hủy thành công.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cancel_channel',
          'Hủy vé',
          channelDescription: 'Thông báo hủy vé',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
