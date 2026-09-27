with Interfaces;
use type Interfaces.Unsigned_32;
with Tactical_Types; use Tactical_Types;

package Tactical_RANS with SPARK_Mode => On is

   subtype Rans_State is Interfaces.Unsigned_32;

   --  rANS Sabitleri (M = 256 olcek, L = 2^16 alt sinir)
   RANS_L  : constant Rans_State := 16#0001_0000#;  --  65536 (2^16)
   SCALE_M : constant Rans_State := 256;            --  2^8 olcek

   type Freq_Array is array (Byte) of Word32;

   type Rans_Status is (Success, Buffer_Full, Invalid_Input, Stream_Error);

   --  Frekans tablosunu olusturur (Tum frekanslar toplami tam 256 olur)
   procedure Build_Frequency_Table
     (In_Buf   : Byte_Array;
      In_Len   : Natural;
      Freqs    : out Freq_Array;
      Cum_Freq : out Freq_Array) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1,
     Post => (for all B in Byte => Freqs (B) >= 1)
             and then Cum_Freq (0) = 0;

   --  rANS Entropi Kodlayici (Geriye dogru LIFO kodlama)
   procedure Rans_Encode
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Freqs     : Freq_Array;
      Cum_Freq  : Freq_Array;
      Out_Buf   : in out Output_Buffer;
      Out_Len   : out Natural;
      End_State : out Rans_State;
      Status    : out Rans_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then (for all B in Byte => Freqs (B) >= 1)
             and then Cum_Freq (0) = 0,
     Post => Out_Len <= Out_Buf'Length;

   --  rANS Entropi Cozucu (Ileriye dogru kod cozumleme)
   procedure Rans_Decode
     (In_Buf      : Byte_Array;
      In_Len      : Natural;
      Start_State : Rans_State;
      Freqs       : Freq_Array;
      Cum_Freq    : Freq_Array;
      Out_Buf     : in out Payload_Buffer;
      Out_Len     : Natural;
      Status      : out Rans_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then Out_Len <= Out_Buf'Length
             and then Start_State >= RANS_L
             and then (for all B in Byte => Freqs (B) >= 1)
             and then Cum_Freq (0) = 0;

end Tactical_RANS;
