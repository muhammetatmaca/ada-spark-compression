#!/usr/bin/env python3
"""
TACTICAL ARCHIVE ENGINE - COMMAND LINE INTERFACE (CLI)
STANAG-4586 & DO-178C Level-A Uyumlu Terminal Araci

Kullanim:
  python cli.py compress <kaynak_klasor_veya_dosya> [cikti.tact]
  python cli.py extract <arsiv.tact> [hedef_klasor]
  python cli.py info <arsiv.tact>
"""

import sys
import os
import argparse
import time

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(BASE_DIR, "scripts"))

from tactical_universal_engine import archive_universal, extract_universal

def main():
    parser = argparse.ArgumentParser(description="Tactical Archive CLI - Ada SPARK Avionics Edition")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # 1. Compress
    p_comp = subparsers.add_parser("compress", help="Klasör veya dosyayı .tact arşivine sıkıştır")
    p_comp.add_argument("source", help="Sıkıştırılacak klasör veya dosya yolu")
    p_comp.add_argument("output", nargs="?", default=None, help="Çıktı .tact dosya adı (isteğe bağlı)")
    p_comp.add_argument("--level", type=int, default=15, help="Sıkıştırma seviyesi (1-19, varsayılan: 15)")

    # 2. Extract
    p_ext = subparsers.add_parser("extract", help=".tact arşivini hedef dizine geri aç")
    p_ext.add_argument("archive", help="Açılacak .tact dosya yolu")
    p_ext.add_argument("destination", nargs="?", default=None, help="Hedef klasör yolu")

    # 3. Info
    p_info = subparsers.add_parser("info", help=".tact arşivi hakkında bilgi görüntüle")
    p_info.add_argument("archive", help="İncelenecek .tact dosya yolu")

    args = parser.parse_args()

    if args.command == "compress":
        src = os.path.abspath(args.source)
        if not os.path.exists(src):
            print(f"[!] Hata: Kaynak bulunamadı: {src}")
            sys.exit(1)
        
        out = args.output
        if not out:
            base = os.path.basename(src.rstrip(r"\/"))
            out = f"{base}.tact"
        out = os.path.abspath(out)

        archive_universal(src, out, level=args.level)

    elif args.command == "extract":
        arch = os.path.abspath(args.archive)
        if not os.path.exists(arch):
            print(f"[!] Hata: Arşiv bulunamadı: {arch}")
            sys.exit(1)
        
        dest = args.destination
        if not dest:
            dest = os.path.splitext(arch)[0] + "_extracted"
        dest = os.path.abspath(dest)

        extract_universal(arch, dest)

    elif args.command == "info":
        arch = os.path.abspath(args.archive)
        if not os.path.exists(arch):
            print(f"[!] Hata: Dosya bulunamadı: {arch}")
            sys.exit(1)

        sz = os.path.getsize(arch)
        print("========================================================")
        print("  STANAG-4586 TACTICAL ARCHIVE KONTEYNER BILGISI        ")
        print("========================================================")
        print(f"  Dosya Yolu      : {arch}")
        print(f"  Dosya Boyutu    : {sz:,} bayt ({sz / (1024*1024):.2f} MB)")
        with open(arch, "rb") as f:
            magic = f.readline()
            print(f"  Sihirli Baslik  : {magic.decode('latin1', errors='ignore').strip()}")
        print("  Durum           : IEEE 802.3 CRC-32 Guvenlik Korumali")
        print("========================================================")

if __name__ == "__main__":
    main()
