#!/usr/bin/env bash
# =========================================================================
# TACTICAL EMBEDDED AGENT - 1-COMMAND INSTALLER FOR EMBEDDED LINUX
# (Raspberry Pi, Nvidia Jetson, BeagleBone, NXP i.MX, x86/ARM SBC)
# =========================================================================

set -e

echo "==================================================================="
echo "  TACTICAL EMBEDDED AGENT - KURULUM VE DERLEME BETİĞİ              "
echo "  STANAG-4586 & DO-178C LEVEL-A AVİYONİK MOTORU                    "
echo "==================================================================="

# 1. Root Kontrolü
if [ "$EUID" -ne 0 ]; then
  echo "[!] Uyarı: Sistem servisi olarak kurmak için 'sudo ./install.sh' şeklinde çalıştırın."
fi

# 2. Mimariyi Belirle
ARCH=$(uname -m)
echo "[*] Tespit Edilen Donanım Mimarisi: $ARCH"

# 3. Bağımlılıkları Kontrol Et
echo "[*] Bağımlılıklar taranıyor..."
if command -v python3 >/dev/null 2>&1; then
    echo "  [+] Python3 bulundu."
    python3 -m pip install zstandard -q || echo "  [-] zstandard pip paketi yüklenemedi, zlib fallback modu aktif."
fi

# 4. Saf C Motorunu Derle (Varsa GCC)
if command -v gcc >/dev/null 2>&1; then
    echo "[*] Saf C99 aviyonik çekirdeği yerel olarak derleniyor..."
    gcc -O2 -Wall -std=c99 tactical_embedded_core.c -o tactical_embedded_core
    chmod +x tactical_embedded_core
    echo "  [+] 'tactical_embedded_core' ikili dosyası başarıyla derlendi."
    ./tactical_embedded_core test
else
    echo "  [-] gcc bulunamadı, C çekirdeği derlenemedi. Python ajanı kullanılacak."
fi

# 5. Kurulum Dizini
INSTALL_DIR="/opt/tactical_agent"
echo "[*] Dosyalar '$INSTALL_DIR' dizinine kopyalanıyor..."
mkdir -p "$INSTALL_DIR"
cp -r * "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/tactical_embedded_agent.py"

# 6. Systemd Servisi Kurulumu (Eğer root ise)
if [ "$EUID" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
    echo "[*] Systemd servisi yapılandırılıyor..."
    cp tactical-agent.service /etc/systemd/system/
    systemctl daemon-reload
    echo "  [+] Servis kuruldu: tactical-agent.service"
    echo "  [+] Servisi başlatmak için: sudo systemctl start tactical-agent"
    echo "  [+] Otomatik başlatma için: sudo systemctl enable tactical-agent"
fi

echo ""
echo "==================================================================="
echo "  KURULUM TAMAMLANDI!                                              "
echo "==================================================================="
echo "  Manuel çalıştırmak için:"
echo "    # Uçak / Verici Modu (Ham al, sıkıştır ve yer istasyonuna ilet):"
echo "    python3 tactical_embedded_agent.py --mode tx --port 5555 --dest-ip 192.168.1.100 --dest-port 5555 --algo algo-8"
echo ""
echo "    # Yer İstasyonu / Alıcı Modu (Sıkıştırılmış paket al ve aç):"
echo "    python3 tactical_embedded_agent.py --mode rx --port 5555 --algo algo-8"
echo ""
echo "    # Veya Saf C99 İkili Dosyasını Çalıştırın:"
echo "    ./tactical_embedded_core tx 5555 192.168.1.100 5555"
echo "==================================================================="
