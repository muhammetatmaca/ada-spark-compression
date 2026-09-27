with Interfaces; use Interfaces;

package body Secure_Scrub with SPARK_Mode => On is

   procedure Zeroize_Buffer (Buffer : in out Byte_Array) is
   begin
      for I in Buffer'Range loop
         Buffer (I) := 0;
         pragma Loop_Invariant
           (for all K in Buffer'First .. I => Buffer (K) = 0);
      end loop;
   end Zeroize_Buffer;

   function Constant_Time_Equal
     (Left  : Hash_256;
      Right : Hash_256) return Boolean
   is
      Diff : Byte := 0;
   begin
      for I in Left'Range loop
         Diff := Diff or (Left (I) xor Right (I));
         pragma Loop_Invariant
           ((Diff = 0) =
            (for all K in Left'First .. I => Left (K) = Right (K)));
      end loop;

      return Diff = 0;
   end Constant_Time_Equal;

end Secure_Scrub;
