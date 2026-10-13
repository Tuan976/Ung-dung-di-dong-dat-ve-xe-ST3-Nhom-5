# Hướng Dẫn Cài Đặt & Triển Khai AI Vision Service (Local & Public)

Hệ thống AI Vision phục vụ nhận diện vé xe khách, bến xe/điểm đón, đọc chữ OCR và mô tả bối cảnh giao thông được tích hợp trực tiếp vào ứng dụng Flutter **VéXe Khách**.

---

## 1. Cấu Hình Phần Cứng Thực Tế & Lựa Chọn Mô Hình

- **Hệ điều hành**: Windows 10 Home Single Language (Build 2009 / 64-bit)
- **CPU**: Intel Core thế hệ 11/12/13 (x64)
- **RAM vật lý**: 16 GB (Khả dụng: ~2 - 4 GB)
- **GPU & VRAM**:
  - Intel(R) Iris(R) Xe Graphics (Tích hợp)
  - NVIDIA GeForce MX550 (VRAM: **2048 MiB / 2 GB**)
- **Dung lượng đĩa khả dụng**:
  - Ổ `C:\`: ~14.8 GB free
  - Ổ `D:\`: ~17.8 GB free (Đặt kho lưu trữ mô hình `D:\ollama_models`)

### Lựa Chọn Mô Hình:
- **Mô hình được kích hoạt**: `moondream:latest` (Dung lượng: **1.7 GB**, tham số: 1B vision phi2 + clip).
  - *Lý do*: VRAM của card NVIDIA MX550 chỉ đạt 2GB, RAM hệ thống còn trống khoảng 2-3GB. Các mô hình như `qwen2.5-vl:3b` hay `7b` đòi hỏi tối thiểu 4GB - 8GB VRAM để chạy mượt mà không tràn RAM vật lý hoặc không có sẵn tag trên Ollama library. `moondream:latest` cho tốc độ suy luận nhanh (~2-4 giây/ảnh), nhận diện cực tốt chữ số, vé xe, và bối cảnh đường phố.

---

## 2. Kiến Trúc Dịch Vụ AI Vision

```
[Flutter App / Camera / Gallery]
               │
               ▼ (HTTPS Bearer Auth)
[Cloudflare Tunnel / LAN / Local]
               │
               ▼ (Port 5050)
[Flask AI Vision Service]  <───> [OpenCV QRCodeDetector]
       │             │                 │ (Xác thực với backend)
       │             │                 ▼
       │             └─────────> [Main Flask Bus Backend (:5000)]
       ▼ (Port 11434)
[Ollama Local Engine] ──> [D:\ollama_models\moondream:latest]
```

---

## 3. Các Bước Cài Đặt & Khởi Chạy

### Bước 1: Khởi động Ollama (Lưu trữ trên ổ D)
Chạy PowerShell với quyền người dùng hiện tại:
```powershell
$env:OLLAMA_MODELS = "D:\ollama_models"
$env:OLLAMA_HOST = "127.0.0.1:11434"
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" serve
```

### Bước 2: Cài đặt thư viện Python cho AI Vision Service
```powershell
cd d:\WebDatVeXe\ai_vision_service
pip install -r requirements.txt
```

### Bước 3: Khởi chạy AI Vision Service (Port 5050)
```powershell
cd d:\WebDatVeXe\ai_vision_service
python app.py
```
Hoặc dùng file script khởi chạy tự động:
```powershell
d:\WebDatVeXe\start_ai_vision_service.bat
```

### Bước 4: Khởi chạy Public Tunnel (HTTPS an toàn)
```powershell
d:\WebDatVeXe\cloudflared.exe tunnel --url http://127.0.0.1:5050
```
*Lưu ý:* Đường dẫn Public HTTPS sinh ra sẽ có dạng:
`https://<subdomain>.trycloudflare.com`

---

## 4. Tích Hợp Vào Ứng Dụng Flutter

- **File cấu hình môi trường**: `lib/core/config/vision_config.dart`
- **Hỗ trợ 4 môi trường kết nối linh hoạt**:
  1. `production`: HTTPS Cloudflare Tunnel (Khuyên dùng cho điện thoại thật, mạng di động 4G/5G).
  2. `lanDevice`: Địa chỉ IP mạng LAN máy tính `http://192.168.123.41:5050` (Khi điện thoại và máy tính cùng chung Wi-Fi).
  3. `androidEmulator`: Địa chỉ máy ảo Android Studio `http://10.0.2.2:5050`.
  4. `local`: `http://127.0.0.1:5050` (Khi chạy Flutter desktop Windows hoặc Web).
- **Màn hình giao diện**: `lib/screens/vision/vision_assistant_screen.dart`
- **Nút truy cập**: Đã tích hợp ngay trên thanh Header trang chủ (`HomeScreen`) góc trên bên phải với icon **AI Vision**.
