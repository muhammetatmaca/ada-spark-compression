with Tactical_Types; use Tactical_Types;

package Tactical_Omni with SPARK_Mode => On is

   Omni_Block_Size : constant Positive := 256;
   subtype Omni_Block is Byte_Array (1 .. Omni_Block_Size);

   type Omni_Status is
     (Success, Invalid_Input, Buffer_Overflow, Decode_Error);

   --  EML 2-Baytlik Kolmogorov Analitik Egilim Modeli (Base, Slope)
   type EML_Trend is record
      Base  : Byte;
      Slope : Byte;
   end record;

   --  Büyük Taktik Sentez Sikistirma Motoru (Grand Omni Synthesis)
   --  1. Kademe: Laya System 1 Tipli Karar Darbogazi (28 Bayt)
   --  2. Kademe: EML Kolmogorov Analitik Egilim Modeli (2 Bayt)
   --  3. Kademe: Taktik Delta Korelasyon Eleme
   --  4. Kademe: Kayan Pencereli LZSS Sozluk Kodlamasi
   procedure Compress_Omni
     (In_Buf  : Omni_Block;
      Out_Buf : out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Omni_Status) with
     Post => Out_Len <= Out_Buf'Length;

   --  Büyük Taktik Sentez Geri Acma Motoru (%100 Kayipsiz Bit-Exact)
   procedure Decompress_Omni
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : out Omni_Block;
      Status  : out Omni_Status) with
     Pre => In_Buf'First = 1
            and then In_Len <= In_Buf'Length
            and then In_Len <= Max_Output_Size;

end Tactical_Omni;
