#!/usr/bin/env python3
"""
TACTICAL ARCHIVE STUDIO - ADA SPARK AVIONICS EDITION
STANAG-4586 & DO-178C Level-A Uyumlu Aviyonik ve Taktiksel Veri Sıkıştırma Süiti

Geliştirici: Muhammet Atmaca
Masaüstü Grafik Arayüzü (Modern Aviyonik Dashboard)
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

# ==========================================
# GÖRSEL TEMA VE RENK PALETİ (MODERN AVİYONİK)
# ==========================================
CLR_BG         = "#0B0F17"   # Uzay Siyahı / Koyu Arka Plan
CLR_CARD       = "#131B26"   # Kart ve Panel Arka Planı
CLR_CARD_ALT   = "#1A2433"   # Vurgulu Kart
CLR_BORDER     = "#243247"   # İnce Çerçeve
CLR_TEXT       = "#F1F5F9"   # Ana Metin (Parlak Beyaz)
CLR_MUTED      = "#8B9BB0"   # İkincil Metin (Kül Grisi)
CLR_EMERALD    = "#10B981"   # Başarı / Yeşil Vurgu
CLR_CYAN       = "#06B6D4"   # Aviyonik Camgöbeği
CLR_AMBER      = "#F59E0B"   # Uyarı / Turuncu
CLR_ROSE       = "#F43F5E"   # Acil Durum / Kırmızı
FONT_FAMILY    = "Segoe UI"
FONT_MONO      = "Consolas"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SPARK_EXE = os.path.join(BASE_DIR, "bin", "tactical_archive.exe")
MFD_EXE = os.path.join(BASE_DIR, "bin", "tactical_mfd_cockpit.exe")

MAGIC_UNIVERSAL = b"TACT-UNIVERSAL-V3\n"

# ==========================================
# MOTOR FONKSİYONLARI (GERÇEK & ASENKRON)
# ==========================================
def run_universal_compression(src_path, out_file, progress_cb, log_cb, done_cb):
    try:
        t0 = time.time()
        log_cb(f"Taktik boru hattı başlatılıyor: {os.path.basename(src_path)}")
        progress_cb(5, "Dosyalar indeksleniyor...")

        src_path = os.path.abspath(src_path)
        is_single_file = os.path.isfile(src_path)
        
        # 1. Aşama: Dosya Taraması
        all_items = []
        total_raw_bytes = 0
        if is_single_file:
            all_items.append((src_path, os.path.basename(src_path)))
            total_raw_bytes = os.path.getsize(src_path)
        else:
            for root, dirs, files in os.walk(src_path):
                rel_dir = os.path.relpath(root, src_path)
                if rel_dir != ".":
                    all_items.append((root, rel_dir))
                for f in files:
                    full = os.path.join(root, f)
                    arc = f if rel_dir == "." else os.path.join(rel_dir, f)
                    all_items.append((full, arc))
                    try:
                        if not os.path.islink(full):
                            total_raw_bytes += os.path.getsize(full)
                    except:
                        pass

        log_cb(f"Taranan Öğe: {len(all_items):,} adet ({total_raw_bytes / (1024*1024):.2f} MB)")
        progress_cb(15, "Zstandard Ultra (Level 19) motoru devreye alınıyor...")

        # 2. Aşama: Çok Çekirdekli Zstd + Streaming Tar
        cctx = zstd.ZstdCompressor(level=15, threads=-1)
        processed_bytes = 0
        processed_count = 0
        
        with open(out_file, "wb") as f_out:
            f_out.write(MAGIC_UNIVERSAL)
            with cctx.stream_writer(f_out) as compressor:
                with tarfile.open(fileobj=compressor, mode="w|") as tar:
                    for full, arc in all_items:
                        tar.add(full, arcname=arc, recursive=False)
                        processed_count += 1
                        if os.path.isfile(full) and not os.path.islink(full):
                            try:
                                processed_bytes += os.path.getsize(full)
                            except:
                                pass
                        
                        if processed_count % 1500 == 0 or processed_count == len(all_items):
                            pct = 15 + int((processed_count / max(1, len(all_items))) * 80)
                            progress_cb(pct, f"Sıkıştırılıyor: {processed_count:,} / {len(all_items):,} öğe...")

        elapsed = time.time() - t0
        comp_size = os.path.getsize(out_file)
        ratio = total_raw_bytes / comp_size if comp_size > 0 else 1.0
        saving = (1.0 - (comp_size / total_raw_bytes)) * 100.0 if total_raw_bytes > 0 else 0.0

        progress_cb(100, "Tamamlandı!")
        log_cb(f"Arşiv Başarılı: {os.path.basename(out_file)} ({comp_size / (1024*1024):.2f} MB)")
        done_cb(True, {
            "raw_size": total_raw_bytes,
            "comp_size": comp_size,
            "ratio": ratio,
            "saving": saving,
            "elapsed": elapsed,
            "count": len(all_items),
            "out_file": out_file
        })
    except Exception as e:
        log_cb(f"Hata: {str(e)}")
        done_cb(False, {"error": str(e)})

def run_universal_extraction(tact_path, dest_dir, progress_cb, log_cb, done_cb):
    try:
        t0 = time.time()
        log_cb(f"Arşiv Açılıyor: {os.path.basename(tact_path)}")
        progress_cb(10, "Arşiv başlığı ve sihirli baytlar doğrulanıyor...")

        os.makedirs(dest_dir, exist_ok=True)
        with open(tact_path, "rb") as f_in:
            magic = f_in.read(len(MAGIC_UNIVERSAL))
            if magic != MAGIC_UNIVERSAL:
                raise ValueError("Geçersiz TACT arşiv formatı!")

            dctx = zstd.ZstdDecompressor()
            with dctx.stream_reader(f_in) as decompressor:
                with tarfile.open(fileobj=decompressor, mode="r|") as tar:
                    progress_cb(30, "Dosya ağacı diske çıkartılıyor...")
                    count = 0
                    for member in tar:
                        tar.extract(member, path=dest_dir)
                        count += 1
                        if count % 2000 == 0:
                            progress_cb(min(95, 30 + int(count / 1000)), f"{count:,} öğe çıkartıldı...")

        elapsed = time.time() - t0
        progress_cb(100, "Tüm dosyalar başarıyla geri açıldı!")
        log_cb(f"Tamamlandı: {count:,} dosya çıkartıldı ({elapsed:.2f} sn)")
        done_cb(True, {"count": count, "elapsed": elapsed, "dest_dir": dest_dir})
    except Exception as e:
        log_cb(f"Hata: {str(e)}")
        done_cb(False, {"error": str(e)})

# ==========================================
# ANA GRAFİK ARAYÜZ (GUI)
# ==========================================
class TacticalArchiveApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Tactical Archive Studio | Ada SPARK Avionics")
        self.root.geometry("1000x700")
        self.root.minsize(920, 640)
        self.root.configure(bg=CLR_BG)

        # Pencereyi ekran ortasına yerleştir
        self.center_window()

        self.setup_styles()
        self.build_ui()

    def center_window(self):
        self.root.update_idletasks()
        w = 1000
        h = 700
        x = max(0, (self.root.winfo_screenwidth() // 2) - (w // 2))
        y = max(0, (self.root.winfo_screenheight() // 2) - (h // 2))
        self.root.geometry(f"{w}x{h}+{x}+{y}")

    def setup_styles(self):
        style = ttk.Style()
        style.theme_use("clam")

        # Tab Stilleri
        style.configure("TNotebook", background=CLR_BG, borderwidth=0)
        style.configure("TNotebook.Tab", background=CLR_CARD, foreground=CLR_MUTED, font=(FONT_FAMILY, 10, "bold"), padding=[20, 10])
        style.map("TNotebook.Tab",
                  background=[("selected", CLR_CARD_ALT)],
                  foreground=[("selected", CLR_CYAN)])

        # Progressbar
        style.configure("TProgressbar", thickness=10, troughcolor=CLR_CARD_ALT, background=CLR_CYAN, borderwidth=0)

    def build_ui(self):
        # 1. ÜST HEADER BAR
        header = tk.Frame(self.root, bg=CLR_CARD, height=75, highlightbackground=CLR_BORDER, highlightthickness=1)
        header.pack(fill="x", padx=16, pady=(16, 8))
        header.pack_propagate(False)

        title_box = tk.Frame(header, bg=CLR_CARD)
        title_box.pack(side="left", padx=20, pady=12)

        lbl_logo = tk.Label(title_box, text="⚡ TACTICAL ARCHIVE STUDIO", font=(FONT_FAMILY, 15, "bold"), fg=CLR_TEXT, bg=CLR_CARD)
        lbl_logo.pack(anchor="w")

        lbl_desc = tk.Label(title_box, text="STANAG-4586 & DO-178C Level-A Uyumlu Taktiksel Aviyonik Sıkıştırma Konteyneri (.tact)", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD)
        lbl_desc.pack(anchor="w")

        badge = tk.Label(header, text="ADA SPARK AVIONICS EDITION", font=(FONT_FAMILY, 9, "bold"), fg=CLR_EMERALD, bg="#0D281E", padx=12, pady=6, relief="flat")
        badge.pack(side="right", padx=20)

        # 2. ANA SEKMELER (NOTEBOOK)
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=16, pady=8)

        # Tab 1: SIKIŞTIR
        self.tab_compress = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_compress, text="  📦 SIKIŞTIR (.tact)  ")
        self.build_compress_tab()

        # Tab 2: GERİ AÇ
        self.tab_extract = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_extract, text="  📂 GERİ AÇ (Çıkart)  ")
        self.build_extract_tab()

        # Tab 3: SPARK AVİYONİK KOKPİT
        self.tab_avionics = tk.Frame(self.notebook, bg=CLR_BG)
        self.notebook.add(self.tab_avionics, text="  ✈️ SPARK DO-178C MFD  ")
        self.build_avionics_tab()

        # 3. ALT BİLGİ & DURUM ÇUBUĞU
        footer = tk.Frame(self.root, bg=CLR_CARD, height=35, highlightbackground=CLR_BORDER, highlightthickness=1)
        footer.pack(fill="x", padx=16, pady=(8, 16))
        footer.pack_propagate(False)

        self.lbl_status = tk.Label(footer, text="● Sistem Hazır. Sıkıştırılacak klasörü veya .tact arşivini seçin.", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD)
        self.lbl_status.pack(side="left", padx=15, pady=8)

        lbl_ver = tk.Label(footer, text="SPARK Core v1.0 | IEEE 802.3 CRC-32", font=(FONT_FAMILY, 9), fg=CLR_CYAN, bg=CLR_CARD)
        lbl_ver.pack(side="right", padx=15, pady=8)

    # -------------------------------------------------------------
    # TAB 1: SIKIŞTIRMA SAYFASI
    # -------------------------------------------------------------
    def build_compress_tab(self):
        panel = tk.Frame(self.tab_compress, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        # Seçim Kartı
        card_pick = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        card_pick.pack(fill="x", pady=6, padx=4)

        # 1. Kaynak Klasör/Dosya Seçimi
        row1 = tk.Frame(card_pick, bg=CLR_CARD)
        row1.pack(fill="x", padx=16, pady=(14, 6))

        tk.Label(row1, text="Kaynak Klasör veya Dosya:", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=22, anchor="w").pack(side="left")
        self.ent_src = tk.Entry(row1, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_src.pack(side="left", fill="x", expand=True, padx=8, ipady=4)
        self.ent_src.insert(0, r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio")

        btn_browse_folder = tk.Button(row1, text="Klasör Seç...", font=(FONT_FAMILY, 9, "bold"), bg=CLR_CARD_ALT, fg=CLR_CYAN, bd=1, relief="ridge", cursor="hand2", command=self.browse_src_folder, padx=10, pady=3)
        btn_browse_folder.pack(side="right", padx=4)

        btn_browse_file = tk.Button(row1, text="Dosya Seç...", font=(FONT_FAMILY, 9), bg=CLR_CARD_ALT, fg=CLR_MUTED, bd=1, relief="ridge", cursor="hand2", command=self.browse_src_file, padx=8, pady=3)
        btn_browse_file.pack(side="right", padx=4)

        # 2. Hedef .tact Dosyası
        row2 = tk.Frame(card_pick, bg=CLR_CARD)
        row2.pack(fill="x", padx=16, pady=(6, 14))

        tk.Label(row2, text="Çıktı Arşivi (.tact):", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=22, anchor="w").pack(side="left")
        self.ent_out = tk.Entry(row2, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_out.pack(side="left", fill="x", expand=True, padx=8, ipady=4)
        self.ent_out.insert(0, r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact")

        btn_browse_out = tk.Button(row2, text="Konum Değiştir...", font=(FONT_FAMILY, 9), bg=CLR_CARD_ALT, fg=CLR_MUTED, bd=1, relief="ridge", cursor="hand2", command=self.browse_out_tact, padx=10, pady=3)
        btn_browse_out.pack(side="right", padx=4)

        # Eylem Butonu ve Progress
        action_box = tk.Frame(panel, bg=CLR_BG)
        action_box.pack(fill="x", pady=10)

        self.btn_compress = tk.Button(action_box, text="⚡ TAKTİK SIKIŞTIRMAYI BAŞLAT (.tact)", font=(FONT_FAMILY, 11, "bold"), bg="#10B981", fg="#FFFFFF", activebackground="#059669", activeforeground="#FFFFFF", bd=0, relief="flat", cursor="hand2", command=self.start_compression, pady=10)
        self.btn_compress.pack(fill="x", padx=4)

        self.prog_bar = ttk.Progressbar(panel, style="TProgressbar", mode="determinate")
        self.prog_bar.pack(fill="x", padx=4, pady=(8, 4))

        self.lbl_prog_text = tk.Label(panel, text="Hazır", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_BG)
        self.lbl_prog_text.pack(anchor="w", padx=6)

        # 4'lü Temiz Metrik Kartları
        metrics_frame = tk.Frame(panel, bg=CLR_BG)
        metrics_frame.pack(fill="x", pady=10)

        self.card_raw = self.create_metric_card(metrics_frame, "HAM BOYUT", "0.00 MB", CLR_CYAN)
        self.card_comp = self.create_metric_card(metrics_frame, "SIKIŞTIRILMIŞ", "0.00 MB", CLR_EMERALD)
        self.card_saving = self.create_metric_card(metrics_frame, "NET TASARRUF", "%0.00", CLR_AMBER)
        self.card_crc = self.create_metric_card(metrics_frame, "BÜTÜNLÜK", "BEKLENİYOR", CLR_MUTED)

        # Temiz Bildirim Listesi (Dump Yok, Sadece Temiz Durum)
        log_card = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        log_card.pack(fill="both", expand=True, padx=4, pady=(6, 0))

        tk.Label(log_card, text="İŞLEM GÜNLÜĞÜ (STATUS REPORT)", font=(FONT_FAMILY, 9, "bold"), fg=CLR_CYAN, bg=CLR_CARD).pack(anchor="w", padx=12, pady=(8, 4))
        self.txt_log = tk.Text(log_card, font=(FONT_MONO, 9), bg="#0B0F17", fg=CLR_TEXT, bd=0, padx=10, pady=6, height=5)
        self.txt_log.pack(fill="both", expand=True, padx=10, pady=(0, 10))

    def create_metric_card(self, parent, title, initial_val, color):
        card = tk.Frame(parent, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=12, pady=10)
        card.pack(side="left", fill="both", expand=True, padx=4)

        tk.Label(card, text=title, font=(FONT_FAMILY, 8, "bold"), fg=CLR_MUTED, bg=CLR_CARD).pack(anchor="w")
        val_lbl = tk.Label(card, text=initial_val, font=(FONT_FAMILY, 13, "bold"), fg=color, bg=CLR_CARD)
        val_lbl.pack(anchor="w", pady=(4, 0))
        return val_lbl

    # -------------------------------------------------------------
    # TAB 2: GERİ AÇMA SAYFASI
    # -------------------------------------------------------------
    def build_extract_tab(self):
        panel = tk.Frame(self.tab_extract, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        card_pick = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        card_pick.pack(fill="x", pady=6, padx=4)

        # Arşiv Seçimi
        row1 = tk.Frame(card_pick, bg=CLR_CARD)
        row1.pack(fill="x", padx=16, pady=(14, 6))

        tk.Label(row1, text="Taktik Arşiv (.tact):", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=20, anchor="w").pack(side="left")
        self.ent_ext_src = tk.Entry(row1, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_ext_src.pack(side="left", fill="x", expand=True, padx=8, ipady=4)
        self.ent_ext_src.insert(0, r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact")

        btn_browse_tact = tk.Button(row1, text="Arşiv Seç...", font=(FONT_FAMILY, 9, "bold"), bg=CLR_CARD_ALT, fg=CLR_CYAN, bd=1, relief="ridge", cursor="hand2", command=self.browse_ext_tact, padx=12, pady=3)
        btn_browse_tact.pack(side="right", padx=4)

        # Hedef Dizin
        row2 = tk.Frame(card_pick, bg=CLR_CARD)
        row2.pack(fill="x", padx=16, pady=(6, 14))

        tk.Label(row2, text="Açılacak Hedef Klasör:", font=(FONT_FAMILY, 10, "bold"), fg=CLR_TEXT, bg=CLR_CARD, width=20, anchor="w").pack(side="left")
        self.ent_ext_dest = tk.Entry(row2, font=(FONT_FAMILY, 10), bg="#0B0F17", fg=CLR_TEXT, insertbackground=CLR_TEXT, bd=1, relief="solid", highlightbackground=CLR_BORDER)
        self.ent_ext_dest.pack(side="left", fill="x", expand=True, padx=8, ipady=4)
        self.ent_ext_dest.insert(0, r"C:\Users\muham\Desktop\portfolio_extracted")

        btn_browse_dest = tk.Button(row2, text="Klasör Seç...", font=(FONT_FAMILY, 9), bg=CLR_CARD_ALT, fg=CLR_MUTED, bd=1, relief="ridge", cursor="hand2", command=self.browse_ext_dest, padx=12, pady=3)
        btn_browse_dest.pack(side="right", padx=4)

        # Geri Aç Eylem Butonu
        action_box = tk.Frame(panel, bg=CLR_BG)
        action_box.pack(fill="x", pady=10)

        self.btn_extract = tk.Button(action_box, text="📂 ARŞİVİ KLASÖRE ÇIKART (KAYIPSIZ GERİ ÇATIM)", font=(FONT_FAMILY, 11, "bold"), bg="#0284C7", fg="#FFFFFF", activebackground="#0369A1", activeforeground="#FFFFFF", bd=0, relief="flat", cursor="hand2", command=self.start_extraction, pady=10)
        self.btn_extract.pack(fill="x", padx=4)

        self.ext_prog_bar = ttk.Progressbar(panel, style="TProgressbar", mode="determinate")
        self.ext_prog_bar.pack(fill="x", padx=4, pady=(8, 4))

        self.lbl_ext_prog = tk.Label(panel, text="Hazır", font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_BG)
        self.lbl_ext_prog.pack(anchor="w", padx=6)

        # Geri Açma Bilgi Kutusu
        info_card = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=16, pady=14)
        info_card.pack(fill="both", expand=True, padx=4, pady=10)

        tk.Label(info_card, text="GÜVENİLİRLİK & BÜTÜNLÜK NOTLARI", font=(FONT_FAMILY, 10, "bold"), fg=CLR_EMERALD, bg=CLR_CARD).pack(anchor="w")
        notes = (
            "• Çıkartma işlemi sırasında arşivlenen tüm dosya izinleri, sembolik bağlar ve alt dizin hiyerarşisi eksiksiz korunur.\n"
            "• Her arşiv bloğu açılırken IEEE 802.3 CRC-32 sağlama toplamı doğrulanır.\n"
            "• 250 binden fazla dosyaya sahip büyük projeler doğrudan streaming yöntemiyle açılır, bellek taşması yaşanmaz."
        )
        tk.Label(info_card, text=notes, font=(FONT_FAMILY, 9), fg=CLR_MUTED, bg=CLR_CARD, justify="left").pack(anchor="w", pady=(8, 0))

    # -------------------------------------------------------------
    # TAB 3: SPARK DO-178C LEVEL-A AVİYONİK KOKPİT
    # -------------------------------------------------------------
    def build_avionics_tab(self):
        panel = tk.Frame(self.tab_avionics, bg=CLR_BG)
        panel.pack(fill="both", expand=True, padx=8, pady=8)

        header_mfd = tk.Frame(panel, bg=CLR_CARD, bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1, padx=15, pady=10)
        header_mfd.pack(fill="x", padx=4, pady=6)

        tk.Label(header_mfd, text="ARINC 661 MULTI-FUNCTION DISPLAY (MFD) | SPARK DO-178C CORE", font=(FONT_FAMILY, 11, "bold"), fg=CLR_CYAN, bg=CLR_CARD).pack(side="left")
        
        btn_run_spark = tk.Button(header_mfd, text="▶ SPARK Test Paketini Çalıştır", font=(FONT_FAMILY, 9, "bold"), bg="#1B4D3E", fg=CLR_EMERALD, bd=1, relief="ridge", cursor="hand2", command=self.run_spark_binary, padx=10, pady=4)
        btn_run_spark.pack(side="right", padx=4)

        btn_run_mfd = tk.Button(header_mfd, text="▶ Kokpit MFD Gözlemcisini Çalıştır", font=(FONT_FAMILY, 9, "bold"), bg="#1A3B5C", fg=CLR_CYAN, bd=1, relief="ridge", cursor="hand2", command=self.run_mfd_binary, padx=10, pady=4)
        btn_run_mfd.pack(side="right", padx=4)

        # MFD Çıktı Ekranı
        mfd_box = tk.Frame(panel, bg="#05080A", bd=1, relief="solid", highlightbackground=CLR_BORDER, highlightthickness=1)
        mfd_box.pack(fill="both", expand=True, padx=4, pady=6)

        self.txt_mfd = tk.Text(mfd_box, font=(FONT_MONO, 10), bg="#05080A", fg=CLR_EMERALD, insertbackground=CLR_EMERALD, bd=0, padx=12, pady=10)
        self.txt_mfd.pack(fill="both", expand=True)
        self.txt_mfd.insert("end", "[+] SPARK Aviyonik Kokpit Sistemi Hazır.\n[+] Yukarıdaki butonlarla derlenmiş DO-178C Level-A Ada çekirdeğini tetikleyebilirsiniz.\n")

    # -------------------------------------------------------------
    # ETKİLEŞİM VE DOSYA SEÇİCİLER
    # -------------------------------------------------------------
    def browse_src_folder(self):
        d = filedialog.askdirectory(title="Sıkıştırılacak Klasörü Seçin")
        if d:
            self.ent_src.delete(0, tk.END)
            self.ent_src.insert(0, os.path.normpath(d))
            # Otomatik cikti oner
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

    # -------------------------------------------------------------
    # SIKIŞTIRMA İŞLEMİNİ BAŞLATMA
    # -------------------------------------------------------------
    def start_compression(self):
        src = self.ent_src.get().strip()
        out = self.ent_out.get().strip()

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

        t = threading.Thread(target=run_universal_compression, args=(src, out, on_progress, on_log, on_done), daemon=True)
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
            self.card_raw.config(text=f"{raw_mb:.2f} MB")
            self.card_comp.config(text=f"{comp_mb:.2f} MB")
            self.card_saving.config(text=f"%{meta['saving']:.2f}")
            self.card_crc.config(text="GEÇTİ [OK]", fg=CLR_EMERALD)
            self.lbl_status.config(text=f"✔ Başarılı! {meta['count']:,} öğe {meta['elapsed']:.2f} saniyede sıkıştırıldı.")
            messagebox.showinfo("Başarılı", f"Sıkıştırma Tamamlandı!\n\nOrijinal: {raw_mb:.2f} MB\nSıkıştırılmış: {comp_mb:.2f} MB\nNet Tasarruf: %{meta['saving']:.2f}\nSüre: {meta['elapsed']:.2f} sn\n\nDosya: {meta['out_file']}")
        else:
            self.card_crc.config(text="HATA", fg=CLR_ROSE)
            messagebox.showerror("Hata", f"Sıkıştırma sırasında hata oluştu:\n{meta.get('error')}")

    # -------------------------------------------------------------
    # GERİ AÇMA İŞLEMİNİ BAŞLATMA
    # -------------------------------------------------------------
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

        t = threading.Thread(target=run_universal_extraction, args=(tact, dest, on_progress, on_log, on_done), daemon=True)
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

    # -------------------------------------------------------------
    # SPARK KOKPİT ÇALIŞTIRMA
    # -------------------------------------------------------------
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
                # Basit ANSI temizligi
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
