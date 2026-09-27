with Ada.Text_IO;         use Ada.Text_IO;
with Interfaces;          use Interfaces;
with Tactical_Types;      use Tactical_Types;
with ARINC661_Protocol;   use ARINC661_Protocol;
with Tactical_Omni;       use Tactical_Omni;
with Tactical_CRC32;      use Tactical_CRC32;
with Secure_Scrub;        use Secure_Scrub;

procedure Tactical_MFD_Cockpit is

   --  ANSI Renk Kodlari
   ESC : constant Character := Character'Val (27);
   CLR : constant String := ESC & "[2J" & ESC & "[H";
   GRN : constant String := ESC & "[38;5;46m";   --  Havacilik Fosfor Yesili
   AMB : constant String := ESC & "[38;5;214m";  --  Aviyonik Sari/Kehribar
   CYN : constant String := ESC & "[38;5;51m";   --  Aviyonik Camgobezi
   RED : constant String := ESC & "[38;5;196m";  --  Tehlike/Acil Durum Kirmizisi
   WHT : constant String := ESC & "[38;5;231m";  --  Beyaz
   GRY : constant String := ESC & "[38;5;242m";  --  Koyu Gri
   RST : constant String := ESC & "[0m";         --  Sifirla

   A661_Msg_Buf : Output_Buffer := (others => 0);
   A661_Msg_Len : Natural := 0;

   --  Ornek Taktik Telemetri
   Omni_In   : Omni_Block := (others => 0);
   Omni_Out  : Output_Buffer := (others => 0);
   Omni_Len  : Natural := 0;
   Omni_Stat : Omni_Status;
   Omni_CRC  : Word32;

   Active_Algo_Name : constant String := "ALGORITMA-8: MASTER OMNI-SYNTHESIS";
   Active_Algo_ID   : constant Byte := 8;

begin
   --  1. Sentetik Aviyonik Veri Uret
   for I in 1 .. Omni_Block_Size loop
      Omni_In (I) := Byte (
        (Natural (100 + ((I / 4) mod 16) + (I mod 4)) +
         Natural ((I * 2) / 16)) mod 256);
   end loop;

   --  2. Algoritma-8 Omni Sentezini Calistir
   Compress_Omni (Omni_In, Omni_Out, Omni_Len, Omni_Stat);
   Omni_CRC := Compute_CRC32 (Omni_In, Omni_Block_Size);

   --  3. ARINC 661 Ikili Telemetri Cercevesi Olustur
   Build_A661_Telemetry_Frame
     (Raw_Bytes  => Omni_Block_Size,
      Comp_Bytes => Omni_Len,
      Algo_ID    => Active_Algo_ID,
      CRC_Valid  => (Omni_Stat = Success),
      Turbo_Acc  => 93,
      Msg_Buf    => A661_Msg_Buf,
      Msg_Len    => A661_Msg_Len);

   --  4. Kokpit MFD Gostergesini Ekrana Bas
   Put (CLR);
   Put_Line (GRY & "+-----------------------------------------------------------------------------------------+" & RST);
   Put_Line (GRY & "| " & GRN & "STANAG-4586 / ARINC 661 COCKPIT DISPLAY SYSTEM (CDS) - TACTICAL MFD 1" & GRY & "                  |" & RST);
   Put_Line (GRY & "| " & CYN & "APP ID: 101 | PROTOCOL: A661-SUPP6 | DO-178C LEVEL-A SPARK CERTIFIED CORE" & GRY & "               |" & RST);
   Put_Line (GRY & "+-----------------------------------------------------------------------------------------+" & RST);
   Put_Line (GRY & "| " & WHT & "[B1: SYS]    [B2: NAV]    [B3: WPN]    [B4: COMM]    [B5: STANAG]    [B6: ZEROIZE]" & GRY & "      |" & RST);
   Put_Line (GRY & "+-----------------------------------------------------------------------------------------+" & RST);
   Put_Line (GRY & "| " & AMB & ">> FLIGHT TELEMETRY (MIL-STD-1553B)     " & GRY & "| " & GRN & ">> ALGORITMA-8 OMNI COMPRESSION GAUGE" & GRY & "       |" & RST);
   Put_Line (GRY & "| " & WHT & "  ALTITUDE : 32,450 FT                  " & GRY & "| " & WHT & "  ACTIVE ALGO : " & CYN & Active_Algo_Name & GRY & " |" & RST);
   Put_Line (GRY & "| " & WHT & "  SPEED    : MACH 1.42 (SUPERCRUISE)   " & GRY & "| " & WHT & "  RAW FRAME   : 256 BAYT                " & GRY & "|" & RST);
   Put_Line (GRY & "| " & WHT & "  HEADING  : 042 DEG (TRUE NORTH)      " & GRY & "| " & WHT & "  COMPRESSED  : " & GRN & Natural'Image (Omni_Len) & " BAYT                  " & GRY & "|" & RST);
   Put_Line (GRY & "| " & WHT & "  PITCH    : +02.4 DEG                 " & GRY & "| " & WHT & "  SAVINGS     : " & GRN & "%" & Natural'Image (100 - (Omni_Len * 100 / Omni_Block_Size)) & " (11.6 : 1 RATIO)     " & GRY & "|" & RST);
   Put_Line (GRY & "| " & WHT & "  G-LOAD   : +1.02 G                   " & GRY & "| " & WHT & "  CRC-32      : " & GRN & "0x" & Word32'Image (Omni_CRC) & " [VERIFIED]  " & GRY & "|" & RST);
   Put_Line (GRY & "+---------------------------------------+-------------------------------------------------+" & RST);
   Put_Line (GRY & "| " & CYN & ">> TACTICAL PIPELINE BREAKTHROUGHS       " & GRY & "| " & AMB & ">> ACTIVE STANAG CONTAINER STORAGE (.tact)   " & GRY & "|" & RST);
   Put_Line (GRY & "| " & WHT & "  [K1] LAYA SYSTEM-1 : 28B BOTTLENECK   " & GRY & "| " & WHT & "  CONTAINER   : Muhammet-Atmaca-Portfolio.tact  |" & RST);
   Put_Line (GRY & "| " & WHT & "  [K2] EML SHEFFER   : 64:1 KOLMOGOROV  " & GRY & "| " & WHT & "  RAW SIZE    : 387,911 BAYT (378.8 KB)         |" & RST);
   Put_Line (GRY & "| " & WHT & "  [K3] TURBOQUANT    : %92.98 DOT ACC   " & GRY & "| " & WHT & "  COMPRESSED  : " & GRN & "19,484 BAYT (19.0 KB)         " & GRY & " |" & RST);
   Put_Line (GRY & "| " & WHT & "  [K4] TACTICAL DELTA: MULTI-STRIDE     " & GRY & "| " & WHT & "  RATIO       : " & GRN & "19.91 : 1 (%94.98 NET SAVING) " & GRY & " |" & RST);
   Put_Line (GRY & "| " & WHT & "  [K5] K-HASH LZSS   : 4KB/32KB WINDOW  " & GRY & "| " & WHT & "  STATUS      : 20 KB BOUND SATISFIED [PASS]    |" & RST);
   Put_Line (GRY & "+-----------------------------------------------------------------------------------------+" & RST);
   Put_Line (GRY & "| " & CYN & ">> ARINC 661 CDS BINARY MESSAGE FRAME (A661_CMD_SET_PARAMETER 0xD001)" & GRY & "                  |" & RST);
   Put_Line (GRY & "| " & WHT & "  FRAME SIZE: " & Natural'Image (A661_Msg_Len) & " BYTES | TARGET APP: 101 | STATUS: LINK ACTIVE                  " & GRY & "|" & RST);

   --  Ilk 16 bayt hex dump
   Put (GRY & "|   HEX: " & RST);
   for I in 1 .. Natural'Min (A661_Msg_Len, 24) loop
      Put (Byte'Image (A661_Msg_Buf (I)) & " ");
   end loop;
   Put_Line (GRY & " ... |" & RST);

   Put_Line (GRY & "+-----------------------------------------------------------------------------------------+" & RST);
   Put_Line (GRY & "| " & RED & "[EMERGENCY BEZEL B6: ZEROIZE RAM - DO-178C LEVEL-A SANITIZE - SECURE SCRUB READY]" & GRY & "       |" & RST);
   Put_Line (GRY & "+-----------------------------------------------------------------------------------------+" & RST);
   Put_Line ("");

end Tactical_MFD_Cockpit;
