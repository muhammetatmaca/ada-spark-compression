with Tactical_Types; use Tactical_Types;
with Interfaces;
use type Interfaces.Unsigned_8;

package Secure_Scrub with SPARK_Mode => On is

   --  Bellekteki hassas veriyi veya kriptografik anahtari sifirlar
   procedure Zeroize_Buffer (Buffer : in out Byte_Array) with
     Post => (for all I in Buffer'Range => Buffer (I) = 0);

   --  Yan kanal zamanlama analizine karsi sabit zamanli esitlik denetimi
   function Constant_Time_Equal
     (Left  : Hash_256;
      Right : Hash_256) return Boolean with
     Post => (Constant_Time_Equal'Result = (Left = Right));

end Secure_Scrub;
