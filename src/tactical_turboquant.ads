with Tactical_Types; use Tactical_Types;

package Tactical_TurboQuant with SPARK_Mode => On is

   --  Taktik ve Askeri Sensor Sinirlari (-100,000.0 .. +100,000.0)
   subtype Sensor_Float  is Real range -1.0E5 .. 1.0E5;
   subtype Rotated_Float is Real range -1.0E7 .. 1.0E7;

   Vector_Dim : constant Positive := 32;
   subtype Vector_Index is Positive range 1 .. Vector_Dim;

   type Vector_32 is array (Vector_Index) of Sensor_Float;
   type Rotated_Vector_32 is array (Vector_Index) of Rotated_Float;

   --  TurboQuant 16-Bayt Sikistirilmis Paket Yapisi
   --  Scale_Data : 4 Bayt (Sabit Noktali Olcek Katsayisi)
   --  MSE_Codes  : 8 Bayt (32 Boyut x 2-Bit Skaler Kuantalama)
   --  QJL_Signs  : 4 Bayt (32 Boyut x 1-Bit QJL Artik Hata Isaretleri)
   --  Toplam     : 16 Bayt (128 Bayttan Inis -> 8:1 / %87.5 Tasarruf)
   subtype Packet_Bytes is Byte_Array (1 .. 16);

   type TQ_Status is (Success, Invalid_Vector, Buffer_Error);

   --  1. Hizli Walsh-Hadamard Donusumu (FWHT) ile Ortogonal Rotasyon
   --  O(D log D) karmasiklikta, enerji korunumlu (Isometry) donusum
   procedure FWHT_Rotate
     (Input_Vec  : Vector_32;
      Output_Vec : out Rotated_Vector_32);

   --  Ters Ortogonal Rotasyon (R^T = R^-1)
   procedure FWHT_Inverse_Rotate
     (Input_Vec  : Rotated_Vector_32;
      Output_Vec : out Vector_32);

   --  2. TurboQuant Vektor Sikistirma Motoru (128 Bayt -> 16 Bayt)
   procedure Compress_Vector
     (Input_Vec : Vector_32;
      Packet    : out Packet_Bytes;
      Status    : out TQ_Status);

   --  3. TurboQuant Vektor Geri Acma Motoru (16 Bayt -> Reconstructed Vector)
   procedure Decompress_Vector
     (Packet     : Packet_Bytes;
      Output_Vec : out Vector_32;
      Status     : out TQ_Status);

   --  4. Sikistirilmis Uzayda Dogrudan Ic Carpim (Dot Product) Tahmini
   --  Veriyi geri acmadan iki adet 16 baytlik paket uzerinden
   --  bit duzeyinde XOR/Popcount ile dogrudan ic carpim kestirimi
   function Estimate_Dot_Product
     (Packet_A : Packet_Bytes;
      Packet_B : Packet_Bytes) return Real;

   --  5. Orijinal Vektorler Arasi Gercek Referans Ic Carpim
   function Compute_Dot_Product
     (Vec_A : Vector_32;
      Vec_B : Vector_32) return Real;

end Tactical_TurboQuant;
