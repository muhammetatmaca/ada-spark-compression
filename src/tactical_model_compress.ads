with Tactical_Types; use Tactical_Types;
with Tactical_EML;   use Tactical_EML;

package Tactical_Model_Compress with SPARK_Mode => On is

   type Model_Status is
     (Success, Invalid_Model, Buffer_Full, Eval_Failed);

   --  EML Programini 2-bit yogun bayt dizisine paketler (4 komut / 1 bayt)
   procedure Pack_EML_Program
     (Prog    : EML_Program;
      Out_Buf : out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Model_Status) with
     Pre  => Prog'Length <= Max_Prog_Len
             and then Prog'First = 1,
     Post => Out_Len <= Out_Buf'Length;

   --  2-bit yogun bayt dizisinden EML Programini cikarir
   procedure Unpack_EML_Program
     (In_Buf   : Byte_Array;
      Prog_Len : Natural;
      Prog     : out Program_Buffer;
      Status   : out Model_Status) with
     Pre  => In_Buf'First = 1
             and then Prog_Len <= Max_Prog_Len;

   --  Model Tabanli Geri Catim: EML programini calistirarak telemetri uretir
   procedure Regenerate_Telemetry
     (Prog    : EML_Program;
      Out_Buf : in out Payload_Buffer;
      Out_Len : Natural;
      Status  : out Model_Status) with
     Pre  => Prog'Length <= Max_Prog_Len
             and then Prog'First = 1
             and then Out_Len <= Max_Block_Size;

end Tactical_Model_Compress;
