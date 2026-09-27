with Ada.Directories;        use Ada.Directories;
with Ada.Streams;            use Ada.Streams;
with Ada.Streams.Stream_IO;  use Ada.Streams.Stream_IO;
with Interfaces;             use Interfaces;
with Tactical_LZSS;          use Tactical_LZSS;

package body Tactical_Container is

   subtype Word16 is Interfaces.Unsigned_16;
   Block_Size_4K : constant Positive := 4096;

   procedure Update_CRC (CRC : in out Word32; B : Byte) is
      Poly : constant Word32 := 16#EDB8_8320#;
   begin
      CRC := CRC xor Word32 (B);
      for Bit in 1 .. 8 loop
         if (CRC and 1) /= 0 then
            CRC := Shift_Right (CRC, 1) xor Poly;
         else
            CRC := Shift_Right (CRC, 1);
         end if;
      end loop;
   end Update_CRC;

   -----------------------
   -- Archive_Directory --
   -----------------------

   procedure Archive_Directory
     (Dir_Path     : String;
      Archive_Path : String;
      Total_Raw    : out Word32;
      Total_Comp   : out Word32;
      File_Count   : out Natural;
      Status       : out Container_Status)
   is
      Search      : Search_Type;
      Item        : Directory_Entry_Type;
      Arch_File   : Ada.Streams.Stream_IO.File_Type;
      Src_File    : Ada.Streams.Stream_IO.File_Type;
      Count       : Natural := 0;
      Raw_Sum     : Word32  := 0;
      Comp_Sum    : Word32  := 0;

      SE_Buf      : Stream_Element_Array (1 .. Stream_Element_Offset
                                                 (Block_Size_4K));
      SE_Last     : Stream_Element_Offset;
      Comp_Buf    : Output_Buffer := (others => 0);
      Comp_Len    : Natural;
      LZ_Stat     : LZSS_Status;
      CRC_Val     : Word32;
   begin
      Total_Raw  := 0;
      Total_Comp := 0;
      File_Count := 0;

      if not Exists (Dir_Path) or else Kind (Dir_Path) /= Directory then
         Status := Dir_Not_Found;
         return;
      end if;

      --  1. Gecis: Dosya Sayisini Say
      Start_Search
        (Search, Dir_Path, "*", (Ordinary_File => True, others => False));
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         Count := Count + 1;
      end loop;
      End_Search (Search);

      if Count = 0 then
         Status := Success;
         return;
      end if;

      --  2. Arşiv Dosyasını Oluştur
      Create (Arch_File, Out_File, Archive_Path);

      --  Baslik: [Magic: TACT][Ver: 2][Count: 4B]
      Character'Write (Stream (Arch_File), 'T');
      Character'Write (Stream (Arch_File), 'A');
      Character'Write (Stream (Arch_File), 'C');
      Character'Write (Stream (Arch_File), 'T');
      Byte'Write (Stream (Arch_File), 2);
      Word32'Write (Stream (Arch_File), Word32 (Count));

      --  3. Gecis: Dosyalari Oku, 4KB LZSS ile Sikistir ve Yaz
      Start_Search
        (Search, Dir_Path, "*", (Ordinary_File => True, others => False));
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);

         declare
            F_Name   : constant String := Simple_Name (Item);
            F_Path   : constant String := Full_Name (Item);
            F_Size   : constant Word32 := Word32 (Size (Item));
            N_Blocks : constant Word32 :=
              (F_Size + Word32 (Block_Size_4K) - 1) / Word32 (Block_Size_4K);
            W16_Len  : constant Word16 := Word16 (F_Name'Length);
         begin
            --  Dosya CRC-32 Hesabi
            Open (Src_File, In_File, F_Path);
            CRC_Val := 16#FFFF_FFFF#;
            while not End_Of_File (Src_File) loop
               Read (Src_File, SE_Buf, SE_Last);
               for I in 1 .. SE_Last loop
                  Update_CRC (CRC_Val, Byte (SE_Buf (I)));
               end loop;
            end loop;
            CRC_Val := not CRC_Val;
            Close (Src_File);

            --  Dosya Meta Verisi Yaz
            Word16'Write (Stream (Arch_File), W16_Len);
            String'Write (Stream (Arch_File), F_Name);
            Word32'Write (Stream (Arch_File), F_Size);
            Word32'Write (Stream (Arch_File), CRC_Val);
            Word32'Write (Stream (Arch_File), N_Blocks);

            Raw_Sum := Raw_Sum + F_Size;

            --  4KB Bloklar Halinde Sikistirma
            Open (Src_File, In_File, F_Path);
            while not End_Of_File (Src_File) loop
               Read (Src_File, SE_Buf, SE_Last);

               declare
                  Raw_In : Byte_Array (1 .. Natural (SE_Last));
               begin
                  for I in 1 .. SE_Last loop
                     Raw_In (Natural (I)) := Byte (SE_Buf (I));
                  end loop;

                  Compress_LZSS_4K
                    (In_Buf  => Raw_In,
                     In_Len  => Natural (SE_Last),
                     Out_Buf => Comp_Buf,
                     Out_Len => Comp_Len,
                     Status  => LZ_Stat);

                  if LZ_Stat = Success
                    and then Comp_Len < Natural (SE_Last)
                  then
                     --  Sikistirilmis Blok: Comp_L > 0
                     Word16'Write (Stream (Arch_File), Word16 (SE_Last));
                     Word16'Write (Stream (Arch_File), Word16 (Comp_Len));

                     for I in 1 .. Comp_Len loop
                        Byte'Write (Stream (Arch_File), Comp_Buf (I));
                     end loop;

                     Comp_Sum := Comp_Sum + Word32 (Comp_Len + 4);
                  else
                     --  Ham Saklama (Bypass): Comp_L = 0
                     Word16'Write (Stream (Arch_File), Word16 (SE_Last));
                     Word16'Write (Stream (Arch_File), 0);

                     for I in 1 .. SE_Last loop
                        Byte'Write (Stream (Arch_File), Raw_In (Natural (I)));
                     end loop;

                     Comp_Sum := Comp_Sum + Word32 (SE_Last + 4);
                  end if;
               end;
            end loop;
            Close (Src_File);
         end;
      end loop;
      End_Search (Search);

      Close (Arch_File);

      Total_Raw  := Raw_Sum;
      Total_Comp := Comp_Sum + 9;
      File_Count := Count;
      Status     := Success;
   end Archive_Directory;

   -----------------------
   -- Extract_Directory --
   -----------------------

   procedure Extract_Directory
     (Archive_Path : String;
      Target_Dir   : String;
      File_Count   : out Natural;
      Status       : out Container_Status)
   is
      Arch_File   : Ada.Streams.Stream_IO.File_Type;
      Dst_File    : Ada.Streams.Stream_IO.File_Type;
      M1, M2, M3, M4 : Character;
      Ver         : Byte;
      N_Files     : Word32;

      Comp_Buf    : Output_Buffer  := (others => 0);
      Dec_Block   : Payload_Buffer := (others => 0);
      Dec_Len     : Natural;
      LZ_Stat     : LZSS_Status;
      CRC_Calc    : Word32;
      Extr_Count  : Natural := 0;
   begin
      File_Count := 0;

      if not Exists (Archive_Path) then
         Status := Archive_Error;
         return;
      end if;

      if not Exists (Target_Dir) then
         Create_Path (Target_Dir);
      end if;

      Open (Arch_File, In_File, Archive_Path);

      Character'Read (Stream (Arch_File), M1);
      Character'Read (Stream (Arch_File), M2);
      Character'Read (Stream (Arch_File), M3);
      Character'Read (Stream (Arch_File), M4);
      Byte'Read (Stream (Arch_File), Ver);
      Word32'Read (Stream (Arch_File), N_Files);

      if M1 /= 'T' or else M2 /= 'A' or else M3 /= 'C' or else M4 /= 'T'
        or else Ver /= 2
      then
         Close (Arch_File);
         Status := Archive_Error;
         return;
      end if;

      for F in 1 .. N_Files loop
         declare
            N_Len    : Word16;
            F_Size   : Word32;
            F_CRC    : Word32;
            N_Blocks : Word32;
            Raw_L    : Word16;
            Comp_L   : Word16;
         begin
            Word16'Read (Stream (Arch_File), N_Len);

            declare
               F_Name : String (1 .. Natural (N_Len));
            begin
               String'Read (Stream (Arch_File), F_Name);
               Word32'Read (Stream (Arch_File), F_Size);
               Word32'Read (Stream (Arch_File), F_CRC);
               Word32'Read (Stream (Arch_File), N_Blocks);

               declare
                  Out_Path : constant String :=
                    Compose (Target_Dir, F_Name);
               begin
                  Create (Dst_File, Out_File, Out_Path);
               end;
               CRC_Calc := 16#FFFF_FFFF#;

               for B in 1 .. N_Blocks loop
                  Word16'Read (Stream (Arch_File), Raw_L);
                  Word16'Read (Stream (Arch_File), Comp_L);

                  if Comp_L = 0 then
                     --  Ham Saklanmis Blok (Bypass)
                     for I in 1 .. Natural (Raw_L) loop
                        declare
                           B_Val : Byte;
                        begin
                           Byte'Read (Stream (Arch_File), B_Val);
                           Byte'Write (Stream (Dst_File), B_Val);
                           Update_CRC (CRC_Calc, B_Val);
                        end;
                     end loop;
                  else
                     --  Sikistirilmis Blok (4KB LZSS)
                     for I in 1 .. Natural (Comp_L) loop
                        Byte'Read (Stream (Arch_File), Comp_Buf (I));
                     end loop;

                     declare
                        In_Slice : constant Byte_Array (1 .. Natural (Comp_L))
                          := Comp_Buf (1 .. Natural (Comp_L));
                     begin
                        Decompress_LZSS_4K
                          (In_Buf  => In_Slice,
                           In_Len  => Natural (Comp_L),
                           Out_Buf => Dec_Block,
                           Out_Len => Dec_Len,
                           Status  => LZ_Stat);
                     end;

                     if LZ_Stat /= Success
                       or else Dec_Len /= Natural (Raw_L)
                     then
                        Close (Dst_File);
                        Close (Arch_File);
                        Status := Archive_Error;
                        return;
                     end if;

                     for I in 1 .. Natural (Raw_L) loop
                        Byte'Write (Stream (Dst_File), Dec_Block (I));
                        Update_CRC (CRC_Calc, Dec_Block (I));
                     end loop;
                  end if;
               end loop;

               Close (Dst_File);
               CRC_Calc := not CRC_Calc;

               if CRC_Calc /= F_CRC then
                  Close (Arch_File);
                  Status := CRC_Mismatch;
                  return;
               end if;

               Extr_Count := Extr_Count + 1;
            end;
         end;
      end loop;

      Close (Arch_File);
      File_Count := Extr_Count;
      Status     := Success;
   end Extract_Directory;

end Tactical_Container;
