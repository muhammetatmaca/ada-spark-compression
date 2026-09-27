with Interfaces; use Interfaces;

package body Tactical_RANS with SPARK_Mode => On is

   procedure Build_Frequency_Table
     (In_Buf   : Byte_Array;
      In_Len   : Natural;
      Freqs    : out Freq_Array;
      Cum_Freq : out Freq_Array)
   is
      Running_Cum : Word32 := 0;
   begin
      pragma Unreferenced (In_Buf, In_Len);

      Freqs    := (others => 1);
      Cum_Freq := (others => 0);

      --  Kumulatif frekanslari hesapla (Toplam tam 256)
      for B in Byte range 0 .. 255 loop
         Cum_Freq (B) := Running_Cum;
         Running_Cum  := Running_Cum + Freqs (B);
         pragma Loop_Invariant (Running_Cum <= Word32 (B) + 1);
      end loop;
   end Build_Frequency_Table;

   procedure Rans_Encode
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Freqs     : Freq_Array;
      Cum_Freq  : Freq_Array;
      Out_Buf   : in out Output_Buffer;
      Out_Len   : out Natural;
      End_State : out Rans_State;
      Status    : out Rans_Status)
   is
      State     : Rans_State := RANS_L;
      Write_Pos : Positive := 1;
      Sym       : Byte;
      F         : Word32;
      C         : Word32;
   begin
      Out_Len   := 0;
      End_State := RANS_L;

      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      --  Geriye dogru kodlama: Decompressor ileriye dogru okur
      for I in reverse 1 .. In_Len loop
         Sym := In_Buf (I);
         F   := Freqs (Sym);
         C   := Cum_Freq (Sym);

         --  Renormalizasyon: State >= L * F oldugunda bayt cikar
         while State >= RANS_L * F loop
            if Write_Pos > Out_Buf'Last then
               Status  := Buffer_Full;
               Out_Len := Write_Pos - 1;
               return;
            end if;

            Out_Buf (Write_Pos) := Byte (State and 16#FF#);
            Write_Pos := Write_Pos + 1;
            State := Shift_Right (State, 8);

            pragma Loop_Invariant
              (Write_Pos >= 1 and then Write_Pos <= Out_Buf'Last + 1);
            pragma Loop_Invariant (F >= 1 and then F <= 256);
         end loop;

         --  rANS Durum Guncellemesi (Tamamen 24-bit icinde sinirli)
         State := (State / F) * SCALE_M + C + (State mod F);

         pragma Loop_Invariant
           (Write_Pos >= 1 and then Write_Pos <= Out_Buf'Last + 1);
         pragma Loop_Invariant (State >= RANS_L);
      end loop;

      Out_Len := Write_Pos - 1;

      --  rANS LIFO akisini duzeltmek icin bayt tamponu cevrilir
      if Out_Len > 1 then
         for K in 1 .. Out_Len / 2 loop
            declare
               Temp : constant Byte := Out_Buf (K);
            begin
               Out_Buf (K) := Out_Buf (Out_Len - K + 1);
               Out_Buf (Out_Len - K + 1) := Temp;
            end;
            pragma Loop_Invariant (K in 1 .. Out_Len / 2);
            pragma Loop_Invariant (Out_Len <= Out_Buf'Last);
         end loop;
      end if;

      End_State := State;
      Status    := Success;
   end Rans_Encode;

   procedure Rans_Decode
     (In_Buf      : Byte_Array;
      In_Len      : Natural;
      Start_State : Rans_State;
      Freqs       : Freq_Array;
      Cum_Freq    : Freq_Array;
      Out_Buf     : in out Payload_Buffer;
      Out_Len     : Natural;
      Status      : out Rans_Status)
   is
      State    : Rans_State := Start_State;
      Read_Pos : Positive := 1;
      Slot     : Word32;
      Sym      : Byte;
      F        : Word32;
      C        : Word32;
   begin
      if Out_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      for I in 1 .. Out_Len loop
         Slot := State and (SCALE_M - 1);

         --  Slot degerine karsilik gelen sembolu bul
         Sym := 0;
         for B in Byte range 0 .. 255 loop
            if Cum_Freq (B) <= Slot
              and then Slot < Cum_Freq (B) + Freqs (B)
            then
               Sym := B;
               exit;
            end if;
            pragma Loop_Invariant (Slot <= 255);
         end loop;

         F := Freqs (Sym);
         C := Cum_Freq (Sym);

         Out_Buf (I) := Sym;

         --  rANS Durumunu Geri Sar
         State := F * Shift_Right (State, 8) + (Slot - C);

         --  Renormalizasyon: State < L iken giristen bayt oku
         while State < RANS_L and then Read_Pos <= In_Len loop
            State := Shift_Left (State, 8) or Word32 (In_Buf (Read_Pos));
            Read_Pos := Read_Pos + 1;

            pragma Loop_Invariant (Read_Pos >= 1);
            pragma Loop_Invariant (State < 16#0100_0000#);
         end loop;

         pragma Loop_Invariant (Read_Pos >= 1);
      end loop;

      Status := Success;
   end Rans_Decode;

end Tactical_RANS;
