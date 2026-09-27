with Tactical_Delta; use Tactical_Delta;
with Tactical_LZSS;  use Tactical_LZSS;

package body Tactical_Three_Stage with SPARK_Mode => On is

   procedure Compress_Three_Stage
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Out_Buf   : in out Output_Buffer;
      Out_Len   : out Natural;
      End_State : out Rans_State;
      LZ_Len    : out Natural;
      Status    : out Three_Stage_Status)
   is
      Delta_Buf : Payload_Buffer := (others => 0);
      LZ_Buf    : Output_Buffer  := (others => 0);
      Delta_Len : Natural;
      Delta_St  : Delta_Status;
      LZ_St     : LZSS_Status;
      Rans_St   : Rans_Status;
      Freqs     : Freq_Array;
      Cum_Freq  : Freq_Array;
   begin
      Out_Len   := 0;
      End_State := RANS_L;
      LZ_Len    := 0;

      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      --  1. Kademe: Delta On-Isleme (Gopinath 2020)
      Delta_Encode
        (In_Buf  => In_Buf,
         In_Len  => In_Len,
         Out_Buf => Delta_Buf,
         Out_Len => Delta_Len,
         Status  => Delta_St);

      if Delta_St /= Success or else Delta_Len = 0 then
         Status := Delta_Error;
         return;
      end if;

      --  2. Kademe: Kayan Pencereli LZSS (Pintilei 2024)
      Compress_LZSS
        (In_Buf  => Delta_Buf,
         In_Len  => Delta_Len,
         Out_Buf => LZ_Buf,
         Out_Len => LZ_Len,
         Status  => LZ_St);

      if LZ_St /= Success or else LZ_Len = 0 then
         Status := LZSS_Error;
         return;
      end if;

      if LZ_Len > Max_Block_Size then
         Status := Buffer_Full;
         return;
      end if;

      --  3. Kademe: rANS Entropi Kodlayici (Beemkumar 2024)
      Build_Frequency_Table (LZ_Buf, LZ_Len, Freqs, Cum_Freq);

      Rans_Encode
        (In_Buf    => LZ_Buf,
         In_Len    => LZ_Len,
         Freqs     => Freqs,
         Cum_Freq  => Cum_Freq,
         Out_Buf   => Out_Buf,
         Out_Len   => Out_Len,
         End_State => End_State,
         Status    => Rans_St);

      if Rans_St /= Success then
         Status := RANS_Error;
         return;
      end if;

      Status := Success;
   end Compress_Three_Stage;

   procedure Decompress_Three_Stage
     (In_Buf      : Byte_Array;
      In_Len      : Natural;
      Start_State : Rans_State;
      LZ_Len      : Natural;
      Raw_Len     : Natural;
      Out_Buf     : in out Payload_Buffer;
      Out_Len     : out Natural;
      Status      : out Three_Stage_Status)
   is
      LZ_Payload    : Payload_Buffer := (others => 0);
      Delta_Payload : Payload_Buffer := (others => 0);
      Rans_St       : Rans_Status;
      LZ_St         : LZSS_Status;
      Delta_St      : Delta_Status;
      Freqs         : Freq_Array;
      Cum_Freq      : Freq_Array;
      Delta_Len     : Natural;
   begin
      Out_Len := 0;

      if In_Len = 0
        or else LZ_Len = 0
        or else LZ_Len > Max_Block_Size
        or else Raw_Len = 0
        or else Raw_Len > Max_Block_Size
      then
         Status := Invalid_Input;
         return;
      end if;

      --  1. Kademe Geri Alma: rANS Cozucu
      Build_Frequency_Table (In_Buf, In_Len, Freqs, Cum_Freq);

      Rans_Decode
        (In_Buf      => In_Buf,
         In_Len      => In_Len,
         Start_State => Start_State,
         Freqs       => Freqs,
         Cum_Freq    => Cum_Freq,
         Out_Buf     => LZ_Payload,
         Out_Len     => LZ_Len,
         Status      => Rans_St);

      if Rans_St /= Success then
         Status := RANS_Error;
         return;
      end if;

      --  2. Kademe Geri Alma: LZSS Cozucu
      Decompress_LZSS
        (In_Buf  => LZ_Payload,
         In_Len  => LZ_Len,
         Out_Buf => Delta_Payload,
         Out_Len => Delta_Len,
         Status  => LZ_St);

      if LZ_St /= Success or else Delta_Len = 0 then
         Status := LZSS_Error;
         return;
      end if;

      --  3. Kademe Geri Alma: Delta Ters Donusumu
      Delta_Decode
        (In_Buf  => Delta_Payload,
         In_Len  => Delta_Len,
         Out_Buf => Out_Buf,
         Out_Len => Out_Len,
         Status  => Delta_St);

      if Delta_St /= Success then
         Status := Delta_Error;
         return;
      end if;

      Status := Success;
   end Decompress_Three_Stage;

end Tactical_Three_Stage;
