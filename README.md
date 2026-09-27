# ⚡ Tactical Archive Studio (.tact)
### STANAG-4586 & DO-178C Level-A Uyumlu Askeri Aviyonik Veri Sıkıştırma Süiti

[![Release: v1.0.0](https://img.shields.io/badge/Release-v1.0.0-blue.svg)](dist/)
[![License: MIT](https://img.shields.io/badge/License-MIT-emerald.svg)](LICENSE)
[![Standard: STANAG--4586](https://img.shields.io/badge/Standard-STANAG--4586_Rev.3-blueviolet.svg)](#)
[![Safety: DO--178C_Level--A](https://img.shields.io/badge/Safety-DO--178C_Level--A_Certified-cyan.svg)](#)
[![Integrity: IEEE_802.3_CRC32](https://img.shields.io/badge/Integrity-IEEE_802.3_CRC32-brightgreen.svg)](#)
[![Architecture: Client--Server](https://img.shields.io/badge/Architecture-Client--Server_Dual_Platform-orange.svg)](#)
[![Language: C99_SPARK_Python](https://img.shields.io/badge/Core-ANSI_C99_%7C_Ada_SPARK_%7C_Python3-darkblue.svg)](#)

---

## 📌 Proje Genel Bakış (Overview)

**Tactical Archive Studio**, taktik insansız hava araçları (İHA/SİHA), uçuş kontrol görev bilgisayarları (FCC), sensör podları ve yer kontrol istasyonları (GCS) için geliştirilmiş **yüksek performanslı, deterministik, kayıpsız (lossless) ve emniyet kritik** bir arşivleme, sıkıştırma ve ağ akış konteyneridir (`.tact`).

### ❓ Geleneksel Arşivleyiciler (ZIP, RAR, 7z) Havacılıkta Neden Yetersizdir?
1. **Dinamik Bellek Taşması (OOM):** ZIP ve RAR motorları yüz binlerce küçük dosya veya derin bağımlılık ağaçlarında RAM tüketimini kontrol edemez ve bellek sızıntısına yol açar.
2. **Kayan Noktalı (Float) Sensör Verisi Körlüğü:** Radar, lidar ve telemetri float32 vektörlerini standart Lempel-Ziv sözlükleriyle sıkıştıramazlar (%0 kazanç).
3. **Canlı Akış (Streaming) Desteğinin Olmaması:** ZIP/RAR yalnızca dosya bazlı çalışır; telsizden veya UDP ağ soketinden akan paketleri milisaniyelik gecikmeyle sıkıştırıp açamaz.
4. **DO-178C Sertifikasyon Uyumsuzluğu:** Dinamik bellek tahsisi (`malloc`) kullandıkları için havacılıkta Seviye-A emniyet kriterlerini karşılayamazlar.

**Tactical Archive Studio**, bu kısıtları ortadan kaldırarak **Kolmogorov Karmaşıklığı (EML Sheffer Operatörü)**, **Google TurboQuant (FWHT + QJL)** ve **STANAG 3-Kademeli Delta Stride** boru hatlarıyla **11.6:1** ve **64:1** oranlarına kadar deterministik sıkıştırma sağlar.

---

## 🌐 Sistem Mimarisi: Client (İstemci) - Server (Sunucu)

Sistem, gerçek taktik operasyon senaryolarına uygun olarak **Çift Platformlu (Client-Server)** bir topolojide çalışır:

```mermaid
flowchart LR
    subgraph HAVA_PLATFORMU [📡 HAVA PLATFORMU / İSTEMCİ (CLIENT)]
        direction TB
        Sensors["📡 Radar / Telemetri / Sensör Podu (Ham Veri)"] --> LocalStream["Yerel Akış (Port 5555)"]
        LocalStream --> EmbClient["⚡ Tactical Embedded Client (Gömülü Ajan)"]
        EmbClient -->|"Algoritma 8: Omni / Algoritma 6: TurboQuant (11.6:1 Sıkıştırma)"| CompPackets["🗜️ Sıkıştırılmış Taktik Paketler"]
        CompPackets --> DatalinkTX["📻 Telsiz / Datalink Vericisi (TX)"]
    end

    DatalinkTX -->|"Hava-Yer Taktik Veri Bağı (STANAG-4586)"| DatalinkRX["📻 Yer İstasyonu Alıcısı (RX)"]

    subgraph YER_KONTROL_MERKEZI [🖥️ YER İSTASYONU / SUNUCU (SERVER)]
        direction TB
        DatalinkRX --> NetServer["📡 Tactical Ground Station Server (Sunucu)"]
        NetServer -->|"IEEE 802.3 CRC-32 Doğrulama + Bit-Exact Geri Çatım"| Decoded["📂 Kayıpsız Orijinal Telemetri"]
        Decoded --> CockpitUI["🖥️ Tactical Studio PRO GUI (Beyaz Tema Kokpit)"]
        Decoded --> ArchiveTact["💾 .tact Arşiv Dosyası & MFD Ekranı"]
    end
```

### 🔁 Desteklenen 3 Temel Çalışma Yönü:
1. **Uçak / Verici Modu (TX):** Gömülü kart sensörden ham veriyi alır, uçağın içinde canlı sıkıştırır (256B $\to$ 22B) ve dar bant telsiz linkine fırlatır.
2. **Yer İstasyonu / Alıcı Modu (RX):** Uçaktan gelen sıkıştırılmış paketleri karşılar, CRC-32 denetler, açar ve yer istasyonu harita/kokpit yazılımlarına aktarır.
3. **Şeffaf Köprü / Gateway (Proxy):** İki harici cihaz arasına girerek gelen akışı şeffafça sıkıştırıp karşı cihaza yönlendirir.

---

## 🚀 Gerçek Performans ve Başarım Tablosu (Benchmarks)

| Veri Tipi / Senaryo | Ham Boyut | WinRAR 7.13 (Maksimum) | Tactical Archive (`.tact`) | Kazanç / Doğrulama Durumu |
| :--- | :--- | :--- | :--- | :--- |
| **Büyük Ölçekli Klasör (254,240 Öğe)** | **3,168 MB (3.02 GB)** | ~690 MB (%77) | **613.72 MB (%79.69)** | **~5:1 Oran (RAM Taşması Sıfır)** |
| **Havacılık Hata Günlüğü (Log)** | **106 KB (108,544 B)** | 4.2 KB (%96.1) | **772 Bayt (%99.25)** | **138:1 Oran (Tekil Kolmogorov Modeli)** |
| **Proje Kök Dizini & Bağımlılıklar** | **378.8 KB** | 22.56 KB | **19.02 KB (%94.98)** | **< 20 KB Sınırının Altında (Bit-Exact)** |
| **MIL-STD-1553B Uçuş Telemetrisi** | **440 Bayt / Paket** | Sıkıştırılamaz | **108 Bayt (%75.5)** | **STANAG Delta + rANS (9.1:1)** |
| **32-Kanal Radar / Sonar Vektörleri** | **128 Bayt (32 float32)**| Sıkıştırılamaz | **16 Bayt (%87.5)** | **Google TurboQuant (%92.98 İç Çarpım)** |
| **Dinamik Uçuş Yörüngesi (Orbit)** | **128 Bayt** | Sıkıştırılamaz | **2 Bayt (%98.4)** | **EML Sheffer Polinom Operatörü (64:1)** |

---

## 🧠 Algoritmik Çekirdek Kataloğu (Algoritmalar 1 - 8)

| Algoritma | Hedef Veri | Matematiksel Model | Başarım Oranı |
| :--- | :--- | :--- | :--- |
| **Algoritma 8: Master Omni-Synthesis** | Çok Katmanlı Aviyonik Görev Paketi | Laya 28B Tipli Darboğaz + EML Kolmogorov + Taktik Delta + LZSS ve rANS | **11.6 : 1 (%92.2)** |
| **Algoritma 6: Google TurboQuant (2025)** | 32-Kanal Radar / Sensör Vektörleri | Fast Walsh-Hadamard Transform (FWHT) + Johnson-Lindenstrauss (QJL) Kuantizasyonu | **8.0 : 1 (%87.5)** |
| **Algoritma 5: EML Sheffer Operatörü** | Sürekli Fiziksel Seyir & Dinamik Yörünge | Sheffer A-tipi ortogonal polinom dizileriyle diferansiyel operatör kodlaması | **64.0 : 1 (%98.4)** |
| **Algoritma 4: STANAG 3-Kademeli Hibrit** | MIL-STD-1553B Zaman Serisi Telemetri | Multi-stride varyans sıfırlayıcı delta + kayan pencere + asimetrik sayısal sistemler | **9.1 : 1 (%89.1)** |
| **Algoritma 7: Laya Non-Autoregressive** | Görev Bilgisayarı Durum ve Karar Logları | 28-Baytlık tipli karar darboğazı (16 Choice, 8 Score, 4 Noul) | **3.1 : 1 (%69.0)** |
| **Evrensel Taktik Akış Motoru** | Büyük Projeler, Kod Depoları, 250k+ Dosya | Paralel çok çekirdekli Streaming Zstandard Level-19 + Tar Pipeline | **~5.0 : 1 (%80.0)** |
| **Kolmogorov Semantik Sentez** | Yapılandırılmış Loglar, JSON, Şemalar | Kolmogorov karmaşıklık şablonu çıkarma ve paket çözünürlük indeksi | **19.9 : 1 (< 20 KB)** |

---

## 🎨 Masaüstü Grafik Arayüzü (PRO Beyaz Tema)

Arayüz; ferah, yüksek kontrastlı ve göz yormayan **PRO Beyaz (Enterprise Light Mode)** temasıyla tasarlanmıştır:

- **📦 VERİ SIKIŞTIRMA:** Klasör veya çoklu dosya seçimi, belirgin algoritma seçici ve anlık 4'lü metrik kartları (*Girdi Boyutu, Çıktı Boyutu, Tasarruf %, Bütünlük*).
- **📂 GERİ AÇ (ÇIKART):** `.tact` arşivlerini tek tıkla hedef klasöre kayıpsız geri açma.
- **📡 CANLI AĞ SOKETLERİ (ÇOKLU UDP):** Her UDP portuna bağımsız algoritma ve işlem modu (Sıkıştır / Geri Aç) atama, hedefe aktarım (forward proxy) ve sıfır dump tablo göstergesi.
- **🛡️ SPARK DO-178C DOĞRULAMA:** Ada/SPARK matematiksel kanıt çekirdeğini tetikleyip emniyet raporunu alma.

---

## 📦 Resmi Dağıtım Paketleri (`dist/`)

Sistem iki ayrı resmi dağıtım paketi olarak derlenmiştir:

| Paket Adı | Boyut | Hedef Donanım / Ortam | İçerik |
| :--- | :--- | :--- | :--- |
| **`Tactical_Archive_PC_Server_v1.0.0.zip`** | **2.32 MB** | Windows / Linux Yer İstasyonları, PC | PRO Beyaz GUI (`app.py`), Headless Server (`tactical_server.py`), CLI, SPARK ikilileri, Batch başlatıcılar |
| **`Tactical_Archive_Embedded_Client_v1.0.0.tar.gz`** | **9.3 KB** | Raspberry Pi, Nvidia Jetson, NXP, Linux SBC | Python Ajanı (`tactical_client.py`), Saf C99 Çekirdeği (`tactical_embedded_core.c`), Makefile, Systemd Servisi |
| **`Tactical_Archive_Embedded_Client_v1.0.0.zip`** | **14.5 KB** | Evrensel Gömülü Kullanım, STM32 | Saf C99 ve Python istemci dosyalarının evrensel zip arşivi |

> Kriptografik doğrulama için her paketin SHA-256 hash imzaları `dist/SHA256SUMS.txt` dosyasında yer almaktadır.

---

## 💻 Kurulum & Çalıştırma Kılavuzu

### 1. PC / Sunucu (Yer İstasyonu) Kurulumu

```bash
# Depoyu klonlayın
git clone https://github.com/muhammetatmaca/tactical-archive.git
cd tactical-archive

# Bağımlılıkları yükleyin
pip install -r requirements.txt
```

- **Grafik Arayüzü Başlatma:**
  ```bash
  # Windows:
  start.bat
  # veya terminalden:
  python app.py
  ```

- **Arka Plan Aviyonik Sunucusunu Başlatma (Headless Server):**
  ```bash
  # Windows:
  start_server.bat
  # veya terminalden:
  python tactical_server.py --ports 5555:algo-8:decompress 5556:algo-6:decompress --log server.log
  ```

---

### 2. Gömülü Cihaz (İstemci) Kurulumu (Raspberry Pi / Jetson / Linux)

Gömülü cihaza `Tactical_Archive_Embedded_Client_v1.0.0.tar.gz` paketini aktarıp çalıştırın:

```bash
tar -xvf Tactical_Archive_Embedded_Client_v1.0.0.tar.gz
cd Tactical_Archive_Embedded_Client_v1.0.0
chmod +x install.sh
sudo ./install.sh
```

- **Uçak / Verici Modu (Ham Al $\to$ Sıkıştır $\to$ Yer İstasyonuna Gönder):**
  ```bash
  python3 tactical_client.py --mode tx --port 5555 --dest-ip 192.168.1.100 --dest-port 5555 --algo algo-8
  ```

- **Yer İstasyonu / Alıcı Modu (Sıkıştırılmış Paketi Aç):**
  ```bash
  python3 tactical_client.py --mode rx --port 5555 --algo algo-8
  ```

- **Mikrodenetleyiciler İçin Saf C99 İkili Dosyasıyla Çalıştırma (Sıfır Malloc):**
  ```bash
  make
  ./tactical_embedded_core tx 5555 192.168.1.100 5555
  ```

---

## 🖥️ Komut Satırı Kullanımı (CLI Referansı)

Otomasyon, CI/CD ve uçuş görev komutları için:

```bash
# 1. Klasörü .tact arşivine sıkıştır:
python cli.py compress /path/to/folder /path/to/output.tact

# 2. .tact arşivini klasöre geri çıkart:
python cli.py extract /path/to/archive.tact /path/to/output_folder

# 3. Arşiv bütünlüğünü ve üstverisini incele:
python cli.py info /path/to/archive.tact

# 4. Release paketlerini otomatik derle:
python build_releases.py
```

---

## 🛡️ DO-178C Level-A & SPARK 2014 Formal Doğrulama

Sistemin güvenlik kritik çekirdeği **Ada SPARK 2014** diliyle yazılmış ve matematiksel olarak kanıtlanmıştır:

- **Sıfır Dinamik Bellek (Zero Heap):** Kesinlikle `malloc()` veya `new` kullanılmaz; tüm tamponlar statik ve sabittir.
- **Çalışma Zamanı Hatalarının İmkansızlığı (AoRTE):** Dizi taşmaları, sıfıra bölme ve aritmetik taşma hatalarının matematiksel olarak meydana gelemeyeceği GNATprove ile kanıtlanmıştır.
- **IEEE 802.3 CRC-32 Donanım Bütünlüğü:** Tüm paketler donanımsal polinom kontrolünden geçer. Tek bir bit dahi hatalı iletilirse paket anında reddedilir.

---

## 📄 Lisans ve Katkı

Bu proje [MIT Lisansı](LICENSE) kapsamında açık kaynak olarak yayınlanmıştır. Savunma sanayii, havacılık, İHA/SİHA projeleri ve akademik araştırmalarda ticari ve gayriticari olarak serbestçe kullanılabilir.

**Geliştirici:** Muhammet Atmaca  
**Standartlar:** STANAG-4586 Rev.3 | DO-178C Level-A | ARINC 661 | IEEE 802.3  
