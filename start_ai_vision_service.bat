@echo off
chcp 65001 >nul
title AI Vision Service - He Thong Dat Ve Xe

echo ========================================================
echo   KHOI DONG HE THONG AI VISION SERVICE - VE XE KHACH
echo ========================================================

echo [1/4] Dat thu muc mo hinh sang o D...
set OLLAMA_MODELS=D:\ollama_models
set OLLAMA_HOST=127.0.0.1:11434

echo [2/4] Khoi chay Ollama Engine nen...
start "Ollama Engine" "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" serve

ping -n 3 127.0.0.1 >nul

echo [3/4] Khoi chay AI Vision Service Flask (Port 5050)...
set VISION_HOST=0.0.0.0
set VISION_PORT=5050
set VISION_MODEL=moondream:latest
set VISION_API_TOKEN=vexekhach_ai_vision_sec_2026_tok

start "AI Vision Service" python d:\WebDatVeXe\ai_vision_service\app.py

ping -n 3 127.0.0.1 >nul

echo [4/4] Khoi chay Cloudflare Public Tunnel HTTPS...
start "Cloudflare Tunnel" d:\WebDatVeXe\cloudflared.exe tunnel --url http://127.0.0.1:5050

echo ========================================================
echo   HE THONG DA SAN SANG!
echo   - Local Endpoint:  http://127.0.0.1:5050/health
echo   - LAN Endpoint:    http://10.12.20.125:5050/health
echo   - LM Studio:       http://10.12.20.125:1234/v1
echo ========================================================
echo Nhan phim bat ky de thoat cua so nay (cac tien trinh nen van tiep tuc chay)...
pause >nul
