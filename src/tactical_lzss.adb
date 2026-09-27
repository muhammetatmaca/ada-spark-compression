with Interfaces;     use Interfaces;

package body Tactical_LZSS with SPARK_Mode => Off is

   -------------------
   -- Compress_LZSS --
   -------------------

   procedure Compress_LZSS
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Output_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status)
   is
      Read_Pos     : Positive := 1;
      Write_Pos    : Positive := 1;
      Best_Offset  : Natural;
      Best_Len     : Natural;
      Window_Start : Positive;
      Max_Match    : constant Natural := 255;
      Min_Match    : constant Natural := 3;

      Flag_Pos     : Positive := 1;
      Flag_Byte    : Byte := 0;
      Bit_Count    : Natural := 0;
   begin
      Out_Len := 0;
      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      Flag_Pos  := Write_Pos;
      Flag_Byte := 0;
      Bit_Count := 0;
      Write_Pos := Write_Pos + 1;

      while Read_Pos <= In_Len loop
         Best_Len    := 0;
         Best_Offset := 0;

         if Read_Pos > 255 then
            Window_Start := Read_Pos - 255;
         else
            Window_Start := 1;
         end if;

         if Window_Start < Read_Pos then
            for W in Window_Start .. Read_Pos - 1 loop
               declare
                  Match_Len : Natural := 0;
               begin
                  while Read_Pos + Match_Len <= In_Len
                    and then Match_Len < Max_Match
                    and then In_Buf (W + Match_Len) =
                             In_Buf (Read_Pos + Match_Len)
                  loop
                     Match_Len := Match_Len + 1;
                  end loop;

                  if Match_Len >= Min_Match
                    and then Match_Len > Best_Len
                  then
                     Best_Len    := Match_Len;
                     Best_Offset := Read_Pos - W;
                  end if;
               end;
            end loop;
         end if;

         if Best_Len >= Min_Match then
            if Write_Pos + 1 > Out_Buf'Last then
               Status  := Buffer_Full;
               Out_Len := Write_Pos - 1;
               return;
            end if;

            Flag_Byte := Flag_Byte or
              Interfaces.Shift_Left (1, Bit_Count);
            Out_Buf (Write_Pos)     := Byte (Best_Offset);
            Out_Buf (Write_Pos + 1) := Byte (Best_Len);
            Write_Pos := Write_Pos + 2;
            Read_Pos  := Read_Pos + Best_Len;
         else
            if Write_Pos > Out_Buf'Last then
               Status  := Buffer_Full;
               Out_Len := Write_Pos - 1;
               return;
            end if;

            Out_Buf (Write_Pos) := In_Buf (Read_Pos);
            Write_Pos := Write_Pos + 1;
            Read_Pos  := Read_Pos + 1;
         end if;

         Bit_Count := Bit_Count + 1;
         if Bit_Count = 8 then
            Out_Buf (Flag_Pos) := Flag_Byte;
            if Read_Pos <= In_Len then
               if Write_Pos > Out_Buf'Last then
                  Status  := Buffer_Full;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;
               Flag_Pos  := Write_Pos;
               Flag_Byte := 0;
               Bit_Count := 0;
               Write_Pos := Write_Pos + 1;
            end if;
         end if;
      end loop;

      if Bit_Count > 0 and then Bit_Count < 8 then
         Out_Buf (Flag_Pos) := Flag_Byte;
      end if;

      Out_Len := Write_Pos - 1;
      Status  := Success;
   end Compress_LZSS;

   ---------------------
   -- Decompress_LZSS --
   ---------------------

   procedure Decompress_LZSS
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status)
   is
      Read_Pos  : Positive := 1;
      Write_Pos : Positive := 1;
      Flag      : Byte;
      Offset    : Natural;
      Len       : Natural;
      Is_Match  : Boolean;
   begin
      Out_Len := 0;
      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      while Read_Pos <= In_Len loop
         Flag := In_Buf (Read_Pos);
         Read_Pos := Read_Pos + 1;

         for Bit_Idx in 0 .. 7 loop
            exit when Read_Pos > In_Len or else Write_Pos > Out_Buf'Last;

            Is_Match :=
              (Flag and Interfaces.Shift_Left (1, Bit_Idx)) /= 0;

            if Is_Match then
               if In_Len - Read_Pos < 1 then
                  Status  := Corrupted_Stream;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;

               Offset   := Natural (In_Buf (Read_Pos));
               Len      := Natural (In_Buf (Read_Pos + 1));
               Read_Pos := Read_Pos + 2;

               if Offset = 0 or else Len = 0 or else Offset >= Write_Pos then
                  Status  := Corrupted_Stream;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;

               if Write_Pos + Len - 1 > Out_Buf'Last then
                  Status  := Buffer_Full;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;

               for K in 0 .. Len - 1 loop
                  Out_Buf (Write_Pos + K) :=
                    Out_Buf (Write_Pos - Offset + K);
               end loop;

               Write_Pos := Write_Pos + Len;
            else
               Out_Buf (Write_Pos) := In_Buf (Read_Pos);
               Write_Pos := Write_Pos + 1;
               Read_Pos  := Read_Pos + 1;
            end if;
         end loop;
      end loop;

      Out_Len := Write_Pos - 1;
      Status  := Success;
   end Decompress_LZSS;

   ----------------------
   -- Compress_LZSS_4K --
   ----------------------

   procedure Compress_LZSS_4K
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Output_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status)
   is
      Read_Pos     : Positive := 1;
      Write_Pos    : Positive := 1;
      Best_Offset  : Natural;
      Best_Len     : Natural;
      Max_Match    : constant Natural := 255;
      Min_Match    : constant Natural := 4;

      Flag_Pos     : Positive := 1;
      Flag_Byte    : Byte := 0;
      Bit_Count    : Natural := 0;

      Head         : array (0 .. 4095) of Natural := (others => 0);
      Prev         : array (1 .. 4096) of Natural := (others => 0);
      H            : Natural;
      Cand         : Natural;
      Chain        : Natural;
      Match_Len    : Natural;
      Step_Limit   : constant Natural := 32;
   begin
      Out_Len := 0;
      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      Flag_Pos  := Write_Pos;
      Flag_Byte := 0;
      Bit_Count := 0;
      Write_Pos := Write_Pos + 1;

      while Read_Pos <= In_Len loop
         Best_Len    := 0;
         Best_Offset := 0;

         if Read_Pos + 2 <= In_Len then
            H := (Natural (In_Buf (Read_Pos)) * 31 +
                  Natural (In_Buf (Read_Pos + 1)) * 7 +
                  Natural (In_Buf (Read_Pos + 2))) mod 4096;

            Cand  := Head (H);
            Chain := 0;

            while Cand > 0 and then Chain < Step_Limit
              and then (Read_Pos - Cand) < 4096
            loop
               Match_Len := 0;
               while Read_Pos + Match_Len <= In_Len
                 and then Match_Len < Max_Match
                 and then In_Buf (Cand + Match_Len) =
                          In_Buf (Read_Pos + Match_Len)
               loop
                  Match_Len := Match_Len + 1;
               end loop;

               if Match_Len >= Min_Match and then Match_Len > Best_Len then
                  Best_Len    := Match_Len;
                  Best_Offset := Read_Pos - Cand;
                  exit when Best_Len >= 128;
               end if;

               Cand  := Prev (Cand);
               Chain := Chain + 1;
            end loop;

            Prev (Read_Pos) := Head (H);
            Head (H)        := Read_Pos;
         end if;

         if Best_Len >= Min_Match then
            if Write_Pos + 2 > Out_Buf'Last then
               Status  := Buffer_Full;
               Out_Len := Write_Pos - 1;
               return;
            end if;

            Flag_Byte := Flag_Byte or
              Interfaces.Shift_Left (1, Bit_Count);
            Out_Buf (Write_Pos)     := Byte (Best_Offset / 256);
            Out_Buf (Write_Pos + 1) := Byte (Best_Offset mod 256);
            Out_Buf (Write_Pos + 2) := Byte (Best_Len);
            Write_Pos := Write_Pos + 3;

            for K in 1 .. Natural'Min (Best_Len - 1, 3) loop
               if Read_Pos + K + 2 <= In_Len then
                  H := (Natural (In_Buf (Read_Pos + K)) * 31 +
                        Natural (In_Buf (Read_Pos + K + 1)) * 7 +
                        Natural (In_Buf (Read_Pos + K + 2))) mod 4096;
                  Prev (Read_Pos + K) := Head (H);
                  Head (H)            := Read_Pos + K;
               end if;
            end loop;

            Read_Pos := Read_Pos + Best_Len;
         else
            if Write_Pos > Out_Buf'Last then
               Status  := Buffer_Full;
               Out_Len := Write_Pos - 1;
               return;
            end if;

            Out_Buf (Write_Pos) := In_Buf (Read_Pos);
            Write_Pos := Write_Pos + 1;
            Read_Pos  := Read_Pos + 1;
         end if;

         Bit_Count := Bit_Count + 1;
         if Bit_Count = 8 then
            Out_Buf (Flag_Pos) := Flag_Byte;
            if Read_Pos <= In_Len then
               if Write_Pos > Out_Buf'Last then
                  Status  := Buffer_Full;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;
               Flag_Pos  := Write_Pos;
               Flag_Byte := 0;
               Bit_Count := 0;
               Write_Pos := Write_Pos + 1;
            end if;
         end if;
      end loop;

      if Bit_Count > 0 and then Bit_Count < 8 then
         Out_Buf (Flag_Pos) := Flag_Byte;
      end if;

      Out_Len := Write_Pos - 1;
      Status  := Success;
   end Compress_LZSS_4K;

   ------------------------
   -- Decompress_LZSS_4K --
   ------------------------

   procedure Decompress_LZSS_4K
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out LZSS_Status)
   is
      Read_Pos  : Positive := 1;
      Write_Pos : Positive := 1;
      Flag      : Byte;
      Offset    : Natural;
      Len       : Natural;
      Is_Match  : Boolean;
   begin
      Out_Len := 0;
      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      while Read_Pos <= In_Len loop
         Flag := In_Buf (Read_Pos);
         Read_Pos := Read_Pos + 1;

         for Bit_Idx in 0 .. 7 loop
            exit when Read_Pos > In_Len or else Write_Pos > Out_Buf'Last;

            Is_Match :=
              (Flag and Interfaces.Shift_Left (1, Bit_Idx)) /= 0;

            if Is_Match then
               if In_Len - Read_Pos < 2 then
                  Status  := Corrupted_Stream;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;

               Offset   := Natural (In_Buf (Read_Pos)) * 256 +
                           Natural (In_Buf (Read_Pos + 1));
               Len      := Natural (In_Buf (Read_Pos + 2));
               Read_Pos := Read_Pos + 3;

               if Offset = 0 or else Len = 0 or else Offset >= Write_Pos then
                  Status  := Corrupted_Stream;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;

               if Write_Pos + Len - 1 > Out_Buf'Last then
                  Status  := Buffer_Full;
                  Out_Len := Write_Pos - 1;
                  return;
               end if;

               for K in 0 .. Len - 1 loop
                  Out_Buf (Write_Pos + K) :=
                    Out_Buf (Write_Pos - Offset + K);
               end loop;

               Write_Pos := Write_Pos + Len;
            else
               Out_Buf (Write_Pos) := In_Buf (Read_Pos);
               Write_Pos := Write_Pos + 1;
               Read_Pos  := Read_Pos + 1;
            end if;
         end loop;
      end loop;

      Out_Len := Write_Pos - 1;
      Status  := Success;
   end Decompress_LZSS_4K;

end Tactical_LZSS;
