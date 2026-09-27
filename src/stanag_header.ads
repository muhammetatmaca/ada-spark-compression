with Tactical_Types; use Tactical_Types;

package STANAG_Header with SPARK_Mode => On is

   type Header_Status is
     (Success, Invalid_Magic, Unsupported_Version, Buffer_Too_Small);

   --  STANAG Magic Baytlari: 'T', 'A', 'C', 'T'
   Magic_0 : constant Byte := 16#54#;
   Magic_1 : constant Byte := 16#41#;
   Magic_2 : constant Byte := 16#43#;
   Magic_3 : constant Byte := 16#54#;

   Current_Version : constant Byte := 1;

   --  Baslik paketleme proseduru (20 Bayt)
   procedure Pack_Header
     (Header  : Archive_Header;
      Out_Buf : out Header_Buffer);

   --  Gelen ham tamponu ayristirip basligi dogrular
   procedure Unpack_Header
     (In_Buf  : Byte_Array;
      Header  : out Archive_Header;
      Status  : out Header_Status) with
     Pre  => In_Buf'First = 1;

end STANAG_Header;
