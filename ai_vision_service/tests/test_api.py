import os
import io
import time
import unittest
import requests
from PIL import Image, ImageDraw
import cv2
import numpy as np

API_BASE = "http://127.0.0.1:5050"
TOKEN = "vexekhach_ai_vision_sec_2026_tok"
AUTH_HEADERS = {"Authorization": f"Bearer {TOKEN}"}


class TestAIVisionService(unittest.TestCase):

    def test_01_health_check(self):
        """Kiểm tra GET /health trả về 200 và Ollama connected."""
        res = requests.get(f"{API_BASE}/health", timeout=5)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data.get("status"), "healthy")
        self.assertEqual(data.get("ollama", {}).get("status"), "connected")

    def test_02_auth_protection(self):
        """Kiểm tra yêu cầu xác thực Bearer token."""
        # Không có token -> 401
        res = requests.get(f"{API_BASE}/v1/models", timeout=5)
        self.assertEqual(res.status_code, 401)

        # Sai token -> 401
        res_bad = requests.get(
            f"{API_BASE}/v1/models",
            headers={"Authorization": "Bearer bad_secret_key"},
            timeout=5
        )
        self.assertEqual(res_bad.status_code, 401)

        # Đúng token -> 200
        res_ok = requests.get(f"{API_BASE}/v1/models", headers=AUTH_HEADERS, timeout=5)
        self.assertEqual(res_ok.status_code, 200)
        self.assertTrue(res_ok.json().get("success"))

    def test_03_invalid_file_upload(self):
        """Kiểm tra từ chối upload file không phải là ảnh hợp lệ."""
        files = {"image": ("dummy.txt", b"This is not an image file content", "text/plain")}
        res = requests.post(
            f"{API_BASE}/v1/vision/describe",
            headers=AUTH_HEADERS,
            files=files,
            timeout=5
        )
        self.assertEqual(res.status_code, 400)
        self.assertFalse(res.json().get("success"))

    def test_04_describe_image(self):
        """Kiểm tra POST /v1/vision/describe với ảnh thật."""
        img = Image.new("RGB", (320, 240), color=(73, 109, 137))
        d = ImageDraw.Draw(img)
        d.text((30, 80), "XE KHACH TUYEN HA NOI - HAI PHONG", fill=(255, 255, 255))
        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        buf.seek(0)

        files = {"image": ("bus_sample.jpg", buf.getvalue(), "image/jpeg")}
        res = requests.post(
            f"{API_BASE}/v1/vision/describe",
            headers=AUTH_HEADERS,
            files=files,
            timeout=60
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get("success"))
        self.assertIn("description", data)
        self.assertGreater(len(data.get("description", "")), 5)

    def test_05_ocr_and_qr_extraction(self):
        """Kiểm tra POST /v1/vision/ocr với ảnh chứa chữ và mã QR."""
        # Tạo ảnh có QR code hợp lệ bằng OpenCV
        encoder = cv2.QRCodeEncoder.create()
        qr_mat = encoder.encode("VX-BOOKING-8822")
        qr_bordered = cv2.copyMakeBorder(qr_mat, 25, 25, 25, 25, cv2.BORDER_CONSTANT, value=255)
        qr_resized = cv2.resize(qr_bordered, (260, 260), interpolation=cv2.INTER_NEAREST)

        success, encoded_img = cv2.imencode(".png", qr_resized)
        self.assertTrue(success)

        files = {"image": ("ticket_qr.png", encoded_img.tobytes(), "image/png")}
        res = requests.post(
            f"{API_BASE}/v1/vision/ocr",
            headers=AUTH_HEADERS,
            files=files,
            timeout=60
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get("success"))
        self.assertTrue(data.get("qr_detected"))
        self.assertEqual(data.get("qr_content"), "VX-BOOKING-8822")

    def test_06_analyze_bus_ticket(self):
        """Kiểm tra POST /v1/vision/analyze chuyên sâu vé xe."""
        img = Image.new("RGB", (360, 200), color=(255, 255, 255))
        d = ImageDraw.Draw(img)
        d.text((20, 20), "VE XE KHACH PHUONG TRANG", fill=(0, 0, 0))
        d.text((20, 60), "Ma dat ve: PT-554433", fill=(200, 0, 0))
        d.text((20, 100), "Tuyen: TP.HCM -> Da Lat", fill=(0, 0, 0))
        d.text((20, 140), "Ghe: B04 - Gio: 08:00", fill=(0, 0, 0))

        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        buf.seek(0)

        files = {"image": ("ticket.jpg", buf.getvalue(), "image/jpeg")}
        data = {"type": "ticket"}
        res = requests.post(
            f"{API_BASE}/v1/vision/analyze",
            headers=AUTH_HEADERS,
            files=files,
            data=data,
            timeout=60
        )
        self.assertEqual(res.status_code, 200)
        resp_data = res.json()
        self.assertTrue(resp_data.get("success"))
        self.assertEqual(resp_data.get("analysis_type"), "ticket")
        self.assertIn("analysis_result", resp_data)


if __name__ == "__main__":
    unittest.main()
