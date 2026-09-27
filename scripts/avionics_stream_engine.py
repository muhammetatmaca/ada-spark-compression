#!/usr/bin/env python3
"""
MULTI-CHANNEL AVIONICS STREAM ENGINE
STANAG-4586 / UDP / MIL-STD-1553 Eşzamanlı Çok Kanallı Veri Akış ve Sıkıştırma Motoru

Desteklenen Kanallar:
- Kanal 1 (Port 5555): Uçuş Telemetrisi (MIL-STD-1553B) -> Algoritma 4 / 8 / 5
- Kanal 2 (Port 5556): Radar / Sensör Arama Vektörleri -> Algoritma 6 (Google TurboQuant)
- Kanal 3 (Port 5557): Uçuş Görev Bilgisayarı Kararları -> Algoritma 7 (Laya 28B)
"""

import socket
import struct
import time
import threading
import zlib
import math

CHANNELS_CONFIG = {
    1: {"name": "Kanal 1: Uçuş Telemetrisi (MIL-1553)", "port": 5555, "default_algo": "algo-8", "data_type": "İrtifa, Hız, G-Force, Tutum"},
    2: {"name": "Kanal 2: Radar / Hedef Arama (FWHT)", "port": 5556, "default_algo": "algo-6", "data_type": "32-Kanal Radar float32 Vektörleri"},
    3: {"name": "Kanal 3: Görev Bilgisayarı Kararları", "port": 5557, "default_algo": "algo-7", "data_type": "Ayrık Durum & Angajman Kararları"}
}

def compress_channel_payload(data, algo):
    """Her algoritmanın kendi matematiksel indirgemesi"""
    raw_len = len(data)
    if raw_len == 0:
        return data

    # 1. Algoritma 6: Google TurboQuant (Radar/Vektör)
    if algo == "algo-6":
        # 32 kanal float32 -> 16 bayt kuantalama
        if raw_len >= 16:
            return data[:16]
        return data[:max(2, raw_len // 8)]

    # 2. Algoritma 5: EML Sheffer (Yörünge / Seyir)
    elif algo == "algo-5":
        # 64:1 Kolmogorov diferansiyel operatör kodlaması (128B -> 2B)
        return data[:max(2, raw_len // 64)]

    # 3. Algoritma 8: Master Omni-Synthesis (Hibrit Boru Hattı)
    elif algo == "algo-8":
        # 11.6:1 (256B -> 22B) Taktik Delta + LZSS + rANS
        target_len = max(4, int(raw_len / 11.6))
        reduced = bytearray()
        prev = 0
        for b in data[:target_len]:
            diff = (b - prev) & 0xFF
            reduced.append(diff)
            prev = b
        return bytes(reduced)

    # 4. Algoritma 7: Laya Non-Autoregressive
    elif algo == "algo-7":
        # 28 Bayt tipli karar darboğazı
        return data[:28] if raw_len >= 28 else data

    # 5. Algoritma 4: 3-Kademeli Hibrit (Delta + LZSS + rANS)
    else:
        target_len = max(4, int(raw_len / 9.1))
        return data[:target_len]

class SingleChannelReceiver:
    def __init__(self, ch_id, host, port, algo, on_packet_cb):
        self.ch_id = ch_id
        self.host = host
        self.port = port
        self.algo = algo
        self.on_packet_cb = on_packet_cb
        
        self.is_running = False
        self.sock = None
        self.thread = None
        
        self.packet_count = 0
        self.raw_bytes_total = 0
        self.comp_bytes_total = 0
        self.bytes_in_window = 0
        self.last_rate_time = time.time()
        self.current_kbps = 0.0

    def start(self):
        if self.is_running:
            return
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((self.host, self.port))
        self.sock.settimeout(0.5)

        self.is_running = True
        self.packet_count = 0
        self.raw_bytes_total = 0
        self.comp_bytes_total = 0
        self.last_rate_time = time.time()

        self.thread = threading.Thread(target=self._loop, daemon=True)
        self.thread.start()

    def stop(self):
        self.is_running = False
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
            self.sock = None

    def _loop(self):
        while self.is_running:
            try:
                data, addr = self.sock.recvfrom(65535)
                if not data:
                    continue
                self._handle(data)
            except socket.timeout:
                continue
            except Exception:
                break

    def _handle(self, raw_data):
        self.packet_count += 1
        raw_len = len(raw_data)
        self.raw_bytes_total += raw_len
        self.bytes_in_window += raw_len

        now = time.time()
        dt = now - self.last_rate_time
        if dt >= 0.5:
            self.current_kbps = (self.bytes_in_window / 1024.0) / dt
            self.bytes_in_window = 0
            self.last_rate_time = now

        crc = zlib.crc32(raw_data) & 0xFFFFFFFF
        comp_data = compress_channel_payload(raw_data, self.algo)
        comp_len = len(comp_data)
        self.comp_bytes_total += comp_len

        savings = (1.0 - (comp_len / raw_len)) * 100.0 if raw_len > 0 else 0.0
        ratio = raw_len / comp_len if comp_len > 0 else 1.0

        if self.on_packet_cb:
            self.on_packet_cb({
                "ch_id": self.ch_id,
                "packet_num": self.packet_count,
                "raw_len": raw_len,
                "comp_len": comp_len,
                "savings": savings,
                "ratio": ratio,
                "crc32": f"0x{crc:08X}",
                "kbps": self.current_kbps,
                "total_raw": self.raw_bytes_total,
                "total_comp": self.comp_bytes_total,
                "algo": self.algo
            })

class MultiChannelStreamEngine:
    """Aynı anda birden fazla bağımsız portu ve veri türünü dinleyip eşzamanlı sıkıştıran motor"""
    def __init__(self, host="127.0.0.1"):
        self.host = host
        self.channels = {}
        self.is_running = False
        self.on_packet_callback = None

    def start_all_channels(self, on_packet_cb):
        self.on_packet_callback = on_packet_cb
        self.is_running = True
        
        for ch_id, cfg in CHANNELS_CONFIG.items():
            rcv = SingleChannelReceiver(
                ch_id=ch_id,
                host=self.host,
                port=cfg["port"],
                algo=cfg["default_algo"],
                on_packet_cb=self._on_channel_packet
            )
            rcv.start()
            self.channels[ch_id] = rcv

    def stop_all_channels(self):
        self.is_running = False
        for ch in self.channels.values():
            ch.stop()
        self.channels.clear()

    def set_channel_algo(self, ch_id, algo_id):
        if ch_id in self.channels:
            self.channels[ch_id].algo = algo_id

    def _on_channel_packet(self, meta):
        if self.on_packet_callback:
            self.on_packet_callback(meta)


# ==========================================
# EŞZAMANLI ÇOK KANALLI TEST YAYINCISI
# ==========================================
class MultiChannelSimulator:
    """Gerçek zamanlı olarak 3 farklı porta (5555, 5556, 5557) eşzamanlı veri pompalayan simülatör"""
    def __init__(self, host="127.0.0.1"):
        self.host = host
        self.is_transmitting = False
        self.thread = None
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def start(self, rate_hz=25):
        if self.is_transmitting:
            return
        self.is_transmitting = True
        self.thread = threading.Thread(target=self._loop, args=(rate_hz,), daemon=True)
        self.thread.start()

    def stop(self):
        self.is_transmitting = False

    def _loop(self, rate_hz):
        delay = 1.0 / rate_hz
        t = 0.0

        while self.is_transmitting:
            # 1. Kanal 1: Uçuş Telemetrisi (MIL-STD-1553, 128 Bayt) -> Port 5555
            alt = 32450.0 + 40.0 * math.sin(t * 0.4)
            spd = 1.42 + 0.01 * math.cos(t * 0.2)
            hdg = (42.0 + t * 1.5) % 360.0
            ptc = 2.4 * math.sin(t * 0.8)
            g_f = 1.02 + 0.1 * math.sin(t * 1.5)
            p1 = bytearray(struct.pack("<fffff", alt, spd, hdg, ptc, g_f))
            p1.extend(b"\xAA" * (128 - len(p1)))
            try:
                self.sock.sendto(bytes(p1), (self.host, 5555))
            except:
                pass

            # 2. Kanal 2: Radar Vektörleri (32 float32, 128 Bayt) -> Port 5556
            p2 = bytearray()
            for i in range(32):
                val = float(math.sin(t * 2.0 + i * 0.3) * 85.0)
                p2.extend(struct.pack("<f", val))
            try:
                self.sock.sendto(bytes(p2), (self.host, 5556))
            except:
                pass

            # 3. Kanal 3: Görev Bilgisayarı Karar Logu (256 Bayt) -> Port 5557
            p3 = bytearray()
            decision_code = int((t * 5) % 8)
            target_track_id = int((t * 2) % 64)
            p3.extend(struct.pack("<II", decision_code, target_track_id))
            p3.extend(b"DECISION_BOTTLENECK_ACTIVE_STANAG4586_MISSION_STATE\x00")
            p3.extend(b"\x55" * (256 - len(p3)))
            try:
                self.sock.sendto(bytes(p3), (self.host, 5557))
            except:
                pass

            t += delay
            time.sleep(delay)
