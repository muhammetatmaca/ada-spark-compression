with Interfaces;
use type Interfaces.Unsigned_32;
with Tactical_Types; use Tactical_Types;
with Tactical_RANS;  use Tactical_RANS;

package Tactical_Two_Stage with SPARK_Mode => On is

   type Two_Stage_Status is
     (Success, LZSS_Error, RANS_Error, Invalid_Input, Buffer_Full);

   --  Iki Kademeli Sikistirma (Zstandard Mimarisi: 1. LZSS + 2. rANS)
   procedure Compress_Two_Stage
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Out_Buf   : in out Output_Buffer;
      Out_Len   : out Natural;
      End_State : out Rans_State;
      LZ_Len    : out Natural;
      Status    : out Two_Stage_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length;

   --  Iki Kademeli Geri Acma (1. rANS Cozucu + 2. LZSS Cozucu)
   procedure Decompress_Two_Stage
     (In_Buf      : Byte_Array;
      In_Len      : Natural;
      Start_State : Rans_State;
      LZ_Len      : Natural;
      Out_Buf     : in out Payload_Buffer;
      Out_Len     : out Natural;
      Status      : out Two_Stage_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then LZ_Len <= Max_Block_Size
             and then Start_State >= RANS_L,
     Post => Out_Len <= Out_Buf'Length;

end Tactical_Two_Stage;
