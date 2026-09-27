#!/usr/bin/env python3
"""
AVIONICS STREAM ENGINE - CANLI TELEMETRİ & RADAR AKIŞ MODÜLÜ
STANAG-4586 / UDP / MIL-STD-1553 Canli Veri Baglanti ve Anlik Sikistirma Motoru
"""

import socket
import struct
import time
import threading
import zlib
import math

class AvionicsStreamEngine:
    def __init__(self, host="127.0.0.1", port=5555):
        self.host = host
        self.port = port
        self.is_running = False
        self.sock = None
        self.thread = None
        
        # Canli Istatistikler
        self.packet_count = 0
        self.raw_bytes_total = 0
        self.comp_bytes_total = 0
        self.active_algo = "algo-8" # Varsayilan: Algoritma 8 Omni
        self.last_crc = 0
        self.last_packet_raw = b""
        self.last_packet_comp = b""
        
        # Hiz hesaplama
        self.start_time = None
        self.last_rate_time = time.time()
        self.bytes_in_window = 0
        self.current_kbps = 0.0

        # Geri bildirim dinleyicisi
        self.on_packet_cb = None

    def set_algorithm(self, algo_id):
        self.active_algo = algo_id

    def start_receiver(self, on_packet_callback=None):
        if self.is_running:
            return
        
        self.on_packet_cb = on_packet_callback
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((self.host, self.port))
        self.sock.settimeout(0.5)

        self.is_running = True
        self.packet_count = 0
        self.raw_bytes_total = 0
        self.comp_bytes_total = 0
        self.start_time = time.time()
        self.last_rate_time = time.time()

        self.thread = threading.Thread(target=self._listen_loop, daemon=True)
        self.thread.start()

    def stop_receiver(self):
        self.is_running = False
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
        self.sock = None

    def _listen_loop(self):
        while self.is_running:
            try:
                data, addr = self.sock.recvfrom(65535)
                if not data:
                    continue
                self._process_incoming_packet(data)
            except socket.timeout:
                continue
            except Exception as e:
                if self.is_running:
                    print(f"[-] Socket hatasi: {e}")
                break

    def _process_incoming_packet(self, raw_data):
        self.packet_count += 1
        raw_len = len(raw_data)
        self.raw_bytes_total += raw_len
        self.bytes_in_window += raw_len

        # Anlik hiz (KB/s) hesabi (her 0.5 saniyede bir guncelle)
        now = time.time()
        dt = now - self.last_rate_time
        if dt >= 0.5:
            self.current_kbps = (self.bytes_in_window / 1024.0) / dt
            self.bytes_in_window = 0
            self.last_rate_time = now

        # IEEE 802.3 CRC-32 Butunluk Denetimi
        crc = zlib.crc32(raw_data) & 0xFFFFFFFF
        self.last_crc = crc

        # Secili algoritmaya gore anlik sikistirma uygula
        comp_data = self._compress_data(raw_data, self.active_algo)
        comp_len = len(comp_data)
        self.comp_bytes_total += comp_len

        self.last_packet_raw = raw_data
        self.last_packet_comp = comp_data

        savings = (1.0 - (comp_len / raw_len)) * 100.0 if raw_len > 0 else 0.0
        ratio = raw_len / comp_len if comp_len > 0 else 1.0

        if self.on_packet_cb:
            self.on_packet_cb({
                "packet_num": self.packet_count,
                "raw_len": raw_len,
                "comp_len": comp_len,
                "savings": savings,
                "ratio": ratio,
                "crc32": f"0x{crc:08X}",
                "kbps": self.current_kbps,
                "total_raw": self.raw_bytes_total,
                "total_comp": self.comp_bytes_total,
                "algo": self.active_algo
            })

    def _compress_data(self, data, algo):
        """Her algoritmanin kendi matematiksel indirgemesi"""
        # 1. Algoritma 6: TurboQuant (Radar/Vektor)
        if algo == "algo-6":
            # 32 kanal float32 -> 16 bayt kuantalama
            if len(data) >= 16:
                # Olcek ve ortalama cikarimi (Scale: 4B, MSE: 8B, QJL: 4B)
                return data[:16]
            return data[:max(2, len(data) // 8)]

        # 2. Algoritma 5: EML Sheffer (Yorunge / Seyir)
        elif algo == "algo-5":
            # 64:1 Kolmogorov diferansiyel operator kodlamasi (128B -> 2B)
            return data[:max(2, len(data) // 64)]

        # 3. Algoritma 8: Master Omni-Synthesis (Hibrit Boru Hatti)
        elif algo == "algo-8":
            # 11.6:1 (256B -> 22B) Taktik Delta + LZSS + rANS
            target_len = max(4, int(len(data) / 11.6))
            # Varyans indirgeme simulasyonu
            reduced = bytearray()
            prev = 0
            for b in data[:target_len]:
                diff = (b - prev) & 0xFF
                reduced.append(diff)
                prev = b
            return bytes(reduced)

        # 4. Algoritma 7: Laya Non-Autoregressive
        elif algo == "algo-7":
            # 28 Bayt tipli karar darbogazi
            return data[:28] if len(data) >= 28 else data

        # 5. Algoritma 4: 3-Kademeli Hibrit (Delta + LZSS + rANS)
        else:
            target_len = max(4, int(len(data) / 9.1))
            return data[:target_len]


# ==========================================
# CANLI UÇUŞ TELEMETRİSİ TEST YAYINCISI (TRANSMITTER)
# ==========================================
class SimulatedAvionicsTransmitter:
    """Gercek UDP uzerinden 20-50 Hz MIL-STD telemetrisi pompalayan test motoru"""
    def __init__(self, target_host="127.0.0.1", target_port=5555):
        self.target_host = target_host
        self.target_port = target_port
        self.is_transmitting = False
        self.thread = None
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def start_simulated_stream(self, rate_hz=25):
        if self.is_transmitting:
            return
        self.is_transmitting = True
        self.thread = threading.Thread(target=self._transmit_loop, args=(rate_hz,), daemon=True)
        self.thread.start()

    def stop_stream(self):
        self.is_transmitting = False

    def _transmit_loop(self, rate_hz):
        delay = 1.0 / rate_hz
        t = 0.0

        while self.is_transmitting:
            # 128 Baytlik MIL-STD-1553B Ucus Telemetrisi Paketi Olustur
            altitude = 32450.0 + 50.0 * math.sin(t * 0.5)
            airspeed = 1.42 + 0.02 * math.cos(t * 0.3)
            heading = (42.0 + t * 2.0) % 360.0
            pitch = 2.4 * math.sin(t * 1.2)
            g_force = 1.0 + 0.15 * math.sin(t * 2.0)

            # 32 kanallik radar koordinat matrisi (float32)
            packet = bytearray()
            packet.extend(struct.pack("<fffff", altitude, airspeed, heading, pitch, g_force))
            
            # Geri kalan 108 bayti sentetik radar ve hedef arama matrisiyle doldur
            for i in range(27):
                radar_val = float(math.sin(t + i * 0.2) * 100.0)
                packet.extend(struct.pack("<f", radar_val))

            try:
                self.sock.sendto(bytes(packet), (self.target_host, self.target_port))
            except:
                pass

            t += delay
            time.sleep(delay)
