with Tactical_Types; use Tactical_Types;

package Tactical_Delta with SPARK_Mode => On is

   type Delta_Status is (Success, Invalid_Input, Buffer_Full);

   --  Gopinath (2020) Modeli: Ardisik telemetri ve rota oruntulerini
   --  fark (delta) uzayina donusturerek entropiyi asgariye indirir.
   procedure Delta_Encode
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out Delta_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length
             and then (if Status = Success then Out_Len = In_Len);

   --  Geri Donusum: Fark uzayindaki verileri orijinal seriye donusturur.
   procedure Delta_Decode
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out Delta_Status) with
     Pre  => In_Len <= In_Buf'Length
             and then In_Buf'First = 1
             and then In_Len <= Max_Block_Size,
     Post => Out_Len <= Out_Buf'Length
             and then (if Status = Success then Out_Len = In_Len);

end Tactical_Delta;
