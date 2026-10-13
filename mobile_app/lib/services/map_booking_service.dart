import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config/api_config.dart';
import '../models/map_station.dart';
import '../models/booking_strategy.dart';

class MapBookingService {
  final http.Client _client;

  MapBookingService({http.Client? client}) : _client = client ?? http.Client();

  // Dữ liệu dự phòng chuẩn xác (Verified Fallback Dataset)
  // Đảm bảo ứng dụng luôn hiển thị được trạm dừng thực tế ngay cả khi mất mạng
  static final List<MapStation> fallbackStations = [
    // ------------------ KHU VỰC SÀI GÒN & DỌC TRỤC QL13 - QL14 ------------------
    MapStation(
      id: 'sg_bxmd_cu',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Bến xe Miền Đông (Cũ)',
      address: '292 Đinh Bộ Lĩnh, Phường 26, Quận Bình Thạnh, TP. Hồ Chí Minh',
      latitude: 10.8142,
      longitude: 106.7118,
      stopType: 'both',
      sequence: 1,
      isActive: true,
      description: 'Cổng số 1, sảnh chính đón khách đi các tỉnh Tây Nguyên và Miền Trung.',
    ),
    MapStation(
      id: 'sg_hang_xanh',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Ngã tư Hàng Xanh',
      address: 'Cây xăng Comeco, 178 Điện Biên Phủ, Phường 21, Quận Bình Thạnh, TP. Hồ Chí Minh',
      latitude: 10.8016,
      longitude: 106.7113,
      stopType: 'both',
      sequence: 2,
      isActive: true,
      description: 'Dưới chân cầu vượt Hàng Xanh, đón khách hướng trung tâm TP.HCM ra QL13.',
    ),
    MapStation(
      id: 'sg_binh_trieu',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Cầu Bình Triệu (QL13)',
      address: 'Đường Quốc lộ 13, Phường Hiệp Bình Chánh, TP. Thủ Đức, TP. Hồ Chí Minh',
      latitude: 10.8246,
      longitude: 106.7140,
      stopType: 'both',
      sequence: 3,
      isActive: true,
      description: 'Dọc Quốc lộ 13 đoạn chân cầu Bình Triệu, thuận tiện cho khách khu vực Thủ Đức.',
    ),
    MapStation(
      id: 'sg_can_nhon_hoa',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Trạm Cân Nhơn Hòa (QL13)',
      address: '520 Quốc lộ 13, Phường Hiệp Bình Phước, TP. Thủ Đức, TP. Hồ Chí Minh',
      latitude: 10.8401,
      longitude: 106.7163,
      stopType: 'both',
      sequence: 4,
      isActive: true,
      description: 'Điểm đón dọc Quốc lộ 13 gần Cân Nhơn Hòa và Khu dân cư Vạn Phúc City.',
    ),
    MapStation(
      id: 'sg_binh_phuoc',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Ngã tư Bình Phước (QL13)',
      address: 'Chân cầu vượt Bình Phước, QL13 giao QL1A, P. Hiệp Bình Phước, TP. Thủ Đức',
      latitude: 10.8653,
      longitude: 106.7188,
      stopType: 'both',
      sequence: 5,
      isActive: true,
      description: 'Cửa ngõ ra Quốc lộ 13 đi Bình Dương - Chơn Thành - Đắk Nông.',
    ),
    MapStation(
      id: 'sg_cong_chao_bd',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Cổng chào Bình Dương (QL13)',
      address: 'Chân cầu Vĩnh Bình, Đại lộ Bình Dương (QL13), TP. Thuận An, Bình Dương',
      latitude: 10.8802,
      longitude: 106.6989,
      stopType: 'both',
      sequence: 6,
      isActive: true,
      description: 'Ranh giới TP.HCM và Bình Dương, vỉa hè rộng xe khách dễ tấp đón khách.',
    ),
    MapStation(
      id: 'sg_cau_ong_bo',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Ngã tư Cầu Ông Bố (QL13)',
      address: 'Đại lộ Bình Dương (QL13), Phường Lái Thiêu, TP. Thuận An, Bình Dương',
      latitude: 10.9021,
      longitude: 106.7122,
      stopType: 'both',
      sequence: 7,
      isActive: true,
      description: 'Ngã tư sầm uất trung tâm Lái Thiêu, điểm đón quen thuộc đi Tây Nguyên.',
    ),
    MapStation(
      id: 'sg_aeon_canary',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'AEON Mall Canary (QL13)',
      address: 'Số 01 Đại lộ Bình Dương (QL13), P. Thuận Giao, TP. Thuận An, Bình Dương',
      latitude: 10.9388,
      longitude: 106.7029,
      stopType: 'both',
      sequence: 8,
      isActive: true,
      description: 'Khu vực cổng trung tâm thương mại AEON Mall Canary Bình Dương dọc trục QL13.',
    ),
    MapStation(
      id: 'sg_thu_dau_mot',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Trạm TP. Thủ Dầu Một (QL13)',
      address: 'Đại lộ Bình Dương (QL13), Phường Hiệp Thành, TP. Thủ Dầu Một, Bình Dương',
      latitude: 10.9807,
      longitude: 106.6527,
      stopType: 'both',
      sequence: 9,
      isActive: true,
      description: 'Trục đường chính Quốc lộ 13 qua trung tâm Thành phố Thủ Dầu Một.',
    ),
    MapStation(
      id: 'sg_ben_cat',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Trạm dừng Bến Cát (QL13)',
      address: 'Quốc lộ 13, Phường Mỹ Phước, Thị xã Bến Cát, Tỉnh Bình Dương',
      latitude: 11.1609,
      longitude: 106.5942,
      stopType: 'both',
      sequence: 10,
      isActive: true,
      description: 'Khu vực cổng KCN Mỹ Phước 1, 2, 3 dọc Quốc lộ 13.',
    ),
    MapStation(
      id: 'sg_bau_bang',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Ngã ba Bàu Bàng (QL13)',
      address: 'Quốc lộ 13, Thị trấn Lai Uyên, Huyện Bàu Bàng, Tỉnh Bình Dương',
      latitude: 11.2750,
      longitude: 106.6050,
      stopType: 'both',
      sequence: 11,
      isActive: true,
      description: 'Điểm tập kết hành khách khu đô thị & KCN Bàu Bàng dọc trục QL13.',
    ),
    MapStation(
      id: 'sg_chon_thanh',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Ngã 4 Chơn Thành (Giao QL13 & QL14)',
      address: 'Ngã tư Chơn Thành, Quốc lộ 13 giao Quốc lộ 14, TX. Chơn Thành, Bình Phước',
      latitude: 11.4543,
      longitude: 106.6867,
      stopType: 'both',
      sequence: 12,
      isActive: true,
      description: 'Giao lộ chiến lược nơi tuyến rẽ từ Quốc lộ 13 sang Quốc lộ 14 đi Đắk Nông.',
    ),
    MapStation(
      id: 'sg_dong_xoai',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Bến xe TP. Đồng Xoài (QL14)',
      address: 'Đường Phú Riềng Đỏ (Quốc lộ 14), TP. Đồng Xoài, Tỉnh Bình Phước',
      latitude: 11.5333,
      longitude: 106.8810,
      stopType: 'both',
      sequence: 13,
      isActive: true,
      description: 'Bến xe trung tâm Đồng Xoài trên Quốc lộ 14, dừng nghỉ và đón trả khách.',
    ),
    MapStation(
      id: 'sg_bu_dang',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Trạm dừng Bù Đăng (QL14)',
      address: 'Quốc lộ 14, Thị trấn Đức Phong, Huyện Bù Đăng, Tỉnh Bình Phước',
      latitude: 11.7674,
      longitude: 107.2387,
      stopType: 'both',
      sequence: 14,
      isActive: true,
      description: 'Trạm dừng chân quen thuộc khu vực Bù Đăng trước khi vượt đèo vào Đắk Nông.',
    ),
    MapStation(
      id: 'sg_an_suong',
      routeId: 'sg_cj',
      area: 'Sài Gòn',
      name: 'Bến xe An Sương',
      address: 'Quốc lộ 22, Xã Bà Điểm, Huyện Hóc Môn, TP. Hồ Chí Minh',
      latitude: 10.8447,
      longitude: 106.6186,
      stopType: 'both',
      sequence: 15,
      isActive: true,
      description: 'Sảnh chờ bến xe An Sương, xe trung chuyển đưa đón ra ngã tư Bình Phước - QL13.',
    ),

    // ------------------ KHU VỰC CƯ JÚT & DỌC TRỤC QL14 (TỈNH ĐẮK NÔNG) ------------------
    MapStation(
      id: 'cj_dak_ru',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Cổng chào Tỉnh Đắk Nông (QL14)',
      address: 'Km 904 Quốc lộ 14, Xã Đắk Ru, Huyện Đắk R\'lấp, Tỉnh Đắk Nông',
      latitude: 11.9150,
      longitude: 107.4100,
      stopType: 'both',
      sequence: 1,
      isActive: true,
      description: 'Cửa ngõ phía Nam chào đón vào địa phận tỉnh Đắk Nông trên Quốc lộ 14.',
    ),
    MapStation(
      id: 'cj_kien_duc',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Trạm dừng Kiến Đức (QL14)',
      address: 'Quốc lộ 14, Thị trấn Kiến Đức, Huyện Đắk R\'lấp, Tỉnh Đắk Nông',
      latitude: 11.9799,
      longitude: 107.5013,
      stopType: 'both',
      sequence: 2,
      isActive: true,
      description: 'Trung tâm thị trấn Kiến Đức trên trục đường Hồ Chí Minh (QL14).',
    ),
    MapStation(
      id: 'cj_gia_nghia',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Bến xe TP. Gia Nghĩa (QL14)',
      address: 'Đường 23/3 (Quốc lộ 14), Phường Nghĩa Thành, TP. Gia Nghĩa, Tỉnh Đắk Nông',
      latitude: 12.0038,
      longitude: 107.6902,
      stopType: 'both',
      sequence: 3,
      isActive: true,
      description: 'Bến xe liên tỉnh trung tâm Thành phố Gia Nghĩa, tỉnh lỵ tỉnh Đắk Nông.',
    ),
    MapStation(
      id: 'cj_dak_song',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Ngã ba Đắk Song (QL14)',
      address: 'Quốc lộ 14, Thị trấn Đức An, Huyện Đắk Song, Tỉnh Đắk Nông',
      latitude: 12.2709,
      longitude: 107.6169,
      stopType: 'both',
      sequence: 4,
      isActive: true,
      description: 'Điểm giao thương sầm uất trung tâm huyện Đắk Song trên Quốc lộ 14.',
    ),
    MapStation(
      id: 'cj_dak_mil',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Trạm dừng Đắk Mil (QL14)',
      address: 'Đường Nguyễn Tất Thành (Quốc lộ 14), Thị trấn Đắk Mil, Huyện Đắk Mil, Tỉnh Đắk Nông',
      latitude: 12.4330,
      longitude: 107.6831,
      stopType: 'both',
      sequence: 5,
      isActive: true,
      description: 'Trạm dừng chân trung tâm huyện Đắk Mil, ven hồ Tây Đắk Mil thơ mộng.',
    ),
    MapStation(
      id: 'cj_dak_sak',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Ngã ba Đắk Sắk (QL14)',
      address: 'Quốc lộ 14, Xã Đắk Sắk, Huyện Đắk Mil, Tỉnh Đắk Nông',
      latitude: 12.4700,
      longitude: 107.7200,
      stopType: 'both',
      sequence: 6,
      isActive: true,
      description: 'Khu vực chợ và ngã ba Đắk Sắk, thuận tiện đón trả bà con vùng lân cận.',
    ),
    MapStation(
      id: 'cj_ben_xe',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Bến xe Huyện Cư Jút (QL14)',
      address: 'Đường Nguyễn Tất Thành (Quốc lộ 14), Thị trấn Ea T\'ling, Huyện Cư Jút, Tỉnh Đắk Nông',
      latitude: 12.5932,
      longitude: 107.8924,
      stopType: 'both',
      sequence: 7,
      isActive: true,
      description: 'Bến xe trung tâm huyện Cư Jút, bến đỗ an toàn, có sảnh đợi xe rộng rãi.',
    ),
    MapStation(
      id: 'cj_nga_ba_nam_dong',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Ngã ba Cư Jút (Rẽ Nam Dong)',
      address: 'Giao lộ Quốc lộ 14 & Tỉnh lộ 682, Thị trấn Ea T\'ling, Huyện Cư Jút, Tỉnh Đắk Nông',
      latitude: 12.5975,
      longitude: 107.8906,
      stopType: 'both',
      sequence: 8,
      isActive: true,
      description: 'Vị trí giao thương sầm uất trung tâm thị trấn, ngã rẽ vào các xã Nam Dong, Đắk D\'rông.',
    ),
    MapStation(
      id: 'cj_cho_trung_tam',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Chợ Trung Tâm Cư Jút',
      address: 'Đường Hùng Vương, Thị trấn Ea T\'ling, Huyện Cư Jút, Tỉnh Đắk Nông',
      latitude: 12.5951,
      longitude: 107.8942,
      stopType: 'both',
      sequence: 9,
      isActive: true,
      description: 'Cửa chính chợ trung tâm huyện, điểm tập kết quen thuộc để đón xe và gửi hàng hóa.',
    ),
    MapStation(
      id: 'cj_cong_chao',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Cổng chào Huyện Cư Jút (QL14)',
      address: 'Km 728 Quốc lộ 14, Xã Tâm Thắng, Huyện Cư Jút, Tỉnh Đắk Nông',
      latitude: 12.6105,
      longitude: 107.9150,
      stopType: 'both',
      sequence: 10,
      isActive: true,
      description: 'Cổng chào lớn biểu tượng huyện Cư Jút trên Quốc lộ 14, không gian thoáng đãng.',
    ),
    MapStation(
      id: 'cj_xa_nam_dong',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Trạm dừng Xã Nam Dong',
      address: 'Trung tâm Xã Nam Dong (Tỉnh lộ 682), Huyện Cư Jút, Tỉnh Đắk Nông',
      latitude: 12.5518,
      longitude: 107.8421,
      stopType: 'both',
      sequence: 11,
      isActive: true,
      description: 'Điểm đón trả khách cho người dân khu vực nông trường cà phê và trung tâm xã Nam Dong.',
    ),
    MapStation(
      id: 'cj_cau_serepok',
      routeId: 'sg_cj',
      area: 'Cư Jút',
      name: 'Cầu Sêrêpôk - Cầu 14 (QL14)',
      address: 'Đầu cầu Sêrêpôk, Quốc lộ 14, Xã Tâm Thắng, Huyện Cư Jút, Tỉnh Đắk Nông',
      latitude: 12.6322,
      longitude: 107.9287,
      stopType: 'both',
      sequence: 12,
      isActive: true,
      description: 'Ranh giới địa lý tự nhiên nối tỉnh Đắk Nông và Đắk Lắk trên Quốc lộ 14.',
    ),
  ];

  static final List<LatLng> fallbackPolyline = [
    const LatLng(10.81456, 106.71228),
    const LatLng(10.81733, 106.71317),
    const LatLng(10.82463, 106.71405),
    const LatLng(10.82567, 106.71447),
    const LatLng(10.82754, 106.71437),
    const LatLng(10.83192, 106.71413),
    const LatLng(10.83554, 106.71395),
    const LatLng(10.83824, 106.71469),
    const LatLng(10.84013, 106.7163),
    const LatLng(10.84241, 106.71804),
    const LatLng(10.845, 106.71824),
    const LatLng(10.84823, 106.71836),
    const LatLng(10.85066, 106.71955),
    const LatLng(10.85617, 106.72257),
    const LatLng(10.8621, 106.72486),
    const LatLng(10.86464, 106.72428),
    const LatLng(10.86556, 106.724),
    const LatLng(10.86523, 106.72331),
    const LatLng(10.86573, 106.71963),
    const LatLng(10.86486, 106.71796),
    const LatLng(10.86484, 106.71799),
    const LatLng(10.86647, 106.719),
    const LatLng(10.86774, 106.72148),
    const LatLng(10.86595, 106.72342),
    const LatLng(10.86537, 106.72354),
    const LatLng(10.86492, 106.724),
    const LatLng(10.86558, 106.72397),
    const LatLng(10.86671, 106.72309),
    const LatLng(10.86796, 106.72094),
    const LatLng(10.86813, 106.71682),
    const LatLng(10.86986, 106.71265),
    const LatLng(10.87053, 106.70833),
    const LatLng(10.87135, 106.70477),
    const LatLng(10.87361, 106.70252),
    const LatLng(10.87666, 106.70025),
    const LatLng(10.8802, 106.69892),
    const LatLng(10.88285, 106.69826),
    const LatLng(10.88565, 106.69934),
    const LatLng(10.88673, 106.69974),
    const LatLng(10.88874, 106.70136),
    const LatLng(10.89222, 106.70466),
    const LatLng(10.89657, 106.7083),
    const LatLng(10.90207, 106.71218),
    const LatLng(10.91216, 106.71316),
    const LatLng(10.92244, 106.7134),
    const LatLng(10.92812, 106.71189),
    const LatLng(10.9342, 106.71044),
    const LatLng(10.93633, 106.70985),
    const LatLng(10.94238, 106.70851),
    const LatLng(10.95397, 106.70345),
    const LatLng(10.95717, 106.70023),
    const LatLng(10.96022, 106.69653),
    const LatLng(10.96376, 106.68904),
    const LatLng(10.96809, 106.68009),
    const LatLng(10.97196, 106.67289),
    const LatLng(10.9734, 106.67088),
    const LatLng(10.97909, 106.66807),
    const LatLng(10.98323, 106.66647),
    const LatLng(10.98379, 106.66447),
    const LatLng(10.98305, 106.66196),
    const LatLng(10.9823, 106.65823),
    const LatLng(10.98157, 106.65666),
    const LatLng(10.98105, 106.65363),
    const LatLng(10.98073, 106.65268),
    const LatLng(10.98075, 106.65358),
    const LatLng(10.98103, 106.65385),
    const LatLng(10.98333, 106.65272),
    const LatLng(10.98486, 106.65258),
    const LatLng(10.98671, 106.65261),
    const LatLng(10.98818, 106.65202),
    const LatLng(10.99017, 106.65108),
    const LatLng(10.99156, 106.65108),
    const LatLng(10.99306, 106.65046),
    const LatLng(10.99575, 106.65016),
    const LatLng(10.99711, 106.64911),
    const LatLng(11.00017, 106.64693),
    const LatLng(11.00546, 106.64565),
    const LatLng(11.00828, 106.64556),
    const LatLng(11.01182, 106.64701),
    const LatLng(11.01481, 106.64766),
    const LatLng(11.02161, 106.64897),
    const LatLng(11.02411, 106.64931),
    const LatLng(11.02581, 106.64811),
    const LatLng(11.0275, 106.64526),
    const LatLng(11.03036, 106.64287),
    const LatLng(11.03422, 106.64012),
    const LatLng(11.03872, 106.63773),
    const LatLng(11.04336, 106.63508),
    const LatLng(11.05012, 106.63142),
    const LatLng(11.05481, 106.62945),
    const LatLng(11.05854, 106.6286),
    const LatLng(11.06376, 106.62865),
    const LatLng(11.06904, 106.62778),
    const LatLng(11.07261, 106.62746),
    const LatLng(11.07441, 106.62769),
    const LatLng(11.07833, 106.62718),
    const LatLng(11.08419, 106.62652),
    const LatLng(11.09541, 106.62599),
    const LatLng(11.10028, 106.62519),
    const LatLng(11.10623, 106.6218),
    const LatLng(11.11171, 106.6182),
    const LatLng(11.11968, 106.61538),
    const LatLng(11.12743, 106.6129),
    const LatLng(11.132, 106.60737),
    const LatLng(11.13477, 106.6044),
    const LatLng(11.13841, 106.60397),
    const LatLng(11.14418, 106.60139),
    const LatLng(11.14926, 106.59753),
    const LatLng(11.15161, 106.59937),
    const LatLng(11.15279, 106.60185),
    const LatLng(11.15485, 106.60807),
    const LatLng(11.15684, 106.61013),
    const LatLng(11.15637, 106.60979),
    const LatLng(11.15464, 106.60744),
    const LatLng(11.15246, 106.60079),
    const LatLng(11.15216, 106.5985),
    const LatLng(11.15404, 106.59552),
    const LatLng(11.15566, 106.59262),
    const LatLng(11.15796, 106.59369),
    const LatLng(11.16089, 106.59419),
    const LatLng(11.16423, 106.59246),
    const LatLng(11.1665, 106.59366),
    const LatLng(11.16928, 106.596),
    const LatLng(11.1723, 106.59838),
    const LatLng(11.17701, 106.60067),
    const LatLng(11.18023, 106.60258),
    const LatLng(11.18396, 106.60504),
    const LatLng(11.18814, 106.60811),
    const LatLng(11.19112, 106.61035),
    const LatLng(11.19531, 106.61375),
    const LatLng(11.19801, 106.61645),
    const LatLng(11.20189, 106.62133),
    const LatLng(11.20495, 106.62586),
    const LatLng(11.20721, 106.62855),
    const LatLng(11.20953, 106.62961),
    const LatLng(11.21243, 106.63052),
    const LatLng(11.21723, 106.63212),
    const LatLng(11.22132, 106.63347),
    const LatLng(11.22459, 106.63433),
    const LatLng(11.22833, 106.635),
    const LatLng(11.23308, 106.63586),
    const LatLng(11.23626, 106.63646),
    const LatLng(11.23991, 106.6371),
    const LatLng(11.24366, 106.6378),
    const LatLng(11.24896, 106.63873),
    const LatLng(11.25183, 106.63849),
    const LatLng(11.25649, 106.63764),
    const LatLng(11.26235, 106.63657),
    const LatLng(11.26644, 106.63582),
    const LatLng(11.2713, 106.63492),
    const LatLng(11.27436, 106.63439),
    const LatLng(11.27879, 106.63359),
    const LatLng(11.28237, 106.633),
    const LatLng(11.28737, 106.63227),
    const LatLng(11.29013, 106.63189),
    const LatLng(11.29751, 106.63101),
    const LatLng(11.30244, 106.6306),
    const LatLng(11.30712, 106.63072),
    const LatLng(11.31128, 106.63106),
    const LatLng(11.31541, 106.63173),
    const LatLng(11.31878, 106.6327),
    const LatLng(11.32305, 106.63358),
    const LatLng(11.32822, 106.63491),
    const LatLng(11.33347, 106.6364),
    const LatLng(11.33853, 106.63793),
    const LatLng(11.34405, 106.63966),
    const LatLng(11.34629, 106.63947),
    const LatLng(11.34973, 106.63712),
    const LatLng(11.35606, 106.63282),
    const LatLng(11.35869, 106.63116),
    const LatLng(11.36318, 106.62823),
    const LatLng(11.36699, 106.62593),
    const LatLng(11.37304, 106.62247),
    const LatLng(11.37858, 106.61972),
    const LatLng(11.38145, 106.62036),
    const LatLng(11.38628, 106.62621),
    const LatLng(11.39639, 106.63617),
    const LatLng(11.42377, 106.65811),
    const LatLng(11.43439, 106.66374),
    const LatLng(11.43883, 106.66457),
    const LatLng(11.44017, 106.6647),
    const LatLng(11.45075, 106.66657),
    const LatLng(11.46056, 106.67154),
    const LatLng(11.45833, 106.67574),
    const LatLng(11.4543, 106.68668),
    const LatLng(11.45432, 106.68771),
    const LatLng(11.45654, 106.68062),
    const LatLng(11.45964, 106.67327),
    const LatLng(11.46808, 106.67375),
    const LatLng(11.47078, 106.67537),
    const LatLng(11.47473, 106.67601),
    const LatLng(11.4766, 106.67906),
    const LatLng(11.47897, 106.68188),
    const LatLng(11.48246, 106.68507),
    const LatLng(11.48633, 106.68693),
    const LatLng(11.49785, 106.69588),
    const LatLng(11.50128, 106.69892),
    const LatLng(11.50591, 106.70443),
    const LatLng(11.50767, 106.70687),
    const LatLng(11.50834, 106.70947),
    const LatLng(11.50893, 106.71145),
    const LatLng(11.50977, 106.71225),
    const LatLng(11.51189, 106.71371),
    const LatLng(11.51307, 106.71707),
    const LatLng(11.51518, 106.72369),
    const LatLng(11.51803, 106.73297),
    const LatLng(11.51833, 106.73606),
    const LatLng(11.51786, 106.74056),
    const LatLng(11.51688, 106.74882),
    const LatLng(11.51658, 106.75134),
    const LatLng(11.51617, 106.75515),
    const LatLng(11.51449, 106.75791),
    const LatLng(11.51135, 106.76131),
    const LatLng(11.50993, 106.76525),
    const LatLng(11.50689, 106.76782),
    const LatLng(11.50775, 106.77155),
    const LatLng(11.50803, 106.77326),
    const LatLng(11.50848, 106.77625),
    const LatLng(11.5091, 106.78011),
    const LatLng(11.50908, 106.78494),
    const LatLng(11.50938, 106.78908),
    const LatLng(11.50999, 106.79334),
    const LatLng(11.51054, 106.79506),
    const LatLng(11.51163, 106.79757),
    const LatLng(11.51438, 106.80405),
    const LatLng(11.51552, 106.80752),
    const LatLng(11.51656, 106.81238),
    const LatLng(11.51719, 106.81575),
    const LatLng(11.51783, 106.81889),
    const LatLng(11.51871, 106.823),
    const LatLng(11.52019, 106.82991),
    const LatLng(11.52111, 106.83424),
    const LatLng(11.52162, 106.83653),
    const LatLng(11.52262, 106.84109),
    const LatLng(11.52861, 106.87039),
    const LatLng(11.53333, 106.88099),
    const LatLng(11.53435, 106.89054),
    const LatLng(11.53726, 106.90012),
    const LatLng(11.53733, 106.90256),
    const LatLng(11.53832, 106.91442),
    const LatLng(11.54294, 106.92071),
    const LatLng(11.54539, 106.92407),
    const LatLng(11.54757, 106.92759),
    const LatLng(11.55283, 106.93675),
    const LatLng(11.55869, 106.948),
    const LatLng(11.56403, 106.95401),
    const LatLng(11.56994, 106.96055),
    const LatLng(11.57273, 106.96369),
    const LatLng(11.57772, 106.96936),
    const LatLng(11.58364, 106.97597),
    const LatLng(11.58822, 106.97782),
    const LatLng(11.58981, 106.97878),
    const LatLng(11.59275, 106.98145),
    const LatLng(11.59525, 106.98354),
    const LatLng(11.59685, 106.98598),
    const LatLng(11.59932, 106.98735),
    const LatLng(11.60128, 106.98859),
    const LatLng(11.60301, 106.99172),
    const LatLng(11.60362, 106.99534),
    const LatLng(11.60488, 106.99794),
    const LatLng(11.60526, 106.9995),
    const LatLng(11.60416, 107.00398),
    const LatLng(11.60526, 107.00702),
    const LatLng(11.60805, 107.01016),
    const LatLng(11.6094, 107.01215),
    const LatLng(11.61255, 107.01744),
    const LatLng(11.61386, 107.01969),
    const LatLng(11.61665, 107.02437),
    const LatLng(11.61906, 107.02844),
    const LatLng(11.62203, 107.03093),
    const LatLng(11.62648, 107.03192),
    const LatLng(11.62712, 107.03392),
    const LatLng(11.62753, 107.03523),
    const LatLng(11.62822, 107.0362),
    const LatLng(11.62953, 107.03703),
    const LatLng(11.63306, 107.03896),
    const LatLng(11.63552, 107.04027),
    const LatLng(11.63623, 107.04048),
    const LatLng(11.63782, 107.04068),
    const LatLng(11.63977, 107.0409),
    const LatLng(11.64111, 107.0414),
    const LatLng(11.6419, 107.04195),
    const LatLng(11.64427, 107.04388),
    const LatLng(11.64546, 107.04582),
    const LatLng(11.64795, 107.0502),
    const LatLng(11.64805, 107.05287),
    const LatLng(11.64982, 107.05422),
    const LatLng(11.65321, 107.0556),
    const LatLng(11.65817, 107.05762),
    const LatLng(11.66076, 107.05917),
    const LatLng(11.66429, 107.06108),
    const LatLng(11.66576, 107.06169),
    const LatLng(11.66741, 107.0633),
    const LatLng(11.66886, 107.06534),
    const LatLng(11.67099, 107.06517),
    const LatLng(11.67494, 107.06567),
    const LatLng(11.67932, 107.06623),
    const LatLng(11.68211, 107.0667),
    const LatLng(11.68392, 107.06883),
    const LatLng(11.68615, 107.07118),
    const LatLng(11.68777, 107.07457),
    const LatLng(11.68735, 107.07884),
    const LatLng(11.68909, 107.08084),
    const LatLng(11.69241, 107.08122),
    const LatLng(11.6941, 107.08376),
    const LatLng(11.69497, 107.08671),
    const LatLng(11.6976, 107.08914),
    const LatLng(11.69994, 107.09126),
    const LatLng(11.70824, 107.09882),
    const LatLng(11.70905, 107.10143),
    const LatLng(11.70905, 107.10888),
    const LatLng(11.70908, 107.11294),
    const LatLng(11.70938, 107.11692),
    const LatLng(11.70868, 107.11955),
    const LatLng(11.70744, 107.12258),
    const LatLng(11.70881, 107.12926),
    const LatLng(11.70953, 107.13571),
    const LatLng(11.71003, 107.13783),
    const LatLng(11.71116, 107.13922),
    const LatLng(11.71227, 107.13997),
    const LatLng(11.7146, 107.14062),
    const LatLng(11.71617, 107.14061),
    const LatLng(11.71765, 107.13992),
    const LatLng(11.71969, 107.13898),
    const LatLng(11.72322, 107.13847),
    const LatLng(11.72479, 107.13867),
    const LatLng(11.7264, 107.1397),
    const LatLng(11.72804, 107.14077),
    const LatLng(11.72911, 107.1412),
    const LatLng(11.73015, 107.14138),
    const LatLng(11.73115, 107.14208),
    const LatLng(11.73225, 107.14337),
    const LatLng(11.73354, 107.1439),
    const LatLng(11.73694, 107.14573),
    const LatLng(11.73915, 107.14811),
    const LatLng(11.74079, 107.14936),
    const LatLng(11.74177, 107.15244),
    const LatLng(11.744, 107.15373),
    const LatLng(11.74618, 107.15693),
    const LatLng(11.74777, 107.15854),
    const LatLng(11.75064, 107.15813),
    const LatLng(11.75181, 107.15885),
    const LatLng(11.75267, 107.15944),
    const LatLng(11.75466, 107.15971),
    const LatLng(11.75602, 107.16005),
    const LatLng(11.75711, 107.16044),
    const LatLng(11.75836, 107.15995),
    const LatLng(11.76179, 107.15937),
    const LatLng(11.76642, 107.16317),
    const LatLng(11.77044, 107.16569),
    const LatLng(11.77334, 107.16767),
    const LatLng(11.77995, 107.17131),
    const LatLng(11.78203, 107.17374),
    const LatLng(11.78328, 107.17518),
    const LatLng(11.78479, 107.17699),
    const LatLng(11.78928, 107.18124),
    const LatLng(11.79198, 107.18374),
    const LatLng(11.79603, 107.18757),
    const LatLng(11.79781, 107.19028),
    const LatLng(11.79824, 107.19387),
    const LatLng(11.7985, 107.19634),
    const LatLng(11.79895, 107.20057),
    const LatLng(11.79907, 107.20399),
    const LatLng(11.79902, 107.20661),
    const LatLng(11.79809, 107.20972),
    const LatLng(11.79782, 107.21133),
    const LatLng(11.79834, 107.21286),
    const LatLng(11.80039, 107.21466),
    const LatLng(11.80383, 107.21954),
    const LatLng(11.80616, 107.22475),
    const LatLng(11.80879, 107.22853),
    const LatLng(11.80613, 107.22916),
    const LatLng(11.80323, 107.23148),
    const LatLng(11.80077, 107.23403),
    const LatLng(11.79898, 107.23536),
    const LatLng(11.79133, 107.2331),
    const LatLng(11.7901, 107.23127),
    const LatLng(11.78723, 107.22959),
    const LatLng(11.78243, 107.22902),
    const LatLng(11.77713, 107.23423),
    const LatLng(11.77519, 107.23541),
    const LatLng(11.77286, 107.23787),
    const LatLng(11.76995, 107.2384),
    const LatLng(11.76737, 107.23868),
    const LatLng(11.76709, 107.24045),
    const LatLng(11.7658, 107.24153),
    const LatLng(11.76371, 107.24089),
    const LatLng(11.7622, 107.23948),
    const LatLng(11.7635, 107.24086),
    const LatLng(11.76542, 107.24148),
    const LatLng(11.76733, 107.24108),
    const LatLng(11.76722, 107.23878),
    const LatLng(11.76982, 107.23845),
    const LatLng(11.77253, 107.23804),
    const LatLng(11.77513, 107.23547),
    const LatLng(11.77658, 107.23479),
    const LatLng(11.78196, 107.22946),
    const LatLng(11.78632, 107.22933),
    const LatLng(11.78987, 107.23096),
    const LatLng(11.79039, 107.23324),
    const LatLng(11.79035, 107.2358),
    const LatLng(11.79299, 107.23686),
    const LatLng(11.79595, 107.23799),
    const LatLng(11.7981, 107.23923),
    const LatLng(11.79942, 107.24114),
    const LatLng(11.80174, 107.24208),
    const LatLng(11.80399, 107.24446),
    const LatLng(11.8092, 107.24717),
    const LatLng(11.81316, 107.25192),
    const LatLng(11.81571, 107.25671),
    const LatLng(11.81671, 107.25785),
    const LatLng(11.82116, 107.26184),
    const LatLng(11.82575, 107.26486),
    const LatLng(11.83171, 107.27069),
    const LatLng(11.83526, 107.27402),
    const LatLng(11.83867, 107.27614),
    const LatLng(11.84085, 107.27861),
    const LatLng(11.84342, 107.28027),
    const LatLng(11.84589, 107.28218),
    const LatLng(11.84908, 107.28353),
    const LatLng(11.85162, 107.28557),
    const LatLng(11.85343, 107.28764),
    const LatLng(11.85646, 107.29033),
    const LatLng(11.85751, 107.29238),
    const LatLng(11.85872, 107.29467),
    const LatLng(11.86237, 107.29961),
    const LatLng(11.865, 107.30208),
    const LatLng(11.86705, 107.30382),
    const LatLng(11.86804, 107.30605),
    const LatLng(11.86926, 107.30964),
    const LatLng(11.87169, 107.31127),
    const LatLng(11.87504, 107.31318),
    const LatLng(11.87891, 107.31464),
    const LatLng(11.883, 107.31706),
    const LatLng(11.88587, 107.31828),
    const LatLng(11.88819, 107.31886),
    const LatLng(11.89047, 107.32011),
    const LatLng(11.89152, 107.32094),
    const LatLng(11.89243, 107.32245),
    const LatLng(11.89325, 107.32458),
    const LatLng(11.8939, 107.3257),
    const LatLng(11.89865, 107.32914),
    const LatLng(11.90262, 107.33055),
    const LatLng(11.90412, 107.3327),
    const LatLng(11.90584, 107.33593),
    const LatLng(11.90567, 107.34014),
    const LatLng(11.90479, 107.34328),
    const LatLng(11.9042, 107.34803),
    const LatLng(11.90248, 107.35409),
    const LatLng(11.90162, 107.35724),
    const LatLng(11.90178, 107.35903),
    const LatLng(11.90575, 107.36426),
    const LatLng(11.90825, 107.36629),
    const LatLng(11.90991, 107.36963),
    const LatLng(11.91289, 107.37318),
    const LatLng(11.91341, 107.37499),
    const LatLng(11.91291, 107.38006),
    const LatLng(11.91246, 107.38529),
    const LatLng(11.91206, 107.39073),
    const LatLng(11.91193, 107.39595),
    const LatLng(11.91301, 107.39908),
    const LatLng(11.91482, 107.39992),
    const LatLng(11.91737, 107.4019),
    const LatLng(11.91906, 107.40998),
    const LatLng(11.92212, 107.41631),
    const LatLng(11.92832, 107.42212),
    const LatLng(11.93136, 107.43028),
    const LatLng(11.93469, 107.43619),
    const LatLng(11.9348, 107.44189),
    const LatLng(11.93563, 107.44598),
    const LatLng(11.93974, 107.44938),
    const LatLng(11.93971, 107.45646),
    const LatLng(11.94438, 107.46261),
    const LatLng(11.94903, 107.46522),
    const LatLng(11.95338, 107.46922),
    const LatLng(11.95489, 107.47246),
    const LatLng(11.9594, 107.47407),
    const LatLng(11.96126, 107.47721),
    const LatLng(11.96279, 107.48572),
    const LatLng(11.97248, 107.49199),
    const LatLng(11.97612, 107.49802),
    const LatLng(11.97608, 107.50017),
    const LatLng(11.97488, 107.50116),
    const LatLng(11.97337, 107.50072),
    const LatLng(11.97167, 107.50039),
    const LatLng(11.9699, 107.5007),
    const LatLng(11.96829, 107.50065),
    const LatLng(11.96967, 107.50078),
    const LatLng(11.97124, 107.50045),
    const LatLng(11.97292, 107.50073),
    const LatLng(11.97466, 107.50106),
    const LatLng(11.97596, 107.50079),
    const LatLng(11.97608, 107.49882),
    const LatLng(11.97995, 107.50129),
    const LatLng(11.98898, 107.50979),
    const LatLng(11.99657, 107.51302),
    const LatLng(11.99933, 107.5194),
    const LatLng(12.00011, 107.52431),
    const LatLng(11.99806, 107.53327),
    const LatLng(11.99487, 107.54238),
    const LatLng(11.99223, 107.54853),
    const LatLng(11.99249, 107.55383),
    const LatLng(11.99198, 107.55885),
    const LatLng(11.98924, 107.56317),
    const LatLng(11.98756, 107.56682),
    const LatLng(11.98517, 107.56924),
    const LatLng(11.98433, 107.5719),
    const LatLng(11.98162, 107.57351),
    const LatLng(11.98037, 107.57554),
    const LatLng(11.98108, 107.57951),
    const LatLng(11.98058, 107.58192),
    const LatLng(11.98084, 107.58597),
    const LatLng(11.98176, 107.59018),
    const LatLng(11.9836, 107.59647),
    const LatLng(11.98405, 107.59987),
    const LatLng(11.98257, 107.60188),
    const LatLng(11.98183, 107.60744),
    const LatLng(11.9854, 107.61061),
    const LatLng(11.98442, 107.61423),
    const LatLng(11.9834, 107.61696),
    const LatLng(11.98058, 107.62021),
    const LatLng(11.97863, 107.62377),
    const LatLng(11.97677, 107.62743),
    const LatLng(11.9775, 107.63117),
    const LatLng(11.97772, 107.63275),
    const LatLng(11.97659, 107.63528),
    const LatLng(11.9753, 107.63721),
    const LatLng(11.97599, 107.63948),
    const LatLng(11.97713, 107.64203),
    const LatLng(11.97662, 107.64404),
    const LatLng(11.97642, 107.64914),
    const LatLng(11.97815, 107.65406),
    const LatLng(11.97947, 107.65705),
    const LatLng(11.98203, 107.65864),
    const LatLng(11.98346, 107.66025),
    const LatLng(11.98692, 107.66244),
    const LatLng(11.99027, 107.66289),
    const LatLng(11.99175, 107.66338),
    const LatLng(11.99246, 107.66449),
    const LatLng(11.9923, 107.66592),
    const LatLng(11.99153, 107.6675),
    const LatLng(11.99171, 107.66934),
    const LatLng(11.99283, 107.67052),
    const LatLng(11.99604, 107.6713),
    const LatLng(11.99977, 107.67243),
    const LatLng(12.0029, 107.67376),
    const LatLng(12.00392, 107.6749),
    const LatLng(12.00313, 107.67576),
    const LatLng(12.00124, 107.67647),
    const LatLng(12.00108, 107.67814),
    const LatLng(12.00226, 107.6834),
    const LatLng(12.00379, 107.69024),
    const LatLng(12.00272, 107.69292),
    const LatLng(11.99695, 107.69493),
    const LatLng(11.99412, 107.69552),
    const LatLng(11.99507, 107.69742),
    const LatLng(11.99395, 107.69596),
    const LatLng(11.99449, 107.69484),
    const LatLng(12.00094, 107.69572),
    const LatLng(12.00129, 107.69471),
    const LatLng(12.00354, 107.69214),
    const LatLng(12.00372, 107.68903),
    const LatLng(12.0024, 107.68324),
    const LatLng(12.00242, 107.68209),
    const LatLng(12.00382, 107.68179),
    const LatLng(12.00569, 107.67982),
    const LatLng(12.00766, 107.67936),
    const LatLng(12.01025, 107.68028),
    const LatLng(12.01221, 107.68205),
    const LatLng(12.01525, 107.68427),
    const LatLng(12.01755, 107.68518),
    const LatLng(12.02244, 107.68619),
    const LatLng(12.02457, 107.68685),
    const LatLng(12.02577, 107.68748),
    const LatLng(12.02828, 107.688),
    const LatLng(12.0294, 107.68806),
    const LatLng(12.03175, 107.68762),
    const LatLng(12.03392, 107.68749),
    const LatLng(12.03561, 107.68685),
    const LatLng(12.03825, 107.68581),
    const LatLng(12.04292, 107.68536),
    const LatLng(12.04476, 107.68449),
    const LatLng(12.04828, 107.68325),
    const LatLng(12.05134, 107.68094),
    const LatLng(12.05411, 107.68072),
    const LatLng(12.05688, 107.6783),
    const LatLng(12.06541, 107.67725),
    const LatLng(12.06859, 107.67404),
    const LatLng(12.07035, 107.67276),
    const LatLng(12.07111, 107.67016),
    const LatLng(12.07534, 107.6684),
    const LatLng(12.08162, 107.66789),
    const LatLng(12.08289, 107.66381),
    const LatLng(12.08596, 107.65715),
    const LatLng(12.08803, 107.65271),
    const LatLng(12.08989, 107.64926),
    const LatLng(12.09426, 107.65236),
    const LatLng(12.09871, 107.65483),
    const LatLng(12.10228, 107.65814),
    const LatLng(12.10501, 107.65776),
    const LatLng(12.1084, 107.65768),
    const LatLng(12.11598, 107.65758),
    const LatLng(12.12621, 107.65433),
    const LatLng(12.13607, 107.6509),
    const LatLng(12.14074, 107.6514),
    const LatLng(12.14271, 107.65018),
    const LatLng(12.14098, 107.64707),
    const LatLng(12.14048, 107.64478),
    const LatLng(12.14307, 107.64386),
    const LatLng(12.14739, 107.64369),
    const LatLng(12.15546, 107.6401),
    const LatLng(12.16015, 107.63806),
    const LatLng(12.16453, 107.63887),
    const LatLng(12.16836, 107.64067),
    const LatLng(12.17175, 107.63912),
    const LatLng(12.17687, 107.63939),
    const LatLng(12.18453, 107.6373),
    const LatLng(12.18812, 107.63767),
    const LatLng(12.19274, 107.63862),
    const LatLng(12.19888, 107.63378),
    const LatLng(12.20363, 107.63207),
    const LatLng(12.20426, 107.62764),
    const LatLng(12.20638, 107.62489),
    const LatLng(12.20696, 107.62144),
    const LatLng(12.21113, 107.6212),
    const LatLng(12.22146, 107.62023),
    const LatLng(12.22545, 107.62146),
    const LatLng(12.22543, 107.62475),
    const LatLng(12.22863, 107.63019),
    const LatLng(12.23053, 107.63113),
    const LatLng(12.23499, 107.62772),
    const LatLng(12.2332, 107.62421),
    const LatLng(12.23369, 107.62151),
    const LatLng(12.23703, 107.62003),
    const LatLng(12.24033, 107.61808),
    const LatLng(12.24402, 107.61778),
    const LatLng(12.24873, 107.61413),
    const LatLng(12.25194, 107.6133),
    const LatLng(12.25298, 107.61015),
    const LatLng(12.25691, 107.61031),
    const LatLng(12.26342, 107.61135),
    const LatLng(12.26505, 107.60895),
    const LatLng(12.26633, 107.60507),
    const LatLng(12.27036, 107.60464),
    const LatLng(12.27412, 107.60465),
    const LatLng(12.27257, 107.60761),
    const LatLng(12.27141, 107.60971),
    const LatLng(12.27176, 107.61118),
    const LatLng(12.27236, 107.6133),
    const LatLng(12.27309, 107.61543),
    const LatLng(12.27202, 107.61586),
    const LatLng(12.27111, 107.61647),
    const LatLng(12.27079, 107.61771),
    const LatLng(12.2707, 107.61783),
    const LatLng(12.27088, 107.61691),
    const LatLng(12.27157, 107.61617),
    const LatLng(12.27261, 107.61546),
    const LatLng(12.27249, 107.61406),
    const LatLng(12.2722, 107.61178),
    const LatLng(12.27145, 107.61024),
    const LatLng(12.27208, 107.60847),
    const LatLng(12.27369, 107.60634),
    const LatLng(12.27337, 107.60224),
    const LatLng(12.28095, 107.59856),
    const LatLng(12.28383, 107.59665),
    const LatLng(12.29002, 107.59519),
    const LatLng(12.29333, 107.59522),
    const LatLng(12.29567, 107.5979),
    const LatLng(12.29842, 107.59888),
    const LatLng(12.30222, 107.59972),
    const LatLng(12.30603, 107.60326),
    const LatLng(12.31133, 107.61003),
    const LatLng(12.31266, 107.61464),
    const LatLng(12.31598, 107.61837),
    const LatLng(12.31616, 107.62183),
    const LatLng(12.31973, 107.62293),
    const LatLng(12.32316, 107.6238),
    const LatLng(12.32673, 107.62702),
    const LatLng(12.32912, 107.63162),
    const LatLng(12.33194, 107.63424),
    const LatLng(12.33391, 107.63484),
    const LatLng(12.33667, 107.63067),
    const LatLng(12.34661, 107.63296),
    const LatLng(12.35994, 107.63555),
    const LatLng(12.36654, 107.63912),
    const LatLng(12.36934, 107.64271),
    const LatLng(12.37424, 107.64501),
    const LatLng(12.37885, 107.64589),
    const LatLng(12.38451, 107.64709),
    const LatLng(12.3921, 107.64816),
    const LatLng(12.39956, 107.64611),
    const LatLng(12.40192, 107.64552),
    const LatLng(12.40265, 107.64453),
    const LatLng(12.40242, 107.64332),
    const LatLng(12.40695, 107.64693),
    const LatLng(12.41807, 107.65198),
    const LatLng(12.42814, 107.65499),
    const LatLng(12.42597, 107.66532),
    const LatLng(12.42333, 107.6756),
    const LatLng(12.42309, 107.68271),
    const LatLng(12.43032, 107.68298),
    const LatLng(12.43296, 107.68309),
    const LatLng(12.43183, 107.66831),
    const LatLng(12.43488, 107.65964),
    const LatLng(12.44692, 107.65995),
    const LatLng(12.45688, 107.65713),
    const LatLng(12.46118, 107.66312),
    const LatLng(12.46542, 107.6724),
    const LatLng(12.46792, 107.67832),
    const LatLng(12.47004, 107.68755),
    const LatLng(12.47579, 107.69748),
    const LatLng(12.47776, 107.70718),
    const LatLng(12.48182, 107.71341),
    const LatLng(12.48687, 107.71819),
    const LatLng(12.48716, 107.7248),
    const LatLng(12.49172, 107.73549),
    const LatLng(12.5, 107.74174),
    const LatLng(12.50601, 107.7454),
    const LatLng(12.51058, 107.74936),
    const LatLng(12.51919, 107.75642),
    const LatLng(12.52489, 107.76551),
    const LatLng(12.52952, 107.77205),
    const LatLng(12.53224, 107.7766),
    const LatLng(12.53533, 107.7806),
    const LatLng(12.53932, 107.78419),
    const LatLng(12.54015, 107.78673),
    const LatLng(12.54064, 107.7935),
    const LatLng(12.54285, 107.79597),
    const LatLng(12.54465, 107.80472),
    const LatLng(12.54576, 107.8147),
    const LatLng(12.55341, 107.81862),
    const LatLng(12.55626, 107.82267),
    const LatLng(12.55871, 107.82319),
    const LatLng(12.56254, 107.82183),
    const LatLng(12.57118, 107.82644),
    const LatLng(12.57849, 107.83719),
    const LatLng(12.58245, 107.84579),
    const LatLng(12.57994, 107.85572),
    const LatLng(12.5802, 107.86369),
    const LatLng(12.58321, 107.8744),
    const LatLng(12.58508, 107.88855),
    const LatLng(12.58716, 107.89381),
    const LatLng(12.59074, 107.89736),
    const LatLng(12.59252, 107.89341),
    const LatLng(12.59315, 107.89229),
  ];

  /// Tính khoảng cách km theo công thức Haversine
  static double calculateDistanceInKm(double lat1, double lon1, double lat2, double lon2) {
    final distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000.0;
  }

  /// Định dạng khoảng cách hiển thị thân thiện cho người dùng
  static String formatDistance(double? distanceInKm) {
    if (distanceInKm == null) return '';
    if (distanceInKm < 1.0) {
      final meters = (distanceInKm * 1000).round();
      return '$meters m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  /// Truy vấn chiến lược đặt vé theo tuyến từ backend.
  /// Phân loại: 'map_stops' (Sài Gòn ↔ Cư Jút) vs 'standard' (tất cả các tuyến khác).
  Future<BookingStrategy> getRouteStrategy({
    String? from,
    String? to,
    String? routeId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (from != null && from.isNotEmpty) queryParams['from'] = from;
      if (to != null && to.isNotEmpty) queryParams['to'] = to;
      if (routeId != null && routeId.isNotEmpty) queryParams['route_id'] = routeId;

      final uri = Uri.parse('${ApiConfig.baseUrl}/routes/strategy').replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null) {
          return BookingStrategy.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('MapBookingService: Lỗi kiểm tra route strategy: $e');
    }

    // Cơ chế fallback khi mất kết nối mạng
    final f = (from ?? '').toLowerCase().trim();
    final t = (to ?? '').toLowerCase().trim();

    // 1. Sài Gòn ↔ Cư Jút
    final isSg = f.contains('hồ chí minh') || f.contains('sài gòn') || f.contains('hcm');
    final isCj = t.contains('cư jút') || t.contains('cư jut') || t.contains('đắk nông');
    final isCjRev = f.contains('cư jút') || f.contains('cư jut') || f.contains('đắk nông');
    final isSgRev = t.contains('hồ chí minh') || t.contains('sài gòn') || t.contains('hcm');

    if (routeId == 'sg_cj' || (isSg && isCj)) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'sg_cj',
        routeCode: 'SG-CJ',
        direction: 'forward',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'TP. Hồ Chí Minh',
        dbDestination: 'Cư Jut',
        originDisplay: 'Sài Gòn',
        destinationDisplay: 'Cư Jút',
        highway: 'Quốc lộ 13 - Quốc lộ 14 (Đường Hồ Chí Minh)',
        distanceKm: 310.0,
        estimatedDuration: '7 giờ 30 phút',
        message: 'Tuyến Sài Gòn ➔ Cư Jút: Kích hoạt bản đồ BusMap.',
      );
    } else if (isCjRev && isSgRev) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'sg_cj',
        routeCode: 'SG-CJ',
        direction: 'reverse',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'Cư Jut',
        dbDestination: 'TP. Hồ Chí Minh',
        originDisplay: 'Cư Jút',
        destinationDisplay: 'Sài Gòn',
        highway: 'Quốc lộ 13 - Quốc lộ 14 (Đường Hồ Chí Minh)',
        distanceKm: 310.0,
        estimatedDuration: '7 giờ 30 phút',
        message: 'Tuyến Cư Jút ➔ Sài Gòn: Kích hoạt bản đồ BusMap (chiều ngược lại).',
      );
    }

    // 2. TP. Hồ Chí Minh ↔ Đà Lạt
    final isDl = t.contains('đà lạt') || t.contains('da lat');
    final isDlRev = f.contains('đà lạt') || f.contains('da lat');
    if (routeId == 'sg_dl' || (isSg && isDl)) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'sg_dl',
        routeCode: 'SG-DL',
        direction: 'forward',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'TP. Hồ Chí Minh',
        dbDestination: 'Đà Lạt',
        originDisplay: 'TP. Hồ Chí Minh',
        destinationDisplay: 'Đà Lạt',
        highway: 'Quốc lộ 20 & Cao tốc Dầu Giây - Liên Khương',
        distanceKm: 296.6,
        estimatedDuration: '6 giờ 00 phút',
        message: 'Tuyến TP. Hồ Chí Minh ➔ Đà Lạt: Kích hoạt bản đồ BusMap.',
      );
    } else if (isDlRev && isSgRev) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'sg_dl',
        routeCode: 'SG-DL',
        direction: 'reverse',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'Đà Lạt',
        dbDestination: 'TP. Hồ Chí Minh',
        originDisplay: 'Đà Lạt',
        destinationDisplay: 'TP. Hồ Chí Minh',
        highway: 'Quốc lộ 20 & Cao tốc Dầu Giây - Liên Khương',
        distanceKm: 296.6,
        estimatedDuration: '6 giờ 00 phút',
        message: 'Tuyến Đà Lạt ➔ TP. Hồ Chí Minh: Kích hoạt bản đồ BusMap (chiều ngược lại).',
      );
    }

    // 3. TP. Hồ Chí Minh ↔ Cần Thơ
    final isCt = t.contains('cần thơ') || t.contains('can tho');
    final isCtRev = f.contains('cần thơ') || f.contains('can tho');
    if (routeId == 'sg_ct' || (isSg && isCt)) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'sg_ct',
        routeCode: 'SG-CT',
        direction: 'forward',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'TP. Hồ Chí Minh',
        dbDestination: 'Cần Thơ',
        originDisplay: 'TP. Hồ Chí Minh',
        destinationDisplay: 'Cần Thơ',
        highway: 'Cao tốc TP.HCM - Trung Lương - Mỹ Thuận',
        distanceKm: 177.4,
        estimatedDuration: '3 giờ 15 phút',
        message: 'Tuyến TP. Hồ Chí Minh ➔ Cần Thơ: Kích hoạt bản đồ BusMap.',
      );
    } else if (isCtRev && isSgRev) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'sg_ct',
        routeCode: 'SG-CT',
        direction: 'reverse',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'Cần Thơ',
        dbDestination: 'TP. Hồ Chí Minh',
        originDisplay: 'Cần Thơ',
        destinationDisplay: 'TP. Hồ Chí Minh',
        highway: 'Cao tốc TP.HCM - Trung Lương - Mỹ Thuận',
        distanceKm: 177.4,
        estimatedDuration: '3 giờ 15 phút',
        message: 'Tuyến Cần Thơ ➔ TP. Hồ Chí Minh: Kích hoạt bản đồ BusMap (chiều ngược lại).',
      );
    }

    // 4. Hà Nội ↔ Hải Phòng
    final isHn = f.contains('hà nội') || f.contains('ha noi');
    final isHp = t.contains('hải phòng') || t.contains('hai phong');
    final isHpRev = f.contains('hải phòng') || f.contains('hai phong');
    final isHnRev = t.contains('hà nội') || t.contains('ha noi');
    if (routeId == 'hn_hp' || (isHn && isHp)) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'hn_hp',
        routeCode: 'HN-HP',
        direction: 'forward',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'Hà Nội',
        dbDestination: 'Hải Phòng',
        originDisplay: 'Hà Nội',
        destinationDisplay: 'Hải Phòng',
        highway: 'Cao tốc Hà Nội - Hải Phòng (QL5B)',
        distanceKm: 126.5,
        estimatedDuration: '1 giờ 45 phút',
        message: 'Tuyến Hà Nội ➔ Hải Phòng: Kích hoạt bản đồ BusMap.',
      );
    } else if (isHpRev && isHnRev) {
      return const BookingStrategy(
        mode: BookingMode.mapStops,
        routeId: 'hn_hp',
        routeCode: 'HN-HP',
        direction: 'reverse',
        hasMapConfig: true,
        fallbackToStandard: false,
        dbOrigin: 'Hải Phòng',
        dbDestination: 'Hà Nội',
        originDisplay: 'Hải Phòng',
        destinationDisplay: 'Hà Nội',
        highway: 'Cao tốc Hà Nội - Hải Phòng (QL5B)',
        distanceKm: 126.5,
        estimatedDuration: '1 giờ 45 phút',
        message: 'Tuyến Hải Phòng ➔ Hà Nội: Kích hoạt bản đồ BusMap (chiều ngược lại).',
      );
    }

    // 5. Hà Nội ↔ Đà Nẵng (route_map)
    final isDn = t.contains('đà nẵng') || t.contains('da nang');
    final isDnRev = f.contains('đà nẵng') || f.contains('da nang');
    if (routeId == 'hn_dn' || (isHn && isDn) || (isDnRev && isHnRev)) {
      return BookingStrategy(
        mode: BookingMode.custom,
        routeId: 'hn_dn',
        routeCode: 'HN-DN',
        direction: isDn ? 'forward' : 'reverse',
        hasMapConfig: true,
        fallbackToStandard: true,
        dbOrigin: isDn ? 'Hà Nội' : 'Đà Nẵng',
        dbDestination: isDn ? 'Đà Nẵng' : 'Hà Nội',
        originDisplay: isDn ? 'Hà Nội' : 'Đà Nẵng',
        destinationDisplay: isDn ? 'Đà Nẵng' : 'Hà Nội',
        highway: 'Quốc lộ 1A & Cao tốc Bắc Nam',
        distanceKm: 765.0,
        estimatedDuration: '14 giờ 00 phút',
        message: 'Tuyến Hà Nội ↔ Đà Nẵng: Hỗ trợ xem lộ trình trên bản đồ.',
      );
    }

    return BookingStrategy.standard(from: from, to: to);
  }

  /// Lấy dữ liệu điểm dừng, polyline và cột mốc cho một tuyến xe bất kỳ
  Future<RouteMapData?> getRouteStops({
    required String routeId,
    String direction = 'forward',
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/map-routes/stops').replace(
        queryParameters: {
          'route_id': routeId,
          'direction': direction,
        },
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null) {
          return RouteMapData.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('MapBookingService: Lỗi tải stops tuyến $routeId: $e');
    }

    // Fallback thông minh cục bộ
    return _buildLocalFallbackRouteData(routeId, direction);
  }

  /// Gọi API Routing Engine tính toán đường đi thực tế và tối ưu hành trình
  Future<DirectionsResult?> getRouteDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    String optimization = 'transit_route',
    String? routeId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/routes/directions');
      final body = jsonEncode({
        'origin': {'lat': origin.latitude, 'lng': origin.longitude},
        'destination': {'lat': destination.latitude, 'lng': destination.longitude},
        'waypoints': (waypoints ?? []).map((w) => {'lat': w.latitude, 'lng': w.longitude}).toList(),
        'optimization': optimization,
        'route_id': routeId,
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null) {
          return DirectionsResult.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('MapBookingService: Lỗi tính directions: $e');
    }
    return null;
  }

  /// Xác thực tính hợp lệ của trạm đón & trạm trả (sequence và khu vực)
  Future<MapValidationResult> validateSelection({
    required String pickupId,
    required String dropoffId,
    String direction = 'forward',
    String routeId = 'sg_cj',
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/map-routes/validate-selection');
      final body = jsonEncode({
        'pickup_id': pickupId,
        'dropoff_id': dropoffId,
        'direction': direction,
        'route_id': routeId,
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 4));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return const MapValidationResult(isValid: true, message: 'Hành trình hợp lệ');
      } else {
        final errorMsg = data['message'] ?? 'Lựa chọn trạm chưa hợp lệ';
        final errCode = data['error']?['code'] ?? 'INVALID_SELECTION';
        return MapValidationResult(isValid: false, message: errorMsg, errorCode: errCode);
      }
    } catch (e) {
      debugPrint('MapBookingService: Lỗi validate trạm: $e');
      return const MapValidationResult(isValid: true, message: 'Xác thực ngoại tuyến');
    }
  }

  /// Dữ liệu trạm dự phòng cho trường hợp không có mạng
  RouteMapData _buildLocalFallbackRouteData(String routeId, String direction) {
    final cleanRoute = routeId.toLowerCase().trim();
    final all = fallbackStations;

    if (cleanRoute == 'sg_dl') {
      return RouteMapData(
        routeId: 'sg_dl',
        routeName: 'TP. Hồ Chí Minh ↔ Đà Lạt',
        direction: direction,
        departureArea: direction == 'forward' ? 'TP. Hồ Chí Minh' : 'Đà Lạt',
        destinationArea: direction == 'forward' ? 'Đà Lạt' : 'TP. Hồ Chí Minh',
        dbOrigin: direction == 'forward' ? 'TP. Hồ Chí Minh' : 'Đà Lạt',
        dbDestination: direction == 'forward' ? 'Đà Lạt' : 'TP. Hồ Chí Minh',
        pickupStops: direction == 'forward' ? _localDlPickups : _localDlDropoffs,
        dropoffStops: direction == 'forward' ? _localDlDropoffs : _localDlPickups,
        restStops: _localDlRests,
        polyline: _localDlPolyline,
        corridorMilestones: _localDlMilestones,
        highway: 'Quốc lộ 20 & Cao tốc Dầu Giây - Liên Khương',
        distanceKm: 296.6,
        estimatedDuration: '6 giờ 00 phút',
      );
    }

    // Mặc định Sài Gòn ↔ Cư Jút
    final isRev = direction == 'reverse';
    return RouteMapData(
      routeId: 'sg_cj',
      routeName: 'Sài Gòn ↔ Cư Jút',
      direction: direction,
      departureArea: isRev ? 'Cư Jút' : 'Sài Gòn',
      destinationArea: isRev ? 'Sài Gòn' : 'Cư Jút',
      dbOrigin: isRev ? 'Cư Jut' : 'TP. Hồ Chí Minh',
      dbDestination: isRev ? 'TP. Hồ Chí Minh' : 'Cư Jut',
      pickupStops: isRev ? all.where((s) => s.area == 'Cư Jút').toList() : all.where((s) => s.area == 'Sài Gòn').toList(),
      dropoffStops: isRev ? all.where((s) => s.area == 'Sài Gòn').toList() : all.where((s) => s.area == 'Cư Jút').toList(),
      restStops: [],
      polyline: fallbackPolyline,
      corridorMilestones: [
        {'title': 'Bến xe Miền Đông (Cũ)', 'tag': 'QL13', 'lat': 10.8145, 'lng': 106.7123},
        {'title': 'Ngã tư Bình Phước', 'tag': 'QL13', 'lat': 10.8652, 'lng': 106.7242},
        {'title': 'TP. Gia Nghĩa', 'tag': 'QL14', 'lat': 12.0038, 'lng': 107.6902},
        {'title': 'Bến xe Cư Jút', 'tag': 'Đích đến', 'lat': 12.5932, 'lng': 107.8924},
      ],
      highway: 'Quốc lộ 13 - Quốc lộ 14 (Đường Hồ Chí Minh)',
      distanceKm: 310.0,
      estimatedDuration: '7 giờ 30 phút',
    );
  }

  static final List<MapStation> _localDlPickups = [
    MapStation(
      id: 'sg_bxmd_moi',
      routeId: 'sg_dl',
      area: 'TP. Hồ Chí Minh',
      name: 'Bến xe Miền Đông Mới',
      address: '501 Hoàng Hữu Nam, P. Long Bình, TP. Thủ Đức, TP.HCM',
      latitude: 10.8753,
      longitude: 106.8152,
      stopType: 'both',
      sequence: 1,
      isActive: true,
      description: 'Bến xe hiện đại nhất TP.HCM, xuất phát đi cao tốc Dầu Giây.',
    ),
    MapStation(
      id: 'sg_bxmd_cu_dl',
      routeId: 'sg_dl',
      area: 'TP. Hồ Chí Minh',
      name: 'Bến xe Miền Đông (Cũ)',
      address: '292 Đinh Bộ Lĩnh, P. 26, Q. Bình Thạnh, TP.HCM',
      latitude: 10.8145,
      longitude: 106.7123,
      stopType: 'both',
      sequence: 2,
      isActive: true,
      description: 'Quầy vé Đà Lạt trung tâm Bình Thạnh, có xe trung chuyển.',
    ),
  ];

  static final List<MapStation> _localDlDropoffs = [
    MapStation(
      id: 'dl_bx_lien_tinh',
      routeId: 'sg_dl',
      area: 'Đà Lạt',
      name: 'Bến xe Liên Tỉnh Đà Lạt',
      address: 'Số 01 Tô Hiến Thành, Phường 3, TP. Đà Lạt',
      latitude: 11.9285,
      longitude: 108.4447,
      stopType: 'both',
      sequence: 8,
      isActive: true,
      description: 'Bến xe liên tỉnh trung tâm Đà Lạt ngay đầu đèo Prenn.',
    ),
    MapStation(
      id: 'dl_vp_bui_thi_xuan',
      routeId: 'sg_dl',
      area: 'Đà Lạt',
      name: 'Văn phòng Bùi Thị Xuân Đà Lạt',
      address: '12 Bùi Thị Xuân, Phường 2, TP. Đà Lạt',
      latitude: 11.9442,
      longitude: 108.4385,
      stopType: 'both',
      sequence: 9,
      isActive: true,
      description: 'Văn phòng trung tâm phố hoa, cách Hồ Xuân Hương 200m.',
    ),
  ];

  static final List<MapStation> _localDlRests = [
    MapStation(
      id: 'dl_td_madagui',
      routeId: 'sg_dl',
      area: 'Lâm Đồng',
      name: 'Trạm dừng Madagui (Km 152 QL20)',
      address: 'Km 152 Quốc lộ 20, Huyện Đạ Huoai, Lâm Đồng',
      latitude: 11.4121,
      longitude: 107.5678,
      stopType: 'both',
      sequence: 5,
      isActive: true,
      description: 'Trạm nghỉ chân lớn chân đèo Bảo Lộc.',
    ),
  ];

  static final List<LatLng> _localDlPolyline = [
    const LatLng(10.81454, 106.71232),
    const LatLng(10.87530, 106.81520),
    const LatLng(10.95760, 107.13520),
    const LatLng(11.41210, 107.56780),
    const LatLng(11.54580, 107.80890),
    const LatLng(11.75840, 108.41120),
    const LatLng(11.92850, 108.44470),
  ];

  static final List<Map<String, dynamic>> _localDlMilestones = [
    {'title': 'Bến xe Miền Đông mới', 'tag': 'TP.HCM', 'lat': 10.8753, 'lng': 106.8152},
    {'title': 'Ngã 3 Dầu Giây', 'tag': 'Đồng Nai (QL20)', 'lat': 10.9576, 'lng': 107.1352},
    {'title': 'Trạm dừng Madagui', 'tag': 'Đèo Chuối', 'lat': 11.4121, 'lng': 107.5678},
    {'title': 'TP. Bảo Lộc', 'tag': 'Đèo Bảo Lộc', 'lat': 11.5458, 'lng': 107.8089},
    {'title': 'Bến xe Liên tỉnh Đà Lạt', 'tag': 'Đích đến', 'lat': 11.9285, 'lng': 108.4447},
  ];
}

class RouteMapData {
  final String routeId;
  final String routeName;
  final String direction;
  final String departureArea;
  final String destinationArea;
  final String dbOrigin;
  final String dbDestination;
  final List<MapStation> pickupStops;
  final List<MapStation> dropoffStops;
  final List<MapStation> restStops;
  final List<LatLng> polyline;
  final List<Map<String, dynamic>> corridorMilestones;
  final String? highway;
  final double distanceKm;
  final String estimatedDuration;

  const RouteMapData({
    required this.routeId,
    required this.routeName,
    required this.direction,
    required this.departureArea,
    required this.destinationArea,
    required this.dbOrigin,
    required this.dbDestination,
    required this.pickupStops,
    required this.dropoffStops,
    required this.restStops,
    required this.polyline,
    required this.corridorMilestones,
    this.highway,
    required this.distanceKm,
    required this.estimatedDuration,
  });

  factory RouteMapData.fromJson(Map<String, dynamic> json) {
    final pickups = (json['pickup_stops'] as List? ?? [])
        .map((e) => MapStation.fromJson(e as Map<String, dynamic>))
        .toList();
    final dropoffs = (json['dropoff_stops'] as List? ?? [])
        .map((e) => MapStation.fromJson(e as Map<String, dynamic>))
        .toList();
    final rests = (json['rest_stops'] as List? ?? [])
        .map((e) => MapStation.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawPoly = json['polyline'] as List? ?? [];
    final polyline = rawPoly.map((p) {
      if (p is List && p.length >= 2) {
        return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }
      return const LatLng(0, 0);
    }).where((p) => p.latitude != 0 && p.longitude != 0).toList();

    final milestones = (json['corridor_milestones'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return RouteMapData(
      routeId: json['route_id']?.toString() ?? '',
      routeName: json['route_name']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'forward',
      departureArea: json['departure_area']?.toString() ?? '',
      destinationArea: json['destination_area']?.toString() ?? '',
      dbOrigin: json['db_origin']?.toString() ?? '',
      dbDestination: json['db_destination']?.toString() ?? '',
      pickupStops: pickups,
      dropoffStops: dropoffs,
      restStops: rests,
      polyline: polyline,
      corridorMilestones: milestones,
      highway: json['highway']?.toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedDuration: json['estimated_duration']?.toString() ?? '',
    );
  }
}

class DirectionsResult {
  final List<LatLng> polyline;
  final double distanceKm;
  final int durationMinutes;
  final String durationText;
  final String optimization;
  final String optimizationName;
  final String? highway;
  final String source;

  const DirectionsResult({
    required this.polyline,
    required this.distanceKm,
    required this.durationMinutes,
    required this.durationText,
    required this.optimization,
    required this.optimizationName,
    this.highway,
    required this.source,
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    final rawPoly = json['polyline'] as List? ?? [];
    final polyline = rawPoly.map((p) {
      if (p is List && p.length >= 2) {
        return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }
      return const LatLng(0, 0);
    }).where((p) => p.latitude != 0 && p.longitude != 0).toList();

    return DirectionsResult(
      polyline: polyline,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      durationText: json['duration_text']?.toString() ?? '',
      optimization: json['optimization']?.toString() ?? 'transit_route',
      optimizationName: json['optimization_name']?.toString() ?? '',
      highway: json['highway']?.toString(),
      source: json['source']?.toString() ?? 'OpenStreetMap OSRM',
    );
  }
}

class MapValidationResult {
  final bool isValid;
  final String? message;
  final String? errorCode;

  const MapValidationResult({
    required this.isValid,
    this.message,
    this.errorCode,
  });
}

