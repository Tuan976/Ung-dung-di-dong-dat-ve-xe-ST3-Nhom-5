import sys
import requests

sys.stdout.reconfigure(encoding='utf-8')

observation_en = """The image shows a large outdoor area with a green lawn in the foreground. In the middle ground, there is a large white monument sign with bold dark blue letters that reads: "THANH PHO HO CHI MINH - KHU CONG NGHE CAO" (High Tech Park Ho Chi Minh City). Behind the sign, there is a tall modern apartment building complex with beige and white walls, multiple rows of tall street light poles, and a tall communication tower under a clear blue sky."""

reasoning_prompt = f"""Bạn là trợ lý AI chuyên nghiệp của ứng dụng Đặt vé xe khách liên tỉnh.
Dưới đây là thông tin chi tiết được quan sát từ hình ảnh của khách hàng:
\"\"\"{observation_en}\"\"\"

Yêu cầu người dùng: "Chỗ này là chỗ nào"
Tác vụ: Nhận diện điểm đón xe

Hãy phân tích và trả lời chi tiết cho khách hàng bằng tiếng Việt chuẩn xác, tuyệt đối không lặp từ, theo cấu trúc rõ ràng sau:

### 1. Tổng quan & Địa điểm nhận diện
(Xác định chính xác địa danh/công trình dựa trên biển hiệu)

### 2. Các đặc điểm nhận diện nổi bật
(Mô tả các vật thể xung quanh như biển hiệu, tòa nhà, cột đèn, cảnh quan giúp hành khách nhận biết)

### 3. Văn bản đọc được từ ảnh
(Ghi lại chính xác chữ trên bảng/biển)

### 4. Hướng dẫn & Đánh giá đón xe khách
(Đánh giá khả năng đón xe, lưu ý an toàn cho hành khách)
"""

payload = {
    'model': 'qwen2.5:1.5b',
    'prompt': reasoning_prompt,
    'stream': False,
    'options': {'temperature': 0.2, 'repeat_penalty': 1.2, 'top_p': 0.9, 'num_predict': 500}
}

r = requests.post('http://127.0.0.1:11434/api/generate', json=payload, timeout=40)
print('HYBRID PIPELINE RESULT:\n')
print(r.json().get('response'))
