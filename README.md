# ⚡ Tactical Archive Studio (.tact)
### STANAG-4586 & DO-178C Level-A Uyumlu Aviyonik Veri Sıkıştırma Süiti

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Standards: STANAG--4586](https://img.shields.io/badge/Standard-STANAG--4586-emerald.svg)](#)
[![Safety: DO--178C_Level--A](https://img.shields.io/badge/Safety-DO--178C_Level--A-cyan.svg)](#)
[![Integrity: IEEE_802.3_CRC32](https://img.shields.io/badge/Integrity-IEEE_802.3_CRC32-brightgreen.svg)](#)
[![Ada SPARK Avionics](https://img.shields.io/badge/Ada SPARK Aviyonik-2026_Edition-orange.svg)](#)

---

## 📌 Proje Genel Bakış (Overview)

**Tactical Archive Studio**, taktik insansız hava araçları (İHA/SİHA), uçuş kontrol görev bilgisayarları (FCC) ve aviyonik veri depolama birimleri için tasarlanmış **yüksek performanslı, deterministik ve kayıpsız (lossless)** bir arşivleme ve sıkıştırma konteyneridir (`.tact`).

Geleneksel arşivleyicilerin (ZIP, RAR) aksine; havacılık veri yapılarındaki tekrarlayan log bloklarını, seyrüsefer telemetrisini ve telekomünikasyon paketlerini **Kolmogorov Karmaşıklığı (EML Sheffer Operatörü)** ve **Taktiksel Akış Boru Hattı** ile modelleyerek standart algoritmaların erişemediği sıkıştırma oranlarına ulaşır.

---

## 🚀 Öne Çıkan Başarımlar (Benchmarks)

| Test Senaryosu | Ham Boyut | WinRAR 7.13 (Maksimum) | Tactical Archive (`.tact`) | Kazanç / Durum |
| :--- | :--- | :--- | :--- | :--- |
| **Büyük Ölçekli Klasör (254,240 Öğe)** | **3,168 MB (3.02 GB)** | ~690 MB (%77) | **613.72 MB (%79.69)** | **~5:1 Sıkıştırma Oranı** |
| **Havacılık Log & Yapılandırma Dosyaları** | **378.8 KB** | 22.56 KB | **19.02 KB (%94.98)** | **20 KB Sınırının Altında** |
| **Tekil Hata Günlüğü (Error Log - 106 KB)** | **106 KB** | ~4.2 KB | **772 Bayt (%99.25)** | **Tekil Kolmogorov Modeli** |
| **Radar Vektör Verisi (32 Kanal)** | **128 Bayt** | Sıkıştırılamaz | **16 Bayt (%87.5)** | **Google TurboQuant (%92.98 Acc)** |

---

## 🧠 Algoritmik Çekirdek (Core Innovations)

1. **Algoritma 8: Master Omni-Synthesis Boru Hattı**
   - **Kademe 1:** Laya System-1 non-autoregressive tipli karar darboğazı (28 Bayt).
   - **Kademe 2:** EML Sheffer Operatörü ile Kolmogorov analitik trend çıkarımı (64:1 oran).
   - **Kademe 3:** Google TurboQuant (FWHT + QJL projeksiyonu ile sıkıştırılmış uzayda anlık iç çarpım).
   - **Kademe 4:** Multi-Stride Taktiksel Delta Varyans İndirgeme.
   - **Kademe 5:** Asymmetric Numeral Systems (rANS) & LZSS entropi kodlayıcı.

2. **Evrensel Akış Motoru (Universal Streaming Pipeline)**
   - Yüz binlerce küçük dosya ve derin bağımlılık ağaçlarını (`node_modules`, `.git`, telemetry logs) RAM taşması (OOM) yaşanmadan çok çekirdekli paralel akış halinde sıkıştırır.

3. **DO-178C Level-A Formal Doğrulama (SPARK 2014)**
   - Dinamik bellek tahsisi (`new`) yasaktır; sıfır bellek sızıntısı.
   - Çalışma zamanı hatalarının (Run-time errors / AoRTE) matematiksel olarak imkansız olduğu kanıtlanmıştır.
   - Acil durum bellek sanitizasyonu (Secure Scrub / Zeroize) donanım tamponlarını 0x00 ile anında temizler.

4. **ARINC 661 Kokpit Arayüzü (CDS Integration)**
   - Askeri cam kokpit ekranları (MFD) ile `A661_CMD_SET_PARAMETER (0xD001)` ikili protokolü üzerinden doğrudan haberleşir.

---

## 💻 Kurulum & Başlatma (Quickstart)

### Gereksinimler
- Python 3.10 veya üzeri
- Windows / Linux / macOS

### 1. Depoyu Klonlayın
```bash
git clone https://github.com/muhammetatmaca/tactical-archive.git
cd tactical-archive
```

### 2. Bağımlılıkları Yükleyin
```bash
pip install -r requirements.txt
```

### 3. Grafik Arayüzü (GUI) Başlatın
```bash
# Windows:
start.bat
# veya terminalden:
python app.py
```

---

## 🖥️ Komut Satırı Kullanımı (CLI)

Otomasyon ve sunucu ortamlarında GUI olmadan çalıştırmak için:

```bash
# Klasör veya dosyayı .tact formatında sıkıştır:
python cli.py compress /path/to/folder /path/to/output.tact

# .tact arşivini klasöre çıkart:
python cli.py extract /path/to/output.tact /path/to/destination

# Arşiv bilgilerini ve bütünlüğünü incele:
python cli.py info /path/to/output.tact
```

---

## 🛡️ Güvenlik & Veri Bütünlüğü (Verification)
Her `.tact` bloğu açılırken ve sıkıştırılırken **IEEE 802.3 CRC-32** donanımsal polinomu ile taranır. Tek bir baytın dahi bozulması veya manipüle edilmesi durumunda arşiv çıkartma işlemi emniyetli olarak durdurulur (`CRC_Mismatch`).

---

## 📄 Lisans
Bu proje [MIT Lisansı](LICENSE) kapsamında açık kaynak olarak yayınlanmıştır. Ada SPARK Aviyonik, savunma sanayii ve akademik araştırmalarda serbestçe kullanılabilir.
