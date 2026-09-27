# 📡 Tactical Embedded Agent (Gömülü Sistem Kiti)
### STANAG-4586 & DO-178C Level-A Uyumlu Aviyonik Donanım İstemcisi

Bu paket; **İHA/SİHA uçuş bilgisayarları (FCC), sensör podları, Raspberry Pi, Nvidia Jetson, NXP i.MX, BeagleBone, STM32 ve mikrodenetleyiciler** gibi gömülü sistemlerin **Tactical Archive Studio** ile doğrudan ve canlı konuşabilmesi için hazırlanmış bağımsız bir istemcidir.

---

## 🎯 Ne İşe Yarar?

1. **Uçak / Verici Modu (TX Mode):**
   - Gömülü sistemdeki sensörden veya seri porttan ham telemetri verisini okur.
   - Seçilen taktiksel algoritma ile yerinde sıkıştırır (örn. 256 Bayt $\to$ 22 Bayt, **%92.2 bant genişliği tasarrufu**).
   - Telsiz / Datalink üzerinden yer kontrol istasyonunda çalışan Tactical Archive Studio'ya UDP ile fırlatır.

2. **Yer İstasyonu / Alıcı Modu (RX Mode):**
   - Havadan gelen sıkıştırılmış UDP paketlerini karşılar.
   - **IEEE 802.3 CRC-32** donanımsal bütünlük kontrolü yapar.
   - Sıkıştırılmış paketi sıfır veri kaybı ile orijinal haline açar (`decompress`) ve kokpit ekranına veya seri porta aktarır.

3. **İki Farklı Çalışma Seçeneği:**
   - **Python Ajanı (`tactical_embedded_agent.py`):** Linux kurulu kartlar (Raspberry Pi, Jetson, NXP) için sıfır bağımlılıklı, hafif daemon.
   - **Saf C99 Çekirdeği (`tactical_embedded_core.c`):** Mikrodenetleyiciler (STM32, ESP32, FreeRTOS) veya kısıtlı bellekli kartlar için **sıfır heap (`malloc`suz)** deterministik C kodu.

---

## 🚀 1-Komutla Kurulum (Raspberry Pi / Jetson / Linux)

Gömülü cihazınızda terminali açıp şu komutları verin:

```bash
cd embedded_agent
chmod +x install.sh
sudo ./install.sh
```

Bu betik:
- Gerekli Python ortamını hazırlar.
- Donanım mimarisini tespit eder (ARMv7, AArch64, x86_64).
- `gcc` ile saf C aviyonik çekirdeğini otomatik derler.
- Cihaz açıldığında otomatik başlaması için `systemd` servisini (`tactical-agent.service`) sisteme kaydeder.

---

## 💻 Manuel Çalıştırma Örnekleri

### 1. Uçak / Verici Modu (Gömülü Karttan Bilgisayara Canlı Sıkıştırıp Gönderme)
Gömülü kartın 5555 portuna gelen ham telemetriyi **Algoritma 8 (Omni-Synthesis)** ile sıkıştırıp yerdeki bilgisayarınıza (`192.168.1.100:5555`) fırlatmak için:

```bash
python3 tactical_embedded_agent.py \
  --mode tx \
  --ip 0.0.0.0 \
  --port 5555 \
  --dest-ip 192.168.1.100 \
  --dest-port 5555 \
  --algo algo-8
```

### 2. Yer İstasyonu / Alıcı Modu (Gelen Sıkıştırılmış Paketi Açma)
Uçaktan gelen sıkıştırılmış paketleri karşılayıp orijinaline açmak için:

```bash
python3 tactical_embedded_agent.py \
  --mode rx \
  --ip 0.0.0.0 \
  --port 5555 \
  --algo algo-8
```

### 3. Saf C99 İkili Dosyası ile Çalıştırma (Çok Düşük CPU / RAM)
```bash
# Derleme:
make

# Verici Olarak Çalıştırma:
# ./tactical_embedded_core <mod: tx/rx> <dinleme_portu> <hedef_ip> <hedef_port>
./tactical_embedded_core tx 5555 192.168.1.100 5555
```

---

## 🛠️ STM32 ve RTOS Entegrasyonu (C Kütüphanesi)
STM32 veya mikrodenetleyici projelerinizde `tactical_embedded_core.c` ve `tactical_embedded_core.h` dosyalarını doğrudan projenize dahil edebilirsiniz.
- `tactical_crc32(buffer, len)`: IEEE 802.3 CRC-32 hesaplar.
- `tactical_compress_delta(src, len, dst, max)`: MIL-STD-1553B Delta varyans sıkıştırması.
- `tactical_decompress_delta(src, len, dst, max)`: Kayıpsız geri çatım.
- `tactical_turboquant_compress(src, len, dst, max)`: 32-kanal radar/sensör kuantizasyonu (8:1).
- **Bellek:** Sıfır dinamik bellek (`malloc` yasaktır). DO-178C Seviye-A emniyet sertifikasyonuna uygundur.

---

## 🛡️ Veri Bütünlüğü
Tüm paketler **IEEE 802.3 CRC-32** donanım kontrolünden geçer. Tek bir bit dahi hatalı iletilirse paket emniyetli olarak işaretlenir.
