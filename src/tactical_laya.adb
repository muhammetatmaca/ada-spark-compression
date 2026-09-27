with Interfaces;    use Interfaces;
with Tactical_LZSS; use Tactical_LZSS;

package body Tactical_Laya with SPARK_Mode => On is

   --  Laya System 1 Non-Autoregressive Kod Defteri (16 Desen x 16 Bayt)
   --  Telemetri, rampa, ustel, titresim ve JSON sembolleri kapsanir
   type Codebook_Matrix is array (0 .. 15, 1 .. 16) of Byte;

   Codebook : constant Codebook_Matrix :=
     (0  => (others => 0),
      1  => (others => 32),
      2  => (others => 128),
      3  => (others => 255),
      4  => (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15),
      5  => (15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0),
      6  => (0, 2, 4, 8, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 192,
             224),
      7  => (224, 192, 160, 144, 128, 112, 96, 80, 64, 48, 32, 16, 8, 4,
             2, 0),
      8  => (0, 10, 20, 10, 0, 10, 20, 10, 0, 10, 20, 10, 0, 10, 20, 10),
      9  => (0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0,
             255),
      10 => (10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140,
             150, 160),
      11 => (160, 150, 140, 130, 120, 110, 100, 90, 80, 70, 60, 50, 40,
             30, 20, 10),
      12 => (others => 100),
      13 => (100, 101, 102, 103, 100, 101, 102, 103, 100, 101, 102, 103,
             100, 101, 102, 103),
      14 => (34, 58, 32, 34, 123, 125, 44, 10, 32, 32, 34, 58, 32, 34,
             44, 10),
      15 => (others => 48));

   --------------------
   -- Evaluate_State --
   --------------------

   procedure Evaluate_State
     (State     : Laya_Block;
      Decisions : out Laya_Decisions)
   is
      Best_C     : Natural;
      Min_Diff   : Natural;
      Cur_Diff   : Natural;
      Sum_Val    : Natural;
      S_Byte     : Byte;
      C_Byte     : Byte;
      Score_Val  : Natural;
      Noul_Bit   : Byte;
      Score_Idx  : Positive;
      Noul_Idx   : Positive;
      Noul_Shift : Natural;
   begin
      Decisions.Scores  := (others => 0);
      Decisions.Nouls   := (others => 0);

      for K in 1 .. 16 loop
         Best_C   := 0;
         Min_Diff := Natural'Last;
         Sum_Val  := 0;

         for J in 1 .. 16 loop
            S_Byte := State ((K - 1) * 16 + J);
            Sum_Val := Sum_Val + Natural (S_Byte);
         end loop;

         --  1. En Yakin Kod Defteri Deseni (Choice Karari)
         for C in 0 .. 15 loop
            Cur_Diff := 0;
            for J in 1 .. 16 loop
               S_Byte := State ((K - 1) * 16 + J);
               C_Byte := Codebook (C, J);
               if S_Byte >= C_Byte then
                  Cur_Diff := Cur_Diff + Natural (S_Byte - C_Byte);
               else
                  Cur_Diff := Cur_Diff + Natural (C_Byte - S_Byte);
               end if;
            end loop;

            if Cur_Diff < Min_Diff then
               Min_Diff := Cur_Diff;
               Best_C   := C;
            end if;
         end loop;

         Decisions.Choices (K) := Byte (Best_C);

         --  2. Ince Ayar DC Kaydirma (Score Karari: -8..+7 -> 0..15)
         declare
            Total_Delta : Integer := 0;
            Avg_Delta   : Integer;
            Clamped     : Integer;
         begin
            for J in 1 .. 16 loop
               Total_Delta := Total_Delta +
                 (Integer (State ((K - 1) * 16 + J)) -
                  Integer (Codebook (Best_C, J)));
            end loop;

            Avg_Delta := Total_Delta / 16;
            Clamped   := Avg_Delta + 8;
            if Clamped < 0 then
               Clamped := 0;
            elsif Clamped > 15 then
               Clamped := 15;
            end if;
            Score_Val := Natural (Clamped);
         end;

         Score_Idx := (K - 1) / 2 + 1;
         if K mod 2 = 1 then
            Decisions.Scores (Score_Idx) := Byte (Score_Val) and 16#0F#;
         else
            Decisions.Scores (Score_Idx) :=
              Decisions.Scores (Score_Idx) or
              Shift_Left (Byte (Score_Val) and 16#0F#, 4);
         end if;

         --  3. Polarite (Noul Karari: 0 veya 1)
         if (Sum_Val / 16) >= 128 then
            Noul_Bit := 1;
         else
            Noul_Bit := 0;
         end if;

         Noul_Idx   := (K - 1) / 8 + 1;
         Noul_Shift := (K - 1) mod 8;
         Decisions.Nouls (Noul_Idx) :=
           Decisions.Nouls (Noul_Idx) or
           Shift_Left (Noul_Bit, Noul_Shift);
      end loop;
   end Evaluate_State;

   --------------------
   -- Pack_Decisions --
   --------------------

   procedure Pack_Decisions
     (Decisions : Laya_Decisions;
      Out_Buf   : out Decision_Buffer)
   is
   begin
      Out_Buf := (others => 0);
      Out_Buf (1 .. 16)  := Decisions.Choices;
      Out_Buf (17 .. 24) := Decisions.Scores;
      Out_Buf (25 .. 28) := Decisions.Nouls;
   end Pack_Decisions;

   ----------------------
   -- Unpack_Decisions --
   ----------------------

   procedure Unpack_Decisions
     (In_Buf    : Decision_Buffer;
      Decisions : out Laya_Decisions)
   is
   begin
      Decisions.Choices := In_Buf (1 .. 16);
      Decisions.Scores  := In_Buf (17 .. 24);
      Decisions.Nouls   := In_Buf (25 .. 28);
   end Unpack_Decisions;

   ----------------------
   -- Synthesize_State --
   ----------------------

   procedure Synthesize_State
     (Decisions : Laya_Decisions;
      X_Hat     : out Laya_Block)
   is
      Best_C     : Natural;
      Score_Byte : Byte;
      Score_Val  : Natural;
      Offset_Val : Integer;
      Pat_Byte   : Integer;
      Result_Val : Integer;
   begin
      X_Hat := (others => 0);
      for K in 1 .. 16 loop
         Best_C := Natural (Decisions.Choices (K)) mod 16;

         Score_Byte := Decisions.Scores ((K - 1) / 2 + 1);
         if K mod 2 = 1 then
            Score_Val := Natural (Score_Byte and 16#0F#);
         else
            Score_Val := Natural (Shift_Right (Score_Byte, 4) and 16#0F#);
         end if;

         Offset_Val := Integer (Score_Val) - 8;

         for J in 1 .. 16 loop
            Pat_Byte   := Integer (Codebook (Best_C, J));
            Result_Val := (Pat_Byte + Offset_Val) mod 256;
            X_Hat ((K - 1) * 16 + J) := Byte (Result_Val);
         end loop;
      end loop;
   end Synthesize_State;

   -------------------
   -- Compress_Laya --
   -------------------

   procedure Compress_Laya
     (In_Buf  : Laya_Block;
      Out_Buf : out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Laya_Status)
   is
      Decisions : Laya_Decisions;
      Dec_Buf   : Decision_Buffer;
      X_Hat     : Laya_Block;
      Residual  : Laya_Block;
      LZSS_Out  : Output_Buffer := (others => 0);
      LZSS_Len  : Natural;
      LZSS_Stat : LZSS_Status;
   begin
      Out_Buf := (others => 0);
      Out_Len := 0;

      --  1. Tek Gecisli Karar Cikarimi (Single Forward Pass)
      Evaluate_State (In_Buf, Decisions);

      --  2. 28-Baytlik Karar Dizisini Paketleme
      Pack_Decisions (Decisions, Dec_Buf);
      Out_Buf (1 .. 28) := Dec_Buf;

      --  3. Deterministik Durum Geri Catimi
      Synthesize_State (Decisions, X_Hat);

      --  4. Moduler Artik Hata Hesabi: Residual = In_Buf - X_Hat
      for I in Laya_Index loop
         Residual (I) := In_Buf (I) - X_Hat (I);
      end loop;

      --  5. LZSS ile Artik Hatayi Sikistirma
      Compress_LZSS
        (In_Buf  => Residual,
         In_Len  => Block_Size,
         Out_Buf => LZSS_Out,
         Out_Len => LZSS_Len,
         Status  => LZSS_Stat);

      if LZSS_Stat /= Success then
         Status := Buffer_Error;
         return;
      end if;

      if 28 + LZSS_Len > Out_Buf'Last then
         Status := Buffer_Error;
         return;
      end if;

      for I in 1 .. LZSS_Len loop
         Out_Buf (28 + I) := LZSS_Out (I);
      end loop;

      Out_Len := 28 + LZSS_Len;
      Status  := Success;
   end Compress_Laya;

   ---------------------
   -- Decompress_Laya --
   ---------------------

   procedure Decompress_Laya
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : out Laya_Block;
      Status  : out Laya_Status)
   is
      Dec_Buf          : Decision_Buffer;
      Decisions        : Laya_Decisions;
      X_Hat            : Laya_Block;
      Residual_Payload : Payload_Buffer := (others => 0);
      Residual_Len     : Natural;
      LZSS_In          : Payload_Buffer := (others => 0);
      LZSS_Len         : Natural;
      LZSS_Stat        : LZSS_Status;
   begin
      Out_Buf := (others => 0);

      if In_Len < 28 or else In_Len > Max_Output_Size then
         Status := Invalid_Input;
         return;
      end if;

      --  1. 28-Baytlik Karar Darbogazini Cozme
      Dec_Buf := In_Buf (1 .. 28);
      Unpack_Decisions (Dec_Buf, Decisions);

      --  2. Deterministik Tek Gecisli Durum Geri Catimi
      Synthesize_State (Decisions, X_Hat);

      --  3. Artik Hatanin Boyutu
      LZSS_Len := In_Len - 28;

      if LZSS_Len = 0 then
         --  Mukemmel tahmin (Residual = 0)
         Out_Buf := X_Hat;
         Status  := Success;
         return;
      end if;

      if LZSS_Len > Max_Block_Size then
         Status := Buffer_Error;
         return;
      end if;

      for I in 1 .. LZSS_Len loop
         LZSS_In (I) := In_Buf (28 + I);
      end loop;

      Decompress_LZSS
        (In_Buf  => LZSS_In (1 .. LZSS_Len),
         In_Len  => LZSS_Len,
         Out_Buf => Residual_Payload,
         Out_Len => Residual_Len,
         Status  => LZSS_Stat);

      if LZSS_Stat /= Success or else Residual_Len /= Block_Size then
         Status := Decode_Error;
         return;
      end if;

      --  4. %100 Kayipsiz Geri Catim: Out_Buf = X_Hat + Residual
      for I in Laya_Index loop
         Out_Buf (I) := X_Hat (I) + Residual_Payload (I);
      end loop;

      Status := Success;
   end Decompress_Laya;

end Tactical_Laya;
