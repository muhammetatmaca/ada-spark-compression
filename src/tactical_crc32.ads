with Tactical_Types; use Tactical_Types;

package Tactical_CRC32 with SPARK_Mode => On is

   --  IEEE 802.3 standardinda polinomla CRC-32 butunluk ozeti hesaplar
   function Compute_CRC32
     (Buffer : Byte_Array;
      Length : Natural) return Word32 with
     Pre => Length <= Buffer'Length
            and then Buffer'First = 1;

end Tactical_CRC32;
