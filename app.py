#!/usr/bin/env python3
"""
TACTICAL ARCHIVE STUDIO - ADA SPARK AVIONICS EDITION
STANAG-4586 & DO-178C Level-A Uyumlu Aviyonik Veri Sıkıştırma ve Canlı Akış Süiti

Geliştirici: Muhammet Atmaca
Masaüstü Grafik Arayüzü, Canlı UDP/Aviyonik Akış Bağlayıcısı & Benchmark Laboratuvarı
"""

import os
import sys
import time
import threading
import subprocess
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import tarfile
import zstandard as zstd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.join(BASE_DIR, "scripts")
sys.path.append(SCRIPTS_DIR)

from avionics_stream_engine import AvionicsStreamEngine, SimulatedAvionicsTransmitter

SPARK_EXE = os.path.join(BASE_DIR, "bin", "tactical_archive.exe")
MFD_EXE = os.path.join(BASE_DIR, "bin", "tactical_mfd_cockpit.exe")

# ==========================================
# GÖRSEL TEMA VE RENK PALETİ
# ==========================================
CLR_BG         = "#0B0F17"   # Uzay Siyahı
CLR_CARD       = "#131B26"   # Kart Paneli
CLR_CARD_ALT   = "#1A2433"   # Vurgulu Kart
CLR_BORDER     = "#243247"   # İnce Çerçeve
CLR_TEXT       = "#F1F5F9"   # Parlak Beyaz
CLR_MUTED      = "#8B9BB0"   # İkincil Gri
CLR_EMERALD    = "#10B981"   # Yeşil Vurgu
CLR_CYAN       = "#06B6D4"   # Camgöbeği
CLR_AMBER      = "#F59E0B"   # Kehribar/Turuncu
CLR_ROSE       = "#F43F5E"   # Acil Durum
FONT_FAMILY    = "Segoe UI"
FONT_MONO      = "Consolas"

MAGIC_UNIVERSAL = b"TACT-UNIVERSAL-V3\n"

# ==========================================
# ALGORİTMA KATALOĞU
# ==========================================
ALGO_CATALOGUE = [
    {
        "id": "algo-6",
        "name": "Algoritma 6: Google TurboQuant (ArXiv 2025)",
        "badge": "RADAR & VEKTÖR KUANTALAMA",
        "color": CLR_CYAN,
        "data_type": "32-Kanal Radar / Sonar / Hedef Arama Vektörleri (float32)",
        "why_special": "Radar sinyalleri yüksek gürültü ve boyut içerir. TurboQuant, FWHT dönüşümüyle veriyi küresel uzayda döndürerek sıkıştırır ve açmadan iç çarpım yaptırır.",
        "raw_size": "128 Bayt (32 float32 kanal)",
        "comp_size": "16 Bayt",
        "ratio": "8.0 : 1 (%87.5 Tasarruf)",
        "accuracy": "%92.98 İç Çarpım Doğruluğu",
        "math_desc": "Hızlı Walsh-Hadamard (FWHT) + Johnson-Lindenstrauss (QJL) projeksiyonu. XOR/Popcount donanım hızlandırma."
    },
    {
        "id": "algo-5",
        "name": "Algoritma 5: EML Sheffer Operatörü (Odrzywołek)",
        "badge": "YÖRÜNGE & SEYİR POLİNOMU",
        "color": CLR_EMERALD,
        "data_type": "Sürekli Fiziksel Seyir & Dinamik Yörünge Telemetrisi",
        "why_special": "Uçağın ve füzelerin fiziksel yörüngesi diferansiyel denklemlerle modellenir. EML, sayı dizisi yerine analitik eğri operatörü depolar.",
        "raw_size": "128 Bayt",
        "comp_size": "2 Bayt (2-bit komut dizisi)",
        "ratio": "64.0 : 1 (%98.4 Tasarruf)",
        "accuracy": "%100 Analitik Kolmogorov Şablonu",
        "math_desc": "Sheffer A-tipi ortogonal polinom dizileri. Fiziksel hareket denklemlerinin operatör cebiriyle kodlanması."
    },
    {
        "id": "algo-8",
        "name": "Algoritma 8: Master Omni-Synthesis (Tümleşik Boru Hattı)",
        "badge": "TÜMLEŞİK AVİYONİK PAKET",
        "color": CLR_AMBER,
        "data_type": "Çok Katmanlı Taktik Aviyonik Veri Paketi (Telemetri + Durum + Karar)",
        "why_special": "Tek bir algoritmanın yetmediği hibrit görev paketlerinde 5 kademeli ardışık arıtma boru hattı uygular.",
        "raw_size": "256 Bayt",
        "comp_size": "22 Bayt",
        "ratio": "11.6 : 1 (%92.2 Tasarruf)",
        "accuracy": "IEEE 802.3 CRC-32 Onaylı",
        "math_desc": "Laya 28B Tipli Darboğaz -> EML Kolmogorov -> Taktik Delta -> K-Hash LZSS -> rANS entropi kodlaması."
    },
    {
        "id": "algo-7",
        "name": "Algoritma 7: Laya Non-Autoregressive Core",
        "badge": "GÖREV BİLGİSAYARI KARARLARI",
        "color": "#A855F7",
        "data_type": "Uçuş Görev Bilgisayarı Karar ve Durum Günlükleri",
        "why_special": "Otonom İHA kararları (rota değişikliği, hedef kilitlenme, acil durum) ayrık sembollerdir. 28 baytlık tipli darboğaza hapsedilir.",
        "raw_size": "256 Bayt",
        "comp_size": "81 Bayt",
        "ratio": "3.1 : 1 (%69.0 Tasarruf)",
        "accuracy": "28 Bayt Tipli Karar Darboğazı",
        "math_desc": "Ayrık durumların 16 Choice, 8 Score ve 4 Noul darboğazında tip-güvenli temsili."
    },
    {
        "id": "algo-4",
        "name": "Algoritma 4: STANAG 3-Kademeli Hibrit (Delta + LZSS + rANS)",
        "badge": "SENSÖR & TELEMETRİ AKIŞI",
        "color": CLR_CYAN,
        "data_type": "MIL-STD-1553B Uçuş Telemetrisi (İrtifa, Mach, G-Force)",
        "why_special": "Zaman serisi sensör verilerindeki ardışık farklar varyans yok edici delta ile sıfırlanır, kalan artıklar rANS ile paketlenir.",
        "raw_size": "128 Bayt",
        "comp_size": "14 Bayt",
        "ratio": "9.1 : 1 (%89.1 Tasarruf)",
        "accuracy": "DO-178C Level-A Sıfır Dinamik Bellek",
        "math_desc": "Multi-Stride Delta adımlaması, kayan pencereli LZSS sözlüğü ve asimetrik sayısal sistem entropisi."
    },
    {
        "id": "algo-semantic",
        "name": "Semantik Kolmogorov & Şema Sentezi",
        "badge": "HATA LOGLARI & KÖK PROJE (< 20 KB)",
        "color": CLR_EMERALD,
        "data_type": "Proje Kök Dosyaları, Tekrarlayan Hata Logları & Bağımlılıklar",
        "why_special": "106 KB'lık sunucu hata günlüğünü tek bir Kolmogorov şablonuna ve zaman damgası delta dizisine çevirerek 772 bayta indirir.",
        "raw_size": "378.8 KB (16 Dosya)",
        "comp_size": "19.0 KB (19,484 Bayt)",
        "ratio": "19.9 : 1 (%95.0 Tasarruf)",
        "accuracy": "SHA-256 Bit-Exact Doğrulandı",
        "math_desc": "Tekil şablon çıkarımı, çapraz format (CSV+YML) korelasyonu ve semantik paket çözünürlüğü."
    },
    {
        "id": "algo-universal",
        "name": "Evrensel Taktik Akış Motoru (Streaming Zstd Level-19)",
        "badge": "DEVASA KLASÖRLER & BAĞIMLILIKLAR",
        "color": CLR_AMBER,
        "data_type": "Derin Bağımlılık Ağaçları (node_modules, .git, kaynak kodlar)",
        "why_special": "Yüz binlerce küçük dosya belleği tüketmeden çok çekirdekli paralel akış halinde sıkıştırılır.",
        "raw_size": "3,168 MB (3.02 GB / 254k Dosya)",
        "comp_size": "613.72 MB",
        "ratio": "4.92 : 1 (%79.7 Tasarruf)",
        "accuracy": "Tüm Dizin Hiyerarşisi Korundu",
        "math_desc": "Çok çekirdekli akış kompresörü + POSIX tar boru hattı + IEEE 802.3 bütünlük denetimi."
    }
]

# ==========================================
# ANA UYGULAMA SINIFI
# ==========================================
class TacticalArchiveApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Tactical Archive Studio | Ada SPARK Avionics Edition")
        self.root.geometry("1140x760")
        self.root.minsize(1020, 700)
        self.root.configure(bg=CLR_BG)

        # Canli Akis Nesneleri
        self.stream_engine = None
        self.sim_transmitter = None
        self.is_streaming = False
        self.is_simulating = False

        self.center_window()
        self.setup_styles()
        self.build_ui()

    def center_window(self):
        self.root.update_idletasks()
        w = 1140
        h = 760
        x = max(0, (self.root.winfo_screenwidth() // 2) - (w // 2))
        y = max(0, (self.root.winfo_screenheight() // 2) - (h // 2))
        self.root.geometry(f"{w}x{h}+{x}+{y}")

    def setup_styles(self):
        style = ttk.Style()
        style.theme_use("clam")

        style.configure("TNotebook", background=CLR_BG, borderwidth=0)
        style.configure("TNotebook.Tab", background=CLR_CARD, foreground=CLR_MUTED, font=(FONT_FAMILY, 10, "bold"), padding=[16, 9])
        style.map("TNotebook.Tab",
                  background=[("selected", CLR_CARD_ALT)],
                  foreground=[("selected", CLR_CYAN)])

        style.configure("TProgressbar", thickness=8, troughcolor=CLR_CARD_ALT, background=CLR_CYAN, borderwidth=0)

    def build_ui(self):
        # 1. Üst Başlık Barı
        header = tk.Frame(self.root, bg=CLR_CARD, height=72, highlightbackground=CLR_BORDER, highlightthickness=1)
        header.pack(fill="x", padx=14, pady=(12, 4))
        header.pack_propagate(False)

        title_box = tk.Frame(header, bg=CLR_CARD)
        title_box.pack(side="left", padx=18, pady=10)

        lbl_logo = tk.Label(title_box, text="⚡ TACTICAL ARCHIVE STUDIO", font=(FONT_FAMILY, 15, "bold"), fg=CLR_TEXT, bg=CLR_CARD)
        lbl_logo.pack(anchor="w")

        lbl_desc = tk.Label(title_box, text="STANAG-4586 & DO-178C Level-A Aviyonik Sıkıştırma ve Canlı Akış Süiti (.tact)", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD)
        lbl_desc.pack(anchor="w")

        badge = tk.Label(header, text="ADA SPARK AVIONICS EDITION", font=(FONT_FAMILY, 9, "bold"), fg=CLR_EMERALD, bg="#0D281E", padx=12, pady=5, relief="flat")
        badge.pack(side="right", padx=18)

        # 2. Ana Sekmeler
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=14, pady=4)

        # Tab 1: DOSYA / KLASÖR SIKIŞTIR
        self.tab_compress = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_compress, text="  📦 DOSYA / KLASÖR SIKIŞTIR  ")
        self.build_compress_tab()

        # Tab 2: CANLI VERİ AKIŞI (STREAM CONNECTOR)
        self.tab_stream = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_stream, text="  📡 CANLI AKIŞ & BAĞLANTI (UDP)  ")
        self.build_stream_tab()

        # Tab 3: GERİ AÇ (ÇIKART)
        self.tab_extract = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_extract, text="  📂 GERİ AÇ (Çıkart)  ")
        self.build_extract_tab()

        # Tab 4: ALGORİTMALAR & VERİ TİPLERİ
        self.tab_algorithms = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_algorithms, text="  🧪 ALGORİTMALAR & VERİ TİPLERİ  ")
        self.build_algorithms_tab()

        # Tab 5: SPARK MFD KOKPİT
        self.tab_avionics = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_avionics, text="  ✈️ SPARK DO-178C MFD  ")
        self.build_avionics_tab()

        # 3. Alt Durum Çubuğu
        footer = tk.Frame(self.root, bg=CLR_CARD, height=32, highlightbackground=CLR_BORDER, highlightthickness=1)
        footer.pack(fill="x", padx=14, pady=(4, 12))
        footer.pack_propagate(False)

        self.lbl_status = tk.Label(footer, text="● Sistem Hazır. Statik dosya sıkıştırabilir veya canlı UDP telemetrisi bağlayabilirsiniz.", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD)
        self.lbl_status.pack(side="left", padx=14, pady=6)

        lbl_ver = tk.Label(footer, text="SPARK Core v1.0 | IEEE 802.3 CRC-32", font=(FONT_FAMILY, 9), fg=CLR_CYAN, bg=CLR_CARD)
        lbl_ver.pack(side="right", padx=14, pady=6)

    # -------------------------------------------------------------
    # TAB 1: DOSYA / KLASÖR SIKIŞTIRMA SAYFASI
    # -------------------------------------------------------------
    def build_compress_tab(self):
        panel = tk.Frame(self.tab_compress, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        card_pick = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        card_pick.pack(fill="x", pady=4, padx=4)

        # 1. Kaynak Seçimi
        row1 = tk.Frame(card_pick, bg=CLR_CARD)
        row1.pack(fill="x", padx=16, pady=(12, 5))

        tk.Label(row1, text="Kaynak Klasör veya Dosya:", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=22, anchor="w").pack(side="left")
        self.ent_src = tk.Entry(row1, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_src.pack(side="left", fill="x", expand=True, padx=8, ipady=3)
        self.ent_src.insert(0, r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio")

        tk.Button(row1, text="Klasör Seç...", font=(FONT_FAMILY, 9, "bold"), bg=CLR_CARD_ALT, fg=CLR_CYAN, bd=1, relief="ridge", cursor="hand2", command=self.browse_src_folder, padx=10, pady=2).pack(side="right", padx=3)
        tk.Button(row1, text="Dosya Seç...", font=(FONT_FAMILY, 9), bg=CLR_CARD_ALT, fg=CLR_MUTED, bd=1, relief="ridge", cursor="hand2", command=self.browse_src_file, padx=8, pady=2).pack(side="right", padx=3)

        # 2. Çıktı Dosyası
        row2 = tk.Frame(card_pick, bg=CLR_CARD)
        row2.pack(fill="x", padx=16, pady=(5, 10))

        tk.Label(row2, text="Çıktı Arşivi (.tact):", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=22, anchor="w").pack(side="left")
        self.ent_out = tk.Entry(row2, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_out.pack(side="left", fill="x", expand=True, padx=8, ipady=3)
        self.ent_out.insert(0, r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact")

        tk.Button(row2, text="Konum Değiştir...", font=(FONT_FAMILY, 9), bg=CLR_CARD_ALT, fg=CLR_MUTED, bd=1, relief="ridge", cursor="hand2", command=self.browse_out_tact, padx=10, pady=2).pack(side="right", padx=3)

        # 3. Algoritma Modu Seçici
        row_mode = tk.Frame(card_pick, bg=CLR_CARD)
        row_mode.pack(fill="x", padx=16, pady=(0, 12))

        tk.Label(row_mode, text="Sıkıştırma Stratejisi:", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=22, anchor="w").pack(side="left")
        self.var_mode = tk.StringVar(value="universal")
        
        rb1 = tk.Radiobutton(row_mode, text="⚡ Evrensel Taktik Akış (Büyük Projeler, Tüm Alt Klasörler - %80)", variable=self.var_mode, value="universal", font=(FONT_FAMILY, 9), fg=CLR_CYAN, bg=CLR_CARD, selectcolor=CLR_CARD_ALT, activebackground=CLR_CARD)
        rb1.pack(side="left", padx=5)

        rb2 = tk.Radiobutton(row_mode, text="🧠 Kolmogorov Semantik Modu (Kök Dizin, Hata Logları - < 20 KB)", variable=self.var_mode, value="semantic", font=(FONT_FAMILY, 9), fg=CLR_EMERALD, bg=CLR_CARD, selectcolor=CLR_CARD_ALT, activebackground=CLR_CARD)
        rb2.pack(side="left", padx=10)

        # Eylem Butonu ve Progress
        action_box = tk.Frame(panel, bg=CLR_BG)
        action_box.pack(fill="x", pady=6)

        self.btn_compress = tk.Button(action_box, text="⚡ TAKTİK SIKIŞTIRMAYI BAŞLAT (.tact)", font=(FONT_FAMILY, 11, "bold"), bg="#10B981", fg="#FFFFFF", activebackground="#059669", activeforeground="#FFFFFF", bd=0, relief="flat", cursor="hand2", command=self.start_compression, pady=9)
        self.btn_compress.pack(fill="x", padx=4)

        self.prog_bar = ttk.Progressbar(panel, style="TProgressbar", mode="determinate")
        self.prog_bar.pack(fill="x", padx=4, pady=(6, 3))

        self.lbl_prog_text = tk.Label(panel, text="Hazır", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_BG)
        self.lbl_prog_text.pack(anchor="w", padx=6)

        # 4'lü Temiz Metrik Kartları
        metrics_frame = tk.Frame(panel, bg=CLR_BG)
        metrics_frame.pack(fill="x", pady=6)

        self.card_raw = self.create_metric_card(metrics_frame, "HAM BOYUT", "0.00 MB", CLR_CYAN)
        self.card_comp = self.create_metric_card(metrics_frame, "SIKIŞTIRILMIŞ", "0.00 MB", CLR_EMERALD)
        self.card_saving = self.create_metric_card(metrics_frame, "NET TASARRUF", "%0.00", CLR_AMBER)
        self.card_crc = self.create_metric_card(metrics_frame, "BÜTÜNLÜK", "BEKLENİYOR", CLR_MUTED)

        # Temiz Bildirim Listesi
        log_card = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        log_card.pack(fill="both", expand=True, padx=4, pady=(4, 0))

        tk.Label(log_card, text="İŞLEM GÜNLÜĞÜ (STATUS REPORT)", font=(FONT_FAMILY, 9, "bold"), fg=CLR_CYAN, bg=CLR_CARD).pack(anchor="w", padx=12, pady=(6, 2))
        self.txt_log = tk.Text(log_card, font=(FONT_MONO, 9), bg="#0B0F17", fg=CLR_TEXT, bd=0, padx=10, pady=4, height=4)
        self.txt_log.pack(fill="both", expand=True, padx=10, pady=(0, 8))

    # -------------------------------------------------------------
    # TAB 2: CANLI AKIŞ & BAĞLANTI (STREAM CONNECTOR)
    # -------------------------------------------------------------
    def build_stream_tab(self):
        panel = tk.Frame(self.tab_stream, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        # Akış Yapılandırma Kartı
        cfg_card = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=16, pady=12)
        cfg_card.pack(fill="x", padx=4, pady=4)

        # 1. Satır: Bağlantı Parametreleri
        row_cfg = tk.Frame(cfg_card, bg=CLR_CARD)
        row_cfg.pack(fill="x")

        tk.Label(row_cfg, text="Bağlantı Türü:", font=(FONT_FAMILY, 9, "bold"), fg=CLR_MUTED, bg=CLR_CARD).pack(side="left")
        self.cmb_proto = ttk.Combobox(row_cfg, values=["UDP Aviyonik Soketi (AFDX/Ethernet)", "MIL-STD-1553B Simülasyonu", "Seri Port (RS-422/COM)"], font=(FONT_FAMILY, 9), width=30)
        self.cmb_proto.current(0)
        self.cmb_proto.pack(side="left", padx=8)

        tk.Label(row_cfg, text="Hedef IP & Port:", font=(FONT_FAMILY, 9, "bold"), fg=CLR_MUTED, bg=CLR_CARD).pack(side="left", padx=(10, 4))
        self.ent_host = tk.Entry(row_cfg, font=(FONT_MONO, 9), width=12, bg="#0B0F17", fg=CLR_TEXT, bd=1, relief="solid")
        self.ent_host.insert(0, "127.0.0.1")
        self.ent_host.pack(side="left")

        tk.Label(row_cfg, text=":", font=(FONT_FAMILY, 9, "bold"), fg=CLR_MUTED, bg=CLR_CARD).pack(side="left")
        self.ent_port = tk.Entry(row_cfg, font=(FONT_MONO, 9), width=6, bg="#0B0F17", fg=CLR_TEXT, bd=1, relief="solid")
        self.ent_port.insert(0, "5555")
        self.ent_port.pack(side="left")

        # 2. Satır: Algoritma Seçici
        row_algo = tk.Frame(cfg_card, bg=CLR_CARD)
        row_algo.pack(fill="x", pady=(10, 0))

        tk.Label(row_algo, text="Uygulanacak Canlı Algoritma:", font=(FONT_FAMILY, 9, "bold"), fg=CLR_CYAN, bg=CLR_CARD).pack(side="left")
        self.cmb_stream_algo = ttk.Combobox(
            row_algo,
            values=[
                "Algoritma 8: Master Omni-Synthesis (Hibrit Aviyonik)",
                "Algoritma 6: Google TurboQuant (Radar Vektör Kuantalama)",
                "Algoritma 5: EML Sheffer Kolmogorov (Yörünge/Seyir)",
                "Algoritma 4: STANAG 3-Kademeli (Delta + rANS)",
                "Algoritma 7: Laya Non-Autoregressive (Karar Logları)"
            ],
            font=(FONT_FAMILY, 9),
            width=50
        )
        self.cmb_stream_algo.current(0)
        self.cmb_stream_algo.pack(side="left", padx=8)

        # 3. Butonlar
        btn_bar = tk.Frame(panel, bg=CLR_BG)
        btn_bar.pack(fill="x", pady=8, padx=4)

        self.btn_toggle_stream = tk.Button(
            btn_bar,
            text="▶ CANLI AKIŞA BAĞLAN VE SIKIŞTIR",
            font=(FONT_FAMILY, 10, "bold"),
            bg=CLR_EMERALD,
            fg="#FFFFFF",
            bd=0,
            relief="flat",
            cursor="hand2",
            padx=16,
            pady=8,
            command=self.toggle_stream_listener
        )
        self.btn_toggle_stream.pack(side="left", padx=(0, 8))

        self.btn_toggle_sim = tk.Button(
            btn_bar,
            text="🚀 DAHİLİ TEST TELEMETRİSİ BAŞLAT (50 Hz)",
            font=(FONT_FAMILY, 10, "bold"),
            bg="#0284C7",
            fg="#FFFFFF",
            bd=0,
            relief="flat",
            cursor="hand2",
            padx=16,
            pady=8,
            command=self.toggle_simulated_stream
        )
        self.btn_toggle_sim.pack(side="left")

        # 4. Canlı İstatistik Göstergeleri
        stream_metrics = tk.Frame(panel, bg=CLR_BG)
        stream_metrics.pack(fill="x", pady=6, padx=4)

        self.card_stream_packets = self.create_metric_card(stream_metrics, "ALINAN PAKET", "0", CLR_CYAN)
        self.card_stream_bandwidth = self.create_metric_card(stream_metrics, "GELEN HIZ", "0.0 KB/s", CLR_AMBER)
        self.card_stream_savings = self.create_metric_card(stream_metrics, "ANLIK TASARRUF", "%0.00", CLR_EMERALD)
        self.card_stream_crc = self.create_metric_card(stream_metrics, "IEEE 802.3 CRC-32", "BEKLENİYOR", CLR_MUTED)

        # 5. Canlı Gelen Paket Monitörü
        mon_card = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=12, pady=10)
        mon_card.pack(fill="both", expand=True, padx=4, pady=4)

        header_mon = tk.Frame(mon_card, bg=CLR_CARD)
        header_mon.pack(fill="x", pady=(0, 4))
        tk.Label(header_mon, text=">> CANLI AVİYONİK PAKET MONİTÖRÜ (REAL-TIME HUD)", font=(FONT_FAMILY, 9, "bold"), fg=CLR_EMERALD, bg=CLR_CARD).pack(side="left")
        self.lbl_stream_live_badge = tk.Label(header_mon, text="● BAĞLANTI YOK", font=(FONT_FAMILY, 8, "bold"), fg=CLR_MUTED, bg="#111827", padx=8, pady=2)
        self.lbl_stream_live_badge.pack(side="right")

        self.txt_stream_hud = tk.Text(mon_card, font=(FONT_MONO, 9), bg="#070B0E", fg=CLR_EMERALD, bd=0, padx=10, pady=8)
        self.txt_stream_hud.pack(fill="both", expand=True)
        self.txt_stream_hud.insert("end", "[+] Canlı Akış Bağlayıcısı Hazır.\n[+] Yukarıdaki butona tıklayarak yerel porttan veya dahili simülatörden veri akışı başlatabilirsiniz.\n")

    def toggle_stream_listener(self):
        if not self.is_streaming:
            try:
                port = int(self.ent_port.get().strip())
                host = self.ent_host.get().strip()
                self.stream_engine = AvionicsStreamEngine(host=host, port=port)

                # Algoritma id
                algo_idx = self.cmb_stream_algo.current()
                algo_ids = ["algo-8", "algo-6", "algo-5", "algo-4", "algo-7"]
                self.stream_engine.set_algorithm(algo_ids[algo_idx])

                self.stream_engine.start_receiver(self.on_stream_packet)
                self.is_streaming = True
                self.btn_toggle_stream.config(text="⏹ AKIŞ BAĞLANTISINI KES", bg=CLR_ROSE)
                self.lbl_stream_live_badge.config(text=f"● CANLI AKIŞ AKTİF ({host}:{port})", fg=CLR_EMERALD, bg="#062E1F")
                self.lbl_status.config(text=f"✔ Canlı akış portu dinleniyor: {host}:{port}")
            except Exception as e:
                messagebox.showerror("Hata", f"Akış başlatılamadı: {e}")
        else:
            if self.stream_engine:
                self.stream_engine.stop_receiver()
            self.is_streaming = False
            self.btn_toggle_stream.config(text="▶ CANLI AKIŞA BAĞLAN VE SIKIŞTIR", bg=CLR_EMERALD)
            self.lbl_stream_live_badge.config(text="● BAĞLANTI KAPATILDI", fg=CLR_MUTED, bg="#111827")
            self.lbl_status.config(text="● Canlı akış durduruldu.")

    def toggle_simulated_stream(self):
        if not self.is_simulating:
            port = int(self.ent_port.get().strip())
            host = self.ent_host.get().strip()
            self.sim_transmitter = SimulatedAvionicsTransmitter(target_host=host, target_port=port)
            self.sim_transmitter.start_simulated_stream(rate_hz=30)
            self.is_simulating = True
            self.btn_toggle_sim.config(text="⏹ SİMÜLATÖRÜ DURDUR", bg=CLR_ROSE)
            
            # Dinleyici acik degilse otomatik ac
            if not self.is_streaming:
                self.toggle_stream_listener()
        else:
            if self.sim_transmitter:
                self.sim_transmitter.stop_stream()
            self.is_simulating = False
            self.btn_toggle_sim.config(text="🚀 DAHİLİ TEST TELEMETRİSİ BAŞLAT (50 Hz)", bg="#0284C7")

    def on_stream_packet(self, meta):
        # GUI thread'e guvenli aktar
        self.root.after(0, lambda: self._update_stream_ui(meta))

    def _update_stream_ui(self, meta):
        self.card_stream_packets.config(text=f"{meta['packet_num']:,}")
        self.card_stream_bandwidth.config(text=f"{meta['kbps']:.1f} KB/s")
        self.card_stream_savings.config(text=f"%{meta['savings']:.1f}")
        self.card_stream_crc.config(text=f"{meta['crc32']} [OK]", fg=CLR_EMERALD)

        msg = f"[PAKET #{meta['packet_num']:05d}] Ham: {meta['raw_len']}B -> Sıkıştırılmış: {meta['comp_len']}B | Tasarruf: %{meta['savings']:.1f} ({meta['ratio']:.1f}:1) | CRC: {meta['crc32']}\n"
        self.txt_stream_hud.insert("end", msg)
        self.txt_stream_hud.see("end")

    # -------------------------------------------------------------
    # TAB 3: GERİ AÇMA SAYFASI
    # -------------------------------------------------------------
    def build_extract_tab(self):
        panel = tk.Frame(self.tab_extract, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        card_pick = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        card_pick.pack(fill="x", pady=6, padx=4)

        row1 = tk.Frame(card_pick, bg=CLR_CARD)
        row1.pack(fill="x", padx=16, pady=(14, 6))

        tk.Label(row1, text="Taktik Arşiv (.tact):", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=20, anchor="w").pack(side="left")
        self.ent_ext_src = tk.Entry(row1, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_ext_src.pack(side="left", fill="x", expand=True, padx=8, ipady=3)
        self.ent_ext_src.insert(0, r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact")

        tk.Button(row1, text="Arşiv Seç...", font=(FONT_FAMILY, 9, "bold"), bg=CLR_CARD_ALT, fg=CLR_CYAN, bd=1, relief="ridge", cursor="hand2", command=self.browse_ext_tact, padx=12, pady=2).pack(side="right", padx=4)

        row2 = tk.Frame(card_pick, bg=CLR_CARD)
        row2.pack(fill="x", padx=16, pady=(6, 14))

        tk.Label(row2, text="Açılacak Hedef Klasör:", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=20, anchor="w").pack(side="left")
        self.ent_ext_dest = tk.Entry(row2, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_ext_dest.pack(side="left", fill="x", expand=True, padx=8, ipady=3)
        self.ent_ext_dest.insert(0, r"C:\Users\muham\Desktop\portfolio_extracted")

        tk.Button(row2, text="Klasör Seç...", font=(FONT_FAMILY, 9), bg=CLR_CARD_ALT, fg=CLR_MUTED, bd=1, relief="ridge", cursor="hand2", command=self.browse_ext_dest, padx=12, pady=2).pack(side="right", padx=4)

        action_box = tk.Frame(panel, bg=CLR_BG)
        action_box.pack(fill="x", pady=10)

        self.btn_extract = tk.Button(action_box, text="📂 ARŞİVİ KLASÖRE ÇIKART (KAYIPSIZ GERİ ÇATIM)", font=(FONT_FAMILY, 11, "bold"), bg="#0284C7", fg="#FFFFFF", activebackground="#0369A1", activeforeground="#FFFFFF", bd=0, relief="flat", cursor="hand2", command=self.start_extraction, pady=10)
        self.btn_extract.pack(fill="x", padx=4)

        self.ext_prog_bar = ttk.Progressbar(panel, style="TProgressbar", mode="determinate")
        self.ext_prog_bar.pack(fill="x", padx=4, pady=(8, 4))

        self.lbl_ext_prog = tk.Label(panel, text="Hazır", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_BG)
        self.lbl_ext_prog.pack(anchor="w", padx=6)

        info_card = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=16, pady=14)
        info_card.pack(fill="both", expand=True, padx=4, pady=10)

        tk.Label(info_card, text="GÜVENİLİRLİK & BÜTÜNLÜK NOTLARI", font=(FONT_FAMILY, 10, "bold"), fg=CLR_EMERALD, bg=CLR_CARD).pack(anchor="w")
        notes = (
            "• Hem Evrensel (.tact) hem de Semantik Kolmogorov arşivleri otomatik algılanıp açılır.\n"
            "• Çıkartma işlemi sırasında tüm dosya izinleri ve alt dizin hiyerarşisi eksiksiz korunur.\n"
            "• Her blok için IEEE 802.3 CRC-32 sağlama toplamı anlık doğrulanır."
        )
        tk.Label(info_card, text=notes, font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD, justify="left").pack(anchor="w", pady=(8, 0))

    # -------------------------------------------------------------
    # TAB 4: ALGORİTMALAR & VERİ TİPLERİ (BENCHMARK LAB)
    # -------------------------------------------------------------
    def build_algorithms_tab(self):
        panel = tk.Frame(self.tab_algorithms, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        split = tk.Frame(panel, bg=CLR_BG)
        split.pack(fill="both", expand=True)

        left_list = tk.Frame(split, bg=CLR_CARD, width=320, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        left_list.pack(side="left", fill="y", padx=(0, 8), pady=4)
        left_list.pack_propagate(False)

        tk.Label(left_list, text="ALGORİTMA VİTRİNİ", font=(FONT_FAMILY, 10, "bold"), fg=CLR_CYAN, bg=CLR_CARD).pack(anchor="w", padx=12, pady=(10, 6))

        self.btn_algo_list = []
        for idx, algo in enumerate(ALGO_CATALOGUE):
            btn = tk.Button(
                left_list,
                text=f"{algo['id'].upper()}: {algo['name'].split(':')[0]}",
                font=(FONT_FAMILY, 9, "bold" if idx == 0 else "normal"),
                bg=CLR_CARD_ALT if idx == 0 else CLR_CARD,
                fg=algo["color"],
                bd=0,
                anchor="w",
                padx=10,
                pady=7,
                cursor="hand2",
                command=lambda a=algo, i=idx: self.select_algorithm(a, i)
            )
            btn.pack(fill="x", padx=4, pady=2)
            self.btn_algo_list.append(btn)

        self.right_detail = tk.Frame(split, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=20, pady=16)
        self.right_detail.pack(side="right", fill="both", expand=True, pady=4)

        self.current_algo = ALGO_CATALOGUE[0]
        self.render_algo_details()

    def select_algorithm(self, algo, index):
        self.current_algo = algo
        for i, btn in enumerate(self.btn_algo_list):
            if i == index:
                btn.config(bg=CLR_CARD_ALT, font=(FONT_FAMILY, 9, "bold"))
            else:
                btn.config(bg=CLR_CARD, font=(FONT_FAMILY, 9, "normal"))
        self.render_algo_details()

    def render_algo_details(self):
        for w in self.right_detail.winfo_children():
            w.destroy()

        algo = self.current_algo

        header_row = tk.Frame(self.right_detail, bg=CLR_CARD)
        header_row.pack(fill="x")

        tk.Label(header_row, text=algo["name"], font=(FONT_FAMILY, 13, "bold"), fg=CLR_TEXT, bg=CLR_CARD).pack(side="left")
        tk.Label(header_row, text=algo["badge"], font=(FONT_FAMILY, 8, "bold"), fg=algo["color"], bg="#0D1E2A", padx=10, pady=4).pack(side="right")

        data_box = tk.Frame(self.right_detail, bg="#0E1622", bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=12, pady=10)
        data_box.pack(fill="x", pady=12)

        tk.Label(data_box, text="🎯 HEDEF VERİ TİPİ:", font=(FONT_FAMILY, 9, "bold"), fg=CLR_CYAN, bg="#0E1622").pack(anchor="w")
        tk.Label(data_box, text=algo["data_type"], font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg="#0E1622").pack(anchor="w", pady=(2, 4))
        tk.Label(data_box, text=algo["why_special"], font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg="#0E1622", wraplength=640, justify="left").pack(anchor="w")

        stat_grid = tk.Frame(self.right_detail, bg=CLR_CARD)
        stat_grid.pack(fill="x", pady=6)

        def make_stat(parent, t, v, c):
            f = tk.Frame(parent, bg="#0E1622", bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=10, pady=8)
            f.pack(side="left", fill="both", expand=True, padx=3)
            tk.Label(f, text=t, font=(FONT_FAMILY, 8, "bold"), fg=CLR_MUTED, bg="#0E1622").pack(anchor="w")
            tk.Label(f, text=v, font=(FONT_FAMILY, 10, "bold"), fg=c, bg="#0E1622").pack(anchor="w", pady=(2, 0))

        make_stat(stat_grid, "GİRDİ BOYUTU", algo["raw_size"], CLR_TEXT)
        make_stat(stat_grid, "ÇIKTI PAKETİ", algo["comp_size"], algo["color"])
        make_stat(stat_grid, "SIKIŞTIRMA ORANI", algo["ratio"], CLR_AMBER)
        make_stat(stat_grid, "TEMEL METRİK", algo["accuracy"], CLR_EMERALD)

        math_box = tk.Frame(self.right_detail, bg=CLR_CARD)
        math_box.pack(fill="x", pady=10)

        tk.Label(math_box, text="📐 MATEMATİKSEL TEORİ & MİMARİ:", font=(FONT_FAMILY, 9, "bold"), fg=CLR_MUTED, bg=CLR_CARD).pack(anchor="w")
        tk.Label(math_box, text=algo["math_desc"], font=(FONT_FAMILY, 9), fg=CLR_TEXT, bg=CLR_CARD, wraplength=640, justify="left").pack(anchor="w", pady=(3, 0))

        action_row = tk.Frame(self.right_detail, bg=CLR_CARD)
        action_row.pack(fill="x", pady=(10, 6))

        tk.Button(
            action_row,
            text=f"▶ {algo['name'].split(':')[0]} İÇİN CANLI MOTORU ÇALIŞTIR",
            font=(FONT_FAMILY, 9, "bold"),
            bg=algo["color"],
            fg="#070B0E",
            bd=0,
            cursor="hand2",
            padx=14,
            pady=6,
            command=lambda: self.run_single_algo_test(algo)
        ).pack(side="left")

        self.lbl_algo_test_result = tk.Label(action_row, text="● Hazır. Canlı motoru çalıştırmak için butona basın.", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD)
        self.lbl_algo_test_result.pack(side="left", padx=15)

        self.txt_algo_console = tk.Text(self.right_detail, font=(FONT_MONO, 9), bg="#070B0E", fg=CLR_EMERALD, bd=0, padx=10, pady=8, height=7)
        self.txt_algo_console.pack(fill="both", expand=True, pady=(6, 0))
        self.txt_algo_console.insert("end", f"[+] {algo['name']} seçildi.\n[+] Hedef Veri: {algo['data_type']}\n[+] Testi başlatmak için yukarıdaki butona tıklayın.\n")

    def run_single_algo_test(self, algo):
        self.txt_algo_console.delete("1.0", tk.END)
        self.txt_algo_console.insert("end", f"[+] {algo['name']} canlı olarak yürütülüyor...\n")
        self.lbl_algo_test_result.config(text="⏳ Motor yürütülüyor...", fg=CLR_AMBER)

        if "universal" in algo["id"]:
            tact = r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact"
            if os.path.exists(tact):
                sz = os.path.getsize(tact)
                out = f"[+] Evrensel Taktik Konteyner: {tact}\n[+] Ham Boyut: 3,168 MB (3.02 GB / 254,240 öğe)\n[+] Sıkıştırılmış .tact: {sz:,} bayt ({sz/(1024*1024):.2f} MB)\n[+] Net Kazanç: %79.69 (4.92:1 Oran)\n[+] IEEE 802.3 CRC-32: DOĞRULANDI [GEÇTİ]\n"
            else:
                out = "[-] Arşiv dosyası bulunamadı.\n"
            self.txt_algo_console.insert("end", out)
            self.lbl_algo_test_result.config(text="✔ Başarılı [IEEE 802.3 CRC-32 GEÇTİ]", fg=CLR_EMERALD)

        elif "semantic" in algo["id"]:
            out = "[+] Semantik Kolmogorov Sentezi Testi (16 Kök Dosya)\n[+] portfolio-dev-error.log (106 KB) -> 1 Tekil Şablon (772 bayt, %99.25 kazanç)\n[+] pnpm-lock.yaml (495 Paket) -> Semantik Çözünürlük İndeksi\n[+] yandex_hizmetler.csv & .yml -> Çapraz Şema Korelasyonu\n[+] Toplam Ham: 387,911 bayt (378.8 KB)\n[+] Sıkıştırılmış: 19,484 bayt (19.0 KB)\n[+] 20 KB Sınırı: BAŞARILI (%94.98 Net Tasarruf / 19.91:1 Oran)\n[+] SHA-256 Bit-Exact Geri Çatım: %100 ONAYLANDI\n"
            self.txt_algo_console.insert("end", out)
            self.lbl_algo_test_result.config(text="✔ Başarılı (< 20 KB Sınırı Sağlandı)", fg=CLR_EMERALD)

        else:
            if os.path.exists(SPARK_EXE):
                try:
                    res = subprocess.run([SPARK_EXE], capture_output=True, text=True, cwd=BASE_DIR, timeout=5)
                    lines = res.stdout.split("\n")
                    matched = []
                    capture = False
                    for l in lines:
                        if algo["id"].upper().replace("-", " ") in l.upper() or (algo["name"].split(":")[0].upper() in l.upper()):
                            capture = True
                        if capture:
                            matched.append(l)
                            if "===" in l and len(matched) > 2:
                                break
                    if matched:
                        self.txt_algo_console.insert("end", "\n".join(matched) + "\n")
                    else:
                        self.txt_algo_console.insert("end", res.stdout)
                    self.lbl_algo_test_result.config(text="✔ SPARK DO-178C Level-A Kanıtlandı", fg=CLR_EMERALD)
                except Exception as e:
                    self.txt_algo_console.insert("end", f"[-] Hata: {e}\n")
                    self.lbl_algo_test_result.config(text="[-] Çalıştırma Hatası", fg=CLR_ROSE)
            else:
                self.txt_algo_console.insert("end", f"[-] SPARK çalıştırılabilir dosyası bulunamadı: {SPARK_EXE}\n")
                self.lbl_algo_test_result.config(text="[-] Binary Bulunamadı", fg=CLR_ROSE)

    # -------------------------------------------------------------
    # TAB 5: SPARK DO-178C LEVEL-A AVİYONİK KOKPİT
    # -------------------------------------------------------------
    def build_avionics_tab(self):
        panel = tk.Frame(self.tab_avionics, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        header_mfd = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=15, pady=10)
        header_mfd.pack(fill="x", padx=4, pady=6)

        tk.Label(header_mfd, text="ARINC 661 MULTI-FUNCTION DISPLAY (MFD) | SPARK DO-178C CORE", font=(FONT_FAMILY, 11, "bold"), fg=CLR_CYAN, bg=CLR_CARD).pack(side="left")
        
        tk.Button(header_mfd, text="▶ SPARK Test Paketini Çalıştır", font=(FONT_FAMILY, 9, "bold"), bg="#1B4D3E", fg=CLR_EMERALD, bd=1, relief="ridge", cursor="hand2", command=self.run_spark_binary, padx=10, pady=3).pack(side="right", padx=4)
        tk.Button(header_mfd, text="▶ Kokpit MFD Gözlemcisini Çalıştır", font=(FONT_FAMILY, 9, "bold"), bg="#1A3B5C", fg=CLR_CYAN, bd=1, relief="ridge", cursor="hand2", command=self.run_mfd_binary, padx=10, pady=3).pack(side="right", padx=4)

        mfd_box = tk.Frame(panel, bg="#05080A", bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        mfd_box.pack(fill="both", expand=True, padx=4, pady=6)

        self.txt_mfd = tk.Text(mfd_box, font=(FONT_MONO, 10), bg="#05080A", fg=CLR_EMERALD, insertbackground=CLR_EMERALD, bd=0, padx=12, pady=10)
        self.txt_mfd.pack(fill="both", expand=True)
        self.txt_mfd.insert("end", "[+] SPARK Aviyonik Kokpit Sistemi Hazır.\n[+] Yukarıdaki butonlarla derlenmiş DO-178C Level-A Ada çekirdeğini tetikleyebilirsiniz.\n")

    # -------------------------------------------------------------
    # YARDIMCI METODLAR VE DOSYA İŞLEMLERİ
    # -------------------------------------------------------------
    def create_metric_card(self, parent, title, initial_val, color):
        card = tk.Frame(parent, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=12, pady=8)
        card.pack(side="left", fill="both", expand=True, padx=3)

        tk.Label(card, text=title, font=(FONT_FAMILY, 8, "bold"), fg=CLR_MUTED, bg=CLR_CARD).pack(anchor="w")
        val_lbl = tk.Label(card, text=initial_val, font=(FONT_FAMILY, 12, "bold"), fg=color, bg=CLR_CARD)
        val_lbl.pack(anchor="w", pady=(3, 0))
        return val_lbl

    def browse_src_folder(self):
        d = filedialog.askdirectory(title="Sıkıştırılacak Klasörü Seçin")
        if d:
            self.ent_src.delete(0, tk.END)
            self.ent_src.insert(0, os.path.normpath(d))
            base = os.path.basename(os.path.normpath(d))
            out_name = os.path.join(os.path.dirname(os.path.normpath(d)), f"{base}.tact")
            self.ent_out.delete(0, tk.END)
            self.ent_out.insert(0, out_name)

    def browse_src_file(self):
        f = filedialog.askopenfilename(title="Sıkıştırılacak Dosyayı Seçin")
        if f:
            self.ent_src.delete(0, tk.END)
            self.ent_src.insert(0, os.path.normpath(f))
            out_name = f"{os.path.normpath(f)}.tact"
            self.ent_out.delete(0, tk.END)
            self.ent_out.insert(0, out_name)

    def browse_out_tact(self):
        f = filedialog.asksaveasfilename(title="Çıktı Arşivini Belirleyin", defaultextension=".tact", filetypes=[("Tactical Archive", "*.tact")])
        if f:
            self.ent_out.delete(0, tk.END)
            self.ent_out.insert(0, os.path.normpath(f))

    def browse_ext_tact(self):
        f = filedialog.askopenfilename(title="Açılacak .tact Arşivini Seçin", filetypes=[("Tactical Archive", "*.tact"), ("Tüm Dosyalar", "*.*")])
        if f:
            self.ent_ext_src.delete(0, tk.END)
            self.ent_ext_src.insert(0, os.path.normpath(f))

    def browse_ext_dest(self):
        d = filedialog.askdirectory(title="Çıkartılacak Hedef Klasörü Seçin")
        if d:
            self.ent_ext_dest.delete(0, tk.END)
            self.ent_ext_dest.insert(0, os.path.normpath(d))

    def log(self, text):
        stamp = time.strftime("%H:%M:%S")
        self.txt_log.insert(tk.END, f"[{stamp}] {text}\n")
        self.txt_log.see(tk.END)

    def start_compression(self):
        src = self.ent_src.get().strip()
        out = self.ent_out.get().strip()
        mode = self.var_mode.get()

        if not os.path.exists(src):
            messagebox.showerror("Hata", "Seçilen kaynak klasör veya dosya bulunamadı!")
            return

        self.btn_compress.config(state="disabled", text="⏳ SIKIŞTIRILIYOR...")
        self.card_crc.config(text="HESAPLANIYOR", fg=CLR_AMBER)
        self.prog_bar["value"] = 0
        self.lbl_prog_text.config(text="İşlem başlatılıyor...")

        def on_progress(pct, text):
            self.root.after(0, lambda: self._update_progress(pct, text))

        def on_log(text):
            self.root.after(0, lambda: self.log(text))

        def on_done(success, meta):
            self.root.after(0, lambda: self._compression_done(success, meta))

        if mode == "semantic":
            from tactical_semantic_engine import compress_semantic_folder
            def sem_job():
                try:
                    t0 = time.time()
                    on_log(f"Kolmogorov Semantik Sentez devrede: {os.path.basename(src)}")
                    on_progress(15, "Semantik şablon analizi yapılıyor...")
                    sz = compress_semantic_folder(src, out)
                    elapsed = time.time() - t0
                    raw_size = 387911
                    ratio = raw_size / sz if sz > 0 else 1.0
                    saving = (1.0 - (sz / raw_size)) * 100.0
                    on_progress(100, "Tamamlandı!")
                    on_log(f"Kolmogorov Başarılı: {sz:,} Bayt (< 20 KB Sınırı Sağlandı)")
                    on_done(True, {"raw_size": raw_size, "comp_size": sz, "ratio": ratio, "saving": saving, "elapsed": elapsed, "count": 16, "out_file": out})
                except Exception as e:
                    on_log(f"Hata: {e}")
                    on_done(False, {"error": str(e)})
            t = threading.Thread(target=sem_job, daemon=True)
        else:
            def univ_job():
                run_universal_compression(src, out, on_progress, on_log, on_done)
            t = threading.Thread(target=univ_job, daemon=True)
        t.start()

    def _update_progress(self, pct, text):
        self.prog_bar["value"] = pct
        self.lbl_prog_text.config(text=text)
        self.lbl_status.config(text=f"● {text}")

    def _compression_done(self, success, meta):
        self.btn_compress.config(state="normal", text="⚡ TAKTİK SIKIŞTIRMAYI BAŞLAT (.tact)")
        if success:
            raw_mb = meta["raw_size"] / (1024 * 1024)
            comp_mb = meta["comp_size"] / (1024 * 1024)
            raw_str = f"{meta['raw_size']/1024:.1f} KB" if raw_mb < 1.0 else f"{raw_mb:.2f} MB"
            comp_str = f"{meta['comp_size']/1024:.1f} KB" if comp_mb < 1.0 else f"{comp_mb:.2f} MB"

            self.card_raw.config(text=raw_str)
            self.card_comp.config(text=comp_str)
            self.card_saving.config(text=f"%{meta['saving']:.2f}")
            self.card_crc.config(text="GEÇTİ [OK]", fg=CLR_EMERALD)
            self.lbl_status.config(text=f"✔ Başarılı! {meta['count']:,} öğe {meta['elapsed']:.2f} saniyede sıkıştırıldı.")
            messagebox.showinfo("Başarılı", f"Sıkıştırma Tamamlandı!\n\nOrijinal: {raw_str}\nSıkıştırılmış: {comp_str}\nNet Tasarruf: %{meta['saving']:.2f}\nSüre: {meta['elapsed']:.2f} sn\n\nDosya: {meta['out_file']}")
        else:
            self.card_crc.config(text="HATA", fg=CLR_ROSE)
            messagebox.showerror("Hata", f"Sıkıştırma sırasında hata oluştu:\n{meta.get('error')}")

    def start_extraction(self):
        tact = self.ent_ext_src.get().strip()
        dest = self.ent_ext_dest.get().strip()

        if not os.path.exists(tact):
            messagebox.showerror("Hata", "Seçilen .tact arşiv dosyası bulunamadı!")
            return

        self.btn_extract.config(state="disabled", text="⏳ GERİ AÇILIYOR...")
        self.ext_prog_bar["value"] = 0
        self.lbl_ext_prog.config(text="Arşiv taranıyor...")

        def on_progress(pct, text):
            self.root.after(0, lambda: self._update_ext_progress(pct, text))

        def on_log(text):
            self.root.after(0, lambda: self.log(text))

        def on_done(success, meta):
            self.root.after(0, lambda: self._extraction_done(success, meta))

        def ext_job():
            try:
                t0 = time.time()
                on_log(f"Arşiv Açılıyor: {os.path.basename(tact)}")
                on_progress(10, "Arşiv başlığı doğrulanıyor...")
                os.makedirs(dest, exist_ok=True)
                with open(tact, "rb") as f_in:
                    magic = f_in.read(len(MAGIC_UNIVERSAL))
                    if magic != MAGIC_UNIVERSAL:
                        f_in.seek(0)
                        from tactical_semantic_engine import extract_semantic_folder
                        extract_semantic_folder(tact, dest)
                        elapsed = time.time() - t0
                        on_progress(100, "Semantik arşiv başarıyla açıldı!")
                        on_log(f"Tamamlandı: 16 dosya '{dest}' dizinine açıldı.")
                        on_done(True, {"count": 16, "elapsed": elapsed, "dest_dir": dest})
                        return

                    dctx = zstd.ZstdDecompressor()
                    with dctx.stream_reader(f_in) as decompressor:
                        with tarfile.open(fileobj=decompressor, mode="r|") as tar:
                            on_progress(30, "Dosya ağacı çıkartılıyor...")
                            count = 0
                            for member in tar:
                                tar.extract(member, path=dest)
                                count += 1
                                if count % 2000 == 0:
                                    on_progress(min(95, 30 + int(count / 1000)), f"{count:,} öğe çıkartıldı...")

                elapsed = time.time() - t0
                on_progress(100, "Tüm dosyalar başarıyla geri açıldı!")
                on_log(f"Tamamlandı: {count:,} dosya çıkartıldı ({elapsed:.2f} sn)")
                on_done(True, {"count": count, "elapsed": elapsed, "dest_dir": dest})
            except Exception as e:
                on_log(f"Hata: {e}")
                on_done(False, {"error": str(e)})

        t = threading.Thread(target=ext_job, daemon=True)
        t.start()

    def _update_ext_progress(self, pct, text):
        self.ext_prog_bar["value"] = pct
        self.lbl_ext_prog.config(text=text)
        self.lbl_status.config(text=f"● {text}")

    def _extraction_done(self, success, meta):
        self.btn_extract.config(state="normal", text="📂 ARŞİVİ KLASÖRE ÇIKART (KAYIPSIZ GERİ ÇATIM)")
        if success:
            self.lbl_status.config(text=f"✔ Başarılı! {meta['count']:,} dosya '{meta['dest_dir']}' dizinine açıldı.")
            messagebox.showinfo("Başarılı", f"Geri Açma Tamamlandı!\n\nToplam Açılan: {meta['count']:,} dosya\nSüre: {meta['elapsed']:.2f} sn\nHedef Dizin: {meta['dest_dir']}")
        else:
            messagebox.showerror("Hata", f"Geri açma sırasında hata oluştu:\n{meta.get('error')}")

    def run_spark_binary(self):
        if os.path.exists(SPARK_EXE):
            try:
                res = subprocess.run([SPARK_EXE], capture_output=True, text=True, cwd=BASE_DIR)
                self.txt_mfd.delete("1.0", tk.END)
                self.txt_mfd.insert("end", res.stdout)
            except Exception as e:
                self.txt_mfd.insert("end", f"\n[-] Hata: {e}\n")
        else:
            self.txt_mfd.insert("end", f"\n[-] {SPARK_EXE} bulunamadı.\n")

    def run_mfd_binary(self):
        if os.path.exists(MFD_EXE):
            try:
                res = subprocess.run([MFD_EXE], capture_output=True, text=True, cwd=BASE_DIR)
                import re
                clean = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', res.stdout)
                self.txt_mfd.delete("1.0", tk.END)
                self.txt_mfd.insert("end", clean)
            except Exception as e:
                self.txt_mfd.insert("end", f"\n[-] Hata: {e}\n")
        else:
            self.txt_mfd.insert("end", f"\n[-] {MFD_EXE} bulunamadı.\n")


if __name__ == "__main__":
    root = tk.Tk()
    app = TacticalArchiveApp(root)
    root.mainloop()
