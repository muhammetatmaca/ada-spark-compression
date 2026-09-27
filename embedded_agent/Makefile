# TACTICAL EMBEDDED CORE - MAKEFILE
# DO-178C Level-A Askeri Aviyonik Gomulu Derleme Yapilandirmasi

CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -std=c99 -pedantic -D_POSIX_C_SOURCE=200809L
TARGET = tactical_embedded_core

all: $(TARGET)

$(TARGET): tactical_embedded_core.c
	$(CC) $(CFLAGS) $< -o $@

# ARM Cross-Compilation (Raspberry Pi / Jetson / NXP)
arm:
	arm-linux-gnueabihf-gcc $(CFLAGS) tactical_embedded_core.c -o $(TARGET)_arm32

aarch64:
	aarch64-linux-gnu-gcc $(CFLAGS) tactical_embedded_core.c -o $(TARGET)_aarch64

clean:
	rm -f $(TARGET) $(TARGET)_arm32 $(TARGET)_aarch64 *.o
