@echo off
chcp 65001 >nul
echo ========================================================
echo   KHỞI ĐỘNG HỆ THỐNG AI VISION SERVICE - VÉ XE KHÁCH
echo ========================================================

echo 1. Đặt thư mục mô hình sang ổ D (tránh đầy ổ C)...
set OLLAMA_MODELS=D:\ollama_models
set OLLAMA_HOST=127.0.0.1:11434

echo 2. Khởi chạy Ollama Engine nền...
start "Ollama Engine" "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" serve

timeout /t 3 /nobreak >nul

echo 3. Khởi chạy AI Vision Service Flask (Port 5050)...
set VISION_HOST=127.0.0.1
set VISION_PORT=5050
set VISION_MODEL=moondream:latest
set VISION_API_TOKEN=vexekhach_ai_vision_sec_2026_tok

start "AI Vision Service" python d:\WebDatVeXe\ai_vision_service\app.py

timeout /t 2 /nobreak >nul

echo 4. Khởi chạy Cloudflare Public Tunnel (HTTPS)...
start "Cloudflare Tunnel" d:\WebDatVeXe\cloudflared.exe tunnel --url http://127.0.0.1:5050

echo ========================================================
echo   HỆ THỐNG ĐÃ SẴN SÀNG!
echo   - Local Endpoint:  http://127.0.0.1:5050/health
echo   - App Flutter:     Mở app -> Bấm nút 'AI Vision' ở trang chủ
echo ========================================================
pause
