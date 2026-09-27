with Interfaces; use Interfaces;

package body Tactical_CRC32 with SPARK_Mode => On is

   function Compute_CRC32
     (Buffer : Byte_Array;
      Length : Natural) return Word32
   is
      CRC  : Word32 := 16#FFFF_FFFF#;
      Poly : constant Word32 := 16#EDB8_8320#;
      B    : Word32;
   begin
      for I in 1 .. Length loop
         B := Word32 (Buffer (I));
         CRC := CRC xor B;
         for Bit in 1 .. 8 loop
            if (CRC and 1) /= 0 then
               CRC := Shift_Right (CRC, 1) xor Poly;
            else
               CRC := Shift_Right (CRC, 1);
            end if;
            pragma Loop_Invariant (Bit in 1 .. 8);
         end loop;
         pragma Loop_Invariant (I in 1 .. Length);
      end loop;

      return not CRC;
   end Compute_CRC32;

end Tactical_CRC32;
