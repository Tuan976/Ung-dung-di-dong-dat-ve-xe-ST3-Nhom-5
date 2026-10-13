import sys
import unittest
import json
import uuid

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

from app import app
from models import Trip, Booking, User, Route
from extensions import db
from datetime import datetime, timedelta
from api.v1.auth import _generate_access_token

class TestBookingRefactor(unittest.TestCase):
    def setUp(self):
        self.app = app
        self.client = self.app.test_client()
        self.ctx = self.app.app_context()
        self.ctx.push()

    def tearDown(self):
        self.ctx.pop()

    def test_01_sg_to_cj_activates_busmap(self):
        """1. Tìm tuyến Sài Gòn → Cư Jút: kích hoạt đúng luồng BUSMAP."""
        resp = self.client.get('/api/v1/routes/strategy?from=TP. Hồ Chí Minh&to=Cư Jut')
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()['data']
        self.assertEqual(data['booking_mode'], 'map_stops')
        self.assertEqual(data['direction'], 'forward')
        self.assertEqual(data['route_id'], 'sg_cj')
        self.assertTrue(data['has_map_config'])
        self.assertFalse(data['fallback_to_standard'])
        print("\n[PASS] Test 1: Sài Gòn -> Cư Jút kích hoạt đúng luồng BUSMAP")

    def test_02_cj_to_sg_activates_reverse_busmap(self):
        """2. Tìm tuyến Cư Jút → Sài Gòn: kích hoạt đúng luồng BUSMAP theo chiều ngược lại."""
        resp = self.client.get('/api/v1/routes/strategy?from=Cư Jút&to=TP. Hồ Chí Minh')
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()['data']
        self.assertEqual(data['booking_mode'], 'map_stops')
        self.assertEqual(data['direction'], 'reverse')
        self.assertEqual(data['route_id'], 'sg_cj')
        self.assertTrue(data['has_map_config'])
        self.assertFalse(data['fallback_to_standard'])
        print("[PASS] Test 2: Cư Jút -> Sài Gòn kích hoạt đúng luồng BUSMAP chiều ngược lại")

    def test_03_hanoi_to_haiphong_uses_map_stops(self):
        """3. Tuyến Hà Nội ↔ Hải Phòng: được cấu hình hỗ trợ chọn điểm dừng map_stops."""
        resp = self.client.get('/api/v1/routes/strategy?from=Hà Nội&to=Hải Phòng')
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()['data']
        self.assertEqual(data['booking_mode'], 'map_stops')
        self.assertEqual(data['route_id'], 'hn_hp')
        self.assertTrue(data['has_map_config'])
        print("[PASS] Test 3: Tuyến Hà Nội -> Hải Phòng kích hoạt đúng luồng map_stops")

    def test_04_other_routes_classification(self):
        """4. Kiểm tra phân loại các tuyến: route_map và standard."""
        # Tuyến route_map (Hà Nội -> Đà Nẵng)
        resp_rm = self.client.get('/api/v1/routes/strategy?from=Hà Nội&to=Đà Nẵng')
        self.assertEqual(resp_rm.status_code, 200)
        self.assertEqual(resp_rm.get_json()['data']['booking_mode'], 'route_map')

        # Tuyến standard (không có cấu hình bản đồ)
        standard_pairs = [
            ('Cần Thơ', 'Hà Nội'),
            ('Đà Nẵng', 'Nha Trang'),
            ('Bà Rịa - Vũng Tàu', 'Bạc Liêu'),
        ]
        for from_l, to_l in standard_pairs:
            resp = self.client.get(f'/api/v1/routes/strategy?from={from_l}&to={to_l}')
            self.assertEqual(resp.status_code, 200)
            data = resp.get_json()['data']
            self.assertEqual(data['booking_mode'], 'standard')
            self.assertFalse(data['has_map_config'])
            self.assertTrue(data['fallback_to_standard'])
        print("[PASS] Test 4: Phân loại chính xác các tuyến route_map và standard")

    def test_05_missing_or_invalid_map_config_handled_gracefully(self):
        """5. Tuyến đặc biệt thiếu cấu hình bản đồ: xử lý lỗi phù hợp, fallback sang standard."""
        resp = self.client.get('/api/v1/routes/strategy?route_id=unknown_custom_route')
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()['data']
        self.assertEqual(data['booking_mode'], 'standard')
        self.assertFalse(data['has_map_config'])
        self.assertTrue(data['fallback_to_standard'])
        print("[PASS] Test 5: Tuyến thiếu cấu hình bản đồ fallback sang phổ thông an toàn")

    def test_06_state_isolation_between_busmap_and_standard_search(self):
        """6. Người dùng quay lại và tìm tuyến phổ thông sau BUSMAP: không giữ nhầm trạng thái."""
        r1 = self.client.get('/api/v1/routes/strategy?from=TP. Hồ Chí Minh&to=Cư Jut')
        self.assertEqual(r1.get_json()['data']['booking_mode'], 'map_stops')

        r2 = self.client.get('/api/v1/routes/strategy?from=Cần Thơ&to=Hà Nội')
        self.assertEqual(r2.get_json()['data']['booking_mode'], 'standard')
        self.assertIsNone(r2.get_json()['data']['route_id'])
        print("[PASS] Test 6: Cô lập hoàn toàn trạng thái giữa BUSMAP và tìm kiếm phổ thông")

    def test_07_standard_booking_without_map_stops(self):
        """7. Đặt vé phổ thông: không bị lỗi do thiếu điểm đón hoặc điểm trả trên bản đồ."""
        trip = Trip.query.filter_by(status='Scheduled').first()
        self.assertIsNotNone(trip, "Phải có ít nhất 1 chuyến xe Scheduled để kiểm thử")

        user = User.query.first()
        self.assertIsNotNone(user, "Phải có ít nhất 1 user trong database")

        token, _ = _generate_access_token(user)
        seat_num = f"T{uuid.uuid4().hex[:3].upper()}"

        payload = {
            "trip_id": trip.id,
            "seat_number": seat_num,
            "passenger_name": "Nguyen Van Test",
            "passenger_phone": "0912345678",
            "pickup_point": "Bến xe trung tâm",
            "dropoff_point": "Bến xe đích"
        }

        resp = self.client.post(
            '/api/v1/bookings',
            json=payload,
            headers={'Authorization': f'Bearer {token}'}
        )
        self.assertEqual(resp.status_code, 201)
        booking_data = resp.get_json()['data']
        self.assertIn('booking_id', booking_data)
        print(f"[PASS] Test 7: Đặt vé phổ thông thành công không cần trạm bản đồ (Booking #{booking_data['booking_id']})")

    def test_08_busmap_booking_validates_station_data(self):
        """8. Đặt vé BUSMAP: dữ liệu điểm dừng được kiểm tra ở backend."""
        user = User.query.first()
        token, _ = _generate_access_token(user)

        trip = Trip.query.filter_by(status='Scheduled').first()
        seat_num = f"U{uuid.uuid4().hex[:3].upper()}"

        # 8a: Trạm đón giả mạo/không hợp lệ -> Phải bị từ chối 400
        invalid_payload = {
            "trip_id": trip.id,
            "seat_number": seat_num,
            "passenger_name": "Test BusMap Invalid",
            "passenger_phone": "0987654321",
            "pickup_station_id": "fake_station_99999",
            "dropoff_station_id": "cj_bx_cujut"
        }
        resp_invalid = self.client.post(
            '/api/v1/bookings',
            json=invalid_payload,
            headers={'Authorization': f'Bearer {token}'}
        )
        self.assertEqual(resp_invalid.status_code, 400)
        self.assertEqual(resp_invalid.get_json()['error']['code'], 'INVALID_PICKUP_STATION')

        # 8b: Trạm đón và trả hợp lệ từ STATIONS_DATA -> Phải thành công 201
        valid_payload = {
            "trip_id": trip.id,
            "seat_number": seat_num,
            "passenger_name": "Test BusMap Valid",
            "passenger_phone": "0987654321",
            "pickup_station_id": "sg_bxmd_cu",
            "dropoff_station_id": "cj_ben_xe"
        }
        resp_valid = self.client.post(
            '/api/v1/bookings',
            json=valid_payload,
            headers={'Authorization': f'Bearer {token}'}
        )
        self.assertEqual(resp_valid.status_code, 201)
        b_data = resp_valid.get_json()['data']
        self.assertIn('booking_id', b_data)

        # Kiểm tra booking trong DB lưu đúng pickup và dropoff
        created = Booking.query.get(b_data['booking_id'])
        self.assertIn("Bến xe Miền Đông (Cũ)", created.pickup_point)
        self.assertIn("Cư Jút", created.dropoff_point)
        print(f"[PASS] Test 8: Backend kiểm tra và xác thực trạm BUSMAP thành công (Booking #{b_data['booking_id']})")

    def test_09_payment_and_ticket_confirmation_intact(self):
        """9. Thanh toán và xác nhận vé: không bị ảnh hưởng bởi thay đổi."""
        user = User.query.first()
        token, _ = _generate_access_token(user)

        trip = Trip.query.filter_by(status='Scheduled').first()
        seat_num = f"V{uuid.uuid4().hex[:3].upper()}"

        # Tạo booking
        payload = {
            "trip_id": trip.id,
            "seat_number": seat_num,
            "passenger_name": "Khach Thanh Toan Test",
            "passenger_phone": "0933333333",
            "pickup_station_id": "sg_bxmd_cu",
            "dropoff_station_id": "cj_ben_xe"
        }
        resp = self.client.post(
            '/api/v1/bookings',
            json=payload,
            headers={'Authorization': f'Bearer {token}'}
        )
        self.assertEqual(resp.status_code, 201)
        booking_id = resp.get_json()['data']['booking_id']

        # Khởi tạo thanh toán PayOS qua /api/v1/payments/create
        resp_pay = self.client.post(
            '/api/v1/payments/create',
            json={'booking_id': booking_id},
            headers={'Authorization': f'Bearer {token}'}
        )
        self.assertEqual(resp_pay.status_code, 200)
        pay_data = resp_pay.get_json()['data']
        self.assertIn('order_code', pay_data)

        # Lấy chi tiết vé
        resp_ticket = self.client.get(
            f'/api/v1/bookings/{booking_id}',
            headers={'Authorization': f'Bearer {token}'}
        )
        self.assertEqual(resp_ticket.status_code, 200)
        ticket_data = resp_ticket.get_json()['data']
        self.assertEqual(ticket_data['id'], booking_id)
        self.assertIn('ticket_code', ticket_data)
        print(f"[PASS] Test 9: Thanh toán PayOS và chi tiết vé điện tử / QR Code nguyên vẹn (Ticket: {ticket_data['ticket_code']}, Order #{pay_data['order_code']})")

    def test_10_routing_engine_and_sequence_validation(self):
        """10. Kiểm tra Routing Engine (POST /api/v1/routes/directions) và xác thực thứ tự điểm dừng."""
        # 1. Test Routing Engine qua backend API
        payload = {
            'origin': {'lat': 10.8753, 'lng': 106.8152},
            'destination': {'lat': 11.9285, 'lng': 108.4447},
            'optimization': 'transit_route',
            'route_id': 'sg_dl'
        }
        resp = self.client.post('/api/v1/routes/directions', json=payload)
        self.assertEqual(resp.status_code, 200)
        d_data = resp.get_json()['data']
        self.assertIn('polyline', d_data)
        self.assertGreater(len(d_data['polyline']), 10)
        self.assertEqual(d_data['optimization'], 'transit_route')
        self.assertIn('distance_km', d_data)

        # 2. Test Sequence Validation: Chọn điểm trả trước điểm đón phải bị từ chối
        invalid_seq = {
            'pickup_id': 'cj_cau_serepok', # sequence 11
            'dropoff_id': 'cj_gia_nghia',   # sequence 5
            'direction': 'forward',
            'route_id': 'sg_cj'
        }
        resp_inv = self.client.post('/api/v1/map-routes/validate-selection', json=invalid_seq)
        self.assertEqual(resp_inv.status_code, 400)
        self.assertEqual(resp_inv.get_json()['error']['code'], 'INVALID_SEQUENCE')
        print("[PASS] Test 10: Routing Engine và Sequence Validation hoạt động chuẩn xác")

if __name__ == '__main__':
    unittest.main()

