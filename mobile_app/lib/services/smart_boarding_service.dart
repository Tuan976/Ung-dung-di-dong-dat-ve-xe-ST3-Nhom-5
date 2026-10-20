import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/booking.dart';

/// Dịch vụ Smart Boarding - Đồng bộ rung & hiển thị trên đồng hồ thông minh
/// (Tương thích Redmi Watch 5 Active, Xiaomi Band qua app Mi Fitness, Apple Watch, v.v.)
class SmartBoardingService {
  SmartBoardingService._internal();
  static final SmartBoardingService instance = SmartBoardingService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String channelId = 'smart_boarding_watch_channel';
  static const String channelName = 'Smart Boarding (Đồng hồ thông minh)';
  static const String channelDesc = 'Cảnh báo rung giờ lên xe, tài xế đến đón và đổi xe trên cổ tay';

  /// Khởi tạo kênh thông báo với độ ưu tiên cao nhất & nhịp rung mạnh đặc thù cho đồng hồ
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    try {
      tzdata.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notifications.initialize(settings: initSettings);

      // Nhịp rung dồn dập đặc thù để truyền qua Bluetooth làm rung đồng hồ
      final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 1000]);

      final androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
      );

      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.requestNotificationsPermission();
      }

      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Lỗi khởi tạo SmartBoardingService: $e');
    }
  }

  NotificationDetails _buildWatchNotificationDetails({String? subtitle}) {
    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 1000]);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'Smart Boarding - Xe Khách',
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive, // Đẩy thẳng ra Bluetooth đồng hồ ngay cả khi bật Focus
        subtitle: subtitle,
      ),
    );
  }

  DateTime? _parseDepartureTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (_) {
      try {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, int.parse(parts[0].trim()), int.parse(parts[1].trim()));
        }
      } catch (_) {}
    }
    return null;
  }

  /// 1. Vé đã được xác nhận (Khi đặt vé thành công)
  Future<void> notifyTicketConfirmed({
    required String ticketCode,
    required String routeName,
    required String departureTime,
    required String seatNumber,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final title = '🎟️ [VÉ ĐÃ XÁC NHẬN] #$ticketCode';
    final body = '$routeName\n🕒 Giờ chạy: $departureTime | Ghế: $seatNumber\nVé đã sẵn sàng trên cổ tay!';

    await _notifications.show(
      id: 101,
      title: title,
      body: body,
      notificationDetails: _buildWatchNotificationDetails(subtitle: 'Vé xe #$ticketCode'),
      payload: 'booking_confirmed_$ticketCode',
    );
  }

  /// 2. Sắp đến giờ xe chạy (Nhắc nhở trước 60p, 30p, 15p)
  Future<void> notifyDepartureApproaching({
    required String ticketCode,
    required String routeName,
    required int minutesLeft,
    String? pickupPoint,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final title = '⏰ [CÒN $minutesLeft PHÚT] Xe sắp chạy!';
    final body = '$routeName\nĐiểm đón: ${pickupPoint ?? "Bến xe"}\nHãy chuẩn bị hành lý và đứng sẵn ở điểm đón.';

    await _notifications.show(
      id: 102,
      title: title,
      body: body,
      notificationDetails: _buildWatchNotificationDetails(subtitle: 'Nhắc giờ xe chạy'),
      payload: 'departure_reminder_$ticketCode',
    );
  }

  /// 3. Xe sắp đến điểm đón (Tài xế cách < 1km / sắp đến)
  Future<void> notifyBusArrivingPickup({
    required String plateNumber,
    required String pickupPoint,
    int minutesLeft = 5,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final title = '🚌 [XE ĐANG ĐẾN] Còn ~$minutesLeft phút';
    final body = 'Biển số: $plateNumber\nĐiểm đón: $pickupPoint\nBác tài đang ghé điểm đón, hãy chú ý xe tới!';

    await _notifications.show(
      id: 103,
      title: title,
      body: body,
      notificationDetails: _buildWatchNotificationDetails(subtitle: 'Xe sắp đến điểm đón'),
      payload: 'bus_arriving_$plateNumber',
    );
  }

  /// 4. Thay đổi biển số xe hoặc vị trí đón (Khẩn cấp)
  Future<void> notifyUrgentChange({
    required String newPlateNumber,
    required String newPickupPoint,
    String? reason,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final title = '⚠️ [CẬP NHẬT GẤP] Đổi xe & Điểm đón';
    final body = 'Biển số mới: $newPlateNumber\nĐiểm đón: $newPickupPoint\n${reason ?? "Nhà xe điều phối xe mới, vui lòng lưu ý!"}';

    await _notifications.show(
      id: 104,
      title: title,
      body: body,
      notificationDetails: _buildWatchNotificationDetails(subtitle: 'Thay đổi thông tin xe'),
      payload: 'urgent_update_$newPlateNumber',
    );
  }

  /// Các mốc nhắc trước giờ xe chạy (phút)
  static const List<int> reminderMinutes = [60, 30, 15];

  int _reminderId(String ticketCode, int minutes) {
    final base = (ticketCode.hashCode.abs() % 100000) * 1000;
    return 10000 + base + minutes;
  }

  /// Tự động lập lịch nhắc giờ xe chạy (60, 30, 15 phút trước giờ chạy).
  /// Lịch do hệ điều hành giữ nên vẫn nổ đúng giờ kể cả khi app đã đóng/khóa màn hình.
  Future<void> scheduleRemindersForBooking(Booking booking) async {
    if (kIsWeb) return;
    await initialize();
    final depTime = _parseDepartureTime(booking.trip?.departureTime);
    if (depTime == null) return;

    final vn = tz.getLocation('Asia/Ho_Chi_Minh');
    final departure = tz.TZDateTime(vn, depTime.year, depTime.month, depTime.day, depTime.hour, depTime.minute);
    final now = tz.TZDateTime.now(vn);

    for (final minutes in reminderMinutes) {
      final fireAt = departure.subtract(Duration(minutes: minutes));
      if (!fireAt.isAfter(now)) continue;

      final route = booking.trip?.routeName ?? 'Hành trình xe khách';
      final pickup = booking.trip?.startPoint ?? 'Bến xe';
      try {
        await _notifications.zonedSchedule(
          id: _reminderId(booking.ticketCode, minutes),
          title: '⏰ [CÒN $minutes PHÚT] Xe sắp chạy!',
          body: '$route\nĐiểm đón: $pickup\nHãy chuẩn bị hành lý và đứng sẵn ở điểm đón.',
          scheduledDate: fireAt,
          notificationDetails: _buildWatchNotificationDetails(subtitle: 'Nhắc giờ xe chạy'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'departure_reminder_${booking.ticketCode}',
        );
      } catch (e) {
        debugPrint('Lỗi lập lịch nhắc $minutes phút: $e');
      }
    }
  }

  /// Hủy các lịch nhắc của một vé (khi hủy vé / đổi vé)
  Future<void> cancelRemindersForBooking(String ticketCode) async {
    if (kIsWeb) return;
    for (final minutes in reminderMinutes) {
      await _notifications.cancel(id: _reminderId(ticketCode, minutes));
    }
  }

  /// Hàm chạy thử nghiệm trực tiếp 4 kịch bản cho người dùng kiểm tra rung đồng hồ Redmi Watch 5 Active
  Future<void> testScenario({required int scenario, Booking? booking}) async {
    final ticketCode = booking?.ticketCode ?? 'VX8899';
    final route = booking?.trip?.routeName ?? 'TP. Hồ Chí Minh - Cư Jút';
    final seat = booking?.seatNumber ?? 'A02';
    final pickup = booking?.trip?.startPoint ?? 'Cổng Bến xe Miền Đông';
    final timeStr = booking?.trip?.departureTime.isNotEmpty == true
        ? booking!.trip!.departureTime
        : '19:30 - Hôm nay';

    switch (scenario) {
      case 1:
        await notifyTicketConfirmed(
          ticketCode: ticketCode,
          routeName: route,
          departureTime: timeStr,
          seatNumber: seat,
        );
        break;
      case 2:
        await notifyDepartureApproaching(
          ticketCode: ticketCode,
          routeName: route,
          minutesLeft: 30,
          pickupPoint: pickup,
        );
        break;
      case 3:
        await notifyBusArrivingPickup(
          plateNumber: '48B-012.34',
          pickupPoint: pickup,
          minutesLeft: 5,
        );
        break;
      case 4:
        await notifyUrgentChange(
          newPlateNumber: '48B-999.88',
          newPickupPoint: '$pickup (Chuyển sang Cổng 2)',
          reason: 'Xe tăng cường thay đổi để đón bạn nhanh hơn',
        );
        break;
    }
  }

  /// Test hẹn giờ: HĐH tự bắn thông báo sau N giây (vẫn chạy khi đã khóa màn hình iPhone)
  Future<void> testScenarioWithDelay({required int scenario, Booking? booking, int delaySeconds = 3}) async {
    await initialize();
    final vn = tz.getLocation('Asia/Ho_Chi_Minh');
    final ticketCode = booking?.ticketCode ?? 'VX8899';
    try {
      await _notifications.zonedSchedule(
        id: 199,
        title: '🎟️ [TEST HẸN GIỜ] Vé #$ticketCode',
        body: 'Thông báo hẹn giờ do hệ điều hành gửi sau $delaySeconds giây.',
        scheduledDate: tz.TZDateTime.now(vn).add(Duration(seconds: delaySeconds)),
        notificationDetails: _buildWatchNotificationDetails(subtitle: 'Test hẹn giờ'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'test_delay_$ticketCode',
      );
    } catch (e) {
      debugPrint('Lỗi test hẹn giờ: $e');
    }
  }
}
