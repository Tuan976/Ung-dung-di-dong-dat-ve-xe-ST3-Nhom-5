import json
import sys
sys.stdout.reconfigure(encoding='utf-8')
from app import app
from extensions import db
from models import LocationStop, RouteStop, Route

# Danh sách tất cả các trạm dừng và bến xe thực tế được xác minh tọa độ GPS
ALL_STATIONS = [
    # ------------------ KHU VỰC SÀI GÒN / TP. HỒ CHÍ MINH ------------------
    {
        "id": "sg_bxmd_cu",
        "name": "Bến xe Miền Đông (Cũ)",
        "area": "TP. Hồ Chí Minh",
        "address": "292 Đinh Bộ Lĩnh, Phường 26, Quận Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.8145,
        "longitude": 106.7123,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "sg_bxmd_moi",
        "name": "Bến xe Miền Đông Mới",
        "area": "TP. Hồ Chí Minh",
        "address": "501 Hoàng Hữu Nam, Phường Long Bình, TP. Thủ Đức, TP. Hồ Chí Minh",
        "latitude": 10.8753,
        "longitude": 106.8152,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "sg_bx_mientay",
        "name": "Bến xe Miền Tây",
        "area": "TP. Hồ Chí Minh",
        "address": "395 Kinh Dương Vương, Phường An Lạc, Quận Bình Tân, TP. Hồ Chí Minh",
        "latitude": 10.7512,
        "longitude": 106.6180,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "sg_an_suong",
        "name": "Bến xe An Sương",
        "area": "TP. Hồ Chí Minh",
        "address": "Quốc lộ 22, Xã Bà Điểm, Huyện Hóc Môn, TP. Hồ Chí Minh",
        "latitude": 10.8447,
        "longitude": 106.6186,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "sg_hang_xanh",
        "name": "Văn phòng Hàng Xanh",
        "area": "TP. Hồ Chí Minh",
        "address": "178 Điện Biên Phủ, Phường 21, Quận Bình Thạnh, TP. Hồ Chí Minh",
        "latitude": 10.8016,
        "longitude": 106.7116,
        "location_type": "agency",
        "is_active": True
    },
    {
        "id": "sg_nga_tu_binh_phuoc",
        "name": "Ngã tư Bình Phước (QL13)",
        "area": "TP. Hồ Chí Minh",
        "address": "Giao lộ Quốc lộ 13 & Quốc lộ 1A, Phường Hiệp Bình Phước, TP. Thủ Đức, TP. Hồ Chí Minh",
        "latitude": 10.8652,
        "longitude": 106.7242,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "sg_suoi_tien",
        "name": "Khu du lịch Suối Tiên (Xa lộ Hà Nội)",
        "area": "TP. Hồ Chí Minh",
        "address": "120 Xa lộ Hà Nội, Phường Tân Phú, TP. Thủ Đức, TP. Hồ Chí Minh",
        "latitude": 10.8655,
        "longitude": 106.8021,
        "location_type": "stop",
        "is_active": True
    },

    # ------------------ KHU VỰC CƯ JÚT & ĐẮK NÔNG (QL14) ------------------
    {
        "id": "cj_ben_xe",
        "name": "Bến xe Huyện Cư Jút (QL14)",
        "area": "Cư Jút",
        "address": "Đường Nguyễn Tất Thành (Quốc lộ 14), Thị trấn Ea T'ling, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.5932,
        "longitude": 107.8924,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "cj_cho_trung_tam",
        "name": "Chợ Trung Tâm Cư Jút",
        "area": "Cư Jút",
        "address": "Đường Hùng Vương, Thị trấn Ea T'ling, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.5951,
        "longitude": 107.8942,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "cj_nga_ba_nam_dong",
        "name": "Ngã ba Cư Jút (Rẽ Nam Dong)",
        "area": "Cư Jút",
        "address": "Giao lộ QL14 & Tỉnh lộ 682, Thị trấn Ea T'ling, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.5975,
        "longitude": 107.8906,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "cj_cong_chao",
        "name": "Cổng chào Huyện Cư Jút (QL14)",
        "area": "Cư Jút",
        "address": "Km 728 Quốc lộ 14, Xã Tâm Thắng, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.6105,
        "longitude": 107.9150,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "cj_gia_nghia",
        "name": "Bến xe TP. Gia Nghĩa (QL14)",
        "area": "Cư Jút",
        "address": "Đường 23/3 (Quốc lộ 14), Phường Nghĩa Thành, TP. Gia Nghĩa, Tỉnh Đắk Nông",
        "latitude": 12.0038,
        "longitude": 107.6902,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "cj_dak_mil",
        "name": "Trạm dừng Đắk Mil (QL14)",
        "area": "Cư Jút",
        "address": "Đường Nguyễn Tất Thành (Quốc lộ 14), Thị trấn Đắk Mil, Tỉnh Đắk Nông",
        "latitude": 12.4330,
        "longitude": 107.6831,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "cj_cau_serepok",
        "name": "Cầu Sêrêpôk - Cầu 14 (QL14)",
        "area": "Cư Jút",
        "address": "Đầu cầu Sêrêpôk, Quốc lộ 14, Xã Tâm Thắng, Huyện Cư Jút, Tỉnh Đắk Nông",
        "latitude": 12.6322,
        "longitude": 107.9287,
        "location_type": "stop",
        "is_active": True
    },

    # ------------------ KHU VỰC ĐÀ LẠT & LÂM ĐỒNG (QL20) ------------------
    {
        "id": "dl_bx_lien_tinh",
        "name": "Bến xe Liên Tỉnh Đà Lạt",
        "area": "Đà Lạt",
        "address": "Số 01 Tô Hiến Thành, Phường 3, TP. Đà Lạt, Tỉnh Lâm Đồng",
        "latitude": 11.9285,
        "longitude": 108.4447,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "dl_vp_bui_thi_xuan",
        "name": "Văn phòng Trung tâm Bùi Thị Xuân Đà Lạt",
        "area": "Đà Lạt",
        "address": "12 Bùi Thị Xuân, Phường 2, TP. Đà Lạt, Tỉnh Lâm Đồng",
        "latitude": 11.9442,
        "longitude": 108.4385,
        "location_type": "agency",
        "is_active": True
    },
    {
        "id": "dl_nga_5_dai_hoc",
        "name": "Ngã 5 Đại học Đà Lạt",
        "area": "Đà Lạt",
        "address": "Đường Phù Đổng Thiên Vương, Phường 8, TP. Đà Lạt, Tỉnh Lâm Đồng",
        "latitude": 11.9567,
        "longitude": 108.4452,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "dl_td_dau_giay",
        "name": "Trạm dừng chân Dầu Giây (QL20)",
        "area": "Đồng Nai",
        "address": "Ngã 3 Dầu Giây, Huyện Thống Nhất, Tỉnh Đồng Nai",
        "latitude": 10.9576,
        "longitude": 107.1352,
        "location_type": "rest_stop",
        "is_active": True
    },
    {
        "id": "dl_td_madagui",
        "name": "Trạm dừng chân Madagui (Km 152 QL20)",
        "area": "Lâm Đồng",
        "address": "Km 152 Quốc lộ 20, Thị trấn Madagui, Huyện Đạ Huoai, Tỉnh Lâm Đồng",
        "latitude": 11.4121,
        "longitude": 107.5678,
        "location_type": "rest_stop",
        "is_active": True
    },
    {
        "id": "dl_td_tam_chau",
        "name": "Trạm dừng chân Tâm Châu (Bảo Lộc)",
        "area": "Lâm Đồng",
        "address": "294A Trần Phú, Phường 1, TP. Bảo Lộc, Tỉnh Lâm Đồng",
        "latitude": 11.5458,
        "longitude": 107.8089,
        "location_type": "rest_stop",
        "is_active": True
    },
    {
        "id": "dl_nga_ba_phi_nom",
        "name": "Ngã ba Phi Nôm (Đức Trọng)",
        "area": "Lâm Đồng",
        "address": "Quốc lộ 20, Xã Hiệp Thạnh, Huyện Đức Trọng, Tỉnh Lâm Đồng",
        "latitude": 11.7584,
        "longitude": 108.4112,
        "location_type": "stop",
        "is_active": True
    },

    # ------------------ KHU VỰC CẦN THƠ (MIỀN TÂY) ------------------
    {
        "id": "ct_bx_trung_tam",
        "name": "Bến xe Trung tâm Cần Thơ",
        "area": "Cần Thơ",
        "address": "Đường dẫn Cầu Cần Thơ, Phường Hưng Thạnh, Quận Cái Răng, TP. Cần Thơ",
        "latitude": 10.0076,
        "longitude": 105.7821,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "ct_bx_91b",
        "name": "Bến xe 91B Cần Thơ",
        "area": "Cần Thơ",
        "address": "Đường Nguyễn Văn Linh, Phường Hưng Lợi, Quận Ninh Kiều, TP. Cần Thơ",
        "latitude": 10.0272,
        "longitude": 105.7594,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "ct_cho_noi",
        "name": "Bến tàu Chợ Nổi Cái Răng",
        "area": "Cần Thơ",
        "address": "Đường Hai Bà Trưng, Phường Lê Bình, Quận Cái Răng, TP. Cần Thơ",
        "latitude": 10.0039,
        "longitude": 105.7485,
        "location_type": "stop",
        "is_active": True
    },
    {
        "id": "ct_mekong_rest",
        "name": "Trạm dừng Mekong Rest Stop (Tiền Giang)",
        "area": "Tiền Giang",
        "address": "Km 1964 Quốc lộ 1A, Huyện Châu Thành, Tỉnh Tiền Giang",
        "latitude": 10.3725,
        "longitude": 106.2891,
        "location_type": "rest_stop",
        "is_active": True
    },
    {
        "id": "ct_cau_my_thuan",
        "name": "Trạm dừng Cầu Mỹ Thuận (Vĩnh Long)",
        "area": "Vĩnh Long",
        "address": "Đầu Cầu Mỹ Thuận, Quốc lộ 1A, Tỉnh Vĩnh Long",
        "latitude": 10.2764,
        "longitude": 105.9123,
        "location_type": "rest_stop",
        "is_active": True
    },

    # ------------------ KHU VỰC HÀ NỘI ------------------
    {
        "id": "hn_bx_nuoc_ngam",
        "name": "Bến xe Nước Ngầm",
        "area": "Hà Nội",
        "address": "Số 01 Ngọc Hồi, Phường Hoàng Liệt, Quận Hoàng Mai, Hà Nội",
        "latitude": 20.9632,
        "longitude": 105.8427,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "hn_bx_my_dinh",
        "name": "Bến xe Mỹ Đình",
        "area": "Hà Nội",
        "address": "Số 20 Phạm Hùng, Phường Mỹ Đình 2, Quận Nam Từ Liêm, Hà Nội",
        "latitude": 21.0285,
        "longitude": 105.7780,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "hn_bx_giap_bat",
        "name": "Bến xe Giáp Bát",
        "area": "Hà Nội",
        "address": "Km 6 Đường Giải Phóng, Phường Giáp Bát, Quận Hoàng Mai, Hà Nội",
        "latitude": 20.9806,
        "longitude": 105.8415,
        "location_type": "terminal",
        "is_active": True
    },

    # ------------------ KHU VỰC HẢI PHÒNG ------------------
    {
        "id": "hp_bx_cau_rao",
        "name": "Bến xe Cầu Rào",
        "area": "Hải Phòng",
        "address": "Số 1 Thiên Lôi, Phường Đằng Giang, Quận Ngô Quyền, TP. Hải Phòng",
        "latitude": 20.8354,
        "longitude": 106.6972,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "hp_bx_thuong_ly",
        "name": "Bến xe Thượng Lý",
        "area": "Hải Phòng",
        "address": "Số 52 Hà Nội, Phường Sở Dầu, Quận Hồng Bàng, TP. Hải Phòng",
        "latitude": 20.8722,
        "longitude": 106.6611,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "hp_bx_vinh_niem",
        "name": "Bến xe Vĩnh Niệm",
        "area": "Hải Phòng",
        "address": "Đường Bùi Viện, Phường Vĩnh Niệm, Quận Lê Chân, TP. Hải Phòng",
        "latitude": 20.8288,
        "longitude": 106.6789,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "hp_td_v52",
        "name": "Trạm dừng nghỉ V52 Hải Dương (Cao tốc QL5B)",
        "area": "Hải Dương",
        "address": "Km 52 Cao tốc Hà Nội - Hải Phòng, Huyện Gia Lộc, Tỉnh Hải Dương",
        "latitude": 20.8712,
        "longitude": 106.3125,
        "location_type": "rest_stop",
        "is_active": True
    },

    # ------------------ KHU VỰC NHA TRANG (KHÁNH HÒA) ------------------
    {
        "id": "nt_bx_phia_nam",
        "name": "Bến xe phía Nam Nha Trang",
        "area": "Nha Trang",
        "address": "Km 6 Đường 23/10, Xã Vĩnh Trung, TP. Nha Trang, Tỉnh Khánh Hòa",
        "latitude": 12.2471,
        "longitude": 109.1623,
        "location_type": "terminal",
        "is_active": True
    },
    {
        "id": "nt_vp_trung_tam",
        "name": "Văn phòng Nha Trang",
        "area": "Nha Trang",
        "address": "14 Hoàng Hoa Thám, Phường Vạn Thạnh, TP. Nha Trang, Tỉnh Khánh Hòa",
        "latitude": 12.2489,
        "longitude": 109.1965,
        "location_type": "agency",
        "is_active": True
    },
    {
        "id": "nt_td_phan_thiet",
        "name": "Trạm dừng chân Phan Thiết (Bình Thuận)",
        "area": "Bình Thuận",
        "address": "Km 1700 Quốc lộ 1A, Huyện Hàm Thuận Nam, Tỉnh Bình Thuận",
        "latitude": 10.9231,
        "longitude": 108.1023,
        "location_type": "rest_stop",
        "is_active": True
    },
    {
        "id": "nt_td_cam_ranh",
        "name": "Trạm dừng chân Cam Ranh (Khánh Hòa)",
        "area": "Khánh Hòa",
        "address": "Quốc lộ 1A, TP. Cam Ranh, Tỉnh Khánh Hòa",
        "latitude": 11.9213,
        "longitude": 109.1542,
        "location_type": "rest_stop",
        "is_active": True
    }
]

# Định nghĩa thứ tự trạm (RouteStop sequence) cho từng tuyến xe
ROUTE_STOPS_MAP = {
    # 1. Sài Gòn ↔ Cư Jút (sg_cj)
    "sg_cj": [
        {"stop_id": "sg_bxmd_cu", "sequence": 1, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_hang_xanh", "sequence": 2, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_nga_tu_binh_phuoc", "sequence": 3, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_an_suong", "sequence": 4, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "cj_gia_nghia", "sequence": 5, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "cj_dak_mil", "sequence": 6, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "cj_ben_xe", "sequence": 7, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "cj_nga_ba_nam_dong", "sequence": 8, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "cj_cho_trung_tam", "sequence": 9, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "cj_cong_chao", "sequence": 10, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "cj_cau_serepok", "sequence": 11, "stop_type": "dropoff", "direction": "forward"},
    ],
    # 2. TP. Hồ Chí Minh ↔ Đà Lạt (sg_dl)
    "sg_dl": [
        {"stop_id": "sg_bxmd_moi", "sequence": 1, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_bxmd_cu", "sequence": 2, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_hang_xanh", "sequence": 3, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_an_suong", "sequence": 4, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "dl_td_dau_giay", "sequence": 5, "stop_type": "both", "direction": "forward"},
        {"stop_id": "dl_td_madagui", "sequence": 6, "stop_type": "both", "direction": "forward"},
        {"stop_id": "dl_td_tam_chau", "sequence": 7, "stop_type": "both", "direction": "forward"},
        {"stop_id": "dl_nga_ba_phi_nom", "sequence": 8, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "dl_bx_lien_tinh", "sequence": 9, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "dl_vp_bui_thi_xuan", "sequence": 10, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "dl_nga_5_dai_hoc", "sequence": 11, "stop_type": "dropoff", "direction": "forward"},
    ],
    # 3. TP. Hồ Chí Minh ↔ Cần Thơ (sg_ct)
    "sg_ct": [
        {"stop_id": "sg_bx_mientay", "sequence": 1, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_an_suong", "sequence": 2, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "ct_mekong_rest", "sequence": 3, "stop_type": "both", "direction": "forward"},
        {"stop_id": "ct_cau_my_thuan", "sequence": 4, "stop_type": "both", "direction": "forward"},
        {"stop_id": "ct_bx_trung_tam", "sequence": 5, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "ct_bx_91b", "sequence": 6, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "ct_cho_noi", "sequence": 7, "stop_type": "dropoff", "direction": "forward"},
    ],
    # 4. Hà Nội ↔ Hải Phòng (hn_hp)
    "hn_hp": [
        {"stop_id": "hn_bx_nuoc_ngam", "sequence": 1, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "hn_bx_my_dinh", "sequence": 2, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "hn_bx_giap_bat", "sequence": 3, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "hp_td_v52", "sequence": 4, "stop_type": "both", "direction": "forward"},
        {"stop_id": "hp_bx_cau_rao", "sequence": 5, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "hp_bx_thuong_ly", "sequence": 6, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "hp_bx_vinh_niem", "sequence": 7, "stop_type": "dropoff", "direction": "forward"},
    ],
    # 5. TP. Hồ Chí Minh ↔ Nha Trang (sg_nt)
    "sg_nt": [
        {"stop_id": "sg_bxmd_moi", "sequence": 1, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "sg_suoi_tien", "sequence": 2, "stop_type": "pickup", "direction": "forward"},
        {"stop_id": "nt_td_phan_thiet", "sequence": 3, "stop_type": "both", "direction": "forward"},
        {"stop_id": "nt_td_cam_ranh", "sequence": 4, "stop_type": "both", "direction": "forward"},
        {"stop_id": "nt_bx_phia_nam", "sequence": 5, "stop_type": "dropoff", "direction": "forward"},
        {"stop_id": "nt_vp_trung_tam", "sequence": 6, "stop_type": "dropoff", "direction": "forward"},
    ]
}

with app.app_context():
    # Đảm bảo tất cả bảng và cột mới tồn tại
    db.create_all()
    try:
        from sqlalchemy import text
        with db.engine.begin() as conn:
            conn.execute(text("ALTER TABLE route ADD COLUMN routing_mode TEXT DEFAULT 'standard'"))
    except Exception:
        pass

    # 1. Thêm hoặc cập nhật LocationStop
    added_stops = 0
    for s_data in ALL_STATIONS:
        st = LocationStop.query.get(s_data['id'])
        if not st:
            st = LocationStop(
                id=s_data['id'],
                name=s_data['name'],
                area=s_data['area'],
                address=s_data['address'],
                latitude=s_data['latitude'],
                longitude=s_data['longitude'],
                location_type=s_data['location_type'],
                is_active=s_data['is_active']
            )
            db.session.add(st)
            added_stops += 1
        else:
            st.name = s_data['name']
            st.area = s_data['area']
            st.address = s_data['address']
            st.latitude = s_data['latitude']
            st.longitude = s_data['longitude']
            st.location_type = s_data['location_type']
            st.is_active = s_data['is_active']

    db.session.commit()
    print(f"Cap nhat {len(ALL_STATIONS)} tram dung (Them moi: {added_stops})")

    # 2. Xóa và tái tạo RouteStop
    RouteStop.query.delete()
    total_rs = 0
    for r_code, stops in ROUTE_STOPS_MAP.items():
        for item in stops:
            rs = RouteStop(
                route_code=r_code,
                stop_id=item['stop_id'],
                sequence=item['sequence'],
                stop_type=item['stop_type'],
                direction=item.get('direction', 'forward'),
                pickup_allowed=item['stop_type'] in ['pickup', 'both'],
                dropoff_allowed=item['stop_type'] in ['dropoff', 'both']
            )
            db.session.add(rs)
            total_rs += 1
    db.session.commit()
    print(f"Tao thanh cong {total_rs} RouteStop mappings")

    # 3. Cập nhật routing_mode cho các Route trong database
    routes = Route.query.all()
    updated_routes = 0
    for r in routes:
        start_lower = r.start_point.lower()
        end_lower = r.end_point.lower()

        # Tuyến TP.HCM ↔ Cư Jút
        if ("hồ chí minh" in start_lower or "sài gòn" in start_lower) and "cư jut" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1
        elif "cư jut" in start_lower and ("hồ chí minh" in end_lower or "sài gòn" in end_lower):
            r.routing_mode = 'map_stops'
            updated_routes += 1

        # Tuyến TP.HCM ↔ Đà Lạt
        elif ("hồ chí minh" in start_lower or "sài gòn" in start_lower) and "đà lạt" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1
        elif "đà lạt" in start_lower and ("hồ chí minh" in end_lower or "sài gòn" in end_lower):
            r.routing_mode = 'map_stops'
            updated_routes += 1

        # Tuyến TP.HCM ↔ Cần Thơ
        elif ("hồ chí minh" in start_lower or "sài gòn" in start_lower) and "cần thơ" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1
        elif "cần thơ" in start_lower and ("hồ chí minh" in end_lower or "sài gòn" in end_lower):
            r.routing_mode = 'map_stops'
            updated_routes += 1

        # Tuyến TP.HCM ↔ Nha Trang
        elif ("hồ chí minh" in start_lower or "sài gòn" in start_lower) and "nha trang" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1
        elif "nha trang" in start_lower and ("hồ chí minh" in end_lower or "sài gòn" in end_lower):
            r.routing_mode = 'map_stops'
            updated_routes += 1

        # Tuyến Hà Nội ↔ Hải Phòng
        elif "hà nội" in start_lower and "hải phòng" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1
        elif "hải phòng" in start_lower and "hà nội" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1

        # Tuyến Hà Nội ↔ Đà Nẵng: route_map
        elif "hà nội" in start_lower and "đà nẵng" in end_lower:
            r.routing_mode = 'route_map'
            updated_routes += 1
        elif "đà nẵng" in start_lower and "hà nội" in end_lower:
            r.routing_mode = 'route_map'
            updated_routes += 1

        # Tuyến TP.HCM ↔ Hà Nội: map_stops
        elif ("hồ chí minh" in start_lower or "sài gòn" in start_lower) and "hà nội" in end_lower:
            r.routing_mode = 'map_stops'
            updated_routes += 1
        elif "hà nội" in start_lower and ("hồ chí minh" in end_lower or "sài gòn" in end_lower):
            r.routing_mode = 'map_stops'
            updated_routes += 1

        else:
            r.routing_mode = 'standard'

    db.session.commit()
    print(f"Cap nhat routing_mode cho {updated_routes}/{len(routes)} tuyen xe trong SQLite.")
