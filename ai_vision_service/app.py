"""
AI Vision Service for Bus Booking Application
=============================================
Architecture:
- Two-Stage Hybrid AI Pipeline:
    Stage 1: Moondream Vision Model extracts factual visual observations & OCR text in English.
    Stage 2: Qwen2.5 (1.5B) reasoning engine translates and formats comprehensive, structured Vietnamese responses.
- Anti-Repetition Quality Checker:
    Detects repeated phrases, repetitive tokens, or truncation.
    Auto-retries with adjusted penalties if repetition is detected.
- Dedicated OpenCV QR & Verification against main backend.
- Full CORS, Bearer Token Auth, Semaphore concurrency limit, Timeout protection.
"""

import os
import io
import time
import base64
import logging
import re
import unicodedata
from threading import Semaphore
from typing import Optional, Tuple, Dict, Any, List

from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
from PIL import Image
import requests
import cv2
import numpy as np

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("ai_vision_service")

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Load configurations with safe defaults
VISION_HOST = os.getenv("VISION_HOST", "0.0.0.0")
VISION_PORT = int(os.getenv("VISION_PORT", "5050"))
VISION_DEBUG = os.getenv("VISION_DEBUG", "false").lower() == "true"

LMSTUDIO_BASE_URL = os.getenv("LMSTUDIO_BASE_URL", "http://127.0.0.1:1234")
LMSTUDIO_MODEL = os.getenv("LMSTUDIO_MODEL", "qwen2.5-coder-1.5b-instruct")
USE_LMSTUDIO = os.getenv("USE_LMSTUDIO", "true").lower() == "true"

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434")
VISION_MODEL = os.getenv("VISION_MODEL", "moondream:latest")
REASONING_MODEL = os.getenv("REASONING_MODEL", "qwen2.5:1.5b")
VISION_API_TOKEN = os.getenv("VISION_API_TOKEN", "vexekhach_ai_vision_sec_2026_tok")

MAX_CONTENT_LENGTH_MB = int(os.getenv("MAX_CONTENT_LENGTH_MB", "10"))
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH_MB * 1024 * 1024
REQUEST_TIMEOUT_SECONDS = int(os.getenv("REQUEST_TIMEOUT_SECONDS", "80"))
MAX_CONCURRENT_REQUESTS = int(os.getenv("MAX_CONCURRENT_REQUESTS", "2"))

MAIN_BACKEND_URL = os.getenv("MAIN_BACKEND_URL", "https://vexekhach.aweb.io.vn/api/v1")

# Concurrency semaphore
concurrency_limiter = Semaphore(MAX_CONCURRENT_REQUESTS)

# Supported image formats
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "bmp"}

# OpenCV QR detector instance
qr_detector = cv2.QRCodeDetector()


def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def verify_auth_token() -> Tuple[bool, Optional[str]]:
    """Checks Bearer token in Authorization header."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header:
        return False, "Thiếu header Authorization"
    parts = auth_header.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return False, "Định dạng Authorization phải là: Bearer <token>"
    if parts[1] != VISION_API_TOKEN:
        return False, "Token xác thực không hợp lệ hoặc đã hết hạn"
    return True, None


def extract_image_bytes_from_request() -> Tuple[Optional[bytes], Optional[str], Optional[str]]:
    """Extracts image bytes from multipart/form-data or json (base64)."""
    if "image" in request.files:
        file = request.files["image"]
        if file.filename == "":
            return None, None, "Không có file nào được chọn"
        if not allowed_file(file.filename):
            return None, None, f"Định dạng file không hỗ trợ. Cho phép: {', '.join(ALLOWED_EXTENSIONS)}"
        img_bytes = file.read()
        return img_bytes, secure_filename(file.filename), None

    if request.is_json:
        data = request.get_json(silent=True) or {}
        b64_data = data.get("image_base64")
        if b64_data:
            if "," in b64_data:
                b64_data = b64_data.split(",", 1)[1]
            try:
                img_bytes = base64.b64decode(b64_data)
                return img_bytes, "upload_base64.png", None
            except Exception as e:
                return None, None, f"Base64 không hợp lệ: {str(e)}"

    return None, None, "Vui lòng tải ảnh lên bằng trường multipart 'image' hoặc json 'image_base64'"


def validate_image_pillow(img_bytes: bytes) -> Tuple[bool, Optional[Image.Image], Optional[str]]:
    """Validates that bytes represent a genuine image using Pillow."""
    try:
        image = Image.open(io.BytesIO(img_bytes))
        image.verify()
        image = Image.open(io.BytesIO(img_bytes))
        return True, image, None
    except Exception as e:
        return False, None, f"Tệp tải lên không phải là ảnh hợp lệ: {str(e)}"


def detect_qr_code(img_bytes: bytes) -> Optional[str]:
    """Decodes QR code from image bytes using OpenCV."""
    try:
        nparr = np.frombuffer(img_bytes, np.uint8)
        img_cv = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img_cv is None:
            return None
        decoded_text, points, _ = qr_detector.detectAndDecode(img_cv)
        if decoded_text:
            return decoded_text.strip()
        gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
        decoded_text, _, _ = qr_detector.detectAndDecode(gray)
        if decoded_text:
            return decoded_text.strip()
        return None
    except Exception as e:
        logger.warning(f"Lỗi khi quét QR code: {e}")
        return None


def verify_ticket_with_backend(ticket_code_or_url: str) -> Dict[str, Any]:
    """Verifies ticket authenticity with main bus backend."""
    verification = {
        "raw_code": ticket_code_or_url,
        "is_verified": False,
        "backend_checked": False,
        "message": "Mã QR được phát hiện nhưng chưa được kiểm tra với cơ sở dữ liệu chính."
    }
    booking_id = None
    if "booking" in ticket_code_or_url.lower() or "vx" in ticket_code_or_url.lower():
        parts = [p for p in ticket_code_or_url.replace("/", " ").replace("-", " ").split() if p.isdigit()]
        if parts:
            booking_id = parts[0]

    if booking_id:
        try:
            res = requests.get(f"{MAIN_BACKEND_URL}/bookings/{booking_id}", timeout=5)
            verification["backend_checked"] = True
            if res.status_code == 200:
                data = res.json()
                verification["is_verified"] = True
                verification["ticket_data"] = data.get("data", {})
                verification["message"] = f"Vé #{booking_id} hợp lệ trên hệ thống backend."
            elif res.status_code == 404:
                verification["is_verified"] = False
                verification["message"] = f"Không tìm thấy thông tin vé #{booking_id} trên hệ thống."
            else:
                verification["message"] = f"Backend phản hồi mã lỗi {res.status_code}."
        except Exception as e:
            verification["message"] = f"Không thể kết nối đến backend chính để kiểm tra vé: {str(e)}"

    return verification


def detect_phrase_repetition(text: str, max_phrase_words: int = 5, min_repeats: int = 4) -> bool:
    """
    Quality gate: Checks if words or phrases repeat unusually often.
    Prevents degenerate repetitions like 'Khu Cong Nghe Cong Nghe Cong Nghe...'
    """
    words = text.split()
    if len(words) < 8:
        return False
    for n in range(1, max_phrase_words + 1):
        for i in range(len(words) - n * min_repeats + 1):
            phrase = " ".join(words[i : i + n]).lower()
            repeated = True
            for k in range(1, min_repeats):
                next_phrase = " ".join(words[i + k * n : i + (k + 1) * n]).lower()
                if next_phrase != phrase:
                    repeated = False
                    break
            if repeated:
                logger.warning(f"Phát hiện lặp chuỗi bất thường: '{phrase}' lặp lại {min_repeats} lần liên tiếp.")
                return True
    return False


def call_ollama(model: str, prompt: str, image_bytes: Optional[bytes] = None, options: Optional[dict] = None) -> Tuple[bool, str]:
    """Generic helper to call Ollama generate API."""
    payload: Dict[str, Any] = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": options or {
            "temperature": 0.2,
            "repeat_penalty": 1.2,
            "top_p": 0.9,
            "num_predict": 450
        }
    }
    if image_bytes:
        payload["images"] = [base64.b64encode(image_bytes).decode("utf-8")]

    try:
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json=payload,
            timeout=REQUEST_TIMEOUT_SECONDS
        )
        if resp.status_code == 200:
            result = resp.json().get("response", "").strip()
            return True, result
        return False, f"Ollama lỗi HTTP {resp.status_code}: {resp.text}"
    except requests.exceptions.Timeout:
        return False, f"Hết thời gian chờ suy luận AI ({REQUEST_TIMEOUT_SECONDS}s)."
    except requests.exceptions.ConnectionError:
        return False, "Không thể kết nối đến Ollama. Vui lòng đảm bảo tiến trình 'ollama serve' đang chạy."
    except Exception as e:
        return False, f"Lỗi không xác định khi gọi Ollama: {str(e)}"


def call_lmstudio(prompt: str, model: Optional[str] = None, system_prompt: Optional[str] = None, temperature: float = 0.25, max_tokens: int = 400) -> Tuple[bool, str]:
    """Generic helper to call LM Studio OpenAI-compatible API."""
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": model or LMSTUDIO_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": False
    }

    try:
        resp = requests.post(
            f"{LMSTUDIO_BASE_URL}/v1/chat/completions",
            json=payload,
            timeout=REQUEST_TIMEOUT_SECONDS
        )
        if resp.status_code == 200:
            data = resp.json()
            choices = data.get("choices", [])
            if choices and "message" in choices[0]:
                content = choices[0]["message"].get("content", "").strip()
                return True, content
            return False, "LM Studio không trả về nội dung hợp lệ"
        return False, f"LM Studio lỗi HTTP {resp.status_code}: {resp.text}"
    except requests.exceptions.Timeout:
        return False, f"Hết thời gian chờ LM Studio ({REQUEST_TIMEOUT_SECONDS}s)."
    except requests.exceptions.ConnectionError:
        return False, "Không thể kết nối đến LM Studio. Đảm bảo LM Studio Model Server đang bật trên cổng 1234."
    except Exception as e:
        return False, f"Lỗi không xác định khi gọi LM Studio: {str(e)}"


def remove_accents(input_str: str) -> str:
    """Normalize Vietnamese accents for fuzzy keyword matching."""
    if not input_str:
        return ""
    nfkd_form = unicodedata.normalize('NFKD', input_str)
    res = "".join([c for c in nfkd_form if not unicodedata.combining(c)])
    return res.replace('đ', 'd').replace('Đ', 'd').lower()


VIETNAMESE_LANDMARKS_DB = [
    {
        "keywords": [
            "landmark 81", "landmark81", "vinpearl landmark 81", "vinhomes central park",
            "toa nha landmark 81", "toa nha landmark"
        ],
        "name": "Tòa nhà The Landmark 81 (Vinhomes Central Park)",
        "lat": 10.7950,
        "lng": 106.7218,
        "ward": "Phường 22",
        "district": "Quận Bình Thạnh",
        "city": "TP. Hồ Chí Minh",
        "street": "Số 720A Điện Biên Phủ / Đường Nguyễn Hữu Cảnh",
        "pickup_point": "Sảnh đón trả khách Landmark 81, Cổng chính công viên Central Park hoặc Cầu Sài Gòn / ngã tư Hàng Xanh (cách 500m) để đón các tuyến xe khách đi Vũng Tàu, Đồng Nai, Bình Thuận, Miền Trung, Miền Bắc.",
    },
    {
        "keywords": [
            "bitexco", "bitexco financial", "toa nha bitexco", "bitexco tower"
        ],
        "name": "Tòa nhà Bitexco Financial Tower",
        "lat": 10.7718,
        "lng": 106.7044,
        "ward": "Phường Bến Nghé",
        "district": "Quận 1",
        "city": "TP. Hồ Chí Minh",
        "street": "Số 2 Hải Triều / Đường Hồ Tùng Mậu",
        "pickup_point": "Khu vực sảnh đón taxi Bitexco hoặc trạm trung chuyển xe buýt Hàm Nghi (cách 200m).",
    },
    {
        "keywords": ["phan chu trinh", "thpt phan chu trinh", "truong thpt phan chu trinh", "truong phan chu trinh"],
        "name": "Trường THPT Phan Chu Trinh",
        "lat": 12.6000,
        "lng": 107.8200,
        "ward": "Khu vực trường học",
        "district": "Cơ sở giáo dục",
        "city": "Việt Nam",
        "street": "Cổng chính trường học",
        "pickup_point": "Trước cổng trường THPT Phan Chu Trinh hoặc trạm dừng xe buýt gần cổng trường nhất.",
    },
    {
        "keywords": ["keangnam", "keangnam 72", "landmark 72", "lotte center hanoi"],
        "name": "Tòa nhà Keangnam Landmark 72 Hà Nội",
        "lat": 21.0173,
        "lng": 105.7838,
        "ward": "Phường Mễ Trì",
        "district": "Quận Nam Từ Liêm",
        "city": "TP. Hà Nội",
        "street": "Đường Phạm Hùng",
        "pickup_point": "Sảnh đón xe Keangnam hoặc trạm dừng buýt đường Phạm Hùng hướng đi Bến xe Mỹ Đình.",
    },
    {
        "keywords": ["hutech", "truong dai hoc hutech", "dai hoc cong nghe hutech"],
        "name": "Trường Đại học Công nghệ TP.HCM (HUTECH)",
        "lat": 10.8018,
        "lng": 106.7135,
        "ward": "Phường 25",
        "district": "Quận Bình Thạnh",
        "city": "TP. Hồ Chí Minh",
        "street": "475A Điện Biên Phủ",
        "pickup_point": "Cổng chính HUTECH Điện Biên Phủ hoặc trạm dừng buýt dưới chân cầu vượt Hàng Xanh.",
    },
    {
        "keywords": ["khu cong nghe cao", "cong nghe cao tphcm", "shtp"],
        "name": "Khu Công Nghệ Cao TP.HCM (SHTP)",
        "lat": 10.8550,
        "lng": 106.7858,
        "ward": "Phường Tân Phú / Tăng Nhơn Phú B",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Xa lộ Hà Nội (Đường Võ Nguyên Giáp) - Đường Lê Văn Việt",
        "pickup_point": "Trạm xe buýt Khu Công Nghệ Cao trên Xa lộ Hà Nội hoặc Cổng chính Khu Công Nghệ Cao (đón xe đi Đồng Nai, Bình Thuận, Vũng Tàu, Tây Nguyên, Miền Trung).",
    },
    {
        "keywords": ["suoi tien", "kdl suoi tien"],
        "name": "Khu Du Lịch Văn Hóa Suối Tiên",
        "lat": 10.8659,
        "lng": 106.8028,
        "ward": "Phường Tân Phú",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Xa lộ Hà Nội (Quốc lộ 52)",
        "pickup_point": "Trạm dừng Suối Tiên / Cầu vượt bộ hành Suối Tiên (điểm đón xe khách liên tỉnh tấp nập nhất cửa ngõ phía Đông TP.HCM).",
    },
    {
        "keywords": ["mien dong moi", "ben xe mien dong moi"],
        "name": "Bến xe Miền Đông Mới",
        "lat": 10.8808,
        "lng": 106.8174,
        "ward": "Phường Long Bình",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Số 501 Hoàng Hữu Nam / Xa lộ Hà Nội",
        "pickup_point": "Khu vực sảnh đón trả khách Bến xe Miền Đông Mới hoặc trạm dừng xe buýt trước cổng bến xe.",
    },
    {
        "keywords": ["ben xe mien dong cu", "bx mien dong cu"],
        "name": "Bến xe Miền Đông (cũ)",
        "lat": 10.8143,
        "lng": 106.7118,
        "ward": "Phường 26",
        "district": "Quận Bình Thạnh",
        "city": "TP. Hồ Chí Minh",
        "street": "292 Đinh Bộ Lĩnh / Quốc lộ 13",
        "pickup_point": "Cổng số 1, 2, 3 Bến xe Miền Đông hoặc dọc đường Đinh Bộ Lĩnh / Quốc lộ 13.",
    },
    {
        "keywords": ["ben xe mien tay", "bx mien tay"],
        "name": "Bến xe Miền Tây",
        "lat": 10.7482,
        "lng": 106.6163,
        "ward": "Phường An Lạc",
        "district": "Quận Bình Tân",
        "city": "TP. Hồ Chí Minh",
        "street": "395 Kinh Dương Vương",
        "pickup_point": "Cổng ga đi Bến xe Miền Tây hoặc cây xăng đối diện bến xe.",
    },
    {
        "keywords": ["nga tu an suong", "bx an suong", "ben xe an suong"],
        "name": "Ngã tư An Sương / Bến xe An Sương",
        "lat": 10.8492,
        "lng": 106.6214,
        "ward": "Xã Bà Điểm, Huyện Hóc Môn & Phường Trung Mỹ Tây",
        "district": "Quận 12 & Huyện Hóc Môn",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 22 / Quốc lộ 1A / Trường Chinh",
        "pickup_point": "Nhà chờ Bến xe An Sương hoặc chân cầu vượt ngã tư An Sương hướng đi Tây Ninh / Miền Tây.",
    },
    {
        "keywords": ["nga tu hang xanh", "vong xoay hang xanh"],
        "name": "Ngã tư Hàng Xanh",
        "lat": 10.8016,
        "lng": 106.7114,
        "ward": "Phường 21 / Phường 25",
        "district": "Quận Bình Thạnh",
        "city": "TP. Hồ Chí Minh",
        "street": "Điện Biên Phủ giao Xô Viết Nghệ Tĩnh",
        "pickup_point": "Cây xăng Comeco Hàng Xanh hoặc trạm dừng buýt dưới chân cầu vượt Hàng Xanh.",
    },
    {
        "keywords": ["nga tu thu duc", "metro thu duc"],
        "name": "Ngã tư Thủ Đức / Trạm Metro Thủ Đức",
        "lat": 10.8538,
        "lng": 106.7716,
        "ward": "Phường Hiệp Phú & Phường Linh Trung",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Xa lộ Hà Nội giao Lê Văn Việt / Võ Văn Ngân",
        "pickup_point": "Chân cầu vượt Ngã tư Thủ Đức (hướng đi Đồng Nai) hoặc trước trường ĐH Sư Phạm Kỹ Thuật.",
    },
    {
        "keywords": ["cau vuot linh xuan", "nga tu linh xuan"],
        "name": "Cầu vượt Linh Xuân",
        "lat": 10.8711,
        "lng": 106.7644,
        "ward": "Phường Linh Xuân",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 1A giao Quốc lộ 1K",
        "pickup_point": "Dưới dạ cầu vượt Linh Xuân hoặc trạm dừng xe buýt hướng đi Suối Tiên / Dĩ An.",
    },
    {
        "keywords": ["nga tu binh phuoc", "cau vuot binh phuoc"],
        "name": "Ngã tư Bình Phước",
        "lat": 10.8504,
        "lng": 106.7213,
        "ward": "Phường Hiệp Bình Phước",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 1A giao Quốc lộ 13",
        "pickup_point": "Chân cầu vượt Bình Phước (cây xăng hoặc trạm buýt) hướng đi Bình Dương hoặc Miền Tây.",
    },
    {
        "keywords": ["cau vuot nga tu ga", "nga tu ga"],
        "name": "Cầu vượt Ngã tư Ga",
        "lat": 10.8508,
        "lng": 106.6806,
        "ward": "Phường Thạnh Lộc",
        "district": "Quận 12",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 1A giao Hà Huy Giáp",
        "pickup_point": "Dọc Quốc lộ 1A dưới chân cầu vượt Ngã tư Ga.",
    },
    {
        "keywords": ["san bay tan son nhat", "cang hang khong tan son nhat"],
        "name": "Sân bay Quốc tế Tân Sơn Nhất",
        "lat": 10.8185,
        "lng": 106.6588,
        "ward": "Phường 2",
        "district": "Quận Tân Bình",
        "city": "TP. Hồ Chí Minh",
        "street": "Đường Trường Sơn",
        "pickup_point": "Khu vực làn đón xe ô tô ga Quốc nội/Quốc tế hoặc bãi đỗ xe ga ngầm.",
    },
    {
        "keywords": ["cho ben thanh", "quang truong quach thi trang"],
        "name": "Chợ Bến Thành / Quảng trường Quách Thị Trang",
        "lat": 10.7725,
        "lng": 106.6980,
        "ward": "Phường Bến Thành",
        "district": "Quận 1",
        "city": "TP. Hồ Chí Minh",
        "street": "Lê Lợi - Phan Chu Trinh - Hàm Nghi",
        "pickup_point": "Trạm trung chuyển xe buýt Bến Thành (đường Hàm Nghi) hoặc trước chợ Bến Thành.",
    },
    {
        "keywords": ["ben xe vung tau", "bx vung tau"],
        "name": "Bến xe Vũng Tàu",
        "lat": 10.3541,
        "lng": 107.0864,
        "ward": "Phường Thắng Tam",
        "district": "Thành phố Vũng Tàu",
        "city": "Tỉnh Bà Rịa - Vũng Tàu",
        "street": "Số 192 Nam Kỳ Khởi Nghĩa",
        "pickup_point": "Khu vực đón xe khách Bến xe Vũng Tàu.",
    },
    {
        "keywords": ["ben xe da lat", "bx lien tinh da lat"],
        "name": "Bến xe Liên tỉnh Đà Lạt",
        "lat": 11.9275,
        "lng": 108.4447,
        "ward": "Phường 3",
        "district": "Thành phố Đà Lạt",
        "city": "Tỉnh Lâm Đồng",
        "street": "Số 1 Tô Hiến Thành",
        "pickup_point": "Sảnh đón khách đầu đèo Prenn Bến xe Liên tỉnh Đà Lạt.",
    },
    {
        "keywords": ["ben xe phia nam nha trang", "bx nha trang"],
        "name": "Bến xe Phía Nam Nha Trang",
        "lat": 12.2478,
        "lng": 109.1633,
        "ward": "Xã Vĩnh Trung",
        "district": "Thành phố Nha Trang",
        "city": "Tỉnh Khánh Hòa",
        "street": "Số 58 đường 23/10",
        "pickup_point": "Khu vực sân chờ đón khách Bến xe Phía Nam Nha Trang.",
    }
]


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance between two GPS coordinates in kilometers."""
    try:
        import math
        r = 6371.0
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)
        a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2)
        c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
        return r * c
    except Exception:
        return 9999.0


def resolve_location_from_gps(lat: float, lng: float) -> Dict[str, str]:
    """
    Deterministically resolves administrative geography (ward, district, city)
    and major transit corridors from device GPS coordinates.
    """
    # 1. TP. Hồ Chí Minh - TP. Thủ Đức (Corridor Xa lộ Hà Nội / Khu Công nghệ cao / Lê Văn Việt)
    if 10.835 <= lat <= 10.870 and 106.765 <= lng <= 106.820:
        return {
            "area_name": "Khu vực TP. Thủ Đức (Trục Xa lộ Hà Nội / Khu Công nghệ cao - Lê Văn Việt)",
            "district": "Thành phố Thủ Đức",
            "ward": "Phường Tăng Nhơn Phú B / Hiệp Phú",
            "city": "TP. Hồ Chí Minh",
            "street": "Trục Xa lộ Hà Nội (Đường Võ Nguyên Giáp) - Đường Lê Văn Việt",
            "pickup_point": "Trạm xe buýt Khu Công nghệ cao trên Xa lộ Hà Nội hoặc cây xăng gần ngã tư Thủ Đức (điểm đón xe liên tỉnh Tây Nguyên, Miền Trung, Vũng Tàu)."
        }

    # 2. TP. Hồ Chí Minh - TP. Thủ Đức (Khu vực Suối Tiên / Bến xe Miền Đông Mới)
    if 10.865 <= lat <= 10.900 and 106.800 <= lng <= 106.845:
        return {
            "area_name": "Khu vực Bến xe Miền Đông Mới / Suối Tiên (TP. Thủ Đức)",
            "district": "Thành phố Thủ Đức",
            "ward": "Phường Tân Phú / Long Bình",
            "city": "TP. Hồ Chí Minh",
            "street": "Xa lộ Hà Nội (Quốc lộ 1A) - Đường Hoàng Hữu Nam",
            "pickup_point": "Cầu vượt bộ hành Suối Tiên hoặc sảnh đón trả Bến xe Miền Đông Mới."
        }

    # 3. TP. Hồ Chí Minh - TP. Thủ Đức (Cầu vượt Linh Xuân / ĐHQG)
    if 10.850 <= lat <= 10.885 and 106.745 <= lng <= 106.780:
        return {
            "area_name": "Khu vực Cầu vượt Linh Xuân / ĐH Quốc Gia (TP. Thủ Đức)",
            "district": "Thành phố Thủ Đức",
            "ward": "Phường Linh Trung / Linh Xuân",
            "city": "TP. Hồ Chí Minh",
            "street": "Quốc lộ 1A giao Quốc lộ 1K",
            "pickup_point": "Chân cầu vượt Linh Xuân hoặc trạm xe buýt Đại học Quốc Gia."
        }

    # 4. TP. Hồ Chí Minh - TP. Thủ Đức (Ngã tư Bình Phước - QL13)
    if 10.835 <= lat <= 10.865 and 106.705 <= lng <= 106.740:
        return {
            "area_name": "Khu vực Ngã tư Bình Phước (TP. Thủ Đức)",
            "district": "Thành phố Thủ Đức",
            "ward": "Phường Hiệp Bình Phước",
            "city": "TP. Hồ Chí Minh",
            "street": "Quốc lộ 13 giao Quốc lộ 1A",
            "pickup_point": "Chân cầu vượt Bình Phước (cây xăng hoặc trạm buýt) hướng đi Bình Dương hoặc Miền Tây."
        }

    # 5. TP. Hồ Chí Minh - Quận Bình Thạnh (Hàng Xanh / Cầu Sài Gòn)
    if 10.790 <= lat <= 10.810 and 106.705 <= lng <= 106.735:
        return {
            "area_name": "Khu vực Hàng Xanh / Cầu Sài Gòn (Quận Bình Thạnh)",
            "district": "Quận Bình Thạnh",
            "ward": "Phường 22 / Phường 25",
            "city": "TP. Hồ Chí Minh",
            "street": "Trục Điện Biên Phủ / Xô Viết Nghệ Tĩnh",
            "pickup_point": "Cây xăng Comeco Hàng Xanh hoặc chân cầu vượt Hàng Xanh."
        }

    # 6. TP. Hồ Chí Minh - Quận Bình Thạnh (Bến xe Miền Đông cũ)
    if 10.810 <= lat <= 10.830 and 106.700 <= lng <= 106.725:
        return {
            "area_name": "Khu vực Bến xe Miền Đông cũ (Quận Bình Thạnh)",
            "district": "Quận Bình Thạnh",
            "ward": "Phường 26",
            "city": "TP. Hồ Chí Minh",
            "street": "Đường Đinh Bộ Lĩnh / Quốc lộ 13",
            "pickup_point": "Cổng Bến xe Miền Đông cũ hoặc cây xăng Quốc lộ 13."
        }

    # 7. TP. Hồ Chí Minh - Quận 1 (Trung tâm Bến Thành / Bitexco / Hàm Nghi)
    if 10.760 <= lat <= 10.785 and 106.690 <= lng <= 106.715:
        return {
            "area_name": "Khu vực Trung tâm Quận 1",
            "district": "Quận 1",
            "ward": "Phường Bến Thành / Bến Nghé",
            "city": "TP. Hồ Chí Minh",
            "street": "Đường Hàm Nghi / Lê Lợi / Nguyễn Thái Học",
            "pickup_point": "Trạm trung chuyển xe buýt Hàm Nghi hoặc văn phòng nhà xe trung tâm."
        }

    # 8. TP. Hồ Chí Minh - Quận 12 & Hóc Môn (Ngã tư An Sương / QL22)
    if 10.830 <= lat <= 10.865 and 106.600 <= lng <= 106.640:
        return {
            "area_name": "Khu vực Ngã tư An Sương / Bến xe An Sương",
            "district": "Quận 12 & Huyện Hóc Môn",
            "ward": "Phường Trung Mỹ Tây",
            "city": "TP. Hồ Chí Minh",
            "street": "Quốc lộ 22 / Quốc lộ 1A / Trường Chinh",
            "pickup_point": "Nhà chờ Bến xe An Sương hoặc chân cầu vượt ngã tư An Sương."
        }

    # 9. TP. Hồ Chí Minh - Quận Bình Tân (Bến xe Miền Tây / An Lạc)
    if 10.730 <= lat <= 10.765 and 106.595 <= lng <= 106.630:
        return {
            "area_name": "Khu vực Bến xe Miền Tây (Quận Bình Tân)",
            "district": "Quận Bình Tân",
            "ward": "Phường An Lạc",
            "city": "TP. Hồ Chí Minh",
            "street": "Đường Kinh Dương Vương / Quốc lộ 1A",
            "pickup_point": "Cổng ga Bến xe Miền Tây hoặc cây xăng đối diện bến xe."
        }

    # 10. Tỉnh Bình Dương - TP. Dĩ An (QL1K / ĐT743)
    if 10.880 <= lat <= 10.940 and 106.740 <= lng <= 106.800:
        return {
            "area_name": "Khu vực TP. Dĩ An (Bình Dương)",
            "district": "Thành phố Dĩ An",
            "ward": "Phường Đông Hòa / Dĩ An",
            "city": "Tỉnh Bình Dương",
            "street": "Quốc lộ 1K / Đường ĐT743",
            "pickup_point": "Cầu vượt Sóng Thần hoặc ngã tư 550."
        }

    # 11. Tỉnh Bình Dương - TP. Thuận An / Thủ Dầu Một (Trục QL13 Đại lộ Bình Dương)
    if 10.880 <= lat <= 11.150 and 106.620 <= lng <= 106.730:
        return {
            "area_name": "Khu vực Đại lộ Bình Dương - Quốc lộ 13",
            "district": "Thành phố Thuận An / Thủ Dầu Một",
            "ward": "Khu vực trung tâm Bình Dương",
            "city": "Tỉnh Bình Dương",
            "street": "Đại lộ Bình Dương (Quốc lộ 13)",
            "pickup_point": "Trạm thu phí Lái Thiêu / Aeon Mall Bình Dương hoặc ngã tư Gò Đậu."
        }

    # 12. Tỉnh Bình Phước - Chơn Thành / Đồng Xoài (Trục QL14 đi Tây Nguyên)
    if 11.350 <= lat <= 11.700 and 106.650 <= lng <= 107.000:
        return {
            "area_name": "Khu vực TP. Đồng Xoài / Chơn Thành (Trục QL14)",
            "district": "TP. Đồng Xoài / Thị xã Chơn Thành",
            "ward": "Khu vực QL14",
            "city": "Tỉnh Bình Phước",
            "street": "Quốc lộ 14 (Đường Hồ Chí Minh)",
            "pickup_point": "Ngã tư Đồng Xoài hoặc dọc trục Quốc lộ 14 hướng đi Đắk Nông."
        }

    # 13. Tỉnh Đắk Nông - Huyện Cư Jút / Ea T'ling (Điểm cuối tuyến xe)
    if 12.550 <= lat <= 12.750 and 107.800 <= lng <= 107.980:
        return {
            "area_name": "Khu vực Huyện Cư Jút (Đắk Nông)",
            "district": "Huyện Cư Jút",
            "ward": "Thị trấn Ea T'ling",
            "city": "Tỉnh Đắk Nông",
            "street": "Quốc lộ 14 (Đường Hồ Chí Minh) - Trục Cư Jút",
            "pickup_point": "Bến xe Huyện Cư Jút hoặc dọc Quốc lộ 14 đoạn qua thị trấn Ea T'ling."
        }

    # 14. Tỉnh Đắk Nông - TP. Gia Nghĩa / Đắk Mil (Trục QL14)
    if 11.900 <= lat <= 12.550 and 107.450 <= lng <= 107.800:
        return {
            "area_name": "Khu vực Tỉnh Đắk Nông (Trục QL14)",
            "district": "TP. Gia Nghĩa / Huyện Đắk Mil",
            "ward": "Khu vực QL14",
            "city": "Tỉnh Đắk Nông",
            "street": "Quốc lộ 14",
            "pickup_point": "Bến xe Gia Nghĩa hoặc ngã ba Đắk Mil dọc Quốc lộ 14."
        }

    # 15. Tỉnh Lâm Đồng - TP. Đà Lạt (QL20 / Đèo Prenn)
    if 11.900 <= lat <= 12.020 and 108.400 <= lng <= 108.520:
        return {
            "area_name": "Khu vực TP. Đà Lạt",
            "district": "Thành phố Đà Lạt",
            "ward": "Phường 3 / Phường 1",
            "city": "Tỉnh Lâm Đồng",
            "street": "Đường 3 Tháng 4 / Tô Hiến Thành",
            "pickup_point": "Bến xe Liên tỉnh Đà Lạt (đầu đèo Prenn) hoặc vòng xoay Kim Cúc."
        }

    # Fallback theo phạm vi Tỉnh/Thành tổng quát
    if 10.65 <= lat <= 10.95 and 106.50 <= lng <= 106.90:
        return {
            "area_name": f"Vị trí hành khách tại TP. Hồ Chí Minh ({lat:.5f}, {lng:.5f})",
            "district": "TP. Thủ Đức / Quận nội thành",
            "ward": "Khu vực trung tâm",
            "city": "TP. Hồ Chí Minh",
            "street": "Tuyến đường tại tọa độ GPS của bạn",
            "pickup_point": f"Vị trí GPS ({lat:.5f}, {lng:.5f}) trên trục đường xe khách đi qua."
        }

    return {
        "area_name": f"Vị trí GPS ({lat:.5f}, {lng:.5f})",
        "district": "Khu vực hành khách",
        "ward": "Vị trí thiết bị",
        "city": "Việt Nam",
        "street": "Trục đường tại tọa độ hiện tại",
        "pickup_point": f"Tọa độ GPS: {lat:.5f}, {lng:.5f}"
    }


def lookup_landmark_info(
    text: str,
    user_lat: Optional[float] = None,
    user_lng: Optional[float] = None
) -> Optional[Dict[str, Any]]:
    """
    Finds geographic and pickup info for known Vietnamese transit landmarks.
    Enforces GPS consistency: if user GPS is available, landmark is only accepted
    if distance is within 2.5km.
    """
    clean = remove_accents(text).lower()
    for item in VIETNAMESE_LANDMARKS_DB:
        for kw in item["keywords"]:
            if remove_accents(kw).lower() in clean:
                # If GPS is provided, verify landmark is actually near the user
                if user_lat is not None and user_lng is not None and "lat" in item and "lng" in item:
                    dist = haversine_km(user_lat, user_lng, item["lat"], item["lng"])
                    if dist > 2.5:
                        logger.info(f"Bỏ qua landmark '{item['name']}' do cách GPS ({user_lat}, {user_lng}) tới {dist:.2f}km > 2.5km.")
                        continue
                return item
    return None


def is_gps_in_route_corridor(clean_route: str, lat: float, lng: float) -> Tuple[bool, str]:
    """
    Evaluates whether real device GPS coordinates fall within the realistic travel corridor
    of the selected route.
    """
    # 1. TP.HCM - Cư Jút / Đắk Nông / Đắk Lắk (Chạy theo trục QL13 -> QL14 Tây Nguyên)
    if any(k in clean_route for k in ["cu jut", "dak nong", "gia nghia", "buon ma thuot", "dak lak"]):
        # Phân đoạn 1: Trục QL13 (BX Miền Đông cũ -> Cầu Bình Triệu -> Ngã tư Bình Phước -> Lái Thiêu -> Thủ Dầu Một -> Bến Cát -> Bàu Bàng)
        in_ql13 = (10.80 <= lat <= 11.40) and (106.60 <= lng <= 106.735)
        # Phân đoạn 2: Trục QL14 qua Bình Phước (Chơn Thành -> Đồng Xoài -> Bù Đăng)
        in_ql14_bp = (11.40 <= lat <= 11.95) and (106.65 <= lng <= 107.35)
        # Phân đoạn 3: Trục QL14 qua Đắk Nông (Kiến Đức -> Gia Nghĩa -> Đắk Song -> Đắk Mil -> Cư Jút)
        in_ql14_dn = (11.85 <= lat <= 12.80) and (107.35 <= lng <= 108.00)
        # Phân đoạn 4: Buôn Ma Thuột (Đắk Lắk)
        in_bmt = (12.55 <= lat <= 12.85) and (108.00 <= lng <= 108.20)

        if in_ql13 or in_ql14_bp or in_ql14_dn or in_bmt:
            return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm đúng trên hành lang di chuyển Quốc lộ 13 / Quốc lộ 14."
        else:
            if 10.83 <= lat <= 10.90 and 106.76 <= lng <= 106.84:
                return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) đang ở trục Xa lộ Hà Nội / Khu Công nghệ cao (TP. Thủ Đức). Tuyến xe {clean_route} chạy theo trục Quốc lộ 13 -> Quốc lộ 14 (qua Bình Triệu / Bình Dương / Đồng Xoài / Đắk Nông), hoàn toàn không đi qua Xa lộ Hà Nội."
            return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm ngoài hành lang di chuyển Quốc lộ 13 - Quốc lộ 14 của tuyến xe."

    # 2. TP.HCM - Đà Lạt / Lâm Đồng (Trục Xa lộ Hà Nội -> QL1A -> Ngã ba Dầu Giây -> QL20)
    if any(k in clean_route for k in ["da lat", "lam dong", "bao loc", "madagui", "di linh"]):
        in_xlhn = (10.78 <= lat <= 10.90) and (106.70 <= lng <= 106.85)
        in_dn = (10.88 <= lat <= 11.15) and (106.85 <= lng <= 107.25)
        in_ql20 = (11.05 <= lat <= 12.10) and (107.15 <= lng <= 108.55)
        if in_xlhn or in_dn or in_ql20:
            return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm trên trục di chuyển Xa lộ Hà Nội - QL1A - QL20 tuyến đi Đà Lạt."
        return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm ngoài hành lang di chuyển tuyến TP.HCM - Đà Lạt."

    # 3. TP.HCM - Vũng Tàu / Bà Rịa (Xa lộ Hà Nội / Cao tốc Long Thành -> QL51)
    if any(k in clean_route for k in ["vung tau", "ba ria"]):
        in_hcm_east = (10.75 <= lat <= 10.88) and (106.70 <= lng <= 106.88)
        in_ql51 = (10.30 <= lat <= 10.80) and (106.88 <= lng <= 107.25)
        if in_hcm_east or in_ql51:
            return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm trên hành lang di chuyển tuyến TP.HCM - Vũng Tàu (QL51 / Cao tốc)."
        return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm ngoài hành lang di chuyển tuyến Vũng Tàu."

    # 4. TP.HCM - Phan Thiết / Nha Trang / Miền Trung (Xa lộ Hà Nội -> QL1A ven biển / Cao tốc Dầu Giây - Phan Thiết)
    if any(k in clean_route for k in ["nha trang", "khanh hoa", "phan thiet", "binh thuan", "phan rang", "quy nhon", "da nang"]):
        in_hcm_east = (10.78 <= lat <= 10.90) and (106.70 <= lng <= 106.85)
        in_central_coast = (10.85 <= lat <= 16.50) and (106.85 <= lng <= 109.50)
        if in_hcm_east or in_central_coast:
            return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm trong hành lang trục Bắc - Nam / Duyên hải miền Trung."
        return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm ngoài hành lang di chuyển tuyến miền Trung."

    # 5. TP.HCM - Miền Tây (Kinh Dương Vương / BX Miền Tây -> Cao tốc Trung Lương / QL1A Miền Tây)
    if any(k in clean_route for k in ["can tho", "ca mau", "ben tre", "tien giang", "my tho", "kien giang", "an giang", "soc trang", "bac lieu"]):
        in_west = (8.5 <= lat <= 10.78) and (104.5 <= lng <= 106.65)
        if in_west:
            return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm trong hành lang cao tốc Trung Lương / Quốc lộ 1A về Miền Tây."
        return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm ngoài hành lang di chuyển về Miền Tây."

    # 6. TP.HCM - Tây Ninh (Quốc lộ 22 / Xuyên Á qua An Sương - Củ Chi)
    if any(k in clean_route for k in ["tay ninh", "moc bai", "trang bang", "cu chi"]):
        in_ql22 = (10.80 <= lat <= 11.60) and (105.90 <= lng <= 106.65)
        if in_ql22:
            return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm trong hành lang Quốc lộ 22 tuyến TP.HCM - Tây Ninh."
        return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) nằm ngoài hành lang tuyến Tây Ninh."

    # Default fallback: check if within Vietnam territory (8.0 to 23.5 lat, 102.0 to 110.0 lng)
    if 8.0 <= lat <= 23.5 and 102.0 <= lng <= 110.0:
        return True, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) thuộc vùng hoạt động trên lãnh thổ Việt Nam."
    return False, f"Tọa độ GPS ({lat:.5f}, {lng:.5f}) không hợp lệ."


def check_landmark_on_route(
    landmark_item: Optional[Dict[str, Any]],
    raw_facts: str,
    route_name: Optional[str],
    start_point: Optional[str] = "",
    end_point: Optional[str] = "",
    user_lat: Optional[float] = None,
    user_lng: Optional[float] = None,
    resolved_geo: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Checks if a detected landmark and device GPS coordinates match the travel corridor of a given bus route.
    Returns structured analysis with recommendation.
    """
    effective_name = landmark_item["name"] if landmark_item else (resolved_geo["area_name"] if resolved_geo else "Vị trí GPS thiết bị")
    effective_pickup = landmark_item.get("pickup_point") if landmark_item else (resolved_geo.get("pickup_point") if resolved_geo else f"Tọa độ GPS: {user_lat:.5f}, {user_lng:.5f}" if user_lat and user_lng else "Trục đường đón xe")
    effective_street = landmark_item.get("street", "") if landmark_item else (resolved_geo.get("street", "") if resolved_geo else "")

    if not route_name:
        return {
            "has_route": False,
            "is_on_route": None,
            "route_name": None,
            "status_message": "Chưa chọn chuyến xe để đối soát lộ trình.",
            "recommendation": "Vui lòng chọn chuyến xe của bạn để AI kiểm tra xe có đi ngang qua vị trí này không.",
            "landmark_name": effective_name,
            "pickup_point": effective_pickup,
            "latitude": user_lat,
            "longitude": user_lng
        }

    clean_route = remove_accents(f"{route_name} {start_point} {end_point}").lower()

    # Step A: Evaluate device GPS coordinates if provided (PRIMARY GROUND TRUTH)
    gps_matched = None
    gps_reason = ""
    if user_lat is not None and user_lng is not None:
        gps_matched, gps_reason = is_gps_in_route_corridor(clean_route, user_lat, user_lng)

    # Step B: If no landmark matched, rely directly on GPS resolved geography
    if not landmark_item:
        clean_facts = remove_accents(raw_facts).lower()
        cities = ["ho chi minh", "sai gon", "da lat", "dak nong", "cu jut", "vung tau", "nha trang", "can tho", "tay ninh", "ha noi", "da nang"]
        matched_cities = [c for c in cities if c in clean_facts and c in clean_route]

        is_on_route = (gps_matched is True) if gps_matched is not None else bool(matched_cities)
        if is_on_route:
            status_desc = gps_reason or f"Điểm đón này nằm trong khu vực hành lang tuyến {route_name}."
            return {
                "has_route": True,
                "is_on_route": True,
                "route_name": route_name,
                "status_message": f"Điểm đón tại '{effective_name}' NẰM TRÊN LỘ TRÌNH tuyến xe {route_name}! (GPS xác thực: {user_lat:.5f}, {user_lng:.5f})" if user_lat and user_lng else status_desc,
                "recommendation": f"Xe khách tuyến {route_name} sẽ đi ngang qua trục đường {effective_street}. Điểm đón thuận tiện nhất: {effective_pickup}. Bác tài có thể đón bạn theo tọa độ GPS này.",
                "landmark_name": effective_name,
                "pickup_point": effective_pickup,
                "latitude": user_lat,
                "longitude": user_lng
            }
        return {
            "has_route": True,
            "is_on_route": False,
            "route_name": route_name,
            "status_message": gps_reason or f"Vị trí điểm đón tại '{effective_name}' KHÔNG NẰM TRÊN LỘ TRÌNH tuyến xe {route_name}.",
            "recommendation": f"Vị trí này không nằm trên hành lang xe chạy. Vui lòng di chuyển đến điểm đón chính hoặc bến xe xuất bến: {start_point or 'Bến xe xuất bến'}.",
            "landmark_name": effective_name,
            "pickup_point": None,
            "latitude": user_lat,
            "longitude": user_lng
        }

    clean_lm_name = remove_accents(landmark_item.get("name", "")).lower()
    clean_lm_street = remove_accents(landmark_item.get("street", "")).lower()
    clean_lm_district = remove_accents(landmark_item.get("district", "")).lower()
    clean_lm_city = remove_accents(landmark_item.get("city", "")).lower()
    lm_full_text = f"{clean_lm_name} {clean_lm_street} {clean_lm_district}"

    # 1. Highland routes (QL13 -> QL14 corridor only: Bến xe Miền Đông cũ, Bình Triệu, Ngã tư Bình Phước, Bình Dương, Chơn Thành, Đồng Xoài, Đắk Nông, Cư Jút)
    highland_routes = ["cu jut", "dak nong", "gia nghia", "buon ma thuot", "dak lak", "dak mil"]
    is_highland = any(r in clean_route for r in highland_routes)
    highland_corridors = ["quoc lo 13", "ql13", "binh trieu", "nga tu binh phuoc", "lai thieu", "thuan an", "thu dau mot", "ben cat", "bau bang", "chon thanh", "dong xoai", "bu dang", "dak r'lap", "gia nghia", "dak mil", "cu jut", "bx mien dong cu", "dinh bo linh"]

    # 2. Eastern / Central routes (Xa lộ Hà Nội, QL1A, QL20, QL51)
    east_routes = ["da lat", "lam dong", "vung tau", "ba ria", "nha trang", "khanh hoa", "phan thiet", "binh thuan", "quy nhon", "da nang"]
    is_east_route = any(r in clean_route for r in east_routes)
    east_hcm_corridors = [
        "dien bien phu", "hang xanh", "landmark 81", "nguyen huu canh",
        "suoi tien", "nga tu thu duc", "khu cong nghe cao", "thu duc",
        "xa lo ha noi", "linh xuan", "dong nai", "bien hoa", "dau giay", "madagui",
        "bao loc", "bx mien dong moi"
    ]

    # 3. Western / Mekong Delta routes
    west_routes = ["can tho", "ca mau", "ben tre", "tien giang", "my tho", "kien giang", "rach gia", "an giang", "chau doc", "long an", "soc trang", "bac lieu", "dong thap"]
    is_west_route = any(r in clean_route for r in west_routes)
    west_hcm_corridors = ["bx mien tay", "ben xe mien tay", "kinh duong vuong", "an lac", "binh tan", "binh chanh", "ben luc", "tan an", "trung luong"]

    # 4. Tay Ninh routes
    is_tayninh_route = "tay ninh" in clean_route or "moc bai" in clean_route
    tayninh_corridors = ["an suong", "quoc lo 22", "hoc mon", "cu chi", "trang bang", "tay ninh"]

    # Landmark name matching logic
    landmark_matched = False
    if is_highland and any(c in lm_full_text for c in highland_corridors):
        landmark_matched = True
    elif is_east_route and any(c in lm_full_text for c in east_hcm_corridors):
        landmark_matched = True
    elif is_west_route and any(c in lm_full_text for c in west_hcm_corridors):
        landmark_matched = True
    elif is_tayninh_route and any(c in lm_full_text for c in tayninh_corridors):
        landmark_matched = True
    elif any(loc in clean_route for loc in [clean_lm_city, clean_lm_district]) and len(clean_lm_city) > 3:
        landmark_matched = True

    # Combine GPS & Landmark: GPS takes highest authority
    final_is_on_route = (gps_matched is True) if gps_matched is not None else (landmark_matched if gps_matched is None else False)

    if final_is_on_route:
        gps_addon = f" (GPS xác thực: {user_lat:.5f}, {user_lng:.5f})" if user_lat and user_lng else ""
        return {
            "has_route": True,
            "is_on_route": True,
            "route_name": route_name,
            "status_message": f"Điểm đón '{landmark_item['name']}' NẰM TRÊN LỘ TRÌNH tuyến xe {route_name}!{gps_addon}",
            "recommendation": f"Xe sẽ đi ngang qua trục đường {landmark_item.get('street', '')}. Điểm đón thuận tiện nhất: {landmark_item.get('pickup_point', 'Cổng sảnh chính')}.",
            "landmark_name": landmark_item["name"],
            "pickup_point": landmark_item.get("pickup_point"),
            "latitude": user_lat,
            "longitude": user_lng
        }
    else:
        reason_text = gps_reason if gps_matched is False else f"Điểm đón '{landmark_item['name']}' KHÔNG NẰM TRONG LỘ TRÌNH tuyến xe {route_name}."
        return {
            "has_route": True,
            "is_on_route": False,
            "route_name": route_name,
            "status_message": reason_text,
            "recommendation": f"Vị trí này ngược hướng hoặc không nằm trên hành trình xe chạy. Vui lòng di chuyển đến điểm đón chính: {start_point or 'Bến xe xuất bến'}.",
            "landmark_name": landmark_item["name"],
            "pickup_point": None,
            "latitude": user_lat,
            "longitude": user_lng
        }


def run_hybrid_vision_pipeline(
    image_bytes: bytes,
    task_type: str,
    user_question: Optional[str] = None,
    route_name: Optional[str] = None,
    start_point: Optional[str] = None,
    end_point: Optional[str] = None,
    user_lat: Optional[float] = None,
    user_lng: Optional[float] = None
) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """
    Two-Stage Hybrid Vision Pipeline:
    1. Vision Model (Moondream) extracts visual facts and visible text in English.
    2. Reasoning Engine (Qwen 2.5) structures and produces rich, fluent Vietnamese responses.
    3. Quality Gate verifies output is free from degenerate loops.
    """
    # Stage 1: Moondream prompt in English (Vision-native language)
    if task_type == "ocr":
        v_prompt = (
            "Read and transcribe all visible text, numbers, license plates, signs, and words in this image. "
            "Write the exact words and numbers seen. Do not extrapolate."
        )
    elif task_type == "ticket":
        v_prompt = (
            "Examine this ticket or receipt carefully. "
            "Transcribe all visible text, booking codes, route, departure times, passenger name, seat number, and prices. "
            "Describe the visual layout and state whether any part is unreadable."
        )
    elif task_type == "pickup_location":
        v_prompt = (
            "Examine this image carefully to identify the exact location, famous building, school, or landmark in Vietnam. "
            "1. If this is a famous building, skyscraper, or landmark (such as Landmark 81, Bitexco, Keangnam, Ben Thanh Market, Dragon Bridge, etc.), identify and state its exact name. "
            "2. Transcribe all readable text on signs, billboards, gate plaques, street banners, school names, and address plates. "
            "3. Describe the distinctive landmarks, building structure, road signs, and geographic surroundings."
        )
    else:
        v_prompt = (
            "Describe this image thoroughly: all visible objects, vehicles, people, background, "
            "landmarks, and any text written on signs, vehicles, or tickets."
        )

    # Optimize image resolution (max 800px) to boost inference speed by 3x
    optimized_bytes = image_bytes
    try:
        pil_img = Image.open(io.BytesIO(image_bytes))
        if pil_img.mode in ("RGBA", "P"):
            pil_img = pil_img.convert("RGB")
        if max(pil_img.size) > 800:
            pil_img.thumbnail((800, 800), Image.Resampling.LANCZOS)
            out_buf = io.BytesIO()
            pil_img.save(out_buf, format="JPEG", quality=85)
            optimized_bytes = out_buf.getvalue()
    except Exception as e:
        logger.warning(f"Không thể tối ưu kích thước ảnh: {e}")

    # Step 1: Execute Vision Inference (fast & focused)
    ok_v, visual_facts = call_ollama(
        model=VISION_MODEL,
        prompt=v_prompt,
        image_bytes=optimized_bytes,
        options={
            "temperature": 0.1,
            "repeat_penalty": 1.25,
            "top_p": 0.85,
            "num_predict": 180
        }
    )
    if not ok_v:
        return False, visual_facts, None

    # Stage 2: Reasoning & Vietnamese Synthesis via Qwen2.5
    user_q_text = f"Câu hỏi của khách hàng: \"{user_question}\"" if user_question else ""

    # Look up landmark in known Vietnamese transit database (with GPS distance validation)
    resolved_geo = None
    if user_lat is not None and user_lng is not None:
        resolved_geo = resolve_location_from_gps(user_lat, user_lng)

    geo_match = lookup_landmark_info(
        visual_facts + " " + (user_question or ""),
        user_lat=user_lat,
        user_lng=user_lng
    )
    route_analysis = None
    if task_type == "pickup_location":
        route_analysis = check_landmark_on_route(
            geo_match,
            visual_facts,
            route_name,
            start_point,
            end_point,
            user_lat=user_lat,
            user_lng=user_lng,
            resolved_geo=resolved_geo
        )
    if geo_match:
        geo_context = f"""
THÔNG TIN TRA CỨU ĐỊA DANH CHÍNH XÁC:
- Địa danh xác định: {geo_match['name']}
- Thuộc Phường / Xã: {geo_match['ward']}
- Thuộc Quận / Huyện / TP: {geo_match['district']}
- Thuộc Tỉnh / Thành phố: {geo_match['city']}
- Tuyến đường tiếp giáp: {geo_match['street']}
- Điểm đón xe khách thuận tiện: {geo_match['pickup_point']}

QUY TẮC BẮT BUỘC: Bạn PHẢI điền chính xác tên địa điểm là {geo_match['name']}, thuộc {geo_match['district']}, {geo_match['city']}. TUYỆT ĐỐI không thay đổi tên địa danh hay tự bịa ra tỉnh thành khác.
"""
    elif resolved_geo:
        geo_context = f"""
THÔNG TIN VỊ TRÍ XÁC THỰC THEO TỌA ĐỘ GPS THIẾT BỊ:
- Tọa độ GPS hành khách: {user_lat:.6f}, {user_lng:.6f}
- Khu vực xác định: {resolved_geo['area_name']}
- Thuộc Quận / Huyện / TP: {resolved_geo['district']}
- Thuộc Tỉnh / Thành phố: {resolved_geo['city']}
- Tuyến đường / Trục giao thông chính: {resolved_geo['street']}
- Điểm đón xe khách thuận tiện: {resolved_geo['pickup_point']}

QUY TẮC BẮT BUỘC: Bạn PHẢI trình bày vị trí đón của hành khách theo đúng tọa độ GPS ({user_lat:.5f}, {user_lng:.5f}) là {resolved_geo['area_name']}, thuộc {resolved_geo['district']}, {resolved_geo['city']}. TUYỆT ĐỐI KHÔNG tự nhận diện thành landmark nổi tiếng khác ở xa vị trí này.
"""
    else:
        geo_context = """
HƯỚNG DẪN XÁC ĐỊNH ĐỊA GIỚI HÀNH CHÍNH VIỆT NAM:
Dựa trên biển hiệu, chữ đọc được, số nhà hoặc đặc điểm địa danh:
- Hãy xác định đúng tên địa điểm thực tế hoặc biển hiệu đọc được từ ảnh.
- Tuyệt đối KHÔNG tự bịa ra tỉnh thành phố không có cơ sở trong ảnh.
"""

    if task_type == "ticket":
        synth_prompt = f"""Bạn là trợ lý AI chuyên nghiệp của ứng dụng Đặt vé xe khách.
Dưới đây là thông tin quan sát được từ ảnh vé xe của hành khách:
\"\"\"{visual_facts}\"\"\"

{user_q_text}

Hãy phân tích chi tiết và trình bày bằng tiếng Việt mạch lạc, rõ ràng theo đúng cấu trúc sau (không dùng dấu sao **):

1. Thông tin vé & Tuyến xe:
- Nơi đi / Nơi đến: (Nếu đọc được)
- Thời gian khởi hành:
- Tên nhà xe / Phương tiện:

2. Chi tiết đặt chỗ:
- Mã vé / Mã đặt chỗ:
- Số ghế / Vị trí giường:
- Tên hành khách (nếu có):

3. Đánh giá tính rõ ràng & Lưu ý:
(Nêu rõ các chi tiết bị mờ hoặc không xác định được. Tuyệt đối không tự suy diễn thông tin thiếu).
"""
    elif task_type == "pickup_location":
        synth_prompt = f"""Bạn là trợ lý AI chuyên gia địa lý và định vị điểm đón cho ứng dụng Đặt vé xe khách Việt Nam.
Dưới đây là thông tin quan sát từ ảnh điểm đón do hành khách gửi:
\"\"\"{visual_facts}\"\"\"

{geo_context}

{user_q_text}

Nhiệm vụ của bạn: Hãy chỉ rõ tên địa điểm, quận/huyện và tỉnh/thành phố hành khách đang đứng, cùng hướng dẫn đón xe chi tiết bằng tiếng Việt.

Hãy phân tích và trả lời khách hàng chi tiết theo cấu trúc sau (tuyệt đối không dùng dấu sao **):

1. Xác định địa điểm & Vị trí hành chính:
- Tên địa điểm / Khu vực: 
- Thuộc Quận / Huyện / TP: 
- Thuộc Tỉnh / Thành phố: 
- Tuyến đường / Trục giao thông chính: 

2. Đặc điểm nhận diện thực tế tại vị trí:
- Biển hiệu & Chữ đọc được: 
- Cảnh quan xung quanh: 

3. Hướng dẫn đón xe & Lưu ý an toàn:
- Điểm đón xe khách thuận tiện: 
- Lưu ý an toàn cho hành khách: 
"""
    elif task_type == "ocr":
        synth_prompt = f"""Bạn là trợ lý nhận diện chữ cho hành khách xe khách.
Dưới đây là văn bản trích xuất được từ ảnh:
\"\"\"{visual_facts}\"\"\"

{user_q_text}

Hãy trình bày lại toàn bộ văn bản đọc được bằng tiếng Việt chuẩn xác theo cấu trúc (không dùng dấu sao **):

1. Nội dung văn bản đọc được:
(Liệt kê đầy đủ các dòng chữ, số hiệu, địa chỉ, thông tin quan trọng)

2. Phân tích địa chỉ & Ý nghĩa (nếu có):
(Nếu có tên đường, phường, quận/huyện, hãy chỉ rõ địa giới hành chính)

3. Mức độ rõ ràng & Giới hạn nhận diện:
(Chỉ rõ phần nào bị mờ hoặc thiếu thông tin, không tự bịa chữ).
"""
    else:
        synth_prompt = f"""Bạn là trợ lý AI thị giác và địa lý của ứng dụng Đặt vé xe khách.
Dưới đây là các thông tin ghi nhận từ bức ảnh:
\"\"\"{visual_facts}\"\"\"

{geo_context}

{user_q_text}

Hãy mô tả chi tiết, nhận diện rõ tên địa điểm, Quận/Huyện và Tỉnh/Thành phố (nếu có biển hiệu/địa danh) bằng tiếng Việt theo cấu trúc (không dùng dấu sao **):

1. Tổng quan & Vị trí địa lý:
- Tên địa điểm / Khu vực: 
- Quận / Huyện và Tỉnh / Thành phố: 
2. Các đối tượng & Chi tiết quan sát được:
3. Văn bản và biển hiệu đọc được:
4. Đánh giá bối cảnh & Lưu ý cho hành khách:
"""

    # Step 2: Execute Reasoning Synthesis (LM Studio on port 1234 or Ollama fallback)
    ok_r = False
    final_text = ""

    if USE_LMSTUDIO:
        ok_r, final_text = call_lmstudio(
            prompt=synth_prompt,
            model=LMSTUDIO_MODEL,
            temperature=0.25,
            max_tokens=400
        )
        if ok_r:
            logger.info(f"Hoàn tất suy luận lý luận qua LM Studio ({LMSTUDIO_MODEL}) cổng 1234.")
        else:
            logger.warning(f"LM Studio không phản hồi ({final_text}), fallback sang Ollama ({REASONING_MODEL}).")

    if not ok_r:
        ok_r, final_text = call_ollama(
            model=REASONING_MODEL,
            prompt=synth_prompt,
            options={
                "temperature": 0.25,
                "repeat_penalty": 1.2,
                "top_p": 0.9,
                "num_predict": 320
            }
        )

    # Fallback to direct visual_facts if both reasoning backends fail
    if not ok_r:
        logger.warning(f"Không thể suy luận qua LM Studio/Ollama, sử dụng visual facts trực tiếp: {final_text}")
        final_text = visual_facts

    # Step 3: Quality Gate (Detect Repetition)
    if detect_phrase_repetition(final_text):
        logger.warning("Phát hiện văn bản bị lặp, thực hiện retry...")
        retry_prompt = synth_prompt + "\nLƯU Ý ĐẶC BIỆT: Trả lời ngắn gọn, rõ ràng, tuyệt đối không lặp lại bất kỳ từ ngữ nào liên tiếp."
        if USE_LMSTUDIO:
            ok_retry, retry_text = call_lmstudio(
                prompt=retry_prompt,
                model=LMSTUDIO_MODEL,
                temperature=0.15,
                max_tokens=400
            )
            if ok_retry and not detect_phrase_repetition(retry_text):
                final_text = retry_text
        if detect_phrase_repetition(final_text):
            _, retry_text = call_ollama(
                model=REASONING_MODEL,
                prompt=retry_prompt,
                options={
                    "temperature": 0.1,
                    "repeat_penalty": 1.35,
                    "top_p": 0.8,
                    "num_predict": 400
                }
            )
            if not detect_phrase_repetition(retry_text):
                final_text = retry_text
            else:
                return False, "Hệ thống phát hiện kết quả phân tích chưa đạt độ tin cậy do lỗi lặp token. Vui lòng thử lại hoặc chụp góc gần hơn."

    # Remove markdown bold/italic asterisks (**) according to user preference
    final_text = final_text.replace("**", "").replace("### ", "").replace("## ", "")
    # Clean up double spaces if any
    final_text = re.sub(r' +', ' ', final_text).strip()

    # Ground Truth Enforcement: If landmark matched or GPS resolved, enforce location block
    effective_geo = geo_match or resolved_geo
    if effective_geo and task_type == "pickup_location":
        loc_name = effective_geo.get("name") or effective_geo.get("area_name", "Vị trí GPS thiết bị")
        final_text = re.sub(
            r"(- Tên địa điểm / Khu vực:).*",
            f"\\1 {loc_name}",
            final_text,
            flags=re.IGNORECASE
        )
        final_text = re.sub(
            r"(- Thuộc Quận / Huyện / TP:).*",
            f"\\1 {effective_geo['district']}",
            final_text,
            flags=re.IGNORECASE
        )
        final_text = re.sub(
            r"(- Thuộc Tỉnh / Thành phố:).*",
            f"\\1 {effective_geo['city']}",
            final_text,
            flags=re.IGNORECASE
        )
        final_text = re.sub(
            r"(- Tuyến đường / Trục giao thông chính:).*",
            f"\\1 {effective_geo['street']}",
            final_text,
            flags=re.IGNORECASE
        )
        final_text = re.sub(
            r"(- Điểm đón xe khách thuận tiện:).*",
            f"\\1 {effective_geo['pickup_point']}",
            final_text,
            flags=re.IGNORECASE
        )

    if route_analysis and route_analysis.get("has_route"):
        status_tag = "NẰM TRÊN LỘ TRÌNH ĐÓN KHÁCH" if route_analysis.get("is_on_route") else "NẰM NGOÀI LỘ TRÌNH"
        final_text += f"\n\n4. Đánh giá Lộ trình Tuyến xe ({route_analysis.get('route_name', '')}):\n- Kết luận: {status_tag}\n- Chi tiết: {route_analysis.get('status_message', '')}\n- Hướng dẫn đón: {route_analysis.get('recommendation', '')}"

    return True, final_text, route_analysis


# ================== REST ENDPOINTS ==================

@app.route("/", methods=["GET"])
def index():
    """Root landing page showing API information."""
    return jsonify({
        "status": "online",
        "service": "AI Vision Service - Hệ Thống Đặt Vé Xe Khách",
        "version": "1.0.0",
        "pipeline": f"{VISION_MODEL} + {REASONING_MODEL}",
        "endpoints": {
            "health_check": "/health",
            "models_list": "/v1/models",
            "analyze_image": "/v1/vision/analyze (POST)",
            "ocr_text": "/v1/vision/ocr (POST)",
            "describe_image": "/v1/vision/describe (POST)"
        },
        "message": "Máy chủ AI Vision đang hoạt động bình thường trên máy tính trạm."
    }), 200

@app.route("/health", methods=["GET"])
def health_check():
    """Health check for service and Ollama backend."""
    ollama_ok = False
    available_models = []
    ollama_msg = "Chưa kết nối"

    try:
        resp = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=3)
        if resp.status_code == 200:
            ollama_ok = True
            data = resp.json()
            available_models = [m.get("name") for m in data.get("models", [])]
            ollama_msg = "Ollama đang hoạt động bình thường"
    except Exception as e:
        ollama_msg = f"Không thể kết nối đến Ollama: {str(e)}"

    lmstudio_ok = False
    lmstudio_models = []
    lmstudio_msg = "Chưa kết nối"
    try:
        resp_lm = requests.get(f"{LMSTUDIO_BASE_URL}/v1/models", timeout=3)
        if resp_lm.status_code == 200:
            lmstudio_ok = True
            lmstudio_models = [m.get("id") for m in resp_lm.json().get("data", [])]
            lmstudio_msg = "LM Studio đang hoạt động bình thường trên cổng 1234"
    except Exception as e:
        lmstudio_msg = f"Không thể kết nối LM Studio (cổng 1234): {str(e)}"

    is_model_ready = any(VISION_MODEL.split(":")[0] in m for m in available_models)
    is_healthy = lmstudio_ok or (ollama_ok and is_model_ready)
    status_code = 200 if is_healthy else 503

    active_reasoner = f"LM Studio ({LMSTUDIO_MODEL})" if lmstudio_ok else f"Ollama ({REASONING_MODEL})"

    return jsonify({
        "status": "healthy" if status_code == 200 else "degraded",
        "service": "AI Vision Service - Đặt vé xe khách",
        "timestamp": int(time.time()),
        "active_reasoning_backend": active_reasoner,
        "lmstudio": {
            "status": "connected" if lmstudio_ok else "disconnected",
            "url": LMSTUDIO_BASE_URL,
            "message": lmstudio_msg,
            "model": LMSTUDIO_MODEL,
            "models_loaded": lmstudio_models
        },
        "ollama": {
            "status": "connected" if ollama_ok else "disconnected",
            "message": ollama_msg,
            "vision_model": VISION_MODEL,
            "reasoning_model": REASONING_MODEL,
            "is_configured_model_ready": is_model_ready,
            "available_models": available_models
        }
    }), status_code


@app.route("/v1/models", methods=["GET"])
def get_models():
    """Lists allowed and available vision models."""
    auth_ok, auth_err = verify_auth_token()
    if not auth_ok:
        return jsonify({"success": False, "error": auth_err}), 401

    try:
        resp = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=4)
        models = resp.json().get("models", []) if resp.status_code == 200 else []
    except Exception:
        models = []

    return jsonify({
        "success": True,
        "vision_model": VISION_MODEL,
        "reasoning_model": REASONING_MODEL,
        "installed_models": models,
        "supported_vision_models": [
            {"id": "moondream:latest", "desc": "Mô hình Vision siêu nhẹ 1.7GB, phản hồi nhanh"},
            {"id": "qwen2.5:1.5b", "desc": "Mô hình tổng hợp ngôn ngữ tiếng Việt chống lặp"}
        ]
    }), 200


@app.route("/v1/vision/describe", methods=["POST"])
def describe_image():
    """Describes image content in rich Vietnamese without repetitions."""
    auth_ok, auth_err = verify_auth_token()
    if not auth_ok:
        return jsonify({"success": False, "error": auth_err}), 401

    img_bytes, filename, err = extract_image_bytes_from_request()
    if err:
        return jsonify({"success": False, "error": err}), 400

    val_ok, _, val_err = validate_image_pillow(img_bytes)
    if not val_ok:
        return jsonify({"success": False, "error": val_err}), 400

    json_data = request.get_json(silent=True) or {}
    user_prompt = request.form.get("prompt") or json_data.get("prompt")

    acquired = concurrency_limiter.acquire(blocking=False)
    if not acquired:
        return jsonify({"success": False, "error": "Hệ thống đang bận xử lý yêu cầu khác, vui lòng thử lại sau giây lát."}), 429

    start_time = time.time()
    try:
        ok, result, _ = run_hybrid_vision_pipeline(
            image_bytes=img_bytes,
            task_type="describe",
            user_question=user_prompt
        )
        elapsed = round(time.time() - start_time, 2)
        if not ok:
            return jsonify({"success": False, "error": result, "execution_time_seconds": elapsed}), 502

        return jsonify({
            "success": True,
            "filename": filename,
            "task": "describe",
            "model": f"{VISION_MODEL} + {REASONING_MODEL}",
            "description": result,
            "execution_time_seconds": elapsed
        }), 200
    finally:
        concurrency_limiter.release()


@app.route("/v1/vision/ocr", methods=["POST"])
def ocr_image():
    """Performs OCR and QR extraction with anti-repetition protection."""
    auth_ok, auth_err = verify_auth_token()
    if not auth_ok:
        return jsonify({"success": False, "error": auth_err}), 401

    img_bytes, filename, err = extract_image_bytes_from_request()
    if err:
        return jsonify({"success": False, "error": err}), 400

    val_ok, _, val_err = validate_image_pillow(img_bytes)
    if not val_ok:
        return jsonify({"success": False, "error": val_err}), 400

    json_data = request.get_json(silent=True) or {}
    user_prompt = request.form.get("prompt") or json_data.get("prompt")

    acquired = concurrency_limiter.acquire(blocking=False)
    if not acquired:
        return jsonify({"success": False, "error": "Hệ thống đang bận xử lý yêu cầu khác, vui lòng thử lại sau giây lát."}), 429

    start_time = time.time()
    try:
        qr_text = detect_qr_code(img_bytes)
        ok, result, _ = run_hybrid_vision_pipeline(
            image_bytes=img_bytes,
            task_type="ocr",
            user_question=user_prompt
        )
        elapsed = round(time.time() - start_time, 2)
        if not ok:
            return jsonify({"success": False, "error": result, "execution_time_seconds": elapsed}), 502

        return jsonify({
            "success": True,
            "filename": filename,
            "task": "ocr",
            "model": f"{VISION_MODEL} + {REASONING_MODEL}",
            "extracted_text": result,
            "qr_detected": qr_text is not None,
            "qr_content": qr_text,
            "execution_time_seconds": elapsed
        }), 200
    finally:
        concurrency_limiter.release()


@app.route("/v1/vision/analyze", methods=["POST"])
def analyze_image():
    """Comprehensive Vision analysis for tickets, pickup points, signs, and vehicles."""
    auth_ok, auth_err = verify_auth_token()
    if not auth_ok:
        return jsonify({"success": False, "error": auth_err}), 401

    img_bytes, filename, err = extract_image_bytes_from_request()
    if err:
        return jsonify({"success": False, "error": err}), 400

    val_ok, image_pil, val_err = validate_image_pillow(img_bytes)
    if not val_ok:
        return jsonify({"success": False, "error": val_err}), 400

    json_data = request.get_json(silent=True) or {}
    analysis_type = request.form.get("type") or json_data.get("type") or "general"
    custom_prompt = request.form.get("prompt") or json_data.get("prompt")
    route_name = request.form.get("route_name") or json_data.get("route_name")
    start_point = request.form.get("start_point") or json_data.get("start_point")
    end_point = request.form.get("end_point") or json_data.get("end_point")

    # Extract device GPS coordinates if provided
    user_lat = None
    user_lng = None
    try:
        raw_lat = request.form.get("latitude") or json_data.get("latitude")
        raw_lng = request.form.get("longitude") or json_data.get("longitude")
        if raw_lat is not None and str(raw_lat).strip():
            user_lat = float(raw_lat)
        if raw_lng is not None and str(raw_lng).strip():
            user_lng = float(raw_lng)
    except (ValueError, TypeError):
        user_lat = None
        user_lng = None

    # Detect QR code first
    qr_content = detect_qr_code(img_bytes)
    ticket_verification = None
    if qr_content:
        ticket_verification = verify_ticket_with_backend(qr_content)

    acquired = concurrency_limiter.acquire(blocking=False)
    if not acquired:
        return jsonify({"success": False, "error": "Hệ thống đang bận xử lý yêu cầu khác, vui lòng thử lại sau giây lát."}), 429

    start_time = time.time()
    try:
        ok, vision_description, route_analysis = run_hybrid_vision_pipeline(
            image_bytes=img_bytes,
            task_type=analysis_type,
            user_question=custom_prompt,
            route_name=route_name,
            start_point=start_point,
            end_point=end_point,
            user_lat=user_lat,
            user_lng=user_lng
        )
        elapsed = round(time.time() - start_time, 2)
        if not ok:
            return jsonify({"success": False, "error": vision_description, "execution_time_seconds": elapsed}), 502

        response_data = {
            "success": True,
            "filename": filename,
            "task": "analyze",
            "analysis_type": analysis_type,
            "model": f"{VISION_MODEL} + {REASONING_MODEL}",
            "image_dimensions": {"width": image_pil.width, "height": image_pil.height},
            "analysis_result": vision_description,
            "route_analysis": route_analysis,
            "qr_detected": qr_content is not None,
            "qr_code": qr_content,
            "ticket_verification": ticket_verification,
            "execution_time_seconds": elapsed
        }

        return jsonify(response_data), 200
    finally:
        concurrency_limiter.release()


if __name__ == "__main__":
    logger.info(f"Khởi động AI Vision Service trên {VISION_HOST}:{VISION_PORT}...")
    logger.info(f"Pipeline: {VISION_MODEL} + {REASONING_MODEL}")
    app.run(host=VISION_HOST, port=VISION_PORT, debug=VISION_DEBUG)
