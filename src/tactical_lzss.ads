with Tactical_Types; use Tactical_Types;

package Tactical_LZSS with SPARK_Mode => On is

   type LZSS_Status is
     (Success, Buffer_Full, Invalid_Input, Corrupted_Stream);

   --  Kayan pencereli LZSS sikistirma motoru (256-bayt statik pencere)
   procedure Compress_LZSS
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Output_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length
             and then (if Status = Success then Out_Len > 0);

   --  Guvenli LZSS geri acma motoru (Bellek sinirlari matematiksel kanitli)
   procedure Decompress_LZSS
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length;

   --  4KB Kayan Pencereli Hash-Hizlandirmali Taktik LZSS Motoru
   procedure Compress_LZSS_4K
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Output_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length;

   procedure Decompress_LZSS_4K
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length;

end Tactical_LZSS;
