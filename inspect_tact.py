import struct

tact_path = r"C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact"
with open(tact_path, "rb") as f:
    magic = f.read(4)
    ver = struct.unpack("B", f.read(1))[0]
    n_files = struct.unpack("<I", f.read(4))[0]
    print(f"Magic: {magic.decode()}, Version: {ver}, Files: {n_files}")
    print(f"{'Dosya Adi':30s} {'Ham (B)':>10s} {'Sikistirilmis':>15s} {'Tasarruf':>10s}")
    print("-" * 70)
    for _ in range(n_files):
        w16_len = struct.unpack("<H", f.read(2))[0]
        fname = f.read(w16_len).decode()
        f_size = struct.unpack("<I", f.read(4))[0]
        f_crc = struct.unpack("<I", f.read(4))[0]
        n_blocks = struct.unpack("<I", f.read(4))[0]
        comp_file_total = 0
        for _ in range(n_blocks):
            raw_l = struct.unpack("<H", f.read(2))[0]
            comp_l = struct.unpack("<H", f.read(2))[0]
            if comp_l == 0:
                f.read(raw_l)
                comp_file_total += raw_l
            else:
                f.read(comp_l)
                comp_file_total += comp_l
        pct = (1.0 - float(comp_file_total) / float(f_size)) * 100.0 if f_size > 0 else 0.0
        print(f"{fname:30s} {f_size:10d} B {comp_file_total:13d} B {pct:9.1f}%")
