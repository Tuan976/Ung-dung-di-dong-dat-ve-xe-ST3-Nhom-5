import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/assistant/assistant_screen.dart';
import 'package:mobile_app/services/assistant_service.dart';

class _TestAssistant extends AssistantService {
  static final trip = <String, dynamic>{
    'trip_id': 1,
    'route_text': 'TP. Hồ Chí Minh → Cư Jut',
    'company_name': 'HUTECH BUS Test',
    'bus_type_text': 'Ghế ngồi',
    'time_text': '14:00 26/11/2026',
    'available_seats': 2,
    'price_value': 250000,
  };

  final bookings = <AssistantData>[];

  @override
  Future<AssistantData> settings() async => {
    'locations': ['TP. Hồ Chí Minh', 'Cư Jut'],
    'gemini_enabled': true,
  };

  @override
  Future<AssistantData> ask(AssistantData action) async {
    if (action['action'] == 'select_trip') {
      return {
        'response': 'Mình đã mở sơ đồ ghế.',
        'checkout': {
          'trip': trip,
          'pax': 2,
          'contact': {'name': 'Khách thử', 'phone': '0900000000'},
          'online_payment': false,
        },
      };
    }
    expect(action['message'], 'TP.HCM đi Cư Jút ngày mai, 2 vé');
    return {
      'response': 'Tìm thấy một chuyến.',
      'trips': [trip],
    };
  }

  @override
  Future<AssistantData> seats(int tripId) async => {
    'price': 250000,
    'seat_map': [
      {
        'floor': 'Tầng dưới',
        'rows': [
          [
            {'id': 'A01', 'name': 'A01', 'status': 'available'},
            {'id': 'A02', 'name': 'A02', 'status': 'available'},
            {'id': 'A03', 'name': 'A03', 'status': 'occupied'},
          ],
        ],
      },
    ],
  };

  @override
  Future<AssistantData> book(AssistantData booking) async {
    bookings.add(booking);
    return {
      'success': true,
      'ticket_codes': ['HT12345678', 'HT12345679'],
    };
  }
}

void main() {
  testWidgets(
    'assistant submits suggested seats only after order confirmation',
    (tester) async {
      Future<void> tapVisible(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(finder.hitTestable());
        await tester.pumpAndSettle();
      }

      final service = _TestAssistant();
      await tester.pumpWidget(
        MaterialApp(home: AssistantScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Google Gemini'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'TP.HCM đi Cư Jút ngày mai, 2 vé',
      );
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ghế'));
      await tester.pumpAndSettle();

      final suggest = find.text('Chọn giúp 2 ghế');
      await tapVisible(suggest);
      expect(find.text('Đã chọn 2/2 ghế'), findsOneWidget);
      expect(service.bookings, isEmpty);

      final review = find.text('Xem lại đơn');
      await tapVisible(review);
      expect(find.textContaining('Tổng cộng'), findsOneWidget);
      expect(service.bookings, isEmpty);

      final confirm = find.widgetWithText(FilledButton, 'Xác nhận đặt vé');
      await tapVisible(confirm);
      expect(service.bookings.single['seats'], ['A01', 'A02']);
      expect(service.bookings.single['expected_price'], 250000);
      expect(find.text('Tra vé HT12345678'), findsOneWidget);
    },
  );
}
