with Interfaces; use Interfaces;

package body STANAG_Header with SPARK_Mode => On is

   procedure Put_Word32
     (Buf    : in out Byte_Array;
      Offset : Positive;
      Val    : Word32) with
     Pre => Buf'Last >= 4
            and then Offset >= Buf'First
            and then Offset <= Buf'Last - 3
   is
   begin
      Buf (Offset)     := Byte (Shift_Right (Val, 24) and 16#FF#);
      Buf (Offset + 1) := Byte (Shift_Right (Val, 16) and 16#FF#);
      Buf (Offset + 2) := Byte (Shift_Right (Val, 8)  and 16#FF#);
      Buf (Offset + 3) := Byte (Val and 16#FF#);
   end Put_Word32;

   function Get_Word32
     (Buf    : Byte_Array;
      Offset : Positive) return Word32 with
     Pre => Buf'Last >= 4
            and then Offset >= Buf'First
            and then Offset <= Buf'Last - 3
   is
   begin
      return Shift_Left (Word32 (Buf (Offset)), 24)
        or Shift_Left (Word32 (Buf (Offset + 1)), 16)
        or Shift_Left (Word32 (Buf (Offset + 2)), 8)
        or Word32 (Buf (Offset + 3));
   end Get_Word32;

   procedure Pack_Header
     (Header  : Archive_Header;
      Out_Buf : out Header_Buffer)
   is
   begin
      Out_Buf := (others => 0);

      Out_Buf (1) := Magic_0;
      Out_Buf (2) := Magic_1;
      Out_Buf (3) := Magic_2;
      Out_Buf (4) := Magic_3;

      Out_Buf (5) := Header.Version;
      Out_Buf (6) := Header.Algorithm_ID;
      Out_Buf (7) := Header.Flags;
      Out_Buf (8) := 0;

      Put_Word32 (Out_Buf, 9,  Header.Raw_Size);
      Put_Word32 (Out_Buf, 13, Header.Compressed_Size);
      Put_Word32 (Out_Buf, 17, Header.Checksum_CRC32);
   end Pack_Header;

   procedure Unpack_Header
     (In_Buf  : Byte_Array;
      Header  : out Archive_Header;
      Status  : out Header_Status)
   is
   begin
      Header := Archive_Header'
        (Version         => 0,
         Algorithm_ID    => 0,
         Flags           => 0,
         Raw_Size        => 0,
         Compressed_Size => 0,
         Checksum_CRC32  => 0);

      if In_Buf'Length < Header_Size then
         Status := Buffer_Too_Small;
         return;
      end if;

      if In_Buf (1) /= Magic_0
        or else In_Buf (2) /= Magic_1
        or else In_Buf (3) /= Magic_2
        or else In_Buf (4) /= Magic_3
      then
         Status := Invalid_Magic;
         return;
      end if;

      if In_Buf (5) /= Current_Version then
         Status := Unsupported_Version;
         return;
      end if;

      Header.Version         := In_Buf (5);
      Header.Algorithm_ID    := In_Buf (6);
      Header.Flags           := In_Buf (7);
      Header.Raw_Size        := Get_Word32 (In_Buf, 9);
      Header.Compressed_Size := Get_Word32 (In_Buf, 13);
      Header.Checksum_CRC32  := Get_Word32 (In_Buf, 17);

      Status := Success;
   end Unpack_Header;

end STANAG_Header;
