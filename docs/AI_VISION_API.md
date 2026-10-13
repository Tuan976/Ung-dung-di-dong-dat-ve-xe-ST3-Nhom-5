# Tài Liệu Đặc Tả API - AI Vision Service

Dịch vụ AI Vision Service cung cấp các endpoint REST API xử lý hình ảnh cho ứng dụng Đặt vé xe khách liên tỉnh.

- **Base URL (Local)**: `http://127.0.0.1:5050`
- **Base URL (Public Tunnel)**: `https://hall-allocated-graphic-screensaver.trycloudflare.com`
- **Xác thực**: Bearer Token trong Header:
  `Authorization: Bearer vexekhach_ai_vision_sec_2026_tok`

---

## 1. GET /health
Kiểm tra trạng thái sẵn sàng của AI Vision Service và máy chủ Ollama.

- **Yêu cầu xác thực**: Không (Public Health Check).
- **Phản hồi mẫu (200 OK)**:
```json
{
  "ollama": {
    "available_models": ["moondream:latest"],
    "configured_model": "moondream:latest",
    "is_configured_model_ready": true,
    "message": "Ollama đang hoạt động bình thường",
    "status": "connected"
  },
  "service": "AI Vision Service - Đặt vé xe khách",
  "status": "healthy",
  "timestamp": 1791811374
}
```

---

## 2. GET /v1/models
Xem danh sách mô hình thị giác máy tính được hỗ trợ và mô hình đang kích hoạt.

- **Headers**: `Authorization: Bearer <TOKEN>`
- **Phản hồi mẫu (200 OK)**:
```json
{
  "current_active_model": "moondream:latest",
  "installed_models": [
    {
      "name": "moondream:latest",
      "size": 1738451197
    }
  ],
  "success": true,
  "supported_vision_models": [
    {"id": "moondream:latest", "desc": "Mô hình Vision siêu nhẹ 1.7GB, phản hồi nhanh"},
    {"id": "qwen2.5-vl:3b", "desc": "Qwen 2.5 Vision 3B"}
  ]
}
```

---

## 3. POST /v1/vision/describe
Mô tả toàn cảnh bức ảnh bằng tiếng Việt (phương tiện, bến bãi, quang cảnh).

- **Headers**: `Authorization: Bearer <TOKEN>`
- **Body**: `multipart/form-data`
  - `image`: File ảnh (`.jpg`, `.png`, `.webp`)
  - `prompt` *(tùy chọn)*: Lời nhắc bổ sung
- **Phản hồi mẫu (200 OK)**:
```json
{
  "success": true,
  "filename": "bus_station.jpg",
  "task": "describe",
  "model": "moondream:latest",
  "description": "Bức ảnh chụp khu vực bến xe khách đông đúc với nhiều xe khách giường nằm màu đỏ đỗ tại các làn xuất bến...",
  "execution_time_seconds": 3.42
}
```

---

## 4. POST /v1/vision/ocr
Đọc chữ, số hiệu vé xe, biển số xe và giải mã mã QR (nếu có trong ảnh).

- **Headers**: `Authorization: Bearer <TOKEN>`
- **Body**: `multipart/form-data`
  - `image`: File ảnh
- **Phản hồi mẫu (200 OK)**:
```json
{
  "success": true,
  "filename": "ticket_qr.png",
  "task": "ocr",
  "model": "moondream:latest",
  "extracted_text": "VÉ XE KHÁCH VIỆT NAM - Tuyến: Hà Nội đi Hải Phòng...",
  "qr_detected": true,
  "qr_content": "VX-BOOKING-8822",
  "execution_time_seconds": 2.85
}
```

---

## 5. POST /v1/vision/analyze
Phân tích chuyên sâu vé xe, đối chiếu mã QR với cơ sở dữ liệu backend hoặc nhận diện điểm đón xe.

- **Headers**: `Authorization: Bearer <TOKEN>`
- **Body**: `multipart/form-data`
  - `image`: File ảnh
  - `type` *(tùy chọn)*: `ticket` (vé xe) | `pickup_location` (điểm đón) | `general` (tổng quát)
  - `prompt` *(tùy chọn)*: Yêu cầu chi tiết
- **Phản hồi mẫu (200 OK)**:
```json
{
  "success": true,
  "filename": "ticket.jpg",
  "task": "analyze",
  "analysis_type": "ticket",
  "model": "moondream:latest",
  "image_dimensions": {"width": 800, "height": 600},
  "analysis_result": "Vé xe khách Phương Trang, mã đặt chỗ PT-554433, tuyến TP.HCM đi Đà Lạt, xuất bến lúc 08:00, số ghế B04.",
  "qr_detected": true,
  "qr_code": "VX-BOOKING-554433",
  "ticket_verification": {
    "backend_checked": true,
    "is_verified": true,
    "message": "Vé #554433 hợp lệ trên hệ thống backend."
  },
  "execution_time_seconds": 3.75
}
```
