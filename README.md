# HUTECH BUS - Hệ thống Đặt Vé & Quản Lý Xe Khách Chất Lượng Cao

Hệ thống quản lý đặt vé xe khách trực tuyến dành riêng cho hãng xe HUTECH BUS, tích hợp đầy đủ tính năng đặt vé nhanh, quản lý phơi khách (Manifest), ký gửi hàng hóa (Cargo), xếp lịch tài xế/phụ xe và chăm sóc khách hàng tự động bằng chatbot AI.

---

## 🛠️ Công Nghệ Sử Dụng

### Backend (Python Flask)
* **Framework:** Flask, Flask-SQLAlchemy, Flask-SocketIO
* **Database:** SQLite (cho môi trường local/development)
* **Tích hợp:** Rasa Chatbot AI (Tự động hỗ trợ tư vấn lộ trình và đặt vé), PayOS (Cổng thanh toán trực tuyến 1s)
* **Giao diện người dùng:** Jinja2 Templates (Tối ưu hóa SEO, tải trang nhanh)

### Frontend (React SPA - Admin Dashboard)
* **Framework:** React + Vite + TailwindCSS
* **Thư viện chính:** Framer Motion (Hiệu ứng động mượt mà), Lucide React (Bộ icon thiết kế hiện đại)
* **Trình xây dựng:** Vite (Biên dịch tối ưu hóa production)

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Local

### 1. Cấu hình Backend (Python)
1. Cài đặt Python (phiên bản >= 3.8).
2. Tạo môi trường ảo và cài đặt thư viện:
   ```bash
   python -m venv venv
   source venv/bin/activate  # Trên Windows dùng: venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. Tạo file cấu hình môi trường `.env` dựa theo file mẫu `.env.example`.
4. Chạy setup cơ sở dữ liệu ban đầu và khởi chạy server:
   ```bash
   python db_setup.py
   python app.py
   ```
   * *Backend sẽ hoạt động tại địa chỉ: `http://localhost:5000`*

### 2. Cấu hình Frontend (React Admin)
1. Di chuyển vào thư mục `frontend` và cài đặt dependencies:
   ```bash
   cd frontend
   npm install
   ```
2. Khởi chạy React server ở chế độ phát triển (Development mode):
   ```bash
   npm run dev
   ```
   * *Frontend sẽ hoạt động tại địa chỉ: `http://localhost:5173`*

3. Biên dịch ứng dụng React thành bản phân phối tĩnh (Production bundle):
   ```bash
   npm run build
   ```
   * *Mã nguồn đã biên dịch sẽ nằm trong thư mục `frontend/dist/` (Bạn có thể đóng gói thư mục này thông qua file `dist.zip` ở thư mục gốc để upload trực tiếp lên host).*

---

## 📦 Danh Sách File Đã Cập Nhật (Cần upload khi lên Host)

Khi triển khai bản cập nhật mới nhất lên môi trường Production, bạn chỉ cần tải lên các phần sau:
* **Backend:**
  * [routes_booking.py](file:///d:/WebDatVeXe/routes_booking.py) (Xử lý lưu trữ Điểm đón/trả tùy chỉnh từ khách hàng).
* **Giao diện Public:**
  * [WebDatVeXe/templates/book.html](file:///d:/WebDatVeXe/WebDatVeXe/templates/book.html) (Cập nhật ô nhập văn bản tự do cho Điểm đón/trả).
* **Giao diện React SPA (Admin):**
  * Tải lên toàn bộ thư mục `frontend/dist/` đã được build (hoặc giải nén từ file **`dist.zip`** nằm tại thư mục gốc của dự án).

---

## 📝 Nhật Ký Các Bản Sửa Lỗi Gần Đây (Bug Fixes)

1. **Lọc Chuyến Xe trong Kho Gửi (Cargo):**
   * Khắc phục lỗi lọc chuyến xe dựa trên so sánh chuỗi địa danh bằng cách chuyển sang so khớp chính xác theo khóa ngoại `route_id`.
2. **Cho Phép Nhập Điểm Đón/Trả Tự Do:**
   * Thay thế các menu thả xuống (`select`) giới hạn bằng các trường văn bản tự do (`input text`) giúp khách hàng tự do nhập vị trí đón/trả linh hoạt.
3. **Sửa Lỗi Che Khuất Dropdown (Dropdown Clipping):**
   * Tách nền Hero section vào một lớp `overflow-hidden` riêng và chuyển vùng cha chứa form tìm kiếm thành `overflow-visible`.
   * Bổ sung thuộc tính `z-[60]` động khi mở để ngăn các cột kế tiếp đè lên menu lựa chọn tỉnh thành.
