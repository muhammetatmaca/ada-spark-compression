package body Tactical_Compressor with SPARK_Mode => On is

   procedure Compress_Block
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Compression_Status)
   is
      Read_Pos  : Positive := 1;
      Write_Pos : Positive := 1;
      Count     : Natural;
      Curr_Byte : Byte;
   begin
      Out_Len := 0;

      if In_Len = 0 then
         Status := Invalid_Input;
         return;
      end if;

      while Read_Pos <= In_Len loop
         Curr_Byte := In_Buf (Read_Pos);
         Count := 1;

         --  Ayni baytin tekrarini say (Maksimum 255)
         while Read_Pos + Count <= In_Len
           and then In_Buf (Read_Pos + Count) = Curr_Byte
           and then Count < 255
         loop
            Count := Count + 1;
            pragma Loop_Invariant (Count <= 255);
            pragma Loop_Invariant (Read_Pos + Count <= In_Len + 1);
         end loop;

         if Write_Pos + 1 > Out_Buf'Last then
            Status  := Buffer_Full;
            Out_Len := Write_Pos - 1;
            return;
         end if;

         Out_Buf (Write_Pos)     := Byte (Count);
         Out_Buf (Write_Pos + 1) := Curr_Byte;

         Write_Pos := Write_Pos + 2;
         Read_Pos  := Read_Pos + Count;

         pragma Loop_Invariant (Read_Pos >= 1);
         pragma Loop_Invariant (Write_Pos >= 3);
         pragma Loop_Invariant
           (Write_Pos <= Out_Buf'Last + 1);
         pragma Loop_Invariant (Write_Pos mod 2 = 1);
      end loop;

      Out_Len := Write_Pos - 1;
      Status  := Success;
   end Compress_Block;

   procedure Decompress_Block
     (In_Buf  : Byte_Array;
      In_Len  : Natural;
      Out_Buf : in out Payload_Buffer;
      Out_Len : out Natural;
      Status  : out Decompression_Status)
   is
      Read_Pos  : Positive := 1;
      Write_Pos : Positive := 1;
      Count     : Natural;
      Curr_Byte : Byte;
   begin
      Out_Len := 0;

      if In_Len = 0 or else In_Len mod 2 /= 0 then
         Status := Invalid_Input;
         return;
      end if;

      while Read_Pos <= In_Len - 1 loop
         Count     := Natural (In_Buf (Read_Pos));
         Curr_Byte := In_Buf (Read_Pos + 1);

         if Count = 0 then
            Status  := Corrupted_Stream;
            Out_Len := Write_Pos - 1;
            return;
         end if;

         if Write_Pos + Count - 1 > Out_Buf'Last then
            Status  := Output_Buffer_Full;
            Out_Len := Write_Pos - 1;
            return;
         end if;

         for I in 0 .. Count - 1 loop
            Out_Buf (Write_Pos + I) := Curr_Byte;
            pragma Loop_Invariant (Write_Pos + I <= Out_Buf'Last);
         end loop;

         Write_Pos := Write_Pos + Count;
         Read_Pos  := Read_Pos + 2;

         pragma Loop_Invariant (Read_Pos >= 1);
         pragma Loop_Invariant
           (Write_Pos >= 1 and then Write_Pos <= Out_Buf'Last + 1);
         pragma Loop_Invariant (Read_Pos mod 2 = 1);
      end loop;

      Out_Len := Write_Pos - 1;
      Status  := Success;
   end Decompress_Block;

end Tactical_Compressor;
