with Interfaces; use Interfaces;

package body Tactical_Delta with SPARK_Mode => On is

   procedure Delta_Encode
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out Delta_Status)
   is
   begin
      Out_Len := 0;

      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      Out_Buf (1) := In_Buf (1);

      for I in 2 .. In_Len loop
         Out_Buf (I) := In_Buf (I) - In_Buf (I - 1);
         pragma Loop_Invariant (I in 2 .. In_Len);
      end loop;

      Out_Len := In_Len;
      Status  := Success;
   end Delta_Encode;

   procedure Delta_Decode
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out Delta_Status)
   is
   begin
      Out_Len := 0;

      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      Out_Buf (1) := In_Buf (1);

      for I in 2 .. In_Len loop
         Out_Buf (I) := Out_Buf (I - 1) + In_Buf (I);
         pragma Loop_Invariant (I in 2 .. In_Len);
      end loop;

      Out_Len := In_Len;
      Status  := Success;
   end Delta_Decode;

end Tactical_Delta;
