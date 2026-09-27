with Tactical_Types; use Tactical_Types;

package Tactical_Laya with SPARK_Mode => On is

   Block_Size : constant Positive := 256;
   subtype Laya_Index is Positive range 1 .. Block_Size;
   subtype Laya_Block is Byte_Array (Laya_Index);

   --  Laya System 1 Non-Autoregressive Tipli Karar Darbogazi (28 Bayt)
   --  Num_Choices : 16 adet Choice (16 bayt, 0..255 desen sinifi)
   --  Num_Scores  : 16 adet Score  (8 bayt, her biri 4-bit genlik olcegi)
   --  Num_Nouls   : 32 adet Noul   (4 bayt, 32 adet Boolean bayrak/polarite)
   Num_Choices : constant Positive := 16;
   Num_Scores  : constant Positive := 16;
   Num_Nouls   : constant Positive := 32;

   subtype Choice_Array is Byte_Array (1 .. Num_Choices);
   subtype Score_Array  is Byte_Array (1 .. Num_Scores / 2);
   subtype Noul_Array   is Byte_Array (1 .. Num_Nouls / 8);

   Decision_Size : constant Positive := 28;
   subtype Decision_Buffer is Byte_Array (1 .. Decision_Size);

   type Laya_Decisions is record
      Choices : Choice_Array;
      Scores  : Score_Array;
      Nouls   : Noul_Array;
   end record;

   type Laya_Status is
     (Success, Invalid_Input, Buffer_Error, Decode_Error);

   --  1. Tek Gecisli Karar Cikarimi (Single Forward Pass Encoder)
   --  256 baytlik durumu analiz edip 28 baytlik tipli karar uzayina indirger
   procedure Evaluate_State
     (State     : Laya_Block;
      Decisions : out Laya_Decisions);

   --  2. Kararlari 28-Baytlik Kompakt Diziye Paketleme / Ayristirma
   procedure Pack_Decisions
     (Decisions : Laya_Decisions;
      Out_Buf   : out Decision_Buffer);

   procedure Unpack_Decisions
     (In_Buf    : Decision_Buffer;
      Decisions : out Laya_Decisions);

   --  3. Deterministik Tek Gecisli Durum Geri Catimi (Single Pass Decoder)
   --  28 baytlik kararlardan tahmini 256-baytlik X_Hat durumunu uretir
   procedure Synthesize_State
     (Decisions : Laya_Decisions;
      X_Hat     : out Laya_Block);

   --  4. Tam Kayipsiz (Lossless) Laya Hibrit Karar Sikistirma Motoru
   --  [28 Bayt Karar Darbogazi] + [Artik Hata Entropi Kodlamasi]
   procedure Compress_Laya
     (In_Buf  : Laya_Block;
      Out_Buf : out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Laya_Status) with
     Post => Out_Len <= Out_Buf'Length;

   --  5. Tam Kayipsiz (Lossless) Laya Hibrit Geri Acma Motoru
   procedure Decompress_Laya
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : out Laya_Block;
      Status  : out Laya_Status) with
     Pre => In_Buf'First = 1
            and then In_Len <= In_Buf'Length
            and then In_Len <= Max_Output_Size;

end Tactical_Laya;
