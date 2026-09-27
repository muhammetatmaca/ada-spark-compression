with Interfaces;    use Interfaces;
with Tactical_LZSS;  use Tactical_LZSS;
with Tactical_Laya;  use Tactical_Laya;
with Tactical_RANS;  use Tactical_RANS;

package body Tactical_Omni with SPARK_Mode => On is

   PATH_LAYA           : constant Byte := 1;
   PATH_STRIDE_1       : constant Byte := 2;
   PATH_STRIDE_2       : constant Byte := 3;
   PATH_STRIDE_4       : constant Byte := 4;
   PATH_EML            : constant Byte := 5;
   PATH_RAW            : constant Byte := 6;
   PATH_STRIDE_4_RANS  : constant Byte := 7;
   PATH_DIRECT_LZSS    : constant Byte := 8;

   -------------------
   -- Fit_EML_Trend --
   -------------------

   procedure Fit_EML_Trend
     (Residual : Omni_Block;
      Trend    : out EML_Trend)
   is
   begin
      Trend.Base  := Residual (1);
      Trend.Slope := Residual (Omni_Block_Size) - Residual (1);
   end Fit_EML_Trend;

   -------------------
   -- Compress_Omni --
   -------------------

   procedure Compress_Omni
     (In_Buf  : Omni_Block;
      Out_Buf : out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Omni_Status)
   is
      --  Yol 1: Laya Karar Darbogazi
      Decisions    : Laya_Decisions;
      Dec_Buf      : Decision_Buffer;
      X_Hat        : Laya_Block;
      R_Laya       : Omni_Block;
      LZ_Out_1     : Output_Buffer := (others => 0);
      LZ_Len_1     : Natural;
      LZ_Stat_1    : LZSS_Status;
      Cost_1       : Natural := Natural'Last;

      --  Yol 2: Stride-1 Delta (8-Bit Sekans)
      D1           : Omni_Block := (others => 0);
      LZ_Out_2     : Output_Buffer := (others => 0);
      LZ_Len_2     : Natural;
      LZ_Stat_2    : LZSS_Status;
      Cost_2       : Natural := Natural'Last;

      --  Yol 3: Stride-2 Delta (16-Bit Aviyonik Kelimeler)
      D2           : Omni_Block := (others => 0);
      LZ_Out_3     : Output_Buffer := (others => 0);
      LZ_Len_3     : Natural;
      LZ_Stat_3    : LZSS_Status;
      Cost_3       : Natural := Natural'Last;

      --  Yol 4: Stride-4 Delta (32-Bit Telemetri & IEEE Float Kanallari)
      D4           : Omni_Block := (others => 0);
      LZ_Out_4     : Output_Buffer := (others => 0);
      LZ_Len_4     : Natural;
      LZ_Stat_4    : LZSS_Status;
      Cost_4       : Natural := Natural'Last;

      --  Yol 5: EML Analitik Egilim Modeli
      Trend        : EML_Trend;
      Trend_Val    : Byte;
      R_Trend      : Omni_Block;
      D_Trend      : Omni_Block := (others => 0);
      LZ_Out_5     : Output_Buffer := (others => 0);
      LZ_Len_5     : Natural;
      LZ_Stat_5    : LZSS_Status;
      Cost_5       : Natural := Natural'Last;

      --  Yol 7: Stride-4 Delta + LZSS + rANS
      Cost_7       : Natural := Natural'Last;
      LZ_Len_7     : Natural := 0;
      Rans_Len_7   : Natural := 0;
      End_State_7  : Rans_State := 0;
      Rans_Out_7   : Output_Buffer := (others => 0);

      --  Yol 8: Dogrudan Sozluk LZSS (Delta olmadan metin/kod)
      LZ_Out_8     : Output_Buffer := (others => 0);
      LZ_Len_8     : Natural := 0;
      LZ_Stat_8    : LZSS_Status;
      Cost_8       : Natural := Natural'Last;

      Best_Path    : Byte;
      Min_Cost     : Natural;
   begin
      Out_Buf := (others => 0);
      Out_Len := 0;

      --  === YOL 1: Laya Tipli Karar Darbogazi ===
      Evaluate_State (In_Buf, Decisions);
      Pack_Decisions (Decisions, Dec_Buf);
      Synthesize_State (Decisions, X_Hat);

      for I in 1 .. Omni_Block_Size loop
         R_Laya (I) := In_Buf (I) - X_Hat (I);
      end loop;

      Compress_LZSS
        (In_Buf  => R_Laya,
         In_Len  => Omni_Block_Size,
         Out_Buf => LZ_Out_1,
         Out_Len => LZ_Len_1,
         Status  => LZ_Stat_1);

      if LZ_Stat_1 = Success and then 31 + LZ_Len_1 <= Max_Output_Size then
         Cost_1 := 31 + LZ_Len_1;
      end if;

      --  === YOL 2: Stride-1 Delta ===
      D1 (1) := In_Buf (1);
      for I in 2 .. Omni_Block_Size loop
         D1 (I) := In_Buf (I) - In_Buf (I - 1);
      end loop;

      Compress_LZSS
        (In_Buf  => D1,
         In_Len  => Omni_Block_Size,
         Out_Buf => LZ_Out_2,
         Out_Len => LZ_Len_2,
         Status  => LZ_Stat_2);

      if LZ_Stat_2 = Success and then 3 + LZ_Len_2 <= Max_Output_Size then
         Cost_2 := 3 + LZ_Len_2;
      end if;

      --  === YOL 3: Stride-2 Delta (16-Bit Sozcukler) ===
      D2 (1 .. 2) := In_Buf (1 .. 2);
      for I in 3 .. Omni_Block_Size loop
         D2 (I) := In_Buf (I) - In_Buf (I - 2);
      end loop;

      Compress_LZSS
        (In_Buf  => D2,
         In_Len  => Omni_Block_Size,
         Out_Buf => LZ_Out_3,
         Out_Len => LZ_Len_3,
         Status  => LZ_Stat_3);

      if LZ_Stat_3 = Success and then 3 + LZ_Len_3 <= Max_Output_Size then
         Cost_3 := 3 + LZ_Len_3;
      end if;

      --  === YOL 4: Stride-4 Delta (32-Bit Aviyonik Kanallari) ===
      D4 (1 .. 4) := In_Buf (1 .. 4);
      for I in 5 .. Omni_Block_Size loop
         D4 (I) := In_Buf (I) - In_Buf (I - 4);
      end loop;

      Compress_LZSS
        (In_Buf  => D4,
         In_Len  => Omni_Block_Size,
         Out_Buf => LZ_Out_4,
         Out_Len => LZ_Len_4,
         Status  => LZ_Stat_4);

      if LZ_Stat_4 = Success and then 3 + LZ_Len_4 <= Max_Output_Size then
         Cost_4 := 3 + LZ_Len_4;
      end if;

      --  === YOL 5: EML Analitik Egilim Modeli ===
      Fit_EML_Trend (In_Buf, Trend);
      for I in 1 .. Omni_Block_Size loop
         Trend_Val := Trend.Base +
           Byte ((Natural (Trend.Slope) * (I - 1)) / 255);
         R_Trend (I) := In_Buf (I) - Trend_Val;
      end loop;

      D_Trend (1) := R_Trend (1);
      for I in 2 .. Omni_Block_Size loop
         D_Trend (I) := R_Trend (I) - R_Trend (I - 1);
      end loop;

      Compress_LZSS
        (In_Buf  => D_Trend,
         In_Len  => Omni_Block_Size,
         Out_Buf => LZ_Out_5,
         Out_Len => LZ_Len_5,
         Status  => LZ_Stat_5);

      if LZ_Stat_5 = Success and then 5 + LZ_Len_5 <= Max_Output_Size then
         Cost_5 := 5 + LZ_Len_5;
      end if;

      --  === YOL 7: Stride-4 Delta + LZSS + rANS ===
      if LZ_Stat_4 = Success
        and then LZ_Len_4 > 0
        and then LZ_Len_4 <= Max_Block_Size
      then
         declare
            R_Out  : Output_Buffer := (others => 0);
            R_Len  : Natural := 0;
            R_Stat : Rans_Status;
            Freqs  : Freq_Array;
            C_Freq : Freq_Array;
            End_St : Rans_State;
         begin
            Build_Frequency_Table
              (LZ_Out_4 (1 .. LZ_Len_4), LZ_Len_4, Freqs, C_Freq);

            Rans_Encode
              (In_Buf    => LZ_Out_4 (1 .. LZ_Len_4),
               In_Len    => LZ_Len_4,
               Freqs     => Freqs,
               Cum_Freq  => C_Freq,
               Out_Buf   => R_Out,
               Out_Len   => R_Len,
               End_State => End_St,
               Status    => R_Stat);

            if R_Stat = Success
              and then 9 + R_Len <= Max_Output_Size
            then
               Cost_7      := 9 + R_Len;
               LZ_Len_7    := LZ_Len_4;
               Rans_Len_7  := R_Len;
               End_State_7 := End_St;
               for I in 1 .. R_Len loop
                  Rans_Out_7 (I) := R_Out (I);
               end loop;
            end if;
         end;
      end if;

      --  === YOL 8: Dogrudan Sozluk LZSS ===
      Compress_LZSS
        (In_Buf  => In_Buf,
         In_Len  => Omni_Block_Size,
         Out_Buf => LZ_Out_8,
         Out_Len => LZ_Len_8,
         Status  => LZ_Stat_8);

      if LZ_Stat_8 = Success and then 3 + LZ_Len_8 <= Max_Output_Size then
         Cost_8 := 3 + LZ_Len_8;
      end if;

      --  === EN IYI VE EN KUCUK YOLU SEC (OMNI-ARBITRATION) ===
      Best_Path := PATH_RAW;
      Min_Cost  := 1 + Omni_Block_Size;

      if Cost_4 < Min_Cost then
         Min_Cost  := Cost_4;
         Best_Path := PATH_STRIDE_4;
      end if;

      if Cost_3 < Min_Cost then
         Min_Cost  := Cost_3;
         Best_Path := PATH_STRIDE_2;
      end if;

      if Cost_2 < Min_Cost then
         Min_Cost  := Cost_2;
         Best_Path := PATH_STRIDE_1;
      end if;

      if Cost_1 < Min_Cost then
         Min_Cost  := Cost_1;
         Best_Path := PATH_LAYA;
      end if;

      if Cost_5 < Min_Cost then
         Min_Cost  := Cost_5;
         Best_Path := PATH_EML;
      end if;

      if Cost_7 < Min_Cost then
         Min_Cost  := Cost_7;
         Best_Path := PATH_STRIDE_4_RANS;
      end if;

      if Cost_8 < Min_Cost then
         Min_Cost  := Cost_8;
         Best_Path := PATH_DIRECT_LZSS;
      end if;

      --  === PAKETLEME ===
      if Best_Path = PATH_RAW then
         Out_Buf (1) := PATH_RAW;
         for I in 1 .. Omni_Block_Size loop
            Out_Buf (1 + I) := In_Buf (I);
         end loop;
         Out_Len := 1 + Omni_Block_Size;

      elsif Best_Path = PATH_DIRECT_LZSS then
         Out_Buf (1) := PATH_DIRECT_LZSS;
         Out_Buf (2) := Byte (Shift_Right (Word32 (LZ_Len_8), 8) and 16#FF#);
         Out_Buf (3) := Byte (Word32 (LZ_Len_8) and 16#FF#);
         for I in 1 .. LZ_Len_8 loop
            Out_Buf (3 + I) := LZ_Out_8 (I);
         end loop;
         Out_Len := 3 + LZ_Len_8;

      elsif Best_Path = PATH_STRIDE_4_RANS then
         Out_Buf (1) := PATH_STRIDE_4_RANS;
         Out_Buf (2) := Byte (Shift_Right (End_State_7, 24) and 16#FF#);
         Out_Buf (3) := Byte (Shift_Right (End_State_7, 16) and 16#FF#);
         Out_Buf (4) := Byte (Shift_Right (End_State_7, 8) and 16#FF#);
         Out_Buf (5) := Byte (End_State_7 and 16#FF#);
         Out_Buf (6) := Byte (Shift_Right (Word32 (LZ_Len_7), 8) and 16#FF#);
         Out_Buf (7) := Byte (Word32 (LZ_Len_7) and 16#FF#);
         Out_Buf (8) := Byte (Shift_Right (Word32 (Rans_Len_7), 8) and 16#FF#);
         Out_Buf (9) := Byte (Word32 (Rans_Len_7) and 16#FF#);
         for I in 1 .. Rans_Len_7 loop
            Out_Buf (9 + I) := Rans_Out_7 (I);
         end loop;
         Out_Len := 9 + Rans_Len_7;

      elsif Best_Path = PATH_STRIDE_4 then
         Out_Buf (1) := PATH_STRIDE_4;
         Out_Buf (2) := Byte (Shift_Right (Word32 (LZ_Len_4), 8) and 16#FF#);
         Out_Buf (3) := Byte (Word32 (LZ_Len_4) and 16#FF#);
         for I in 1 .. LZ_Len_4 loop
            Out_Buf (3 + I) := LZ_Out_4 (I);
         end loop;
         Out_Len := 3 + LZ_Len_4;

      elsif Best_Path = PATH_STRIDE_2 then
         Out_Buf (1) := PATH_STRIDE_2;
         Out_Buf (2) := Byte (Shift_Right (Word32 (LZ_Len_3), 8) and 16#FF#);
         Out_Buf (3) := Byte (Word32 (LZ_Len_3) and 16#FF#);
         for I in 1 .. LZ_Len_3 loop
            Out_Buf (3 + I) := LZ_Out_3 (I);
         end loop;
         Out_Len := 3 + LZ_Len_3;

      elsif Best_Path = PATH_STRIDE_1 then
         Out_Buf (1) := PATH_STRIDE_1;
         Out_Buf (2) := Byte (Shift_Right (Word32 (LZ_Len_2), 8) and 16#FF#);
         Out_Buf (3) := Byte (Word32 (LZ_Len_2) and 16#FF#);
         for I in 1 .. LZ_Len_2 loop
            Out_Buf (3 + I) := LZ_Out_2 (I);
         end loop;
         Out_Len := 3 + LZ_Len_2;

      elsif Best_Path = PATH_LAYA then
         Out_Buf (1)        := PATH_LAYA;
         Out_Buf (2 .. 29)  := Dec_Buf;
         Out_Buf (30)       :=
           Byte (Shift_Right (Word32 (LZ_Len_1), 8) and 16#FF#);
         Out_Buf (31)       := Byte (Word32 (LZ_Len_1) and 16#FF#);
         for I in 1 .. LZ_Len_1 loop
            Out_Buf (31 + I) := LZ_Out_1 (I);
         end loop;
         Out_Len := 31 + LZ_Len_1;

      else -- PATH_EML
         Out_Buf (1) := PATH_EML;
         Out_Buf (2) := Trend.Base;
         Out_Buf (3) := Trend.Slope;
         Out_Buf (4) := Byte (Shift_Right (Word32 (LZ_Len_5), 8) and 16#FF#);
         Out_Buf (5) := Byte (Word32 (LZ_Len_5) and 16#FF#);
         for I in 1 .. LZ_Len_5 loop
            Out_Buf (5 + I) := LZ_Out_5 (I);
         end loop;
         Out_Len := 5 + LZ_Len_5;
      end if;

      Status := Success;
   end Compress_Omni;

   ---------------------
   -- Decompress_Omni --
   ---------------------

   procedure Decompress_Omni
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : out Omni_Block;
      Status  : out Omni_Status)
   is
      Path_ID      : Byte;
      LZ_Len       : Natural;
      Payload_Buf  : Payload_Buffer := (others => 0);
      Payload_Len  : Natural;
      LZ_Stat      : LZSS_Status;

      Dec_Buf      : Decision_Buffer;
      Decisions    : Laya_Decisions;
      X_Hat        : Laya_Block;

      Trend        : EML_Trend;
      Trend_Val    : Byte;
      R_Temp       : Omni_Block := (others => 0);
   begin
      Out_Buf := (others => 0);

      if In_Len < 3 or else In_Len > Max_Output_Size then
         Status := Invalid_Input;
         return;
      end if;

      Path_ID := In_Buf (1);

      --  1. Ham Saklama (Bypass)
      if Path_ID = PATH_RAW then
         if In_Len /= 1 + Omni_Block_Size then
            Status := Invalid_Input;
            return;
         end if;
         for I in 1 .. Omni_Block_Size loop
            Out_Buf (I) := In_Buf (1 + I);
         end loop;
         Status := Success;
         return;
      end if;

      --  2. Dogrudan Sozluk LZSS (Metin / Kod / Sembol)
      if Path_ID = PATH_DIRECT_LZSS then
         LZ_Len := Natural (In_Buf (2)) * 256 + Natural (In_Buf (3));
         if 3 + LZ_Len /= In_Len or else LZ_Len > Max_Block_Size then
            Status := Invalid_Input;
            return;
         end if;

         for I in 1 .. LZ_Len loop
            Payload_Buf (I) := In_Buf (3 + I);
         end loop;

         declare
            LZ_In_Buf : constant Byte_Array (1 .. LZ_Len) :=
              Payload_Buf (1 .. LZ_Len);
         begin
            Decompress_LZSS
              (In_Buf  => LZ_In_Buf,
               In_Len  => LZ_Len,
               Out_Buf => Payload_Buf,
               Out_Len => Payload_Len,
               Status  => LZ_Stat);
         end;

         if LZ_Stat /= Success or else Payload_Len /= Omni_Block_Size then
            Status := Decode_Error;
            return;
         end if;

         for I in 1 .. Omni_Block_Size loop
            Out_Buf (I) := Payload_Buf (I);
         end loop;
         Status := Success;
         return;
      end if;

      --  2. Stride Yollari (2, 3, 4)
      if Path_ID = PATH_STRIDE_1
        or else Path_ID = PATH_STRIDE_2
        or else Path_ID = PATH_STRIDE_4
      then
         LZ_Len := Natural (In_Buf (2)) * 256 + Natural (In_Buf (3));
         if 3 + LZ_Len /= In_Len or else LZ_Len > Max_Block_Size then
            Status := Invalid_Input;
            return;
         end if;

         for I in 1 .. LZ_Len loop
            Payload_Buf (I) := In_Buf (3 + I);
         end loop;

         declare
            LZ_In_Buf : constant Byte_Array (1 .. LZ_Len) :=
              Payload_Buf (1 .. LZ_Len);
         begin
            Decompress_LZSS
              (In_Buf  => LZ_In_Buf,
               In_Len  => LZ_Len,
               Out_Buf => Payload_Buf,
               Out_Len => Payload_Len,
               Status  => LZ_Stat);
         end;

         if LZ_Stat /= Success or else Payload_Len /= Omni_Block_Size then
            Status := Decode_Error;
            return;
         end if;

         if Path_ID = PATH_STRIDE_1 then
            Out_Buf (1) := Payload_Buf (1);
            for I in 2 .. Omni_Block_Size loop
               Out_Buf (I) := Out_Buf (I - 1) + Payload_Buf (I);
            end loop;

         elsif Path_ID = PATH_STRIDE_2 then
            Out_Buf (1 .. 2) := Payload_Buf (1 .. 2);
            for I in 3 .. Omni_Block_Size loop
               Out_Buf (I) := Out_Buf (I - 2) + Payload_Buf (I);
            end loop;

         else -- PATH_STRIDE_4
            Out_Buf (1 .. 4) := Payload_Buf (1 .. 4);
            for I in 5 .. Omni_Block_Size loop
               Out_Buf (I) := Out_Buf (I - 4) + Payload_Buf (I);
            end loop;
         end if;

         Status := Success;
         return;
      end if;

      --  3. Stride-4 Delta + LZSS + rANS
      if Path_ID = PATH_STRIDE_4_RANS then
         if In_Len < 10 then
            Status := Invalid_Input;
            return;
         end if;

         declare
            End_St    : Rans_State;
            R_Len     : Natural;
            Freqs     : Freq_Array;
            C_Freq    : Freq_Array;
            Rans_In   : Payload_Buffer := (others => 0);
            LZ_Decomp : Payload_Buffer := (others => 0);
            R_Stat    : Rans_Status;
         begin
            End_St := Shift_Left (Word32 (In_Buf (2)), 24) or
                      Shift_Left (Word32 (In_Buf (3)), 16) or
                      Shift_Left (Word32 (In_Buf (4)), 8) or
                      Word32 (In_Buf (5));
            LZ_Len := Natural (In_Buf (6)) * 256 + Natural (In_Buf (7));
            R_Len  := Natural (In_Buf (8)) * 256 + Natural (In_Buf (9));

            if 9 + R_Len /= In_Len
              or else R_Len > Max_Block_Size
              or else LZ_Len > Max_Block_Size
            then
               Status := Invalid_Input;
               return;
            end if;

            for I in 1 .. R_Len loop
               Rans_In (I) := In_Buf (9 + I);
            end loop;

            Build_Frequency_Table (Rans_In (1 .. R_Len), R_Len, Freqs, C_Freq);

            Rans_Decode
              (In_Buf      => Rans_In (1 .. R_Len),
               In_Len      => R_Len,
               Start_State => End_St,
               Freqs       => Freqs,
               Cum_Freq    => C_Freq,
               Out_Buf     => LZ_Decomp,
               Out_Len     => LZ_Len,
               Status      => R_Stat);

            if R_Stat /= Success then
               Status := Decode_Error;
               return;
            end if;

            declare
               LZ_In_Buf : constant Byte_Array (1 .. LZ_Len) :=
                 LZ_Decomp (1 .. LZ_Len);
            begin
               Decompress_LZSS
                 (In_Buf  => LZ_In_Buf,
                  In_Len  => LZ_Len,
                  Out_Buf => Payload_Buf,
                  Out_Len => Payload_Len,
                  Status  => LZ_Stat);
            end;

            if LZ_Stat /= Success or else Payload_Len /= Omni_Block_Size then
               Status := Decode_Error;
               return;
            end if;

            Out_Buf (1 .. 4) := Payload_Buf (1 .. 4);
            for I in 5 .. Omni_Block_Size loop
               Out_Buf (I) := Out_Buf (I - 4) + Payload_Buf (I);
            end loop;

            Status := Success;
            return;
         end;
      end if;

      --  4. Laya Karar Darbogazi
      if Path_ID = PATH_LAYA then
         if In_Len < 31 then
            Status := Invalid_Input;
            return;
         end if;

         Dec_Buf := In_Buf (2 .. 29);
         Unpack_Decisions (Dec_Buf, Decisions);
         Synthesize_State (Decisions, X_Hat);

         LZ_Len := Natural (In_Buf (30)) * 256 + Natural (In_Buf (31));
         if 31 + LZ_Len /= In_Len or else LZ_Len > Max_Block_Size then
            Status := Invalid_Input;
            return;
         end if;

         for I in 1 .. LZ_Len loop
            Payload_Buf (I) := In_Buf (31 + I);
         end loop;

         declare
            LZ_In_Buf : constant Byte_Array (1 .. LZ_Len) :=
              Payload_Buf (1 .. LZ_Len);
         begin
            Decompress_LZSS
              (In_Buf  => LZ_In_Buf,
               In_Len  => LZ_Len,
               Out_Buf => Payload_Buf,
               Out_Len => Payload_Len,
               Status  => LZ_Stat);
         end;

         if LZ_Stat /= Success or else Payload_Len /= Omni_Block_Size then
            Status := Decode_Error;
            return;
         end if;

         for I in 1 .. Omni_Block_Size loop
            Out_Buf (I) := X_Hat (I) + Payload_Buf (I);
         end loop;

         Status := Success;
         return;
      end if;

      --  5. EML Analitik Egilim
      if Path_ID = PATH_EML then
         if In_Len < 5 then
            Status := Invalid_Input;
            return;
         end if;

         Trend.Base  := In_Buf (2);
         Trend.Slope := In_Buf (3);

         LZ_Len := Natural (In_Buf (4)) * 256 + Natural (In_Buf (5));
         if 5 + LZ_Len /= In_Len or else LZ_Len > Max_Block_Size then
            Status := Invalid_Input;
            return;
         end if;

         for I in 1 .. LZ_Len loop
            Payload_Buf (I) := In_Buf (5 + I);
         end loop;

         declare
            LZ_In_Buf : constant Byte_Array (1 .. LZ_Len) :=
              Payload_Buf (1 .. LZ_Len);
         begin
            Decompress_LZSS
              (In_Buf  => LZ_In_Buf,
               In_Len  => LZ_Len,
               Out_Buf => Payload_Buf,
               Out_Len => Payload_Len,
               Status  => LZ_Stat);
         end;

         if LZ_Stat /= Success or else Payload_Len /= Omni_Block_Size then
            Status := Decode_Error;
            return;
         end if;

         R_Temp (1) := Payload_Buf (1);
         for I in 2 .. Omni_Block_Size loop
            R_Temp (I) := R_Temp (I - 1) + Payload_Buf (I);
         end loop;

         for I in 1 .. Omni_Block_Size loop
            Trend_Val := Trend.Base +
              Byte ((Natural (Trend.Slope) * (I - 1)) / 255);
            Out_Buf (I) := R_Temp (I) + Trend_Val;
         end loop;

         Status := Success;
         return;
      end if;

      Status := Invalid_Input;
   end Decompress_Omni;

end Tactical_Omni;
