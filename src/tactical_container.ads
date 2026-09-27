with Tactical_Types; use Tactical_Types;

package Tactical_Container is

   type Container_Status is
     (Success, Dir_Not_Found, Archive_Error, File_Error, CRC_Mismatch);

   --  1. Klasörü Taktik STANAG Arşivine (.tact) Sıkıştırma
   procedure Archive_Directory
     (Dir_Path     : String;
      Archive_Path : String;
      Total_Raw    : out Word32;
      Total_Comp   : out Word32;
      File_Count   : out Natural;
      Status       : out Container_Status);

   --  2. Taktik STANAG Arşivini (.tact) Klasöre Geri Açma ve CRC Doğrulama
   procedure Extract_Directory
     (Archive_Path : String;
      Target_Dir   : String;
      File_Count   : out Natural;
      Status       : out Container_Status);

end Tactical_Container;
