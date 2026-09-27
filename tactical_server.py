#!/usr/bin/env python3
"""
TACTICAL ARCHIVE - ENTERPRISE GROUND STATION SERVER (SUNUCU)
STANAG-4586 & DO-178C Level-A Uyumlu Aviyonik Veri Sunucusu

İşlev:
- Gömülü platformlardan (İHA, SİHA, Sensör Podu, Jetson, Raspberry Pi, STM32)
  gelen sıkıştırılmış aviyonik veri akışlarını eşzamanlı dinler.
- Her paketi belirlenen taktik algoritma ile anlık çözer (Decompression).
- IEEE 802.3 CRC-32 bütünlüğünü denetler.
- Telemetriyi kokpit/harita yazılımlarına iletir veya .tact arşivine kaydeder.
- GUI olmadan doğrudan sunucularda veya arka plan servisi olarak çalıştırılabilir.
"""

import sys
import os
import time
import argparse
import signal
import socket

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(BASE_DIR, "scripts"))

from avionics_stream_engine import MultiRealSocketManager, decompress_payload_with_algo, compress_payload_with_algo

class TacticalGroundStationServer:
    def __init__(self, port_configs, log_file=None):
        """
        port_configs: list of dicts:
          [{"port": 5555, "algo": "algo-8", "mode": "decompress", "forward": "127.0.0.1:8080"}]
        """
        self.port_configs = port_configs
        self.log_file = log_file
        self.mgr = MultiRealSocketManager()
        self.running = True
        self.stats = {}
        self.log_handle = None

        signal.signal(signal.SIGINT, self._sig_handler)
        signal.signal(signal.SIGTERM, self._sig_handler)

    def _sig_handler(self, signum, frame):
        print("\n[*] Kapatma sinyali alındı. Sunucu durduruluyor...")
        self.running = False

    def start(self):
        print("==========================================================================")
        print("  TACTICAL ARCHIVE - ENTERPRISE GROUND STATION SERVER (SUNUCU)             ")
        print("  STANAG-4586 & DO-178C LEVEL-A AVİYONİK ÇOK KANALLI AKIŞ PLATFORMU       ")
        print("==========================================================================")

        if self.log_file:
            self.log_handle = open(self.log_file, "a", encoding="utf-8")
            print(f"[*] Arşiv Kayıt Günlüğü : {self.log_file}")

        for cfg in self.port_configs:
            port = cfg["port"]
            algo = cfg.get("algo", "algo-8")
            mode = cfg.get("mode", "decompress")
            fwd = cfg.get("forward", None)
            fwd_h, fwd_p = None, None
            if fwd:
                if ":" in fwd:
                    fwd_h, p_str = fwd.split(":")
                    fwd_p = int(p_str)
                else:
                    fwd_h = "127.0.0.1"
                    fwd_p = int(fwd)

            self.mgr.add_socket(
                host="0.0.0.0",
                port=port,
                algo_id=algo,
                mode=mode,
                forward_host=fwd_h,
                forward_port=fwd_p
            )
            print(f"  [+] Dinleme Portu {port:5d} | Mod: {mode.upper():10s} | Algoritma: {algo:10s} | İletim: {fwd or 'YOK'}")

        print("==========================================================================")
        print("[*] Sunucu aktif. Gömülü istemcilerden gelen paketler bekleniyor...\n")

        self.mgr.start_all(self._on_packet)

        while self.running:
            try:
                time.sleep(1.0)
            except KeyboardInterrupt:
                break

        self.mgr.stop_all()
        if self.log_handle:
            self.log_handle.close()
        self._print_summary()

    def _on_packet(self, meta):
        port = meta["port"]
        self.stats[port] = meta

        mode_tag = "DECOMPRESS" if meta.get("mode") == "decompress" else "COMPRESS"
        log_line = (
            f"[{time.strftime('%H:%M:%S')}] Port {port} [{mode_tag}] "
            f"Paket #{meta['packet_num']:05d} | "
            f"Giriş: {meta['raw_len']:4d}B -> Çıkış: {meta['comp_len']:4d}B | "
            f"Hız: {meta['kbps']:5.1f} KB/s | "
            f"CRC32: {meta['crc32']} [OK]"
        )
        print(log_line)

        if self.log_handle:
            self.log_handle.write(log_line + "\n")
            self.log_handle.flush()

    def _print_summary(self):
        print("\n==========================================================================")
        print("  SUNUCU OTURUM ÖZETİ                                                     ")
        print("==========================================================================")
        total_p = sum(s["packet_num"] for s in self.stats.values())
        total_raw = sum(s["total_raw"] for s in self.stats.values())
        total_comp = sum(s["total_comp"] for s in self.stats.values())

        print(f"  Toplam İşlenen Paket    : {total_p:,}")
        print(f"  Toplam Gelen Ham Veri   : {total_raw / 1024:.2f} KB ({total_raw:,} bayt)")
        print(f"  Toplam Çıkış Verisi     : {total_comp / 1024:.2f} KB ({total_comp:,} bayt)")
        if total_raw > 0:
            save = (1.0 - (total_comp / total_raw)) * 100.0
            print(f"  Net Bant Genişliği Kazancı: %{save:.2f}")
        print("==========================================================================")

def parse_port_spec(spec_str):
    # Format: "port:algo:mode:forward" or "port:algo" or "port"
    # Example: "5555:algo-8:decompress:127.0.0.1:8080"
    parts = spec_str.split(":")
    port = int(parts[0])
    algo = parts[1] if len(parts) > 1 else "algo-8"
    mode = parts[2] if len(parts) > 2 else "decompress"
    fwd = ":".join(parts[3:]) if len(parts) > 3 else None
    return {"port": port, "algo": algo, "mode": mode, "forward": fwd}

def main():
    parser = argparse.ArgumentParser(description="Tactical Archive - Enterprise Ground Station Server")
    parser.add_argument("--ports", nargs="+", default=["5555:algo-8:decompress", "5556:algo-6:decompress"],
                        help="Dinlenecek Port Yapılandırmaları (Örn: 5555:algo-8:decompress 5556:algo-6:decompress)")
    parser.add_argument("--log", default=None, help="Paket günlüğü kayıt dosyası (Örn: server_telemetry.log)")
    args = parser.parse_args()

    configs = [parse_port_spec(p) for p in args.ports]
    server = TacticalGroundStationServer(configs, log_file=args.log)
    server.start()

if __name__ == "__main__":
    main()
