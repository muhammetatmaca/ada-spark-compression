@echo off
title Ada SPARK Sikistirma Studyosu - DO-178C Level-A
color 0B
echo =========================================================================
echo   ADA SPARK SIKISTIRMA STUDYOSU - STANAG-4586 / DO-178C LEVEL-A
echo =========================================================================
echo.

:: Bagimliliklari kontrol et
echo [*] Bagimliliklar kontrol ediliyor...
python -m pip install -r requirements.txt -q

:: Uygulamayi baslat
echo [*] Arayuz baslatiliyor...
python app.py
