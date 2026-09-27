with Tactical_Types; use Tactical_Types;
with Interfaces;
use type Interfaces.Unsigned_8;

package Tactical_Compressor with SPARK_Mode => On is

   type Compression_Status is
     (Success, Buffer_Full, Invalid_Input);
   type Decompression_Status is
     (Success, Output_Buffer_Full, Corrupted_Stream, Invalid_Input);

   --  Sikistirma Operasyonu: Giris tamponunu cikis tamponuna yazar.
   --  SPARK Sozlesmeleri ile tampon tasmasi matematiksel olarak onlenir.
   procedure Compress_Block
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Compression_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length
             and then (if Status = Success then Out_Len > 0);

   --  Guvenli Acma (Decompression) Operasyonu:
   --  Gelen bozuk verilerin tampon sinirlarini asamayacagini garanti eder.
   procedure Decompress_Block
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out Decompression_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1,
     Post => Out_Len <= Out_Buf'Length;

end Tactical_Compressor;
