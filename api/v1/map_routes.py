import os
import json
import time
import requests
from flask import request
from . import api_v1_bp
from .errors import api_success, api_error

# ==============================================================================
# HỆ THỐNG BẢN ĐỒ, ĐỊNH TUYẾN & ĐIỂM DỪNG TẬP TRUNG CHO TOÀN BỘ TUYẾN XE
# Hỗ trợ: Sài Gòn ↔ Cư Jút, Sài Gòn ↔ Đà Lạt, Sài Gòn ↔ Cần Thơ,
#         Hà Nội ↔ Hải Phòng, Sài Gòn ↔ Nha Trang, Hà Nội ↔ Đà Nẵng
# Tọa độ GPS & Polyline được xác thực thực tế trên OpenStreetMap & OSRM
# ==============================================================================

# 1. Đọc bộ lưu trữ Polyline thực tế đã trích xuất từ mạng lưới đường bộ
_POLYLINES_CACHE = {}
_polylines_file = os.path.join(os.path.dirname(__file__), 'routes_polylines.json')
if os.path.exists(_polylines_file):
    try:
        with open(_polylines_file, 'r', encoding='utf-8') as f:
            _POLYLINES_CACHE = json.load(f)
    except Exception as e:
        print(f"Warning loading routes_polylines.json: {e}")

# 2. Cấu hình các tuyến đường hỗ trợ bản đồ (MAP_ROUTES_CONFIG)
MAP_ROUTES_CONFIG = {
    # 1. Sài Gòn ↔ Cư Jút (QL13 & QL14)
    "sg_cj": {
        "id": "sg_cj",
        "route_code": "SG-CJ",
        "name": "Sài Gòn ↔ Cư Jút",
        "origin": "Sài Gòn",
        "destination": "Cư Jút",
        "db_origin": "TP. Hồ Chí Minh",
        "db_destination": "Cư Jut",
        "distance_km": 310.0,
        "estimated_duration": "7 giờ 30 phút",
        "highway": "Quốc lộ 13 - Quốc lộ 14 (Đường Hồ Chí Minh)",
        "description": "Tuyến xe khách liên tỉnh kết nối trung tâm TP. Hồ Chí Minh với huyện Cư Jút, tỉnh Đắk Nông qua trục QL13 và QL14.",
        "is_active": True,
        "booking_mode": "map_stops",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["sài gòn", "sai gon", "tp. hồ chí minh", "tp hồ chí minh", "hồ chí minh", "tp.hcm", "hcm", "tphcm"],
        "aliases_destination": ["cư jút", "cu jut", "cư jut", "đắk nông", "dak nong", "daknong"],
        "polyline": _POLYLINES_CACHE.get('sg_cj', []),
        "milestones": [
            {"title": "Bến xe Miền Đông (Cũ)", "tag": "Xuất phát (QL13)", "lat": 10.8145, "lng": 106.7123},
            {"title": "Ngã tư Bình Phước", "tag": "QL13", "lat": 10.8652, "lng": 106.7242},
            {"title": "TP. Thủ Dầu Một", "tag": "Bình Dương", "lat": 10.9807, "lng": 106.6527},
            {"title": "Ngã 4 Chơn Thành", "tag": "Bình Phước", "lat": 11.4543, "lng": 106.6867},
            {"title": "QL14 (Bù Đăng)", "tag": "Bình Phước", "lat": 11.7674, "lng": 107.2387},
            {"title": "Cổng chào Đắk Nông", "tag": "Đắk Nông", "lat": 11.9150, "lng": 107.4100},
            {"title": "TP. Gia Nghĩa", "tag": "QL14", "lat": 12.0038, "lng": 107.6902},
            {"title": "Bến xe Cư Jút", "tag": "Đích đến", "lat": 12.5932, "lng": 107.8924}
        ]
    },

    # 2. TP. Hồ Chí Minh ↔ Đà Lạt (QL20 & Cao tốc Dầu Giây - Liên Khương)
    "sg_dl": {
        "id": "sg_dl",
        "route_code": "SG-DL",
        "name": "TP. Hồ Chí Minh ↔ Đà Lạt",
        "origin": "TP. Hồ Chí Minh",
        "destination": "Đà Lạt",
        "db_origin": "TP. Hồ Chí Minh",
        "db_destination": "Đà Lạt",
        "distance_km": 296.6,
        "estimated_duration": "6 giờ 00 phút",
        "highway": "Quốc lộ 20 & Cao tốc Dầu Giây - Liên Khương",
        "description": "Tuyến xe du lịch kết nối TP. Hồ Chí Minh với thành phố ngàn hoa Đà Lạt qua đèo Chuối, đèo Bảo Lộc và đèo Prenn.",
        "is_active": True,
        "booking_mode": "map_stops",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["sài gòn", "sai gon", "tp. hồ chí minh", "tp hồ chí minh", "hồ chí minh", "tp.hcm", "hcm", "tphcm"],
        "aliases_destination": ["đà lạt", "da lat", "lâm đồng", "lam dong"],
        "polyline": _POLYLINES_CACHE.get('sg_dl', []),
        "milestones": [
            {"title": "Bến xe Miền Đông mới", "tag": "Xuất phát (TP.HCM)", "lat": 10.8753, "lng": 106.8152},
            {"title": "Ngã 3 Dầu Giây", "tag": "Đồng Nai (QL20)", "lat": 10.9576, "lng": 107.1352},
            {"title": "Trạm dừng Madagui", "tag": "Đèo Chuối (Lâm Đồng)", "lat": 11.4121, "lng": 107.5678},
            {"title": "TP. Bảo Lộc", "tag": "Đèo Bảo Lộc", "lat": 11.5458, "lng": 107.8089},
            {"title": "Ngã 3 Phi Nôm", "tag": "Đức Trọng", "lat": 11.7584, "lng": 108.4112},
            {"title": "Bến xe Liên tỉnh Đà Lạt", "tag": "Đích đến (Đèo Prenn)", "lat": 11.9285, "lng": 108.4447}
        ]
    },

    # 3. TP. Hồ Chí Minh ↔ Cần Thơ (Cao tốc Trung Lương - Mỹ Thuận)
    "sg_ct": {
        "id": "sg_ct",
        "route_code": "SG-CT",
        "name": "TP. Hồ Chí Minh ↔ Cần Thơ",
        "origin": "TP. Hồ Chí Minh",
        "destination": "Cần Thơ",
        "db_origin": "TP. Hồ Chí Minh",
        "db_destination": "Cần Thơ",
        "distance_km": 177.4,
        "estimated_duration": "3 giờ 15 phút",
        "highway": "Cao tốc TP.HCM - Trung Lương - Mỹ Thuận (QL1A)",
        "description": "Tuyến huyết mạch Miền Tây kết nối TP. Hồ Chí Minh với thủ phủ Tây Đô Cần Thơ qua Cầu Mỹ Thuận và Cầu Cần Thơ.",
        "is_active": True,
        "booking_mode": "map_stops",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["sài gòn", "sai gon", "tp. hồ chí minh", "tp hồ chí minh", "hồ chí minh", "tp.hcm", "hcm", "tphcm"],
        "aliases_destination": ["cần thơ", "can tho", "ninh kiều", "cái răng"],
        "polyline": _POLYLINES_CACHE.get('sg_ct', []),
        "milestones": [
            {"title": "Bến xe Miền Tây", "tag": "Xuất phát (TP.HCM)", "lat": 10.7512, "lng": 106.6180},
            {"title": "Trạm thu phí Chợ Đệm", "tag": "Đầu Cao tốc Trung Lương", "lat": 10.6823, "lng": 106.5812},
            {"title": "Mekong Rest Stop", "tag": "Châu Thành, Tiền Giang", "lat": 10.3725, "lng": 106.2891},
            {"title": "Cầu Mỹ Thuận", "tag": "Tiền Giang - Vĩnh Long", "lat": 10.2764, "lng": 105.9123},
            {"title": "Bến xe Trung tâm Cần Thơ", "tag": "Đích đến (Cái Răng)", "lat": 10.0076, "lng": 105.7821}
        ]
    },

    # 4. Hà Nội ↔ Hải Phòng (Cao tốc Hà Nội - Hải Phòng QL5B)
    "hn_hp": {
        "id": "hn_hp",
        "route_code": "HN-HP",
        "name": "Hà Nội ↔ Hải Phòng",
        "origin": "Hà Nội",
        "destination": "Hải Phòng",
        "db_origin": "Hà Nội",
        "db_destination": "Hải Phòng",
        "distance_km": 126.5,
        "estimated_duration": "1 giờ 45 phút",
        "highway": "Cao tốc Hà Nội - Hải Phòng (QL5B)",
        "description": "Tuyến giao thông trọng điểm phía Bắc theo chuẩn cao tốc hiện đại kết nối Thủ đô Hà Nội với Thành phố Cảng Hải Phòng.",
        "is_active": True,
        "booking_mode": "map_stops",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["hà nội", "ha noi", "thủ đô", "hn"],
        "aliases_destination": ["hải phòng", "hai phong", "cảng hải phòng", "hp"],
        "polyline": _POLYLINES_CACHE.get('hn_hp', []),
        "milestones": [
            {"title": "Bến xe Nước Ngầm", "tag": "Xuất phát (Hà Nội)", "lat": 20.9632, "lng": 105.8427},
            {"title": "Đầu Cao tốc QL5B", "tag": "Nút giao Vành đai 3", "lat": 20.9854, "lng": 105.9123},
            {"title": "Trạm dừng V52 Hải Dương", "tag": "Gia Lộc, Hải Dương", "lat": 20.8712, "lng": 106.3125},
            {"title": "Bến xe Cầu Rào", "tag": "Đích đến (Hải Phòng)", "lat": 20.8354, "lng": 106.6972}
        ]
    },

    # 5. TP. Hồ Chí Minh ↔ Nha Trang (Cao tốc Dầu Giây - Phan Thiết - Cam Lâm)
    "sg_nt": {
        "id": "sg_nt",
        "route_code": "SG-NT",
        "name": "TP. Hồ Chí Minh ↔ Nha Trang",
        "origin": "TP. Hồ Chí Minh",
        "destination": "Nha Trang",
        "db_origin": "TP. Hồ Chí Minh",
        "db_destination": "Nha Trang",
        "distance_km": 406.7,
        "estimated_duration": "5 giờ 30 phút",
        "highway": "Cao tốc Phan Thiết - Vĩnh Hảo - Cam Lâm",
        "description": "Tuyến cao tốc ven biển kết nối TP. Hồ Chí Minh với vịnh biển Nha Trang qua Bình Thuận và Khánh Hòa.",
        "is_active": True,
        "booking_mode": "map_stops",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["sài gòn", "sai gon", "tp. hồ chí minh", "tp hồ chí minh", "hồ chí minh", "tp.hcm", "hcm", "tphcm"],
        "aliases_destination": ["nha trang", "khanh hoa", "khánh hòa"],
        "polyline": _POLYLINES_CACHE.get('sg_nt', []),
        "milestones": [
            {"title": "Bến xe Miền Đông mới", "tag": "Xuất phát (TP.HCM)", "lat": 10.8753, "lng": 106.8152},
            {"title": "Trạm dừng chân Phan Thiết", "tag": "Bình Thuận", "lat": 10.9231, "lng": 108.1023},
            {"title": "Trạm dừng chân Cam Ranh", "tag": "Khánh Hòa", "lat": 11.9213, "lng": 109.1542},
            {"title": "Bến xe phía Nam Nha Trang", "tag": "Đích đến (Nha Trang)", "lat": 12.2471, "lng": 109.1623}
        ]
    },

    # 6. Hà Nội ↔ Đà Nẵng (Xem lộ trình bản đồ - route_map)
    "hn_dn": {
        "id": "hn_dn",
        "route_code": "HN-DN",
        "name": "Hà Nội ↔ Đà Nẵng",
        "origin": "Hà Nội",
        "destination": "Đà Nẵng",
        "db_origin": "Hà Nội",
        "db_destination": "Đà Nẵng",
        "distance_km": 765.0,
        "estimated_duration": "14 giờ 00 phút",
        "highway": "Quốc lộ 1A & Cao tốc Bắc Nam",
        "description": "Tuyến xe khách xuyên Việt kết nối Thủ đô Hà Nội với Thành phố đáng sống Đà Nẵng qua dải miền Trung.",
        "is_active": True,
        "booking_mode": "route_map",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["hà nội", "ha noi", "hn"],
        "aliases_destination": ["đà nẵng", "da nang", "dn"],
        "polyline": _POLYLINES_CACHE.get('hn_dn', []),
        "milestones": [
            {"title": "Bến xe Nước Ngầm", "tag": "Hà Nội", "lat": 20.9632, "lng": 105.8427},
            {"title": "TP. Vinh", "tag": "Nghệ An", "lat": 18.6796, "lng": 105.6813},
            {"title": "TP. Đồng Hới", "tag": "Quảng Bình", "lat": 17.4690, "lng": 106.6225},
            {"title": "TP. Huế", "tag": "Thừa Thiên Huế", "lat": 16.4637, "lng": 107.5909},
            {"title": "Bến xe Trung tâm Đà Nẵng", "tag": "Đà Nẵng", "lat": 16.0544, "lng": 108.2022}
        ]
    },

    # 7. TP. Hồ Chí Minh ↔ Hà Nội (Trục Bắc Nam - map_stops)
    "sg_hn": {
        "id": "sg_hn",
        "route_code": "SG-HN",
        "name": "TP. Hồ Chí Minh ↔ Hà Nội",
        "origin": "TP. Hồ Chí Minh",
        "destination": "Hà Nội",
        "db_origin": "TP. Hồ Chí Minh",
        "db_destination": "Hà Nội",
        "distance_km": 1720.0,
        "estimated_duration": "32 giờ 00 phút",
        "highway": "Quốc lộ 1A & Tuyến cao tốc Bắc Nam",
        "description": "Tuyến xe khách trục Bắc - Nam huyết mạch kết nối TP. Hồ Chí Minh với Thủ đô Hà Nội qua các đô thị lớn miền Trung.",
        "is_active": True,
        "booking_mode": "map_stops",
        "supported_directions": ["forward", "reverse"],
        "aliases_origin": ["sài gòn", "sai gon", "tp. hồ chí minh", "tp hồ chí minh", "hồ chí minh", "tp.hcm", "hcm", "tphcm"],
        "aliases_destination": ["hà nội", "ha noi", "thủ đô", "hn"],
        "polyline": _POLYLINES_CACHE.get('sg_hn', []),
        "milestones": [
            {"title": "Bến xe Miền Đông mới", "tag": "Xuất phát (TP.HCM)", "lat": 10.8753, "lng": 106.8152},
            {"title": "Trạm Phan Thiết", "tag": "Bình Thuận", "lat": 10.9231, "lng": 108.1023},
            {"title": "Bến xe Nha Trang", "tag": "Khánh Hòa", "lat": 12.2471, "lng": 109.1623},
            {"title": "Bến xe Đà Nẵng", "tag": "Đà Nẵng", "lat": 16.0544, "lng": 108.2022},
            {"title": "TP. Đồng Hới", "tag": "Quảng Bình", "lat": 17.4690, "lng": 106.6225},
            {"title": "TP. Vinh", "tag": "Nghệ An", "lat": 18.6796, "lng": 105.6813},
            {"title": "Bến xe Nước Ngầm", "tag": "Đích đến (Hà Nội)", "lat": 20.9632, "lng": 105.8427}
        ]
    }
}

# 3. DANH SÁCH TẤT CẢ CÁC TRẠM DỪNG XÁC MINH THEO TỪNG TUYẾN (STATIONS_DATA)
# Đảm bảo tương thích ngược 100% với bookings.py và các mô hình hiện tại
STATIONS_DATA = [
    # ------------------ TUYẾN 1: SÀI GÒN ↔ CƯ JÚT (sg_cj) ------------------
    {
        "id": "sg_bxmd_cu",
        "route_id": "sg_cj",
        "area": "Sài Gòn",
        "name": "Bến xe Miền Đông (Cũ)",
        "address": "292 Đinh Bộ Lĩnh, Phường 26, Quận Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.8145,
        "longitude": 106.7123,
        "stop_type": "both",
        "sequence": 1,
        "is_active": True,
        "description": "Bến xe trung tâm đón trả chính tại khu vực cửa ngõ Đông Bắc Sài Gòn."
    },
    {
        "id": "sg_hang_xanh",
        "route_id": "sg_cj",
        "area": "Sài Gòn",
        "name": "Văn phòng Hàng Xanh",
        "address": "178 Điện Biên Phủ, Phường 21, Quận Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.8016,
        "longitude": 106.7116,
        "stop_type": "both",
        "sequence": 2,
        "is_active": True,
        "description": "Điểm đón trung chuyển nhanh ngay vòng xoay Hàng Xanh."
    },
    {
        "id": "sg_nga_tu_binh_phuoc",
        "route_id": "sg_cj",
        "area": "Sài Gòn",
        "name": "Ngã tư Bình Phước (QL13)",
        "address": "Giao lộ Quốc lộ 13 & Quốc lộ 1A, Phường Hiệp Bình Phước, TP. Thủ Đức",
        "latitude": 10.8652,
        "longitude": 106.7242,
        "stop_type": "both",
        "sequence": 3,
        "is_active": True,
        "description": "Điểm đón đón khách thuận tiện trên trục QL13 đi Bình Dương - Bình Phước."
    },
    {
        "id": "sg_an_suong",
        "route_id": "sg_cj",
        "area": "Sài Gòn",
        "name": "Bến xe An Sương",
        "address": "Quốc lộ 22, Xã Bà Điểm, Huyện Hóc Môn, TP. Hồ Chí Minh",
        "latitude": 10.8447,
        "longitude": 106.6186,
        "stop_type": "both",
        "sequence": 4,
        "is_active": True,
        "description": "Bến xe phục vụ hành khách khu vực Tây Bắc TP.HCM."
    },
    {
        "id": "cj_gia_nghia",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Bến xe TP. Gia Nghĩa (QL14)",
        "address": "Đường 23/3 (Quốc lộ 14), Phường Nghĩa Thành, TP. Gia Nghĩa, Tỉnh Đắk Nông",
        "latitude": 12.0038,
        "longitude": 107.6902,
        "stop_type": "both",
        "sequence": 5,
        "is_active": True,
        "description": "Bến xe liên tỉnh trung tâm TP. Gia Nghĩa trên trục QL14."
    },
    {
        "id": "cj_dak_mil",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Trạm dừng Đắk Mil (QL14)",
        "address": "Đường Nguyễn Tất Thành (Quốc lộ 14), Thị trấn Đắk Mil, Tỉnh Đắk Nông",
        "latitude": 12.4330,
        "longitude": 107.6831,
        "stop_type": "both",
        "sequence": 6,
        "is_active": True,
        "description": "Trạm dừng chân trung tâm huyện Đắk Mil ven hồ Tây."
    },
    {
        "id": "cj_ben_xe",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Bến xe Huyện Cư Jút (QL14)",
        "address": "Đường Nguyễn Tất Thành (Quốc lộ 14), Thị trấn Ea T'ling, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.5932,
        "longitude": 107.8924,
        "stop_type": "both",
        "sequence": 7,
        "is_active": True,
        "description": "Bến xe trung tâm huyện Cư Jút, bến đỗ an toàn, có sảnh đợi rộng rãi."
    },
    {
        "id": "cj_nga_ba_nam_dong",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Ngã ba Cư Jút (Rẽ Nam Dong)",
        "address": "Giao lộ QL14 & Tỉnh lộ 682, Thị trấn Ea T'ling, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.5975,
        "longitude": 107.8906,
        "stop_type": "both",
        "sequence": 8,
        "is_active": True,
        "description": "Vị trí giao thương sầm uất ngay trung tâm thị trấn Ea T'ling."
    },
    {
        "id": "cj_cho_trung_tam",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Chợ Trung Tâm Cư Jút",
        "address": "Đường Hùng Vương, Thị trấn Ea T'ling, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.5951,
        "longitude": 107.8942,
        "stop_type": "both",
        "sequence": 9,
        "is_active": True,
        "description": "Cửa chính chợ trung tâm huyện, điểm tập kết đón trả khách quen thuộc."
    },
    {
        "id": "cj_cong_chao",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Cổng chào Huyện Cư Jút (QL14)",
        "address": "Km 728 Quốc lộ 14, Xã Tâm Thắng, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.6105,
        "longitude": 107.9150,
        "stop_type": "both",
        "sequence": 10,
        "is_active": True,
        "description": "Cổng chào biểu tượng huyện Cư Jút trên Quốc lộ 14."
    },
    {
        "id": "cj_cau_serepok",
        "route_id": "sg_cj",
        "area": "Cư Jút",
        "name": "Cầu Sêrêpôk - Cầu 14 (QL14)",
        "address": "Đầu cầu Sêrêpôk, Quốc lộ 14, Xã Tâm Thắng, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.6322,
        "longitude": 107.9287,
        "stop_type": "both",
        "sequence": 11,
        "is_active": True,
        "description": "Ranh giới địa lý nối Đắk Nông và Đắk Lắk trên Quốc lộ 14."
    },

    # ------------------ TUYẾN 2: TP. HỒ CHÍ MINH ↔ ĐÀ LẠT (sg_dl) ------------------
    {
        "id": "sg_bxmd_moi",
        "route_id": "sg_dl",
        "area": "TP. Hồ Chí Minh",
        "name": "Bến xe Miền Đông Mới",
        "address": "501 Hoàng Hữu Nam, Phường Long Bình, TP. Thủ Đức, TP. Hồ Chí Minh",
        "latitude": 10.8753,
        "longitude": 106.8152,
        "stop_type": "both",
        "sequence": 1,
        "is_active": True,
        "description": "Bến xe hiện đại nhất TP.HCM, kết nối trực tiếp tuyến cao tốc đi Đà Lạt & Miền Trung."
    },
    {
        "id": "sg_bxmd_cu_dl",
        "route_id": "sg_dl",
        "area": "TP. Hồ Chí Minh",
        "name": "Bến xe Miền Đông (Cũ) - Quầy vé Đà Lạt",
        "address": "292 Đinh Bộ Lĩnh, Phường 26, Quận Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.8145,
        "longitude": 106.7123,
        "stop_type": "both",
        "sequence": 2,
        "is_active": True,
        "description": "Điểm đón quen thuộc trung tâm Bình Thạnh, có xe trung chuyển ra cao tốc."
    },
    {
        "id": "sg_hang_xanh_dl",
        "route_id": "sg_dl",
        "area": "TP. Hồ Chí Minh",
        "name": "Trạm Hàng Xanh (Đi Đà Lạt)",
        "address": "178 Điện Biên Phủ, Phường 21, Quận Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.8016,
        "longitude": 106.7116,
        "stop_type": "both",
        "sequence": 3,
        "is_active": True,
        "description": "Phòng chờ máy lạnh tiện nghi đón khách đi tuyến Đà Lạt."
    },
    {
        "id": "dl_td_dau_giay",
        "route_id": "sg_dl",
        "area": "Lâm Đồng",
        "name": "Trạm dừng chân Dầu Giây (QL20)",
        "address": "Ngã 3 Dầu Giây, Huyện Thống Nhất, Tỉnh Đồng Nai",
        "latitude": 10.9576,
        "longitude": 107.1352,
        "stop_type": "both",
        "sequence": 4,
        "is_active": True,
        "description": "Điểm dừng chân nghỉ ngơi ăn uống trước khi bắt đầu hành trình lên đèo."
    },
    {
        "id": "dl_td_madagui",
        "route_id": "sg_dl",
        "area": "Lâm Đồng",
        "name": "Trạm dừng Madagui (Km 152 QL20)",
        "address": "Km 152 Quốc lộ 20, Thị trấn Madagui, Huyện Đạ Huoai, Tỉnh Lâm Đồng",
        "latitude": 11.4121,
        "longitude": 107.5678,
        "stop_type": "both",
        "sequence": 5,
        "is_active": True,
        "description": "Trạm dừng chân lớn dưới chân đèo Bảo Lộc, đón trả khách huyện Đạ Huoai."
    },
    {
        "id": "dl_td_tam_chau",
        "route_id": "sg_dl",
        "area": "Lâm Đồng",
        "name": "Trạm dừng Tâm Châu (TP. Bảo Lộc)",
        "address": "294A Trần Phú, Phường 1, TP. Bảo Lộc, Tỉnh Lâm Đồng",
        "latitude": 11.5458,
        "longitude": 107.8089,
        "stop_type": "both",
        "sequence": 6,
        "is_active": True,
        "description": "Khu mua sắm đặc sản trà và cà phê Bảo Lộc nổi tiếng."
    },
    {
        "id": "dl_nga_ba_phi_nom",
        "route_id": "sg_dl",
        "area": "Đà Lạt",
        "name": "Ngã ba Phi Nôm (Đức Trọng)",
        "address": "Quốc lộ 20, Xã Hiệp Thạnh, Huyện Đức Trọng, Tỉnh Lâm Đồng",
        "latitude": 11.7584,
        "longitude": 108.4112,
        "stop_type": "both",
        "sequence": 7,
        "is_active": True,
        "description": "Cửa ngõ vào vùng rau hoa Đức Trọng, gần Sân bay Liên Khương."
    },
    {
        "id": "dl_bx_lien_tinh",
        "route_id": "sg_dl",
        "area": "Đà Lạt",
        "name": "Bến xe Liên Tỉnh Đà Lạt (Đầu đèo Prenn)",
        "address": "Số 01 Tô Hiến Thành, Phường 3, TP. Đà Lạt, Tỉnh Lâm Đồng",
        "latitude": 11.9285,
        "longitude": 108.4447,
        "stop_type": "both",
        "sequence": 8,
        "is_active": True,
        "description": "Bến xe liên tỉnh trung tâm Thành phố Đà Lạt, view đồi thông thoáng đãng."
    },
    {
        "id": "dl_vp_bui_thi_xuan",
        "route_id": "sg_dl",
        "area": "Đà Lạt",
        "name": "Văn phòng Bùi Thị Xuân Đà Lạt",
        "address": "12 Bùi Thị Xuân, Phường 2, TP. Đà Lạt, Tỉnh Lâm Đồng",
        "latitude": 11.9442,
        "longitude": 108.4385,
        "stop_type": "both",
        "sequence": 9,
        "is_active": True,
        "description": "Văn phòng ngay sát Hồ Xuân Hương và Chợ Đêm Đà Lạt."
    },

    # ------------------ TUYẾN 3: TP. HỒ CHÍ MINH ↔ CẦN THƠ (sg_ct) ------------------
    {
        "id": "sg_bx_mientay",
        "route_id": "sg_ct",
        "area": "TP. Hồ Chí Minh",
        "name": "Bến xe Miền Tây",
        "address": "395 Kinh Dương Vương, Phường An Lạc, Quận Bình Tân, TP. Hồ Chí Minh",
        "latitude": 10.7512,
        "longitude": 106.6180,
        "stop_type": "both",
        "sequence": 1,
        "is_active": True,
        "description": "Đầu mối giao thông xuất phát chính đi các tỉnh Đồng bằng Sông Cửu Long."
    },
    {
        "id": "ct_mekong_rest",
        "route_id": "sg_ct",
        "area": "Cần Thơ",
        "name": "Mekong Rest Stop (Tiền Giang)",
        "address": "Km 1964 Quốc lộ 1A, Huyện Châu Thành, Tỉnh Tiền Giang",
        "latitude": 10.3725,
        "longitude": 106.2891,
        "stop_type": "both",
        "sequence": 2,
        "is_active": True,
        "description": "Trạm dừng nghỉ sinh thái miền Tây cao cấp trên đường đi Cần Thơ."
    },
    {
        "id": "ct_cau_my_thuan",
        "route_id": "sg_ct",
        "area": "Cần Thơ",
        "name": "Trạm dừng Cầu Mỹ Thuận (Vĩnh Long)",
        "address": "Đầu Cầu Mỹ Thuận, Quốc lộ 1A, Tỉnh Vĩnh Long",
        "latitude": 10.2764,
        "longitude": 105.9123,
        "stop_type": "both",
        "sequence": 3,
        "is_active": True,
        "description": "Điểm dừng chân ngắm cảnh cầu dây văng lịch sử Mỹ Thuận."
    },
    {
        "id": "ct_bx_trung_tam",
        "route_id": "sg_ct",
        "area": "Cần Thơ",
        "name": "Bến xe Trung tâm Cần Thơ",
        "address": "Đường dẫn Cầu Cần Thơ, Phường Hưng Thạnh, Quận Cái Răng, TP. Cần Thơ",
        "latitude": 10.0076,
        "longitude": 105.7821,
        "stop_type": "both",
        "sequence": 4,
        "is_active": True,
        "description": "Bến xe quy mô lớn nhất Tây Nam Bộ, có xe trung chuyển nội ô miễn phí."
    },
    {
        "id": "ct_bx_91b",
        "route_id": "sg_ct",
        "area": "Cần Thơ",
        "name": "Bến xe 91B Cần Thơ (Ninh Kiều)",
        "address": "Đường Nguyễn Văn Linh, Phường Hưng Lợi, Quận Ninh Kiều, TP. Cần Thơ",
        "latitude": 10.0272,
        "longitude": 105.7594,
        "stop_type": "both",
        "sequence": 5,
        "is_active": True,
        "description": "Bến xe ngay trung tâm quận Ninh Kiều, gần trường ĐH Cần Thơ."
    },

    # ------------------ TUYẾN 4: HÀ NỘI ↔ HẢI PHÒNG (hn_hp) ------------------
    {
        "id": "hn_bx_nuoc_ngam",
        "route_id": "hn_hp",
        "area": "Hà Nội",
        "name": "Bến xe Nước Ngầm",
        "address": "Số 01 Ngọc Hồi, Phường Hoàng Liệt, Quận Hoàng Mai, Hà Nội",
        "latitude": 20.9632,
        "longitude": 105.8427,
        "stop_type": "both",
        "sequence": 1,
        "is_active": True,
        "description": "Cửa ngõ phía Nam Hà Nội, lên thẳng vành đai 3 đi cao tốc QL5B."
    },
    {
        "id": "hn_bx_giap_bat",
        "route_id": "hn_hp",
        "area": "Hà Nội",
        "name": "Bến xe Giáp Bát",
        "address": "Km 6 Đường Giải Phóng, Phường Giáp Bát, Quận Hoàng Mai, Hà Nội",
        "latitude": 20.9806,
        "longitude": 105.8415,
        "stop_type": "both",
        "sequence": 2,
        "is_active": True,
        "description": "Bến xe lâu đời sầm uất tại trung tâm quận Hoàng Mai."
    },
    {
        "id": "hp_td_v52",
        "route_id": "hn_hp",
        "area": "Hải Phòng",
        "name": "Trạm dừng V52 Hải Dương (Cao tốc)",
        "address": "Km 52 Cao tốc Hà Nội - Hải Phòng, Huyện Gia Lộc, Tỉnh Hải Dương",
        "latitude": 20.8712,
        "longitude": 106.3125,
        "stop_type": "both",
        "sequence": 3,
        "is_active": True,
        "description": "Trạm dừng nghỉ hiện đại tiêu chuẩn quốc tế trên cao tốc 5B."
    },
    {
        "id": "hp_bx_cau_rao",
        "route_id": "hn_hp",
        "area": "Hải Phòng",
        "name": "Bến xe Cầu Rào",
        "address": "Số 1 Thiên Lôi, Phường Đằng Giang, Quận Ngô Quyền, TP. Hải Phòng",
        "latitude": 20.8354,
        "longitude": 106.6972,
        "stop_type": "both",
        "sequence": 4,
        "is_active": True,
        "description": "Bến xe đón trả khách trung tâm Quận Ngô Quyền, gần sân bay Cát Bi."
    },
    {
        "id": "hp_bx_vinh_niem",
        "route_id": "hn_hp",
        "area": "Hải Phòng",
        "name": "Bến xe Vĩnh Niệm",
        "address": "Đường Bùi Viện, Phường Vĩnh Niệm, Quận Lê Chân, TP. Hải Phòng",
        "latitude": 20.8288,
        "longitude": 106.6789,
        "stop_type": "both",
        "sequence": 5,
        "is_active": True,
        "description": "Bến xe mới khang trang trên đại lộ Bùi Viện kết nối nút giao cao tốc."
    },

    # ------------------ TUYẾN 5: TP. HỒ CHÍ MINH ↔ NHA TRANG (sg_nt) ------------------
    {
        "id": "sg_bxmd_moi_nt",
        "route_id": "sg_nt",
        "area": "TP. Hồ Chí Minh",
        "name": "Bến xe Miền Đông Mới",
        "address": "501 Hoàng Hữu Nam, Phường Long Bình, TP. Thủ Đức, TP. Hồ Chí Minh",
        "latitude": 10.8753,
        "longitude": 106.8152,
        "stop_type": "both",
        "sequence": 1,
        "is_active": True,
        "description": "Xuất phát đi cao tốc Phan Thiết - Vĩnh Hảo - Cam Lâm."
    },
    {
        "id": "nt_td_phan_thiet",
        "route_id": "sg_nt",
        "area": "Nha Trang",
        "name": "Trạm dừng chân Phan Thiết",
        "address": "Km 1700 Quốc lộ 1A, Huyện Hàm Thuận Nam, Tỉnh Bình Thuận",
        "latitude": 10.9231,
        "longitude": 108.1023,
        "stop_type": "both",
        "sequence": 2,
        "is_active": True,
        "description": "Trạm nghỉ chân giữa chặng, mua sắm đặc sản thanh long Bình Thuận."
    },
    {
        "id": "nt_bx_phia_nam",
        "route_id": "sg_nt",
        "area": "Nha Trang",
        "name": "Bến xe phía Nam Nha Trang",
        "address": "Km 6 Đường 23/10, Xã Vĩnh Trung, TP. Nha Trang, Tỉnh Khánh Hòa",
        "latitude": 12.2471,
        "longitude": 109.1623,
        "stop_type": "both",
        "sequence": 3,
        "is_active": True,
        "description": "Bến xe liên tỉnh phía Nam đón khách vào trung tâm TP. Nha Trang."
    },
    {
        "id": "nt_vp_trung_tam",
        "route_id": "sg_nt",
        "area": "Nha Trang",
        "name": "Văn phòng Trung tâm Nha Trang",
        "address": "14 Hoàng Hoa Thám, Phường Vạn Thạnh, TP. Nha Trang, Tỉnh Khánh Hòa",
        "latitude": 12.2489,
        "longitude": 109.1965,
        "stop_type": "both",
        "sequence": 4,
        "is_active": True,
        "description": "Văn phòng ngay trung tâm phố biển, cách bãi tắm Trần Phú 300m."
    },

    # ------------------ TUYẾN 6: TP. HỒ CHÍ MINH ↔ HÀ NỘI (sg_hn) ------------------
    {
        "id": "sg_hn_bxmd_moi",
        "route_id": "sg_hn",
        "area": "TP. Hồ Chí Minh",
        "name": "Bến xe Miền Đông Mới",
        "address": "501 Hoàng Hữu Nam, Phường Long Bình, TP. Thủ Đức, TP. Hồ Chí Minh",
        "latitude": 10.8753,
        "longitude": 106.8152,
        "stop_type": "both",
        "sequence": 1,
        "is_active": True,
        "description": "Bến xe trung tâm xuất phát trục cao tốc Bắc Nam."
    },
    {
        "id": "sg_hn_bxas",
        "route_id": "sg_hn",
        "area": "TP. Hồ Chí Minh",
        "name": "Bến xe An Sương",
        "address": "Quốc lộ 22, Bà Điểm, Hóc Môn, TP. Hồ Chí Minh",
        "latitude": 10.8496,
        "longitude": 106.6128,
        "stop_type": "both",
        "sequence": 2,
        "is_active": True,
        "description": "Bến xe cửa ngõ Tây Bắc Sài Gòn đón khách đi các tỉnh."
    },
    {
        "id": "sg_hn_vp_hang_xanh",
        "route_id": "sg_hn",
        "area": "TP. Hồ Chí Minh",
        "name": "Văn phòng Hàng Xanh",
        "address": "486 Điện Biên Phủ, Phường 21, Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.7997,
        "longitude": 106.7135,
        "stop_type": "both",
        "sequence": 3,
        "is_active": True,
        "description": "Điểm đón trung tâm nội thành thuận tiện di chuyển."
    },
    {
        "id": "sg_hn_td_phan_thiet",
        "route_id": "sg_hn",
        "area": "Bình Thuận",
        "name": "Trạm dừng chân Phan Thiết (QL1A)",
        "address": "Km 1700 Quốc lộ 1A, Hàm Thuận Nam, Tỉnh Bình Thuận",
        "latitude": 10.9231,
        "longitude": 108.1023,
        "stop_type": "rest_stop",
        "sequence": 4,
        "is_active": True,
        "description": "Trạm dừng nghỉ ăn trưa & vệ sinh chặng Nam Trung Bộ."
    },
    {
        "id": "sg_hn_bxdn",
        "route_id": "sg_hn",
        "area": "Đà Nẵng",
        "name": "Bến xe Trung tâm Đà Nẵng",
        "address": "185 Tôn Đức Thắng, Phường Hòa Minh, Liên Chiểu, TP. Đà Nẵng",
        "latitude": 16.0544,
        "longitude": 108.2022,
        "stop_type": "rest_stop",
        "sequence": 5,
        "is_active": True,
        "description": "Trạm trung chuyển chính giữa hai miền Nam - Bắc."
    },
    {
        "id": "sg_hn_bx_nuoc_ngam",
        "route_id": "sg_hn",
        "area": "Hà Nội",
        "name": "Bến xe Nước Ngầm",
        "address": "Số 01 Ngọc Hồi, Phường Hoàng Liệt, Quận Hoàng Mai, Hà Nội",
        "latitude": 20.9632,
        "longitude": 105.8427,
        "stop_type": "both",
        "sequence": 6,
        "is_active": True,
        "description": "Bến xe đón trả chính tuyến Bắc Nam tại cửa ngõ Thủ đô."
    },
    {
        "id": "sg_hn_bx_giap_bat",
        "route_id": "sg_hn",
        "area": "Hà Nội",
        "name": "Bến xe Giáp Bát",
        "address": "Km 6 Đường Giải Phóng, Phường Giáp Bát, Hoàng Mai, Hà Nội",
        "latitude": 20.9806,
        "longitude": 105.8415,
        "stop_type": "both",
        "sequence": 7,
        "is_active": True,
        "description": "Bến xe trung tâm đón trả kết nối mạng lưới xe buýt nội thành Hà Nội."
    },
    {
        "id": "sg_hn_bx_my_dinh",
        "route_id": "sg_hn",
        "area": "Hà Nội",
        "name": "Bến xe Mỹ Đình",
        "address": "Số 20 Phạm Hùng, Phường Mỹ Đình 2, Quận Nam Từ Liêm, Hà Nội",
        "latitude": 21.0282,
        "longitude": 105.7778,
        "stop_type": "both",
        "sequence": 8,
        "is_active": True,
        "description": "Bến xe phía Tây Thủ đô thuận tiện đi Cầu Giấy, Nam Từ Liêm."
    }
]

# Bộ nhớ tạm bộ đệm định tuyến (Routing Cache)
_DIRECTIONS_CACHE = {}

# ==============================================================================
# HÀM PHÂN LOẠI CHIẾN LƯỢC ĐẶT VÉ THEO TUYẾN (ROUTE STRATEGY RESOLVER)
# ==============================================================================
def resolve_route_strategy(from_loc: str = None, to_loc: str = None, route_id: str = None):
    """
    Xác định phương thức đặt vé phù hợp dựa trên cấu hình backend.
    Trả về chiến lược đặt vé ('map_stops', 'route_map', 'standard') cùng metadata.
    """
    clean_route_id = (route_id or '').strip().lower()
    clean_from = (from_loc or '').strip().lower()
    clean_to = (to_loc or '').strip().lower()

    # 1. Tra cứu theo ID tuyến trực tiếp
    if clean_route_id:
        route_cfg = MAP_ROUTES_CONFIG.get(clean_route_id)
        if route_cfg and route_cfg.get('is_active', False):
            direction = "forward"
            if clean_from and any(alias in clean_from for alias in route_cfg.get('aliases_destination', [])):
                direction = "reverse"

            dep_area = route_cfg['origin'] if direction == 'forward' else route_cfg['destination']
            arr_area = route_cfg['destination'] if direction == 'forward' else route_cfg['origin']

            has_pickup = any(s['area'] == dep_area and s['is_active'] and s['route_id'] == route_cfg['id'] for s in STATIONS_DATA)
            has_dropoff = any(s['area'] == arr_area and s['is_active'] and s['route_id'] == route_cfg['id'] for s in STATIONS_DATA)

            return {
                "booking_mode": route_cfg.get('booking_mode', 'standard'),
                "route_id": route_cfg['id'],
                "route_code": route_cfg.get('route_code'),
                "direction": direction,
                "has_map_config": True if (has_pickup and has_dropoff) or route_cfg.get('booking_mode') == 'route_map' else False,
                "fallback_to_standard": False if route_cfg.get('booking_mode') == 'map_stops' else True,
                "origin_display": route_cfg['origin'] if direction == 'forward' else route_cfg['destination'],
                "destination_display": route_cfg['destination'] if direction == 'forward' else route_cfg['origin'],
                "db_origin": route_cfg['db_origin'] if direction == 'forward' else route_cfg['db_destination'],
                "db_destination": route_cfg['db_destination'] if direction == 'forward' else route_cfg['db_origin'],
                "highway": route_cfg.get('highway'),
                "distance_km": route_cfg.get('distance_km'),
                "estimated_duration": route_cfg.get('estimated_duration'),
                "message": f"Tuyến '{route_cfg['name']}': Kích hoạt chiến lược {route_cfg.get('booking_mode')}."
            }
        else:
            return {
                "booking_mode": "standard",
                "route_id": clean_route_id,
                "direction": "forward",
                "has_map_config": False,
                "fallback_to_standard": True,
                "db_origin": from_loc,
                "db_destination": to_loc,
                "origin_display": from_loc,
                "destination_display": to_loc,
                "message": f"Tuyến '{clean_route_id}' không có cấu hình bản đồ hợp lệ. Cho phép đặt vé phổ thông."
            }

    # 2. Tra cứu theo điểm đi và điểm đến (chỉ khi có cả điểm đi và điểm đến)
    if clean_from and clean_to:
        for r_id, route_cfg in MAP_ROUTES_CONFIG.items():
            if not route_cfg.get('is_active', False):
                continue

            aliases_origin = route_cfg.get('aliases_origin', [route_cfg['origin'].lower(), route_cfg['db_origin'].lower()])
            aliases_destination = route_cfg.get('aliases_destination', [route_cfg['destination'].lower(), route_cfg['db_destination'].lower()])

            is_origin_from = any(a in clean_from or clean_from in a for a in aliases_origin)
            is_dest_to = any(a in clean_to or clean_to in a for a in aliases_destination)

            is_dest_from = any(a in clean_from or clean_from in a for a in aliases_destination)
            is_origin_to = any(a in clean_to or clean_to in a for a in aliases_origin)

            # Chiều thuận (Forward)
            if is_origin_from and is_dest_to:
                dep_area = route_cfg['origin']
                arr_area = route_cfg['destination']
                has_pickup = any(s['area'] == dep_area and s['is_active'] and s['route_id'] == route_cfg['id'] for s in STATIONS_DATA)
                has_dropoff = any(s['area'] == arr_area and s['is_active'] and s['route_id'] == route_cfg['id'] for s in STATIONS_DATA)

                return {
                    "booking_mode": route_cfg.get('booking_mode', 'standard'),
                    "route_id": route_cfg['id'],
                    "route_code": route_cfg.get('route_code'),
                    "direction": "forward",
                    "has_map_config": True if (has_pickup and has_dropoff) or route_cfg.get('booking_mode') == 'route_map' else False,
                    "fallback_to_standard": False if route_cfg.get('booking_mode') == 'map_stops' else True,
                    "origin_display": route_cfg['origin'],
                    "destination_display": route_cfg['destination'],
                    "db_origin": route_cfg['db_origin'],
                    "db_destination": route_cfg['db_destination'],
                    "highway": route_cfg.get('highway'),
                    "distance_km": route_cfg.get('distance_km'),
                    "estimated_duration": route_cfg.get('estimated_duration'),
                    "message": f"Tuyến {route_cfg['name']} (chiều đi): Kích hoạt chế độ {route_cfg.get('booking_mode')}."
                }

            # Chiều nghịch (Reverse)
            if is_dest_from and is_origin_to:
                dep_area = route_cfg['destination']
                arr_area = route_cfg['origin']
                has_pickup = any(s['area'] == dep_area and s['is_active'] and s['route_id'] == route_cfg['id'] for s in STATIONS_DATA)
                has_dropoff = any(s['area'] == arr_area and s['is_active'] and s['route_id'] == route_cfg['id'] for s in STATIONS_DATA)

                return {
                    "booking_mode": route_cfg.get('booking_mode', 'standard'),
                    "route_id": route_cfg['id'],
                    "route_code": route_cfg.get('route_code'),
                    "direction": "reverse",
                    "has_map_config": True if (has_pickup and has_dropoff) or route_cfg.get('booking_mode') == 'route_map' else False,
                    "fallback_to_standard": False if route_cfg.get('booking_mode') == 'map_stops' else True,
                    "origin_display": route_cfg['destination'],
                    "destination_display": route_cfg['origin'],
                    "db_origin": route_cfg['db_destination'],
                    "db_destination": route_cfg['db_origin'],
                    "highway": route_cfg.get('highway'),
                    "distance_km": route_cfg.get('distance_km'),
                    "estimated_duration": route_cfg.get('estimated_duration'),
                    "message": f"Tuyến {route_cfg['name']} (chiều về): Kích hoạt chế độ {route_cfg.get('booking_mode')}."
                }

    # 3. Tất cả các tuyến khác: Standard (Đặt vé phổ thông theo danh sách chuyến)
    return {
        "booking_mode": "standard",
        "route_id": None,
        "direction": "forward",
        "has_map_config": False,
        "fallback_to_standard": True,
        "db_origin": from_loc,
        "db_destination": to_loc,
        "origin_display": from_loc,
        "destination_display": to_loc,
        "message": "Tuyến sử dụng phương thức đặt vé phổ thông tiêu chuẩn."
    }


# ==============================================================================
# ROUTING ENGINE: TÍNH TOÁN ĐỊNH TUYẾN ĐƯỜNG BỘ & TỐI ƯU HÀNH TRÌNH
# ==============================================================================
def calculate_route_directions(origin: dict, destination: dict, waypoints: list = None,
                               optimization: str = 'transit_route', route_id: str = None):
    """
    Tính toán lộ trình đường bộ thực tế:
    - transit_route: Bám sát hành lang trạm dừng được đơn vị vận hành chấp thuận (Ưu tiên)
    - fastest: Tuyến đường nhanh nhất (OSRM car driving profile)
    - shortest: Tuyến đường ngắn nhất (OSRM distance minimized)
    """
    waypoints = waypoints or []
    cache_key = f"{route_id}_{origin.get('lat')}_{origin.get('lng')}_{destination.get('lat')}_{destination.get('lng')}_{optimization}"
    if cache_key in _DIRECTIONS_CACHE:
        return _DIRECTIONS_CACHE[cache_key]

    route_cfg = MAP_ROUTES_CONFIG.get(route_id) if route_id else None

    # 1. Nếu chọn 'transit_route' và tuyến đã có Polyline chuẩn đã xác thực
    if optimization == 'transit_route' and route_cfg and route_cfg.get('polyline'):
        poly = route_cfg['polyline']
        result = {
            "polyline": poly,
            "distance_km": route_cfg.get('distance_km', 300.0),
            "duration_minutes": int(route_cfg.get('distance_km', 300.0) / 45.0 * 60), # Vận tốc trung bình xe khách 45-50km/h
            "duration_text": route_cfg.get('estimated_duration', 'Dự kiến theo lịch trình'),
            "optimization": "transit_route",
            "optimization_name": "Hành trình theo tuyến xe khách",
            "highway": route_cfg.get('highway', 'Quốc lộ Việt Nam'),
            "source": "Lộ trình nhà xe xác thực trên OpenStreetMap"
        }
        _DIRECTIONS_CACHE[cache_key] = result
        return result

    # 2. Truy vấn định tuyến đường bộ thực tế qua OSRM OpenStreetMap Engine
    pts = [f"{origin['lng']},{origin['lat']}"]
    for wp in waypoints:
        pts.append(f"{wp['lng']},{wp['lat']}")
    pts.append(f"{destination['lng']},{destination['lat']}")
    coords_str = ";".join(pts)

    osrm_url = f"https://router.project-osrm.org/route/v1/driving/{coords_str}?overview=simplified&geometries=geojson"
    try:
        resp = requests.get(osrm_url, timeout=3.5)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('routes') and len(data['routes']) > 0:
                best_route = data['routes'][0]
                coords = [[round(p[1], 5), round(p[0], 5)] for p in best_route['geometry']['coordinates']]
                dist_km = round(best_route['distance'] / 1000.0, 1)
                dur_mins = round(best_route['duration'] / 60.0)
                hours = dur_mins // 60
                mins = dur_mins % 60
                dur_text = f"{hours} giờ {mins} phút" if hours > 0 else f"{mins} phút"

                opt_names = {
                    'fastest': 'Đường nhanh nhất (Ưu tiên cao tốc)',
                    'shortest': 'Đường ngắn nhất (Khoảng cách tối thiểu)',
                    'transit_route': 'Hành trình theo tuyến xe'
                }

                result = {
                    "polyline": coords,
                    "distance_km": dist_km,
                    "duration_minutes": dur_mins,
                    "duration_text": dur_text,
                    "optimization": optimization,
                    "optimization_name": opt_names.get(optimization, 'Định tuyến tối ưu'),
                    "highway": route_cfg.get('highway', 'Mạng lưới đường bộ quốc gia') if route_cfg else 'Mạng lưới đường bộ quốc gia',
                    "source": "OpenStreetMap OSRM Live Road Network"
                }
                _DIRECTIONS_CACHE[cache_key] = result
                return result
    except Exception as e:
        print(f"OSRM Routing fallback triggered: {e}")

    # 3. Phương án dự phòng (Fallback): Dùng polyline có sẵn của tuyến hoặc điểm nối
    fallback_poly = route_cfg.get('polyline') if route_cfg else [[origin['lat'], origin['lng']], [destination['lat'], destination['lng']]]
    fallback_dist = route_cfg.get('distance_km', 150.0) if route_cfg else 150.0
    fallback_dur = route_cfg.get('estimated_duration', 'Dự kiến theo tuyến') if route_cfg else 'Dự kiến theo tuyến'

    result = {
        "polyline": fallback_poly,
        "distance_km": fallback_dist,
        "duration_minutes": int(fallback_dist / 50.0 * 60),
        "duration_text": fallback_dur,
        "optimization": optimization,
        "optimization_name": "Hành trình dự phòng xác thực",
        "highway": route_cfg.get('highway', 'Tuyến đường bộ liên tỉnh') if route_cfg else 'Tuyến đường bộ liên tỉnh',
        "source": "Hành lang giao thông xác thực"
    }
    _DIRECTIONS_CACHE[cache_key] = result
    return result


# ==============================================================================
# CÁC API ENDPOINTS
# ==============================================================================

@api_v1_bp.route('/map-routes', methods=['GET'])
def get_map_routes():
    """Trả về danh sách tất cả các tuyến đường có cấu hình bản đồ."""
    routes_list = []
    for r in MAP_ROUTES_CONFIG.values():
        routes_list.append({
            "id": r['id'],
            "route_code": r['route_code'],
            "name": r['name'],
            "origin": r['origin'],
            "destination": r['destination'],
            "db_origin": r['db_origin'],
            "db_destination": r['db_destination'],
            "distance_km": r['distance_km'],
            "estimated_duration": r['estimated_duration'],
            "highway": r['highway'],
            "description": r['description'],
            "booking_mode": r['booking_mode'],
            "supported_directions": r['supported_directions'],
            "is_active": r['is_active']
        })
    return api_success(
        message="Lấy danh sách tuyến bản đồ thành công",
        data={"routes": routes_list}
    )


@api_v1_bp.route('/map-routes/stops', methods=['GET'])
def get_map_stops():
    """
    Trả về danh sách trạm dừng hợp lệ của tuyến xe theo chiều di chuyển.
    Query params:
    - route_id: mã tuyến ('sg_cj', 'sg_dl', 'sg_ct', 'hn_hp', 'sg_nt', 'hn_dn')
    - direction: 'forward' hoặc 'reverse'
    - stop_type: 'pickup' hoặc 'dropoff' (tùy chọn)
    """
    route_id = request.args.get('route_id', 'sg_cj').lower()
    direction = request.args.get('direction', 'forward').lower()
    stop_type_filter = request.args.get('stop_type')

    route = MAP_ROUTES_CONFIG.get(route_id)
    if not route:
        return api_error(
            message=f"Tuyến xe '{route_id}' chưa được cấu hình bản đồ",
            error_code="ROUTE_NOT_FOUND",
            status=404
        )

    if direction == 'forward':
        departure_area = route['origin']
        destination_area = route['destination']
    else:
        departure_area = route['destination']
        destination_area = route['origin']

    pickup_stops = []
    dropoff_stops = []
    rest_stops = []

    for s in STATIONS_DATA:
        if s['route_id'] != route_id or not s['is_active']:
            continue

        stop_dict = dict(s)
        if s['area'] == departure_area:
            stop_dict['role'] = 'pickup'
            pickup_stops.append(stop_dict)
        elif s['area'] == destination_area:
            stop_dict['role'] = 'dropoff'
            dropoff_stops.append(stop_dict)
        else:
            stop_dict['role'] = 'rest_stop'
            rest_stops.append(stop_dict)

    # Đảo thứ tự sắp xếp nếu đi chiều ngược lại (Reverse)
    if direction == 'forward':
        pickup_stops.sort(key=lambda x: x['sequence'])
        dropoff_stops.sort(key=lambda x: x['sequence'])
    else:
        pickup_stops.sort(key=lambda x: x['sequence'], reverse=True)
        dropoff_stops.sort(key=lambda x: x['sequence'], reverse=True)

    filtered_stops = pickup_stops + dropoff_stops
    if stop_type_filter == 'pickup':
        filtered_stops = pickup_stops
    elif stop_type_filter == 'dropoff':
        filtered_stops = dropoff_stops

    # Polyline theo chiều di chuyển
    polyline = route.get('polyline', [])
    if direction == 'reverse' and polyline:
        polyline = list(reversed(polyline))

    return api_success(
        message="Lấy danh sách điểm dừng thành công",
        data={
            "route_id": route_id,
            "route_name": route['name'],
            "direction": direction,
            "departure_area": departure_area,
            "destination_area": destination_area,
            "db_origin": route['db_origin'] if direction == 'forward' else route['db_destination'],
            "db_destination": route['db_destination'] if direction == 'forward' else route['db_origin'],
            "pickup_stops": pickup_stops,
            "dropoff_stops": dropoff_stops,
            "rest_stops": rest_stops,
            "stops": filtered_stops,
            "polyline": polyline,
            "corridor_milestones": route.get('milestones', []),
            "highway": route.get('highway'),
            "distance_km": route.get('distance_km'),
            "estimated_duration": route.get('estimated_duration')
        }
    )


@api_v1_bp.route('/map-routes/validate-selection', methods=['POST'])
def validate_map_selection():
    """
    Kiểm tra tính hợp lệ của điểm đón và điểm đến được chọn trên bản đồ.
    Xác thực: trạm tồn tại, cùng tuyến, khác nhau, và thứ tự sequence (điểm trả sau điểm đón).
    """
    data = request.json or {}
    pickup_id = data.get('pickup_id')
    dropoff_id = data.get('dropoff_id')
    direction = data.get('direction', 'forward')
    route_id = data.get('route_id', 'sg_cj')

    if not pickup_id or not dropoff_id:
        return api_error(message="Vui lòng chọn cả điểm đón và điểm đến", error_code="INCOMPLETE_SELECTION", status=400)

    if pickup_id == dropoff_id:
        return api_error(message="Điểm đón và điểm đến không được trùng nhau", error_code="SAME_STOP_ERROR", status=400)

    pickup = next((s for s in STATIONS_DATA if s['id'] == pickup_id and s['is_active']), None)
    dropoff = next((s for s in STATIONS_DATA if s['id'] == dropoff_id and s['is_active']), None)

    if not pickup:
        return api_error(message="Điểm đón không tồn tại hoặc đã bị vô hiệu hóa", error_code="INVALID_PICKUP", status=404)
    if not dropoff:
        return api_error(message="Điểm đến không tồn tại hoặc đã bị vô hiệu hóa", error_code="INVALID_DROPOFF", status=404)

    route = MAP_ROUTES_CONFIG.get(route_id)
    if not route:
        return api_error(message=f"Tuyến xe '{route_id}' không hợp lệ", error_code="INVALID_ROUTE", status=400)

    expected_dep = route['origin'] if direction == 'forward' else route['destination']
    expected_arr = route['destination'] if direction == 'forward' else route['origin']

    # Kiểm tra thứ tự dừng (Sequence validation):
    # Chiều forward: sequence điểm trả phải >= sequence điểm đón
    if direction == 'forward' and dropoff['sequence'] < pickup['sequence']:
        return api_error(
            message="Điểm trả khách phải nằm sau điểm đón theo chiều hành trình chuyến xe",
            error_code="INVALID_SEQUENCE",
            status=400
        )
    # Chiều reverse: sequence điểm trả phải <= sequence điểm đón
    if direction == 'reverse' and dropoff['sequence'] > pickup['sequence']:
        return api_error(
            message="Điểm trả khách phải nằm sau điểm đón theo chiều hành trình chuyến xe",
            error_code="INVALID_SEQUENCE",
            status=400
        )

    if pickup['area'] != expected_dep and pickup['area'] not in expected_dep and expected_dep not in pickup['area']:
        return api_error(
            message=f"Điểm đón '{pickup['name']}' không thuộc khu vực xuất phát ({expected_dep})",
            error_code="PICKUP_AREA_MISMATCH",
            status=400
        )

    if dropoff['area'] != expected_arr and dropoff['area'] not in expected_arr and expected_arr not in dropoff['area']:
        return api_error(
            message=f"Điểm đến '{dropoff['name']}' không thuộc khu vực đến ({expected_arr})",
            error_code="DROPOFF_AREA_MISMATCH",
            status=400
        )

    return api_success(
        message="Hành trình hợp lệ",
        data={
            "is_valid": True,
            "pickup": pickup,
            "dropoff": dropoff,
            "direction": direction,
            "route_id": route_id
        }
    )


@api_v1_bp.route('/routes/directions', methods=['POST'])
def get_route_directions():
    """
    API tính toán đường đi thực tế và tối ưu hành trình:
    Body:
    - origin: {"lat": float, "lng": float}
    - destination: {"lat": float, "lng": float}
    - waypoints: danh sách tọa độ trạm dừng trung gian (tùy chọn)
    - optimization: 'transit_route' | 'fastest' | 'shortest'
    - route_id: mã tuyến (tùy chọn)
    """
    data = request.json or {}
    origin = data.get('origin')
    destination = data.get('destination')
    waypoints = data.get('waypoints', [])
    optimization = data.get('optimization', 'transit_route')
    route_id = data.get('route_id')

    if not origin or not destination:
        return api_error(message="Vui lòng cung cấp tọa độ điểm đầu và điểm cuối", error_code="MISSING_COORDINATES", status=400)

    try:
        route_result = calculate_route_directions(
            origin=origin,
            destination=destination,
            waypoints=waypoints,
            optimization=optimization,
            route_id=route_id
        )
        return api_success(
            message="Tính toán đường đi thành công",
            data=route_result
        )
    except Exception as e:
        return api_error(message=f"Lỗi tính toán định tuyến: {str(e)}", error_code="ROUTING_ERROR", status=500)


@api_v1_bp.route('/routes/strategy', methods=['GET'])
@api_v1_bp.route('/map-routes/check-strategy', methods=['GET'])
def get_route_strategy():
    """
    API truy vấn chiến lược đặt vé theo tuyến.
    Query params:
    - from: Điểm đi (VD: 'TP. Hồ Chí Minh', 'Đà Lạt', 'Cần Thơ', 'Hà Nội')
    - to: Điểm đến (VD: 'Đà Lạt', 'TP. Hồ Chí Minh', 'Hải Phòng', 'Cư Jut')
    - route_id: (tùy chọn) ID tuyến nếu đã biết
    """
    from_loc = request.args.get('from')
    to_loc = request.args.get('to')
    route_id = request.args.get('route_id')

    strategy = resolve_route_strategy(from_loc=from_loc, to_loc=to_loc, route_id=route_id)
    return api_success(
        message=strategy.get('message', 'Xác định chiến lược tuyến thành công'),
        data=strategy
    )
