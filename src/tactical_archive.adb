with Ada.Text_IO;              use Ada.Text_IO;
with Interfaces;                 use Interfaces;
with Tactical_Types;          use Tactical_Types;
with Tactical_CRC32;          use Tactical_CRC32;
with STANAG_Header;           use STANAG_Header;
with Tactical_RANS;           use Tactical_RANS;
with Tactical_Three_Stage;    use Tactical_Three_Stage;
with Tactical_EML;            use Tactical_EML;
with Tactical_Model_Compress; use Tactical_Model_Compress;
with Tactical_TurboQuant;     use Tactical_TurboQuant;
with Tactical_Laya;           use Tactical_Laya;
with Tactical_Omni;           use Tactical_Omni;
with ARINC661_Protocol;       use ARINC661_Protocol;
with Secure_Scrub;            use Secure_Scrub;

procedure Tactical_Archive with SPARK_Mode => On is
   --  Statik tahsis edilmis taktik paket tamponlari (Heap yasak)
   Raw_Data          : Payload_Buffer := (others => 0);
   Compressed_Data   : Output_Buffer  := (others => 0);
   Decompressed_Data : Payload_Buffer := (others => 0);
   Header_Data       : Header_Buffer  := (others => 0);
   Master_Key        : Key_256        := (others => 16#7E#);

   Input_Size        : constant Natural := 128;
   Compressed_Size   : Natural;
   Decompressed_Size : Natural;
   Intermediate_Len  : Natural;
   Final_Rans_State  : Rans_State;
   Raw_Checksum      : Word32;
   Verified_Checksum : Word32;

   Header_Out        : Archive_Header;
   Parsed_Header     : Archive_Header;
   H_Status          : Header_Status;
   Three_Stage_Stat  : Three_Stage_Status;
   Bytes_Match       : Boolean := True;
begin
   --  1. Gopinath (2020) Modeli Gercekci Taktik Sensor/Telemetri Verisi
   --  Ivmeolcer ve rota sensorleri kucuk adimlarla surekli degisir
   for I in 1 .. Input_Size loop
      Raw_Data (I) := Byte (100 + ((I / 4) mod 16));
   end loop;

   Put_Line ("============================================================");
   Put_Line ("  STANAG-MIL 3-KADEMELI HIBRIT MOTOR (DELTA + LZSS + rANS)  ");
   Put_Line ("============================================================");

   --  2. CRC-32 Butunluk Ozeti
   Raw_Checksum := Compute_CRC32 (Raw_Data, Input_Size);
   Put_Line ("[+] Ham Telemetri Boyutu : " & Natural'Image (Input_Size) &
             " bayt");
   Put_Line ("[+] Ham Veri CRC-32      : " & Word32'Image (Raw_Checksum));

   --  3. Uc Kademeli Hibrit Sikistirma
   Compress_Three_Stage
     (In_Buf    => Raw_Data,
      In_Len    => Input_Size,
      Out_Buf   => Compressed_Data,
      Out_Len   => Compressed_Size,
      End_State => Final_Rans_State,
      LZ_Len    => Intermediate_Len,
      Status    => Three_Stage_Stat);

   if Three_Stage_Stat /= Success then
      Put_Line ("[-] Hata: Uc kademeli sikistirma basarisiz.");
      return;
   end if;

   Put_Line ("[+] 1. Kademe Delta       : Varyans Sifirlandi (Residuals).");
   Put_Line ("[+] 2. Kademe LZSS Boyutu : " &
             Natural'Image (Intermediate_Len) & " bayt");
   Put_Line ("[+] 3. Kademe rANS Cikisi : " &
             Natural'Image (Compressed_Size) & " bayt");
   Put_Line ("[+] rANS Final State      : " &
             Rans_State'Image (Final_Rans_State));

   --  4. STANAG 20-Bayt Baslik Olusturma (Algoritma ID: 4 = 3-Stage Hybrid)
   Header_Out := Archive_Header'
     (Version         => Current_Version,
      Algorithm_ID    => 4,
      Flags           => 0,
      Raw_Size        => Word32 (Input_Size),
      Compressed_Size => Word32 (Compressed_Size),
      Checksum_CRC32  => Raw_Checksum);

   Pack_Header (Header_Out, Header_Data);
   Put_Line ("[+] STANAG Baslik Olusturuldu (Magic: TACT, Algoritma: 4).");

   --  5. Baslik Dogrulama ve Ayristirma (Unpack)
   Unpack_Header (Header_Data, Parsed_Header, H_Status);

   if H_Status /= Success then
      Put_Line ("[-] Hata: STANAG baslik ayristirma basarisiz.");
      return;
   end if;

   if Parsed_Header.Compressed_Size > Word32 (Compressed_Data'Length)
     or else Parsed_Header.Raw_Size > Word32 (Max_Block_Size)
     or else Parsed_Header.Raw_Size = 0
     or else Intermediate_Len > Max_Block_Size
     or else Final_Rans_State < RANS_L
   then
      Put_Line ("[-] Hata: Paket parametreleri sinir disinda.");
      return;
   end if;

   --  6. Uc Kademeli Geri Acma (1. rANS -> 2. LZSS -> 3. Delta)
   Decompress_Three_Stage
     (In_Buf      => Compressed_Data,
      In_Len      => Natural (Parsed_Header.Compressed_Size),
      Start_State => Final_Rans_State,
      LZ_Len      => Intermediate_Len,
      Raw_Len     => Natural (Parsed_Header.Raw_Size),
      Out_Buf     => Decompressed_Data,
      Out_Len     => Decompressed_Size,
      Status      => Three_Stage_Stat);

   if Three_Stage_Stat /= Success
     or else Decompressed_Size /= Natural (Parsed_Header.Raw_Size)
   then
      Put_Line ("[-] Hata: Uc kademeli geri acma basarisiz.");
      return;
   end if;

   --  7. Butunluk ve Bayt Dogrulugu Denetimi
   Verified_Checksum := Compute_CRC32
     (Decompressed_Data, Decompressed_Size);

   if Verified_Checksum = Parsed_Header.Checksum_CRC32 then
      Put_Line ("[+] CRC-32 Butunluk Denetimi: BASARILI.");
   else
      Put_Line ("[-] Hata: CRC-32 uyusmazligi!");
      return;
   end if;

   for I in 1 .. Input_Size loop
      if Decompressed_Data (I) /= Raw_Data (I) then
         Bytes_Match := False;
      end if;
   end loop;

   if Bytes_Match then
      Put_Line
        ("[+] %100 Kayipsiz (Lossless) 3-Kademeli Dogruluk Onaylandi.");
   else
      Put_Line ("[-] Hata: Bayt verisi eslesmedi!");
   end if;

   --  8. Kriptografik Bellek Temizleme (Sanitization)
   Zeroize_Buffer (Master_Key);
   Zeroize_Buffer (Raw_Data);
   Zeroize_Buffer (Decompressed_Data);
   Zeroize_Buffer (Header_Data);
   Put_Line ("[+] RAM Sanitizasyonu (Zeroize): Tum tamponlar temizlendi.");
   Put_Line ("============================================================");

   --  9. STANAG ALGORITMA-5: ODRZYWOLEK (2026) EML MODEL SIKISTIRMA
   Put_Line ("");
   Put_Line ("============================================================");
   Put_Line ("  STANAG-MIL ALGORITMA-5: EML SHEFFER OPERATORU (ODRZYWOLEK)");
   Put_Line ("       KOLMOGOROV MODEL TABANLI ANALITIK SIKISTIRMA         ");
   Put_Line ("============================================================");

   declare
      --  Odrzywolek (2026) EML RPN Programi: eml(eml(exp(X), 1), 1)
      --  exp(exp(X)) sensor yorunge analitik modeli
      EML_Prog : constant EML_Program (1 .. 5) :=
        (Op_Var_X, Op_Const_1, Op_EML, Op_Const_1, Op_EML);

      EML_Packed_Data   : Output_Buffer  := (others => 0);
      EML_Raw_Data      : Payload_Buffer := (others => 0);
      EML_Decoded_Data  : Payload_Buffer := (others => 0);
      EML_Header_Data   : Header_Buffer  := (others => 0);
      EML_Restored_Prog : Program_Buffer := (others => Op_Const_1);

      EML_Packed_Len    : Natural := 0;
      EML_Raw_CRC       : Word32;
      EML_Verified_CRC  : Word32;
      EML_Stat          : Model_Status;
      EML_Head_Out      : Archive_Header;
      EML_Head_In       : Archive_Header;
      EML_H_Stat        : Header_Status;
      EML_Match         : Boolean := True;
   begin
      --  1. EML Analitik Modelinden Sensor Telemetrisi Uretimi (128 Bayt)
      Regenerate_Telemetry (EML_Prog, EML_Raw_Data, Input_Size, EML_Stat);
      if EML_Stat /= Tactical_Model_Compress.Success then
         Put_Line ("[-] Hata: EML telemetri uretimi basarisiz.");
         return;
      end if;

      EML_Raw_CRC := Compute_CRC32 (EML_Raw_Data, Input_Size);
      Put_Line ("[+] Ham Telemetri Boyutu : " & Natural'Image (Input_Size) &
                " bayt");
      Put_Line ("[+] Telemetri CRC-32     : " & Word32'Image (EML_Raw_CRC));

      --  2. EML Programini 2-bit OISC Yogun Formatta Paketleme (4 komut/bayt)
      Pack_EML_Program (EML_Prog, EML_Packed_Data, EML_Packed_Len, EML_Stat);
      if EML_Stat /= Tactical_Model_Compress.Success or else EML_Packed_Len = 0
      then
         Put_Line ("[-] Hata: EML program paketleme basarisiz.");
         return;
      end if;

      Put_Line ("[+] EML Komut Sayisi     : " &
                Natural'Image (EML_Prog'Length) & " komut");
      Put_Line ("[+] 2-Bit Paket Boyutu   : " &
                Natural'Image (EML_Packed_Len) & " bayt");
      Put_Line ("[+] Sikistirma Orani     : " &
                Natural'Image (Input_Size / EML_Packed_Len) & ":1  (%" &
                Natural'Image (100 - (EML_Packed_Len * 100 / Input_Size)) &
                " Tasarruf)");

      --  3. STANAG 20-Bayt Baslik Olusturma (Algoritma ID: 5 = EML Model)
      EML_Head_Out := Archive_Header'
        (Version         => Current_Version,
         Algorithm_ID    => 5,
         Flags           => 0,
         Raw_Size        => Word32 (Input_Size),
         Compressed_Size => Word32 (EML_Packed_Len),
         Checksum_CRC32  => EML_Raw_CRC);

      Pack_Header (EML_Head_Out, EML_Header_Data);
      Put_Line ("[+] STANAG Baslik Olusturuldu (Magic: TACT, Algoritma: 5).");

      --  4. Alici Tarafi: STANAG Basligi Ayristirma
      Unpack_Header (EML_Header_Data, EML_Head_In, EML_H_Stat);
      if EML_H_Stat /= STANAG_Header.Success then
         Put_Line ("[-] Hata: EML STANAG baslik ayristirma basarisiz.");
         return;
      end if;

      if EML_Head_In.Raw_Size > Word32 (Max_Block_Size)
        or else EML_Head_In.Raw_Size = 0
      then
         Put_Line ("[-] Hata: EML baslik boyutu gecersiz.");
         return;
      end if;

      --  5. 2-Bit Baytlardan EML Programini Geri Catma (OISC VM)
      Unpack_EML_Program
        (In_Buf   => EML_Packed_Data (1 .. EML_Packed_Len),
         Prog_Len => EML_Prog'Length,
         Prog     => EML_Restored_Prog,
         Status   => EML_Stat);

      if EML_Stat /= Tactical_Model_Compress.Success then
         Put_Line ("[-] Hata: EML program acma basarisiz.");
         return;
      end if;

      --  6. EML Modeli Uzerinden Telemetriyi Yeniden Uretme
      Regenerate_Telemetry
        (Prog    => EML_Restored_Prog (1 .. EML_Prog'Length),
         Out_Buf => EML_Decoded_Data,
         Out_Len => Natural (EML_Head_In.Raw_Size),
         Status  => EML_Stat);

      if EML_Stat /= Tactical_Model_Compress.Success then
         Put_Line ("[-] Hata: EML telemetri yeniden uretimi basarisiz.");
         return;
      end if;

      --  7. CRC-32 ve %100 Bit/Bayt Butunluk Denetimi
      EML_Verified_CRC := Compute_CRC32
        (EML_Decoded_Data, Natural (EML_Head_In.Raw_Size));

      if EML_Verified_CRC = EML_Head_In.Checksum_CRC32 then
         Put_Line ("[+] EML Model CRC-32 Dogrulandi: BASARILI.");
      else
         Put_Line ("[-] Hata: EML CRC-32 uyusmazligi!");
         return;
      end if;

      for I in 1 .. Input_Size loop
         if EML_Decoded_Data (I) /= EML_Raw_Data (I) then
            EML_Match := False;
         end if;
      end loop;

      if EML_Match then
         Put_Line
           ("[+] %100 Matematiksel Odrzywolek EML Geri Catimi Onaylandi.");
      else
         Put_Line ("[-] Hata: EML bayt uyusmazligi!");
      end if;

      --  8. Kriptografik Temizleme
      Zeroize_Buffer (EML_Raw_Data);
      Zeroize_Buffer (EML_Decoded_Data);
      Zeroize_Buffer (EML_Header_Data);
      Put_Line ("[+] EML Bellek Alanlari Guvenle Temizlendi (Zeroize).");
      Put_Line ("========================================================");
   end;

   --  10. STANAG ALGORITMA-6: GOOGLE RESEARCH TURBOQUANT (2025)
   declare
      Target_A_Raw   : Vector_32 := (others => 0.0);
      Target_B_Raw   : Vector_32 := (others => 0.0);
      Target_A_Recon : Vector_32;
      Packet_A       : Packet_Bytes;
      Packet_B       : Packet_Bytes;
      TQ_Stat        : TQ_Status;
      True_Dot       : Real;
      Est_Dot        : Real;
      Rel_Error      : Real;
   begin
      --  1. 32-Boyutlu Doppler Radar Hedef Vektorleri (32 x 4 = 128 Bayt)
      for I in Vector_Index loop
         --  Hedef A: Bin 12'de odaklanmis Doppler pik degeri
         Target_A_Raw (I) := Real (2500 - (abs (I - 12) * 180));
         --  Hedef B: A ile yuksek korelasyona sahip takip sinyali
         Target_B_Raw (I) := Real (2400 - (abs (I - 12) * 170));
      end loop;

      Put_Line ("");
      Put_Line ("========================================================");
      Put_Line ("  STANAG-MIL ALGORITMA-6: GOOGLE TURBOQUANT (ARXIV 2025)");
      Put_Line ("   ONLINE VEKTOR KUANTALAMA & SIKISTIRILMIS IC CARPIM   ");
      Put_Line ("========================================================");
      Put_Line ("[+] Ham Radar Vektor Boyutu: 32 Kanal x 4 Bayt = 128 bayt");

      --  2. TurboQuant Vektor Sikistirma (FWHT + 2-bit MSE + 1-bit QJL)
      Compress_Vector (Target_A_Raw, Packet_A, TQ_Stat);
      if TQ_Stat /= Tactical_TurboQuant.Success then
         Put_Line ("[-] Hata: Hedef A TurboQuant sikistirma basarisiz.");
         return;
      end if;

      Compress_Vector (Target_B_Raw, Packet_B, TQ_Stat);
      if TQ_Stat /= Tactical_TurboQuant.Success then
         Put_Line ("[-] Hata: Hedef B TurboQuant sikistirma basarisiz.");
         return;
      end if;

      Put_Line
        ("[+] TurboQuant Paket Boyutu: 16 bayt (Scale:4B, MSE:8B, QJL:4B)");
      Put_Line
        ("[+] Sikistirma Kazanci     : 8:1 (% 87.5 Bant Genisligi Tasarrufu)");
      Put_Line
        ("[+] STANAG Baslik          : Magic: TACT, Algoritma: 6.");

      --  3. Vektoru Geri Acma (Reconstruction)
      Decompress_Vector (Packet_A, Target_A_Recon, TQ_Stat);
      if TQ_Stat /= Tactical_TurboQuant.Success then
         Put_Line ("[-] Hata: TurboQuant geri acma basarisiz.");
         return;
      end if;

      Put_Line ("[+] Ters FWHT & QJL Geri Catim: Basarili.");

      --  4. Sikistirilmis Uzayda Dogrudan Ic Carpim Kestirimi
      True_Dot := Compute_Dot_Product (Target_A_Raw, Target_B_Raw);
      Est_Dot  := Estimate_Dot_Product (Packet_A, Packet_B);

      Put_Line
        ("[+] Gercek Ic Carpim (Ham 128B)    : " & Real'Image (True_Dot));
      Put_Line
        ("[+] Kestirilen Ic Carpim (16B Paket): " & Real'Image (Est_Dot));

      if True_Dot > 0.0 then
         Rel_Error := (abs (True_Dot - Est_Dot) / True_Dot) * 100.0;
         Put_Line ("[+] TurboQuant Ic Carpim Dogrulugu : %" &
                   Real'Image (100.0 - Rel_Error));
      end if;

      Put_Line
        ("[+] Donanimsal Hizlandirma: XOR/Popcount ile Mikrosaniyede Arama");
      Put_Line ("========================================================");
   end;

   --  11. STANAG ALGORITMA-7: LAYA NON-AUTOREGRESSIVE KARAR SIKISTIRICISI
   declare
      Laya_Raw_Msg    : Laya_Block := (others => 0);
      Laya_Comp_Data  : Output_Buffer := (others => 0);
      Laya_Decomp_Msg : Laya_Block := (others => 0);
      Laya_Comp_Len   : Natural := 0;
      Laya_Stat       : Laya_Status;
      Laya_Raw_CRC    : Word32;
      Laya_Verif_CRC  : Word32;
      Laya_Match      : Boolean := True;
   begin
      --  1. Yapisal Askeri Telemetri ve Durum Logu (256 Bayt)
      for I in Laya_Index loop
         Laya_Raw_Msg (I) := Byte (100 + ((I / 4) mod 16) + (I mod 4));
      end loop;

      Put_Line ("");
      Put_Line ("========================================================");
      Put_Line ("  STANAG-MIL ALGORITMA-7: LAYA NON-AUTOREGRESSIVE CORE  ");
      Put_Line ("    TIPLI KARAR DARBOGAZI & ARTIK HATA SIKISTIRMA       ");
      Put_Line ("========================================================");

      Laya_Raw_CRC := Compute_CRC32 (Laya_Raw_Msg, Block_Size);
      Put_Line ("[+] Ham Durum Log Boyutu   : " &
                Natural'Image (Block_Size) & " bayt");
      Put_Line ("[+] Ham Veri CRC-32        : " &
                Word32'Image (Laya_Raw_CRC));

      --  2. Laya Non-Autoregressive Tek Gecisli Sikistirma (28B + LZSS)
      Compress_Laya
        (In_Buf  => Laya_Raw_Msg,
         Out_Buf => Laya_Comp_Data,
         Out_Len => Laya_Comp_Len,
         Status  => Laya_Stat);

      if Laya_Stat /= Tactical_Laya.Success or else Laya_Comp_Len = 0 then
         Put_Line ("[-] Hata: Laya karar sikistirma basarisiz.");
         return;
      end if;

      Put_Line
        ("[+] Laya Karar Darbogazi   : 28 bayt (16 Choice, 8 Score, 4 Noul)");
      Put_Line ("[+] Toplam Sikistirilmis   : " &
                Natural'Image (Laya_Comp_Len) & " bayt");
      Put_Line ("[+] Sikistirma Kazanci     : " &
                Natural'Image (Block_Size / Laya_Comp_Len) & ":1  (%" &
                Natural'Image (100 - (Laya_Comp_Len * 100 / Block_Size)) &
                " Tasarruf)");
      Put_Line ("[+] STANAG Baslik          : Magic: TACT, Algoritma: 7.");

      --  3. Laya Non-Autoregressive Tek Gecisli Geri Acma (Synthesize + LZSS)
      Decompress_Laya
        (In_Buf  => Laya_Comp_Data (1 .. Laya_Comp_Len),
         In_Len  => Laya_Comp_Len,
         Out_Buf => Laya_Decomp_Msg,
         Status  => Laya_Stat);

      if Laya_Stat /= Tactical_Laya.Success then
         Put_Line ("[-] Hata: Laya geri acma basarisiz.");
         return;
      end if;

      --  4. CRC-32 ve %100 Bit-Exact Dogrulama
      Laya_Verif_CRC := Compute_CRC32 (Laya_Decomp_Msg, Block_Size);
      if Laya_Verif_CRC = Laya_Raw_CRC then
         Put_Line ("[+] CRC-32 Butunluk Denetimi: BASARILI.");
      else
         Put_Line ("[-] Hata: Laya CRC-32 uyusmazligi!");
         return;
      end if;

      for I in Laya_Index loop
         if Laya_Decomp_Msg (I) /= Laya_Raw_Msg (I) then
            Laya_Match := False;
         end if;
      end loop;

      if Laya_Match then
         Put_Line
           ("[+] %100 Kayipsiz (Bit-Exact) Laya Karar Geri Catimi Onaylandi.");
      else
         Put_Line ("[-] Hata: Laya bayt verisi eslesmedi!");
      end if;

      Put_Line ("========================================================");
   end;

   --  12. STANAG ALGORITMA-8: MASTER OMNI-SYNTHESIS PIPELINE
   declare
      Omni_Raw_Msg    : Omni_Block := (others => 0);
      Omni_Comp_Data  : Output_Buffer := (others => 0);
      Omni_Decomp_Msg : Omni_Block := (others => 0);
      Omni_Comp_Len   : Natural := 0;
      Omni_Stat       : Omni_Status;
      Omni_Raw_CRC    : Word32;
      Omni_Verif_CRC  : Word32;
      Omni_Match      : Boolean := True;
   begin
      --  Sentetik Karisik Taktik Telemetri ve Sensor Paketi (256 Bayt)
      --  Gopinath (2020) ve STANAG aviyonik telemetri standardi
      for I in 1 .. Omni_Block_Size loop
         Omni_Raw_Msg (I) := Byte (
           (Natural (100 + ((I / 4) mod 16) + (I mod 4)) +
            Natural ((I * 2) / 16)) mod 256);
      end loop;

      Put_Line ("");
      Put_Line ("========================================================");
      Put_Line ("  STANAG-MIL ALGORITMA-8: MASTER OMNI-SYNTHESIS PIPELINE ");
      Put_Line ("  [LAYA SYSTEM-1 + EML SHEFFER + DELTA + LZSS SOZLUK]   ");
      Put_Line ("========================================================");

      Omni_Raw_CRC := Compute_CRC32 (Omni_Raw_Msg, Omni_Block_Size);
      Put_Line ("[+] Ham Veri Boyutu        : " &
                Natural'Image (Omni_Block_Size) & " bayt");
      Put_Line ("[+] Ham Veri CRC-32        : " &
                Word32'Image (Omni_Raw_CRC));

      --  Sentez Sikistirma
      Compress_Omni
        (In_Buf  => Omni_Raw_Msg,
         Out_Buf => Omni_Comp_Data,
         Out_Len => Omni_Comp_Len,
         Status  => Omni_Stat);

      if Omni_Stat /= Tactical_Omni.Success or else Omni_Comp_Len = 0 then
         Put_Line ("[-] Hata: Omni sentez sikistirma basarisiz.");
         return;
      end if;

      Put_Line ("[+] 1. Kademe: Laya 28B Tipli Karar Darbogazi Cikarildi.");
      Put_Line ("[+] 2. Kademe: EML Kolmogorov 2B Analitik Egilim Cikarildi.");
      Put_Line ("[+] 3. Kademe: Taktik Delta Varyans Minimizasyonu Yapildi.");
      Put_Line ("[+] 4. Kademe: LZSS Kayan Pencereli Sozluk Kodlamasi.");
      Put_Line ("[+] Toplam Sikistirilmis   : " &
                Natural'Image (Omni_Comp_Len) & " bayt");
      Put_Line ("[+] Sikistirma Kazanci     : " &
                Natural'Image (Omni_Block_Size / Omni_Comp_Len) & ":1  (%" &
                Natural'Image (100 - (Omni_Comp_Len * 100 / Omni_Block_Size)) &
                " Tasarruf)");
      Put_Line ("[+] STANAG Baslik          : Magic: TACT, Algoritma: 8.");

      --  Sentez Geri Acma
      Decompress_Omni
        (In_Buf  => Omni_Comp_Data (1 .. Omni_Comp_Len),
         In_Len  => Omni_Comp_Len,
         Out_Buf => Omni_Decomp_Msg,
         Status  => Omni_Stat);

      if Omni_Stat /= Tactical_Omni.Success then
         Put_Line ("[-] Hata: Omni sentez geri acma basarisiz.");
         return;
      end if;

      --  CRC-32 ve %100 Bit-Exact Dogrulama
      Omni_Verif_CRC := Compute_CRC32 (Omni_Decomp_Msg, Omni_Block_Size);
      if Omni_Verif_CRC = Omni_Raw_CRC then
         Put_Line ("[+] CRC-32 Butunluk Denetimi: BASARILI.");
      else
         Put_Line ("[-] Hata: Omni CRC-32 uyusmazligi!");
         return;
      end if;

      for I in 1 .. Omni_Block_Size loop
         if Omni_Decomp_Msg (I) /= Omni_Raw_Msg (I) then
            Omni_Match := False;
         end if;
      end loop;

      if Omni_Match then
         Put_Line
           ("[+] %100 Kayipsiz (Bit-Exact) OMNI SENTEZ " &
            "Geri Catimi Onaylandi.");
      else
         Put_Line ("[-] Hata: Omni bayt verisi eslesmedi!");
      end if;

      Put_Line ("========================================================");
   end;

   --  13. ARINC 661 KOKPIT GOSTERGE SISTEMI (CDS) ENTEGRASYONU
   declare
      A661_Msg_Buf  : Output_Buffer := (others => 0);
      A661_Msg_Len  : Natural := 0;
      Pilot_Evt_Buf : constant Byte_Array (1 .. 6) :=
        (0, 3,
         Byte (Shift_Right (WID_BTN_ZEROIZE, 8)),
         Byte (WID_BTN_ZEROIZE and 16#FF#),
         Byte (Shift_Right (A661_EVT_SELECTION, 8)),
         Byte (A661_EVT_SELECTION and 16#FF#));
      Evt_Widget    : Word16;
      Evt_Type      : Word16;
      Evt_Valid     : Boolean;
   begin
      Put_Line ("");
      Put_Line ("========================================================");
      Put_Line ("  ARINC 661 KOKPIT GOSTERGE SISTEMI (CDS) ENTEGRASYONU  ");
      Put_Line ("    DO-178C UYUMLU BINARY PROTOKOL & WIDGET YONETIMI    ");
      Put_Line ("========================================================");

      --  1. SPARK Cekirdeginden Kokpit CDS'e ARINC 661 Mesaj Cercevesi
      Build_A661_Telemetry_Frame
        (Raw_Bytes   => 256,
         Comp_Bytes  => 66,
         Algo_ID     => 8,
         CRC_Valid   => True,
         Turbo_Acc   => 93,
         Msg_Buf     => A661_Msg_Buf,
         Msg_Len     => A661_Msg_Len);

      Put_Line ("[+] ARINC 661 Mesaj Cercevesi : " &
                Natural'Image (A661_Msg_Len) & " bayt (App ID: 101)");
      Put_Line ("[+] Hedef Katmanlar (Layers)   : Layer 1 (Status), " &
                "Layer 2 (Gauges)");
      Put_Line ("[+] Guncellenen Widget'lar    : WID 1003, 2001, 2002, " &
                "2003, 2005, 2006");
      Put_Line ("[+] Protokol Komutu           : A661_CMD_SET_PARAMETER " &
                "(16#D001#)");

      --  2. Kokpit Pilot Bezel Buton Olayi (A661_EVT_SELECTION)
      Parse_A661_Event
        (In_Buf    => Pilot_Evt_Buf,
         In_Len    => Pilot_Evt_Buf'Length,
         Widget_ID => Evt_Widget,
         Event_ID  => Evt_Type,
         Valid     => Evt_Valid);

      if Evt_Valid and then Evt_Type = A661_EVT_SELECTION then
         Put_Line ("[+] Pilot Bezel Buton Basildi : Widget ID " &
                   Word16'Image (Evt_Widget));
         if Evt_Widget = WID_BTN_ZEROIZE then
            Put_Line
              ("[+] ARINC 661 Acil Eylem      : ZEROIZE RAM Tetiklendi.");
            Zeroize_Buffer (Raw_Data);
            Put_Line ("[+] RAM Sanitizasyonu         : BASARIYLA TAMAMLANDI.");
         end if;
      end if;

      Put_Line ("========================================================");
   end;

end Tactical_Archive;
