with Interfaces;
use type Interfaces.Unsigned_32;
with Tactical_Types; use Tactical_Types;
with Tactical_RANS;  use Tactical_RANS;

package Tactical_Three_Stage with SPARK_Mode => On is

   type Three_Stage_Status is
     (Success, Delta_Error, LZSS_Error, RANS_Error,
      Invalid_Input, Buffer_Full);

   --  3-Kademeli Hibrit Sikistirma
   --  1. Kademe: Delta On-Isleme (Gopinath 2020)
   --  2. Kademe: Kayan Pencereli LZSS (Pintilei 2024)
   --  3. Kademe: rANS Entropi Kodlayici (Beemkumar 2024)
   procedure Compress_Three_Stage
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Out_Buf   : in out Output_Buffer;
      Out_Len   : out Natural;
      End_State : out Rans_State;
      LZ_Len    : out Natural;
      Status    : out Three_Stage_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length;

   --  3-Kademeli Geri Acma (Ters Sira: rANS -> LZSS -> Delta)
   procedure Decompress_Three_Stage
     (In_Buf      : Byte_Array;
      In_Len      : Natural;
      Start_State : Rans_State;
      LZ_Len      : Natural;
      Raw_Len     : Natural;
      Out_Buf     : in out Payload_Buffer;
      Out_Len     : out Natural;
      Status      : out Three_Stage_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then LZ_Len <= Max_Block_Size
             and then Raw_Len <= Max_Block_Size
             and then Start_State >= RANS_L,
     Post => Out_Len <= Out_Buf'Length;

end Tactical_Three_Stage;
