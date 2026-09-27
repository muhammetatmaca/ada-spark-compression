#!/usr/bin/env python3
"""
ADA SPARK SIKIŞTIRMA SÜİTİ - SÜRÜM ÜRETİM ROBOTU (RELEASE BUILDER)
Hem PC (Sunucu / Yer İstasyonu) hem de Gömülü Sistemler (İstemci) için
dağıtıma hazır resmi sürüm arşivlerini (.zip / .tar.gz) oluşturan üretim aracı.
"""

import os
import sys
import shutil
import zipfile
import tarfile
import hashlib

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DIST_DIR = os.path.join(BASE_DIR, "dist")
VERSION = "v1.0.0"

def compute_sha256(filepath):
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            sha.update(chunk)
    return sha.hexdigest()

def make_pc_release():
    print("[*] 1/2: PC Sürümü (Sunucu / Yer İstasyonu Süiti) Paketleniyor...")
    pc_folder = os.path.join(DIST_DIR, f"Ada_SPARK_Compression_PC_Server_{VERSION}")
    if os.path.exists(pc_folder):
        shutil.rmtree(pc_folder)
    os.makedirs(pc_folder, exist_ok=True)

    # Kök dosyalar
    root_files = [
        "app.py", "tactical_server.py", "cli.py", "start.bat", "start_server.bat",
        "requirements.txt", "README.md", "LICENSE"
    ]
    for rf in root_files:
        src = os.path.join(BASE_DIR, rf)
        if os.path.exists(src):
            shutil.copy2(src, pc_folder)

    # Klasörler (scripts, bin, docs)
    dirs_to_copy = ["scripts", "bin", "docs"]
    for d in dirs_to_copy:
        src = os.path.join(BASE_DIR, d)
        if os.path.exists(src):
            shutil.copytree(src, os.path.join(pc_folder, d), ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))

    # PC Release Beni Oku
    pc_readme = os.path.join(pc_folder, "RELEASE_PC_SERVER.md")
    with open(pc_readme, "w", encoding="utf-8") as f:
        f.write(f"""# 🛡️ Ada SPARK Sıkıştırma Süiti - PC / Server Edition ({VERSION})
### STANAG-4586 & DO-178C Level-A Yer İstasyonu & Aviyonik Veri Sunucusu

Bu paket, **Yer Kontrol İstasyonları (GCS), Komuta Kontrol Merkezleri ve PC İş İstasyonları** için hazırlanmış tam sürüm paketidir.

---

## 🚀 Başlatma Seçenekleri

### 1. Masaüstü Grafik Arayüzü (PRO Beyaz Kokpit GUI):
`start.bat` dosyasına çift tıklayın veya terminalden:
```bash
python app.py
```
- Çoklu UDP portlarını ve algoritmalarını görsel tabloda eşzamanlı izleyin.
- Klasör ve dosyaları deterministik olarak `.tact` arşivine dönüştürün.
- SPARK DO-178C Level-A matematiksel doğrulamalarını çalıştırın.

### 2. Arka Plan Aviyonik Sunucusu (Headless Server Daemon):
`start_server.bat` dosyasına çift tıklayın veya:
```bash
python tactical_server.py --ports 5555:algo-8:decompress 5556:algo-6:decompress --log server_telemetry.log
```
- Gömülü istemcilerden gelen sıkıştırılmış paketleri sıfır GUI yüküyle çözer, doğrular ve loglar.

---
© 2026 Muhammet Atmaca. MIT Lisansı.
""")

    # Zip oluştur
    zip_path = os.path.join(DIST_DIR, f"Ada_SPARK_Compression_PC_Server_{VERSION}.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(pc_folder):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, DIST_DIR)
                zf.write(full_path, rel_path)

    shutil.rmtree(pc_folder)
    print(f"  [+] PC Sürümü Hazır: {zip_path} ({os.path.getsize(zip_path)/(1024*1024):.2f} MB)")
    return zip_path

def make_embedded_release():
    print("[*] 2/2: Gömülü Sistem Sürümü (İstemci / Airborne Client SDK) Paketleniyor...")
    emb_folder = os.path.join(DIST_DIR, f"Ada_SPARK_Compression_Embedded_Client_{VERSION}")
    if os.path.exists(emb_folder):
        shutil.rmtree(emb_folder)
    os.makedirs(emb_folder, exist_ok=True)

    src_emb_dir = os.path.join(BASE_DIR, "embedded_agent")
    for f in os.listdir(src_emb_dir):
        s = os.path.join(src_emb_dir, f)
        if os.path.isfile(s):
            shutil.copy2(s, emb_folder)

    # Kolaylık için tactical_client.py alias'ı
    agent_py = os.path.join(emb_folder, "tactical_embedded_agent.py")
    client_py = os.path.join(emb_folder, "tactical_client.py")
    if os.path.exists(agent_py) and not os.path.exists(client_py):
        shutil.copy2(agent_py, client_py)

    # Embedded Release Beni Oku
    emb_readme = os.path.join(emb_folder, "RELEASE_EMBEDDED_CLIENT.md")
    with open(emb_readme, "w", encoding="utf-8") as f:
        f.write(f"""# 📡 Ada SPARK Sıkıştırma - Embedded Client SDK ({VERSION})
### STANAG-4586 & DO-178C Level-A Gömülü İstemci Kiti

Hedef Donanımlar:
- Raspberry Pi (CM4, Pi 4, Pi 5)
- Nvidia Jetson (Nano, Orin, Xavier)
- NXP i.MX, BeagleBone, Zynq ARM SBC
- STM32, ESP32, FreeRTOS (C99 Çekirdeği ile)

---

## 🚀 1-Komutla Kurulum (Raspberry Pi / Jetson):
```bash
sudo ./install.sh
```

## 🛰️ Uçak / Verici Modu (Ham Al -> Sıkıştır -> Yer İstasyonuna Fırlat):
```bash
python3 tactical_client.py --mode tx --ip 0.0.0.0 --port 5555 --dest-ip 192.168.1.100 --dest-port 5555 --algo algo-8
```

## ⚡ Saf C99 İle Mikrodenetleyici / Bare-Metal Kullanımı:
```bash
make
./tactical_embedded_core tx 5555 192.168.1.100 5555
```

---
© 2026 Muhammet Atmaca. MIT Lisansı.
""")

    # 1. Tar.gz oluştur (Linux / Pi / Jetson için)
    tar_path = os.path.join(DIST_DIR, f"Ada_SPARK_Compression_Embedded_Client_{VERSION}.tar.gz")
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(emb_folder, arcname=f"Ada_SPARK_Compression_Embedded_Client_{VERSION}")

    # 2. Zip oluştur (Evrensel kullanım için)
    zip_path = os.path.join(DIST_DIR, f"Ada_SPARK_Compression_Embedded_Client_{VERSION}.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(emb_folder):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, DIST_DIR)
                zf.write(full_path, rel_path)

    shutil.rmtree(emb_folder)
    print(f"  [+] Gömülü Sürüm Hazır (tar.gz): {tar_path} ({os.path.getsize(tar_path)/1024:.1f} KB)")
    print(f"  [+] Gömülü Sürüm Hazır (zip)   : {zip_path} ({os.path.getsize(zip_path)/1024:.1f} KB)")
    return [tar_path, zip_path]

def main():
    print("==========================================================================")
    print("  ADA SPARK SIKIŞTIRMA SÜİTİ - SÜRÜM ÜRETİM ROBOTU (RELEASE BUILDER)      ")
    print(f"  Hedef Sürüm Etiketi: {VERSION}                                         ")
    print("==========================================================================")

    os.makedirs(DIST_DIR, exist_ok=True)

    artifacts = []
    artifacts.append(make_pc_release())
    artifacts.extend(make_embedded_release())

    # SHA256SUMS oluştur
    checksums_path = os.path.join(DIST_DIR, "SHA256SUMS.txt")
    with open(checksums_path, "w", encoding="utf-8") as f:
        for art in artifacts:
            fname = os.path.basename(art)
            sha = compute_sha256(art)
            f.write(f"{sha}  {fname}\n")

    print("\n==========================================================================")
    print("  TÜM SÜRÜMLER BAŞARIYLA PAKETLENDİ! ('dist/' klasöründe)                 ")
    print("==========================================================================")
    with open(checksums_path, "r", encoding="utf-8") as f:
        print(f.read())
    print("GitHub Releases veya doğrudan dağıtım için hazırdır.")

if __name__ == "__main__":
    main()
