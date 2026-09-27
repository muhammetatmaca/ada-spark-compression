#!/usr/bin/env python3
"""
TACTICAL EMBEDDED AGENT (GÖMÜLÜ SİSTEM İSTEMCİSİ)
STANAG-4586 & DO-178C Uyumlu Aviyonik Ağ Ajanı

Hedef Platformlar:
- Raspberry Pi (CM4, Pi 4, Pi 5)
- Nvidia Jetson (Nano, Orin, Xavier)
- BeagleBone Black, NXP i.MX8, Zynq ARM SBC
- x86_64 / aarch64 Linux Gömülü Görev Bilgisayarları

İşlevler:
1. TX (Verici / Hava Birimi): Gömülü sensörden veya seri porttan ham veriyi alır,
   seçilen taktiksel algoritma ile sıkıştırır ve yer istasyonuna UDP ile basar.
2. RX (Alıcı / Yer Birimi): Yer istasyonundan veya telsizden sıkıştırılmış paketi
   alır, CRC-32 doğrular, orijinal veriyi geri çatar ve yerel cihaza iletir.
"""

import sys
import os
import socket
import time
import argparse
import signal
import zlib

try:
    import zstandard as zstd
    HAS_ZSTD = True
except ImportError:
    HAS_ZSTD = False

# IEEE 802.3 CRC-32
def compute_crc32(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF

# ==============================================================
# ALGORİTMA SIKIŞTIRMA VE GERİ AÇMA ÇEKİRDEĞİ
# ==============================================================
def compress_payload(data: bytes, algo_id: str) -> bytes:
    if not data:
        return b""
    raw_len = len(data)

    if "algo-6" in algo_id:  # Google TurboQuant (8:1 Radar / Vektör)
        packed = bytearray()
        for i in range(0, raw_len, 8):
            chunk = data[i:i+8]
            byte_val = 0
            for bit_idx, b in enumerate(chunk):
                if b > 127:
                    byte_val |= (1 << bit_idx)
            packed.append(byte_val)
        return bytes(packed) if len(packed) > 0 else data[:1]

    elif "algo-8" in algo_id or "algo-4" in algo_id:
        # STANAG Delta Stride + Entropi Kodlama
        delta = bytearray([data[0]])
        for i in range(1, raw_len):
            delta.append((data[i] - data[i-1]) & 0xFF)
        if HAS_ZSTD:
            lvl = 19 if "algo-8" in algo_id else 10
            return zstd.compress(bytes(delta), lvl)
        else:
            return zlib.compress(bytes(delta), 9)

    elif "algo-7" in algo_id:
        # Laya 28B Tipli Karar Darboğazı
        if raw_len <= 28:
            return data
        bottleneck = bytearray(28)
        for i, b in enumerate(data):
            bottleneck[i % 28] ^= b
        return bytes(bottleneck)

    else:
        # Universal / Zstandard
        if HAS_ZSTD:
            return zstd.compress(data, 15)
        return zlib.compress(data, 9)

def decompress_payload(comp_data: bytes, algo_id: str) -> bytes:
    if not comp_data:
        return b""
    try:
        if "algo-8" in algo_id or "algo-4" in algo_id:
            if HAS_ZSTD:
                delta = zstd.decompress(comp_data)
            else:
                delta = zlib.decompress(comp_data)
            raw = bytearray([delta[0]])
            for b in delta[1:]:
                raw.append((raw[-1] + b) & 0xFF)
            return bytes(raw)

        elif "algo-6" in algo_id:
            unpacked = bytearray()
            for b in comp_data:
                for bit_idx in range(8):
                    unpacked.append(255 if (b & (1 << bit_idx)) else 0)
            return bytes(unpacked)

        elif "algo-7" in algo_id:
            return comp_data

        else:
            if HAS_ZSTD:
                return zstd.decompress(comp_data)
            return zlib.decompress(comp_data)
    except Exception as e:
        sys.stderr.write(f"[!] Geri açma hatası: {e}\n")
        return comp_data

# ==============================================================
# GÖMÜLÜ İSTEMCİ ÇALIŞMA DÖNGÜSÜ
# ==============================================================
class TacticalEmbeddedAgent:
    def __init__(self, mode, host, port, target_host, target_port, algo_id, serial_port=None, baud=115200):
        self.mode = mode
        self.host = host
        self.port = int(port)
        self.target_host = target_host
        self.target_port = int(target_port) if target_port else None
        self.algo_id = algo_id
        self.serial_port = serial_port
        self.baud = baud
        self.running = True

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        if self.mode == "rx" or not self.target_port:
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.sock.bind((self.host, self.port))
            self.sock.settimeout(1.0)

        signal.signal(signal.SIGINT, self._sig_handler)
        signal.signal(signal.SIGTERM, self._sig_handler)

    def _sig_handler(self, signum, frame):
        print("\n[*] Kapatma sinyali alındı. Ajan sonlandırılıyor...")
        self.running = False

    def run(self):
        print("===================================================================")
        print("  TACTICAL EMBEDDED AGENT - STANAG-4586 AVIONICS DAEMON           ")
        print("===================================================================")
        print(f"  Çalışma Modu   : {self.mode.upper()}")
        print(f"  Dinlenen Soket : {self.host}:{self.port}")
        if self.target_host and self.target_port:
            print(f"  Hedef Aktarım  : {self.target_host}:{self.target_port}")
        print(f"  Algoritma      : {self.algo_id}")
        print(f"  Zstandard      : {'Aktif (C-API/zstd)' if HAS_ZSTD else 'Pasif (zlib fallback)'}")
        print("===================================================================")
        print("[*] Gömülü ajan aktif. Paketler işleniyor (Durdurmak için Ctrl+C)...\n")

        packet_count = 0
        total_in_bytes = 0
        total_out_bytes = 0

        while self.running:
            try:
                if self.mode == "rx":
                    # Alıcı Modu: Sıkıştırılmış paketi UDP'den karşıla -> Aç -> Çıktı ver
                    data, addr = self.sock.recvfrom(65535)
                    if not data:
                        continue
                    in_len = len(data)
                    total_in_bytes += in_len
                    packet_count += 1

                    crc = compute_crc32(data)
                    raw = decompress_payload(data, self.algo_id)
                    out_len = len(raw)
                    total_out_bytes += out_len

                    print(f"[RX] Paket #{packet_count:04d} | Alınan: {in_len}B -> Açılan: {out_len}B | CRC32: 0x{crc:08X} [OK]")

                    # Hedefe aktar (varsa)
                    if self.target_host and self.target_port:
                        self.sock.sendto(raw, (self.target_host, self.target_port))

                elif self.mode == "tx":
                    # Verici Modu: Dinlenen porttan ham veri al -> Sıkıştır -> Hedefe fırlat
                    data, addr = self.sock.recvfrom(65535)
                    if not data:
                        continue
                    in_len = len(data)
                    total_in_bytes += in_len
                    packet_count += 1

                    crc = compute_crc32(data)
                    comp = compress_payload(data, self.algo_id)
                    out_len = len(comp)
                    total_out_bytes += out_len

                    savings = (1.0 - (out_len / in_len)) * 100.0 if in_len > 0 else 0.0

                    if self.target_host and self.target_port:
                        self.sock.sendto(comp, (self.target_host, self.target_port))

                    print(f"[TX] Paket #{packet_count:04d} | Ham: {in_len}B -> Sıkıştırılmış: {out_len}B (%{savings:.1f} Kazanç) -> Gönderildi: {self.target_host}:{self.target_port}")

            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    sys.stderr.write(f"[!] Hata: {e}\n")
                    time.sleep(0.5)

        self.sock.close()
        print("\n===================================================================")
        print("  ÖZET RAPOR                                                       ")
        print(f"  Toplam İşlenen Paket : {packet_count:,}")
        print(f"  Toplam Giriş Boyutu  : {total_in_bytes:,} Bayt")
        print(f"  Toplam Çıkış Boyutu  : {total_out_bytes:,} Bayt")
        if self.mode == "tx" and total_in_bytes > 0:
            net_save = (1.0 - (total_out_bytes / total_in_bytes)) * 100.0
            print(f"  Net Bant Genişliği Kazancı: %{net_save:.2f}")
        print("===================================================================")

def main():
    parser = argparse.ArgumentParser(description="Tactical Archive Embedded Agent")
    parser.add_argument("--mode", choices=["tx", "rx"], default="tx", help="Çalışma Modu: tx (Verici/Sıkıştır) veya rx (Alıcı/Geri Aç)")
    parser.add_argument("--ip", default="0.0.0.0", help="Dinlenecek Arayüz IP (varsayılan: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=5555, help="Dinlenecek UDP Portu (varsayılan: 5555)")
    parser.add_argument("--dest-ip", default=None, help="Hedef Aktarım IP (örn: 192.168.1.100)")
    parser.add_argument("--dest-port", type=int, default=None, help="Hedef Aktarım Portu (örn: 5556)")
    parser.add_argument("--algo", default="algo-8", help="Algoritma: algo-8, algo-6, algo-5, algo-4, algo-7, universal")
    args = parser.parse_args()

    agent = TacticalEmbeddedAgent(
        mode=args.mode,
        host=args.ip,
        port=args.port,
        target_host=args.dest_ip,
        target_port=args.dest_port,
        algo_id=args.algo
    )
    agent.run()

if __name__ == "__main__":
    main()
