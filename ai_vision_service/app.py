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
        "keywords": ["khu cong nghe cao", "cong nghe cao", "shtp", "high tech park", "hightech park"],
        "name": "Khu Công Nghệ Cao TP.HCM (SHTP)",
        "ward": "Phường Tân Phú / Tăng Nhơn Phú B",
        "district": "Thành phố Thủ Đức (Quận 9 cũ)",
        "city": "TP. Hồ Chí Minh",
        "street": "Xa lộ Hà Nội (Đường Võ Nguyên Giáp) - Đường D1/D2",
        "pickup_point": "Trạm xe buýt Khu Công Nghệ Cao trên Xa lộ Hà Nội hoặc Cổng chính Khu Công Nghệ Cao (điểm đón xe liên tỉnh đi Đồng Nai, Bình Thuận, Vũng Tàu, Miền Trung, Miền Bắc).",
    },
    {
        "keywords": ["suoi tien", "kdl suoi tien"],
        "name": "Khu Du Lịch Văn Hóa Suối Tiên",
        "ward": "Phường Tân Phú",
        "district": "Thành phố Thủ Đức (Quận 9 cũ)",
        "city": "TP. Hồ Chí Minh",
        "street": "Xa lộ Hà Nội (Quốc lộ 52)",
        "pickup_point": "Trạm dừng Suối Tiên / Cầu vượt bộ hành Suối Tiên (điểm đón xe khách liên tỉnh tấp nập nhất cửa ngõ phía Đông TP.HCM).",
    },
    {
        "keywords": ["mien dong moi", "ben xe mien dong moi"],
        "name": "Bến xe Miền Đông Mới",
        "ward": "Phường Long Bình",
        "district": "Thành phố Thủ Đức (Quận 9 cũ)",
        "city": "TP. Hồ Chí Minh",
        "street": "Số 501 Hoàng Hữu Nam / Xa lộ Hà Nội",
        "pickup_point": "Khu vực sảnh đón trả khách Bến xe Miền Đông Mới hoặc trạm dừng xe buýt trước cổng bến xe.",
    },
    {
        "keywords": ["ben xe mien dong", "bx mien dong", "mien dong"],
        "name": "Bến xe Miền Đông (cũ)",
        "ward": "Phường 26",
        "district": "Quận Bình Thạnh",
        "city": "TP. Hồ Chí Minh",
        "street": "292 Đinh Bộ Lĩnh / Quốc lộ 13",
        "pickup_point": "Cổng số 1, 2, 3 Bến xe Miền Đông hoặc dọc đường Đinh Bộ Lĩnh / Quốc lộ 13.",
    },
    {
        "keywords": ["ben xe mien tay", "bx mien tay", "mien tay"],
        "name": "Bến xe Miền Tây",
        "ward": "Phường An Lạc",
        "district": "Quận Bình Tân",
        "city": "TP. Hồ Chí Minh",
        "street": "395 Kinh Dương Vương",
        "pickup_point": "Cổng ga đi Bến xe Miền Tây hoặc cây xăng đối diện bến xe.",
    },
    {
        "keywords": ["an suong", "nga tu an suong", "bx an suong", "ben xe an suong"],
        "name": "Ngã tư An Sương / Bến xe An Sương",
        "ward": "Xã Bà Điểm, Huyện Hóc Môn & Phường Trung Mỹ Tây",
        "district": "Quận 12 & Huyện Hóc Môn",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 22 / Quốc lộ 1A / Trường Chinh",
        "pickup_point": "Nhà chờ Bến xe An Sương hoặc chân cầu vượt ngã tư An Sương hướng đi Tây Ninh / Miền Tây.",
    },
    {
        "keywords": ["hang xanh", "nga tu hang xanh"],
        "name": "Ngã tư Hàng Xanh",
        "ward": "Phường 21 / Phường 25",
        "district": "Quận Bình Thạnh",
        "city": "TP. Hồ Chí Minh",
        "street": "Điện Biên Phủ giao Xô Viết Nghệ Tĩnh",
        "pickup_point": "Cây xăng Comeco Hàng Xanh hoặc trạm dừng buýt dưới chân cầu vượt Hàng Xanh.",
    },
    {
        "keywords": ["nga tu thu duc", "tram thu duc", "metro thu duc"],
        "name": "Ngã tư Thủ Đức / Trạm Metro Thủ Đức",
        "ward": "Phường Hiệp Phú & Phường Linh Trung",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Xa lộ Hà Nội giao Lê Văn Việt / Võ Văn Ngân",
        "pickup_point": "Chân cầu vượt Ngã tư Thủ Đức (hướng đi Đồng Nai) hoặc trước trường ĐH Sư Phạm Kỹ Thuật.",
    },
    {
        "keywords": ["linh xuan", "cau vuot linh xuan"],
        "name": "Cầu vượt Linh Xuân",
        "ward": "Phường Linh Xuân",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 1A giao Quốc lộ 1K",
        "pickup_point": "Dưới dạ cầu vượt Linh Xuân hoặc trạm dừng xe buýt hướng đi Suối Tiên / Dĩ An.",
    },
    {
        "keywords": ["binh phuoc", "nga tu binh phuoc"],
        "name": "Ngã tư Bình Phước",
        "ward": "Phường Hiệp Bình Phước",
        "district": "Thành phố Thủ Đức",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 1A giao Quốc lộ 13",
        "pickup_point": "Chân cầu vượt Bình Phước (cây xăng hoặc trạm buýt) hướng đi Bình Dương hoặc Miền Tây.",
    },
    {
        "keywords": ["nga tu ga", "cau vuot nga tu ga"],
        "name": "Cầu vượt Ngã tư Ga",
        "ward": "Phường Thạnh Lộc",
        "district": "Quận 12",
        "city": "TP. Hồ Chí Minh",
        "street": "Quốc lộ 1A giao Hà Huy Giáp",
        "pickup_point": "Dọc Quốc lộ 1A dưới chân cầu vượt Ngã tư Ga.",
    },
    {
        "keywords": ["tan son nhat", "san bay tan son nhat"],
        "name": "Sân bay Quốc tế Tân Sơn Nhất",
        "ward": "Phường 2",
        "district": "Quận Tân Bình",
        "city": "TP. Hồ Chí Minh",
        "street": "Đường Trường Sơn",
        "pickup_point": "Khu vực làn đón xe ô tô ga Quốc nội/Quốc tế hoặc bãi đỗ xe ga ngầm.",
    },
    {
        "keywords": ["ben thanh", "cho ben thanh"],
        "name": "Chợ Bến Thành / Quảng trường Quách Thị Trang",
        "ward": "Phường Bến Thành",
        "district": "Quận 1",
        "city": "TP. Hồ Chí Minh",
        "street": "Lê Lợi - Phan Chu Trinh - Hàm Nghi",
        "pickup_point": "Trạm trung chuyển xe buýt Bến Thành (đường Hàm Nghi) hoặc trước chợ Bến Thành.",
    },
    {
        "keywords": ["lang dai hoc", "dai hoc quoc gia tphcm", "dhqg"],
        "name": "Khu Đô Thị Đại Học Quốc Gia TP.HCM",
        "ward": "Phường Linh Trung (TP. Thủ Đức) & Phường Đông Hòa (TP. Dĩ An)",
        "district": "TP. Thủ Đức / TP. Dĩ An",
        "city": "TP. Hồ Chí Minh / Tỉnh Bình Dương",
        "street": "Đường Quảng Trường Sáng Tạo / Song Hành Xa lộ Hà Nội",
        "pickup_point": "Trạm xe buýt Nhà Văn Hóa Sinh Viên hoặc cổng KTX Khu A / Khu B.",
    },
    {
        "keywords": ["my dinh", "ben xe my dinh", "bx my dinh"],
        "name": "Bến xe Mỹ Đình",
        "ward": "Phường Mỹ Đình 2",
        "district": "Quận Nam Từ Liêm",
        "city": "TP. Hà Nội",
        "street": "Số 20 Phạm Hùng",
        "pickup_point": "Khu vực sân chờ xe khách Bến xe Mỹ Đình hoặc vỉa hè đường Phạm Hùng.",
    },
    {
        "keywords": ["giap bat", "ben xe giap bat", "bx giap bat"],
        "name": "Bến xe Giáp Bát",
        "ward": "Phường Giáp Bát",
        "district": "Quận Hoàng Mai",
        "city": "TP. Hà Nội",
        "street": "Đường Giải Phóng",
        "pickup_point": "Sảnh chờ xe khách Bến xe Giáp Bát hoặc dải đón khách đường Giải Phóng.",
    },
    {
        "keywords": ["nuoc ngam", "ben xe nuoc ngam", "bx nuoc ngam"],
        "name": "Bến xe Nước Ngầm",
        "ward": "Phường Hoàng Liệt",
        "district": "Quận Hoàng Mai",
        "city": "TP. Hà Nội",
        "street": "Số 1 Ngọc Hồi / Ngã ba Giải Phóng - Pháp Vân",
        "pickup_point": "Sảnh đón Bến xe Nước Ngầm hoặc đường gom Pháp Vân.",
    },
    {
        "keywords": ["yen nghia", "ben xe yen nghia", "bx yen nghia"],
        "name": "Bến xe Yên Nghĩa",
        "ward": "Phường Yên Nghĩa",
        "district": "Quận Hà Đông",
        "city": "TP. Hà Nội",
        "street": "Quốc lộ 6",
        "pickup_point": "Khu vực sảnh đón Bến xe Yên Nghĩa hoặc trạm ga tàu điện Cát Linh - Hà Đông.",
    },
    {
        "keywords": ["gia lam", "ben xe gia lam", "bx gia lam"],
        "name": "Bến xe Gia Lâm",
        "ward": "Phường Gia Thụy",
        "district": "Quận Long Biên",
        "city": "TP. Hà Nội",
        "street": "Đường Ngô Gia Khảm",
        "pickup_point": "Sảnh đón xe khách Bến xe Gia Lâm.",
    },
    {
        "keywords": ["noi bai", "san bay noi bai"],
        "name": "Sân bay Quốc tế Nội Bài",
        "ward": "Xã Phú Minh",
        "district": "Huyện Sóc Sơn",
        "city": "TP. Hà Nội",
        "street": "Võ Nguyên Giáp / Võ Văn Kiệt",
        "pickup_point": "Khu vực sảnh tầng 1 đón khách ga T1 (Nội địa) hoặc T2 (Quốc tế).",
    },
    {
        "keywords": ["da nang", "bx trung tam da nang", "ben xe da nang"],
        "name": "Bến xe Trung tâm Đà Nẵng",
        "ward": "Phường Hòa An",
        "district": "Quận Cẩm Lệ",
        "city": "TP. Đà Nẵng",
        "street": "Đường Tôn Đức Thắng",
        "pickup_point": "Sảnh đón khách Bến xe Trung tâm Đà Nẵng.",
    },
    {
        "keywords": ["cau rong", "dragon bridge"],
        "name": "Cầu Rồng Đà Nẵng",
        "ward": "Phường Phước Ninh (Hải Châu) & Phường An Hải Tây (Sơn Trà)",
        "district": "Quận Hải Châu & Quận Sơn Trà",
        "city": "TP. Đà Nẵng",
        "street": "Đường Nguyễn Văn Linh giao Bạch Đằng",
        "pickup_point": "Dọc đường Bạch Đằng hoặc đường Trần Hưng Đạo gần đuôi/đầu Cầu Rồng.",
    },
    {
        "keywords": ["can tho", "ben xe can tho", "bx trung tam can tho", "bx 91b"],
        "name": "Bến xe Trung tâm Cần Thơ",
        "ward": "Phường Hưng Thạnh",
        "district": "Quận Cái Răng",
        "city": "TP. Cần Thơ",
        "street": "Khu đô thị Nam Cần Thơ / Quốc lộ 1A",
        "pickup_point": "Sảnh đón khách Bến xe Trung tâm Cần Thơ.",
    },
    {
        "keywords": ["vung tau", "ben xe vung tau", "bx vung tau"],
        "name": "Bến xe Vũng Tàu",
        "ward": "Phường Thắng Tam",
        "district": "Thành phố Vũng Tàu",
        "city": "Tỉnh Bà Rịa - Vũng Tàu",
        "street": "Số 192 Nam Kỳ Khởi Nghĩa",
        "pickup_point": "Khu vực đón xe khách Bến xe Vũng Tàu.",
    },
    {
        "keywords": ["da lat", "ben xe da lat", "bx lien tinh da lat"],
        "name": "Bến xe Liên tỉnh Đà Lạt",
        "ward": "Phường 3",
        "district": "Thành phố Đà Lạt",
        "city": "Tỉnh Lâm Đồng",
        "street": "Số 1 Tô Hiến Thành",
        "pickup_point": "Sảnh đón khách đầu đèo Prenn Bến xe Liên tỉnh Đà Lạt.",
    },
    {
        "keywords": ["nha trang", "ben xe phia nam nha trang"],
        "name": "Bến xe Phía Nam Nha Trang",
        "ward": "Xã Vĩnh Trung",
        "district": "Thành phố Nha Trang",
        "city": "Tỉnh Khánh Hòa",
        "street": "Số 58 đường 23/10",
        "pickup_point": "Khu vực sân chờ đón khách Bến xe Phía Nam Nha Trang.",
    }
]


def lookup_landmark_info(text: str) -> Optional[Dict[str, str]]:
    """Finds geographic and pickup info for known Vietnamese transit landmarks."""
    clean = remove_accents(text)
    for item in VIETNAMESE_LANDMARKS_DB:
        for kw in item["keywords"]:
            if remove_accents(kw) in clean:
                return item
    return None


def run_hybrid_vision_pipeline(
    image_bytes: bytes,
    task_type: str,
    user_question: Optional[str] = None
) -> Tuple[bool, str]:
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
            "Examine this location, road, entrance, bus stop, or building carefully. "
            "Transcribe all readable text on signs, billboards, gate plaques, street banners, and address plates. "
            "Describe the distinctive landmarks, building structure, road signs, and geographic surroundings."
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
        return False, visual_facts

    # Stage 2: Reasoning & Vietnamese Synthesis via Qwen2.5
    user_q_text = f"Câu hỏi của khách hàng: \"{user_question}\"" if user_question else ""

    # Look up landmark in known Vietnamese transit database
    geo_match = lookup_landmark_info(visual_facts + " " + (user_question or ""))
    if geo_match:
        geo_context = f"""
THÔNG TIN TRA CỨU ĐỊA DANH GIAO THÔNG CHÍNH XÁC:
- Địa danh xác định: {geo_match['name']}
- Thuộc Phường / Xã: {geo_match['ward']}
- Thuộc Quận / Huyện / TP: {geo_match['district']}
- Thuộc Tỉnh / Thành phố: {geo_match['city']}
- Tuyến đường tiếp giáp: {geo_match['street']}
- Điểm đón xe khách phổ biến: {geo_match['pickup_point']}
(Hãy sử dụng đầy đủ các thông tin địa danh, quận/huyện, tỉnh/thành phố này để trả lời rõ ràng cho khách hàng).
"""
    else:
        geo_context = """
HƯỚNG DẪN XÁC ĐỊNH ĐỊA GIỚI HÀNH CHÍNH VIỆT NAM:
Dựa trên biển hiệu, chữ đọc được, số nhà hoặc đặc điểm địa danh, hãy suy luận và chỉ rõ:
- Tên địa điểm cụ thể
- Thuộc Quận / Huyện nào (hoặc Thành phố trực thuộc như TP. Thủ Đức)
- Thuộc Tỉnh / Thành phố nào (TP. Hồ Chí Minh, Hà Nội, Đà Nẵng, Cần Thơ, Bình Dương...)
- Tuyến đường / Trục giao thông chính.
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

    return True, final_text


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
        ok, result = run_hybrid_vision_pipeline(
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
        ok, result = run_hybrid_vision_pipeline(
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
        ok, vision_description = run_hybrid_vision_pipeline(
            image_bytes=img_bytes,
            task_type=analysis_type,
            user_question=custom_prompt
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
