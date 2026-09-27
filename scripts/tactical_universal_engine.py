#!/usr/bin/env python3
"""
STANAG-MIL TACTICAL UNIVERSAL RECURSIVE ARCHIVE ENGINE (.tact)
Tum alt klasorleri, dosyalari, baglantilari ve izinleri hicbir sey atmadan
tamamen ozyinelemeli (recursive) ve kayipsiz olarak sikistiran motor.
"""

import os
import sys
import time
import tarfile
import zstandard as zstd

MAGIC = b"TACT-UNIVERSAL-V3\n"

class ProgressTar:
    def __init__(self, tar, report_interval=5000):
        self.tar = tar
        self.count = 0
        self.total_bytes = 0
        self.start_time = time.time()
        self.report_interval = report_interval

    def add(self, path, arcname):
        self.tar.add(path, arcname=arcname, recursive=False)
        self.count += 1
        if os.path.isfile(path) and not os.path.islink(path):
            try:
                self.total_bytes += os.path.getsize(path)
            except:
                pass
        if self.count % self.report_interval == 0:
            elapsed = time.time() - self.start_time
            mb = self.total_bytes / (1024 * 1024)
            speed = mb / elapsed if elapsed > 0 else 0
            print(f"  [>] {self.count:,} oge islendi ({mb:.1f} MB ham veri, {speed:.1f} MB/s)...")

def archive_universal(src_dir, output_tact, level=19):
    src_dir = os.path.abspath(src_dir)
    print("========================================================")
    print("  STANAG-MIL UNIVERSAL OZYINELEMELI KLASOR ARSIVLEME    ")
    print(f"  HEDEF KLASOR : {src_dir}")
    print(f"  CIKTI ARSIVI : {output_tact}")
    print(f"  SIKISTIRMA   : Zstandard Level {level} (Cok Cekirdekli Paralel)")
    print("========================================================")

    t0 = time.time()

    # Zstandard cok cekirdekli akis sikistirici
    cctx = zstd.ZstdCompressor(level=level, threads=-1)

    with open(output_tact, "wb") as f_out:
        f_out.write(MAGIC)
        
        with cctx.stream_writer(f_out) as compressor:
            with tarfile.open(fileobj=compressor, mode="w|") as tar:
                ptar = ProgressTar(tar, report_interval=5000)
                
                # Ozyinelemeli olarak tum klasor agacini ekle
                for root, dirs, files in os.walk(src_dir):
                    # Once alt dizini ekle
                    rel_dir = os.path.relpath(root, src_dir)
                    if rel_dir != ".":
                        ptar.add(root, arcname=rel_dir)
                    
                    # Sonra icindeki dosyalari ekle
                    for f in files:
                        full_path = os.path.join(root, f)
                        if rel_dir == ".":
                            arcname = f
                        else:
                            arcname = os.path.join(rel_dir, f)
                        ptar.add(full_path, arcname=arcname)

    elapsed = time.time() - t0
    raw_size = ptar.total_bytes
    tact_size = os.path.getsize(output_tact)
    ratio = raw_size / tact_size if tact_size > 0 else 1.0
    savings = (1.0 - tact_size / raw_size) * 100.0 if raw_size > 0 else 0.0

    print("\n========================================================")
    print("  TUM KLASOR BASARIYLA ARSIVLENDI VE SIKISTIRILDI!      ")
    print("========================================================")
    print(f"[+] Toplam Islenen Oge      : {ptar.count:,} (Dosyalar ve Klasorler)")
    print(f"[+] Toplam Ham Boyut        : {raw_size:,} bayt ({raw_size / (1024*1024):.2f} MB)")
    print(f"[+] Sıkıştırılmış .tact     : {tact_size:,} bayt ({tact_size / (1024*1024):.2f} MB)")
    print(f"[+] Net Tasarruf            : %{savings:.2f}")
    print(f"[+] Sıkıştırma Oranı        : {ratio:.2f} : 1")
    print(f"[+] Gecen Sure              : {elapsed:.2f} saniye (Ort. {raw_size/(1024*1024)/elapsed:.1f} MB/s)")
    print(f"[+] STANAG Konteyner        : {output_tact}")
    print("========================================================\n")
    return tact_size

def extract_universal(tact_path, dest_dir):
    print("========================================================")
    print("  STANAG-MIL UNIVERSAL ARSIV GERI ACMA & DOGRULAMA      ")
    print(f"  ARSIV DOSYASI: {tact_path}")
    print(f"  HEDEF KLASOR : {dest_dir}")
    print("========================================================")

    t0 = time.time()
    os.makedirs(dest_dir, exist_ok=True)

    with open(tact_path, "rb") as f_in:
        magic = f_in.read(len(MAGIC))
        if magic != MAGIC:
            raise ValueError(f"Gecersiz TACT arsiv basligi: {magic}")

        dctx = zstd.ZstdDecompressor()
        with dctx.stream_reader(f_in) as decompressor:
            with tarfile.open(fileobj=decompressor, mode="r|") as tar:
                count = 0
                for member in tar:
                    tar.extract(member, path=dest_dir)
                    count += 1
                    if count % 10000 == 0:
                        print(f"  [<] {count:,} oge geri acildi...")

    elapsed = time.time() - t0
    print(f"[+] Basariyla {count:,} dosya ve klasor '{dest_dir}' dizinine eksiksiz acildi.")
    print(f"[+] Geri Acma Suresi : {elapsed:.2f} saniye")
    print("========================================================\n")

if __name__ == "__main__":
    src = r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio"
    out_tact = r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact"

    # Seviye 15: Cok hizli ve yuksek sikistirma dengesi (1 GB icin ideal)
    archive_universal(src, out_tact, level=15)
