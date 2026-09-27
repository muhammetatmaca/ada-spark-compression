@echo off
title Tactical Archive Studio - Avionics Edition
color 0B
echo =========================================================================
echo   TACTICAL ARCHIVE STUDIO - STANAG-4586 / DO-178C LEVEL-A ENGINE
echo =========================================================================
echo.

:: Bagimliliklari kontrol et
echo [*] Bagimliliklar kontrol ediliyor...
python -m pip install -r requirements.txt -q

:: Uygulamayi baslat
echo [*] Arayuz baslatiliyor...
python app.py
