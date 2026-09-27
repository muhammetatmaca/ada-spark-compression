with Interfaces;

package Tactical_Types with SPARK_Mode => On is

   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Positive range <>) of Byte;

   subtype Word32 is Interfaces.Unsigned_32;
   subtype Real   is Long_Float;

   --  Savunma ve taktik paketleri icin sabit bellek sinirlari (Heap yasak)
   Max_Block_Size  : constant Positive := 4096;
   Max_Output_Size : constant Positive := Max_Block_Size * 2;
   Header_Size     : constant Positive := 20;

   subtype Block_Index  is Positive range 1 .. Max_Block_Size;
   subtype Output_Index is Positive range 1 .. Max_Output_Size;

   subtype Payload_Buffer is Byte_Array (Block_Index);
   subtype Output_Buffer  is Byte_Array (Output_Index);
   subtype Header_Buffer  is Byte_Array (1 .. Header_Size);

   --  256-bit Kriptografik Anahtar ve Ozet Tipleri
   subtype Key_256  is Byte_Array (1 .. 32);
   subtype Hash_256 is Byte_Array (1 .. 32);

   --  STANAG / MIL-STD Uyumlu Taktik Baslik Yapisi (20 Bayt)
   --  Magic           : 'T', 'A', 'C', 'T' (4 bayt)
   --  Version         : 1 bayt
   --  Algorithm_ID    : 1 bayt (1 = LZSS, 2 = RLE)
   --  Flags           : 2 bayt (Sifreleme / Sikistirma bayraklari)
   --  Raw_Size        : 4 bayt (Acilmis boyut)
   --  Compressed_Size : 4 bayt (Sikistirilmis boyut)
   --  Checksum_CRC32  : 4 bayt (IEEE 802.3 CRC32 butunluk etiketi)
   type Archive_Header is record
      Version         : Byte;
      Algorithm_ID    : Byte;
      Flags           : Byte;
      Raw_Size        : Word32;
      Compressed_Size : Word32;
      Checksum_CRC32  : Word32;
   end record;

end Tactical_Types;
