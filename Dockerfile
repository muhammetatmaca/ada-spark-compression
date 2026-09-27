# =========================================================================
# ADA SPARK AVİYONİK SIKIŞTIRMA SÜİTİ (Ada SPARK Avionics Compression Studio)
# STANAG-4586 & DO-178C Level-A Uyumlu Resmi Konteyner Paketi
# =========================================================================

FROM python:3.11-slim

# Temel derleyici ve ağ araçlarını yükle (C99 Çekirdeği için)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    make \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Bağımlılıkları yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Proje kaynak kodlarını kopyala
COPY . .

# Saf C99 Aviyonik Sıkıştırma Çekirdeğini derle ve /usr/local/bin altına bağla
RUN gcc -O3 -Wall -Wextra embedded_agent/tactical_embedded_core.c -o /usr/local/bin/ada_spark_core && \
    chmod +x /usr/local/bin/ada_spark_core

# Açık Kaynak OCI Konteyner Üstverileri (GitHub Packages Entegrasyonu)
LABEL org.opencontainers.image.title="Ada SPARK Aviyonik Sıkıştırma Süiti"
LABEL org.opencontainers.image.description="STANAG-4586 & DO-178C Level-A Uyumlu Emniyet-Kritik Aviyonik Sıkıştırma ve Sunucu Paketi"
LABEL org.opencontainers.image.url="https://github.com/muhammetatmaca/ada-spark-compression"
LABEL org.opencontainers.image.source="https://github.com/muhammetatmaca/ada-spark-compression"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Muhammet Atmaca"

# Çok kanallı telemetri ve radar UDP portları
EXPOSE 5555/udp 5556/udp 5557/udp 5558/udp

# Varsayılan çalışma: Aviyonik Arka Plan Sunucusunu başlat (Port 5555: Omni, Port 5556: Radar)
ENTRYPOINT ["python", "tactical_server.py"]
CMD ["--ports", "5555:algo-8:decompress", "5556:algo-6:decompress"]
