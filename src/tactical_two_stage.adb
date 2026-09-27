with Tactical_LZSS; use Tactical_LZSS;

package body Tactical_Two_Stage with SPARK_Mode => On is

   procedure Compress_Two_Stage
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Out_Buf   : in out Output_Buffer;
      Out_Len   : out Natural;
      End_State : out Rans_State;
      LZ_Len    : out Natural;
      Status    : out Two_Stage_Status)
   is
      Inter_Buf : Output_Buffer := (others => 0);
      LZ_Stat   : LZSS_Status;
      Rans_Stat : Rans_Status;
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

      --  1. Kademe: Kayan Pencereli LZSS
      Compress_LZSS
        (In_Buf  => In_Buf,
         In_Len  => In_Len,
         Out_Buf => Inter_Buf,
         Out_Len => LZ_Len,
         Status  => LZ_Stat);

      if LZ_Stat /= Success or else LZ_Len = 0 then
         Status := LZSS_Error;
         return;
      end if;

      if LZ_Len > Max_Block_Size then
         Status := Buffer_Full;
         return;
      end if;

      --  2. Kademe: rANS Entropi Kodlayici
      Build_Frequency_Table (Inter_Buf, LZ_Len, Freqs, Cum_Freq);

      Rans_Encode
        (In_Buf    => Inter_Buf,
         In_Len    => LZ_Len,
         Freqs     => Freqs,
         Cum_Freq  => Cum_Freq,
         Out_Buf   => Out_Buf,
         Out_Len   => Out_Len,
         End_State => End_State,
         Status    => Rans_Stat);

      if Rans_Stat /= Success then
         Status := RANS_Error;
         return;
      end if;

      Status := Success;
   end Compress_Two_Stage;

   procedure Decompress_Two_Stage
     (In_Buf      : Byte_Array;
      In_Len      : Natural;
      Start_State : Rans_State;
      LZ_Len      : Natural;
      Out_Buf     : in out Payload_Buffer;
      Out_Len     : out Natural;
      Status      : out Two_Stage_Status)
   is
      Inter_Payload : Payload_Buffer := (others => 0);
      Rans_Stat     : Rans_Status;
      LZ_Stat       : LZSS_Status;
      Freqs         : Freq_Array;
      Cum_Freq      : Freq_Array;
   begin
      Out_Len := 0;

      if In_Len = 0 or else LZ_Len = 0 or else LZ_Len > Max_Block_Size then
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
         Out_Buf     => Inter_Payload,
         Out_Len     => LZ_Len,
         Status      => Rans_Stat);

      if Rans_Stat /= Success then
         Status := RANS_Error;
         return;
      end if;

      --  2. Kademe Geri Alma: LZSS Cozucu
      Decompress_LZSS
        (In_Buf  => Inter_Payload,
         In_Len  => LZ_Len,
         Out_Buf => Out_Buf,
         Out_Len => Out_Len,
         Status  => LZ_Stat);

      if LZ_Stat /= Success then
         Status := LZSS_Error;
         return;
      end if;

      Status := Success;
   end Decompress_Two_Stage;

end Tactical_Two_Stage;
