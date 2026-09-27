@echo off
title Ada SPARK Sikistirma - Ground Station Server
color 0A
echo =========================================================================
echo   ADA SPARK SIKISTIRMA - ENTERPRISE GROUND STATION SERVER (STANAG-4586)
echo =========================================================================
echo.
echo [*] Bagimliliklar kontrol ediliyor...
python -m pip install -r requirements.txt -q
echo [*] Aviyonik sunucu dinlemeye aliniyor (Port 5555: Omni, Port 5556: Radar)...
python tactical_server.py --ports 5555:algo-8:decompress 5556:algo-6:decompress --log server_telemetry.log
pause
