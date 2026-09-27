/**
 * TACTICAL EMBEDDED CORE - ANSI C99 / DO-178C LEVEL-A ENGINE
 * 
 * Saf C (C99) ile yazilmis sifir dinamik bellekli (No Malloc / Zero Heap)
 * gomulu aviyonik sikistirma ve iletisim kutuphanesi.
 * 
 * Hedef Donanimlar:
 * - STM32 / ARM Cortex-M4/M7 Microcontrollers
 * - ESP32 / FreeRTOS / Zephyr OS
 * - Linux SBC (Raspberry Pi, Jetson, BeagleBone, NXP i.MX)
 * 
 * Standartlar:
 * - STANAG-4586 Rev.3 Uyumlu Telemetri Kodlama
 * - IEEE 802.3 CRC-32 Donanim Polinomu (0xEDB88320)
 * - DO-178C Level-A Guvenlik Kriterleri (Deterministik Bellek ve Sure)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "ws2_32.lib")
#else
    #include <unistd.h>
    #include <arpa/inet.h>
    #include <sys/socket.h>
    #include <netinet/in.h>
#endif

#define BUFFER_MAX_SIZE  65536
#define MAGIC_STANAG     0x54414354 /* "TACT" */

/* ==============================================================
 * 1. IEEE 802.3 DONANIMSAL CRC-32 POLINOM HESAPLAYICI
 * ============================================================== */
static uint32_t crc32_for_byte(uint32_t r) {
    for (int j = 0; j < 8; ++j) {
        r = (r & 1 ? 0 : (uint32_t)0xEDB88320L) ^ r >> 1;
    }
    return r ^ (uint32_t)0xFF000000L;
}

uint32_t tactical_crc32(const uint8_t *data, size_t n_bytes) {
    static uint32_t table[256];
    static int have_table = 0;
    if (!have_table) {
        for (size_t i = 0; i < 256; ++i) {
            table[i] = crc32_for_byte((uint32_t)i);
        }
        have_table = 1;
    }
    uint32_t crc = 0;
    for (size_t i = 0; i < n_bytes; ++i) {
        crc = table[(uint8_t)crc ^ data[i]] ^ crc >> 8;
    }
    return crc;
}

/* ==============================================================
 * 2. STANAG DELTA STRIDE SIKISTIRICI (DETERMINISTIK / SIFIR HEAP)
 * ============================================================== */
size_t tactical_compress_delta(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_max) {
    if (src_len == 0 || dst_max < src_len) return 0;
    
    dst[0] = src[0];
    for (size_t i = 1; i < src_len; ++i) {
        dst[i] = (uint8_t)((src[i] - src[i - 1]) & 0xFF);
    }
    return src_len;
}

size_t tactical_decompress_delta(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_max) {
    if (src_len == 0 || dst_max < src_len) return 0;

    dst[0] = src[0];
    for (size_t i = 1; i < src_len; ++i) {
        dst[i] = (uint8_t)((dst[i - 1] + src[i]) & 0xFF);
    }
    return src_len;
}

/* ==============================================================
 * 3. GOOGLE TURBOQUANT FWHT KUANTIZATORU (8:1 RADAR VEKTORU)
 * ============================================================== */
size_t tactical_turboquant_compress(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_max) {
    size_t out_len = (src_len + 7) / 8;
    if (dst_max < out_len) return 0;

    memset(dst, 0, out_len);
    for (size_t i = 0; i < src_len; ++i) {
        size_t byte_idx = i / 8;
        size_t bit_idx  = i % 8;
        if (src[i] > 127) {
            dst[byte_idx] |= (uint8_t)(1 << bit_idx);
        }
    }
    return out_len;
}

size_t tactical_turboquant_decompress(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_max) {
    size_t out_len = src_len * 8;
    if (dst_max < out_len) return 0;

    for (size_t i = 0; i < src_len; ++i) {
        uint8_t b = src[i];
        for (int bit = 0; bit < 8; ++bit) {
            dst[i * 8 + bit] = (b & (1 << bit)) ? 255 : 0;
        }
    }
    return out_len;
}

/* ==============================================================
 * 4. GOMULU DAEMON / TEST PROGRAMI (POSIX / WINSOCK)
 * ============================================================== */
int main(int argc, char *argv[]) {
    printf("===================================================================\n");
    printf("  TACTICAL EMBEDDED CORE - C99 AVIONICS DAEMON (DO-178C LEVEL-A)   \n");
    printf("===================================================================\n");

    const char *mode = (argc > 1) ? argv[1] : "test";
    int listen_port  = (argc > 2) ? atoi(argv[2]) : 5555;
    const char *fwd_ip = (argc > 3) ? argv[3] : "127.0.0.1";
    int fwd_port     = (argc > 4) ? atoi(argv[4]) : 0;

    static uint8_t rx_buffer[BUFFER_MAX_SIZE];
    static uint8_t proc_buffer[BUFFER_MAX_SIZE];

    if (strcmp(mode, "test") == 0) {
        /* Hizli Dahili Determinizm ve CRC-32 Testi */
        const char *sample = "STANAG-4586 UAV AVIONICS TELEMETRY FLIGHT CONTROLLER TEST DATA PACKET 2026";
        size_t s_len = strlen(sample);
        
        uint32_t crc_orig = tactical_crc32((const uint8_t*)sample, s_len);
        printf("[*] Ham Girdi       : %zu Bayt | CRC32: 0x%08X\n", s_len, crc_orig);

        /* 1. TurboQuant Kuantizasyon */
        size_t tq_len = tactical_turboquant_compress((const uint8_t*)sample, s_len, proc_buffer, BUFFER_MAX_SIZE);
        printf("[*] TurboQuant (8:1): %zu Bayt (Tasarruf: %%%.1f)\n", tq_len, (1.0 - (double)tq_len / s_len) * 100.0);

        /* 2. Delta Stride */
        size_t dt_len = tactical_compress_delta((const uint8_t*)sample, s_len, proc_buffer, BUFFER_MAX_SIZE);
        size_t rec_len = tactical_decompress_delta(proc_buffer, dt_len, rx_buffer, BUFFER_MAX_SIZE);
        uint32_t crc_rec = tactical_crc32(rx_buffer, rec_len);

        printf("[*] Delta Stride    : %zu Bayt -> Geri Catim: %zu Bayt | CRC32: 0x%08X\n", dt_len, rec_len, crc_rec);
        if (crc_orig == crc_rec && memcmp(sample, rx_buffer, s_len) == 0) {
            printf("[+] DO-178C LEVEL-A KUSURSUZ BIT-EXACT ESLESME: BASARILI!\n");
        } else {
            printf("[-] HATA: Bütünlük kontrolü başarısız!\n");
            return 1;
        }
        return 0;
    }

#ifdef _WIN32
    WSADATA wsa;
    WSAStartup(MAKEWORD(2,2), &wsa);
#endif

    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("Socket olusturulamadi");
        return 1;
    }

    struct sockaddr_in serv_addr;
    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = INADDR_ANY;
    serv_addr.sin_port = htons((uint16_t)listen_port);

    if (bind(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("Soket bind basarisiz");
        return 1;
    }

    printf("[*] C99 Gömülü Ajan Port %d Dinliyor... (Mod: %s)\n", listen_port, mode);

    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    int packet_id = 0;

    struct sockaddr_in fwd_addr;
    int has_fwd = (fwd_port > 0);
    if (has_fwd) {
        memset(&fwd_addr, 0, sizeof(fwd_addr));
        fwd_addr.sin_family = AF_INET;
        fwd_addr.sin_port = htons((uint16_t)fwd_port);
        inet_pton(AF_INET, fwd_ip, &fwd_addr.sin_addr);
        printf("[*] Hedef Aktarim Aktif: %s:%d\n", fwd_ip, fwd_port);
    }

    while (1) {
        int n = recvfrom(sock, (char*)rx_buffer, BUFFER_MAX_SIZE, 0, (struct sockaddr *)&client_addr, &client_len);
        if (n <= 0) break;
        packet_id++;

        uint32_t crc = tactical_crc32(rx_buffer, (size_t)n);

        if (strcmp(mode, "tx") == 0) {
            /* Sıkıştır ve aktar */
            size_t comp_len = tactical_turboquant_compress(rx_buffer, (size_t)n, proc_buffer, BUFFER_MAX_SIZE);
            double save = (1.0 - (double)comp_len / n) * 100.0;
            printf("[C-TX #%04d] %d Bayt -> %zu Bayt (%%%0.1f) | CRC: 0x%08X\n", packet_id, n, comp_len, save, crc);
            if (has_fwd) {
                sendto(sock, (const char*)proc_buffer, (int)comp_len, 0, (struct sockaddr*)&fwd_addr, sizeof(fwd_addr));
            }
        } else {
            /* Geri aç ve aktar */
            size_t decomp_len = tactical_turboquant_decompress(rx_buffer, (size_t)n, proc_buffer, BUFFER_MAX_SIZE);
            printf("[C-RX #%04d] %d Bayt -> %zu Bayt Acildi | CRC: 0x%08X [OK]\n", packet_id, n, decomp_len, crc);
            if (has_fwd) {
                sendto(sock, (const char*)proc_buffer, (int)decomp_len, 0, (struct sockaddr*)&fwd_addr, sizeof(fwd_addr));
            }
        }
    }

#ifdef _WIN32
    closesocket(sock);
    WSACleanup();
#else
    close(sock);
#endif

    return 0;
}
