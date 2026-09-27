with Interfaces; use type Interfaces.Unsigned_8;

package body Tactical_Model_Compress with SPARK_Mode => On is

   ----------------------
   -- Pack_EML_Program --
   ----------------------

   procedure Pack_EML_Program
     (Prog    : EML_Program;
      Out_Buf : out Output_Buffer;
      Out_Len : out Natural;
      Status  : out Model_Status)
   is
      Num_Bytes : Natural;
      Byte_Idx  : Positive;
      Shift     : Natural;
      Code      : Byte;
      Shifted   : Byte;
   begin
      Out_Buf := (others => 0);

      if Prog'Length = 0 then
         Out_Len := 0;
         Status  := Success;
         return;
      end if;

      Num_Bytes := (Prog'Length + 3) / 4;
      Out_Len   := Num_Bytes;

      for K in 0 .. Prog'Length - 1 loop
         case Prog (K + 1) is
            when Op_Const_1 =>
               Code := 0;
            when Op_Var_X =>
               Code := 1;
            when Op_EML =>
               Code := 2;
         end case;

         Byte_Idx := (K / 4) + 1;
         Shift    := (K mod 4) * 2;
         Shifted  := Interfaces.Shift_Left (Code, Shift);
         Out_Buf (Byte_Idx) := Out_Buf (Byte_Idx) or Shifted;

         pragma Loop_Invariant (Byte_Idx <= Num_Bytes);
         pragma Loop_Invariant (Num_Bytes <= 8);
         pragma Loop_Invariant (Out_Len = Num_Bytes);
      end loop;

      Status := Success;
   end Pack_EML_Program;

   ------------------------
   -- Unpack_EML_Program --
   ------------------------

   procedure Unpack_EML_Program
     (In_Buf   : Byte_Array;
      Prog_Len : Natural;
      Prog     : out Program_Buffer;
      Status   : out Model_Status)
   is
      Required_Bytes : Natural;
      Byte_Idx       : Positive;
      Shift          : Natural;
      Raw_Byte       : Byte;
      Code           : Byte;
   begin
      Prog := (others => Op_Const_1);

      if Prog_Len = 0 then
         Status := Success;
         return;
      end if;

      Required_Bytes := (Prog_Len + 3) / 4;

      if In_Buf'Length < Required_Bytes then
         Status := Invalid_Model;
         return;
      end if;

      for K in 0 .. Prog_Len - 1 loop
         Byte_Idx := (K / 4) + 1;
         Shift    := (K mod 4) * 2;

         if Byte_Idx not in In_Buf'Range then
            Status := Invalid_Model;
            return;
         end if;

         Raw_Byte := In_Buf (Byte_Idx);
         Code     := Interfaces.Shift_Right (Raw_Byte, Shift) and 2#11#;

         case Code is
            when 0 =>
               Prog (K + 1) := Op_Const_1;
            when 1 =>
               Prog (K + 1) := Op_Var_X;
            when 2 =>
               Prog (K + 1) := Op_EML;
            when others =>
               Status := Invalid_Model;
               return;
         end case;

         pragma Loop_Invariant (K + 1 <= Max_Prog_Len);
      end loop;

      Status := Success;
   end Unpack_EML_Program;

   --------------------------
   -- Regenerate_Telemetry --
   --------------------------

   procedure Regenerate_Telemetry
     (Prog    : EML_Program;
      Out_Buf : in out Payload_Buffer;
      Out_Len : Natural;
      Status  : out Model_Status)
   is
      X_Val     : Real;
      Res       : Real;
      Ev_Status : Eval_Status;
   begin
      if Out_Len = 0 then
         Status := Success;
         return;
      end if;

      if Prog'Length = 0 then
         Status := Invalid_Model;
         return;
      end if;

      for I in 1 .. Out_Len loop
         X_Val := Real (I) / Real (Out_Len);

         Execute_EML
           (Prog   => Prog,
            X_Val  => X_Val,
            Result => Res,
            Status => Ev_Status);

         if Ev_Status /= Tactical_EML.Success then
            Status := Eval_Failed;
            return;
         end if;

         if Res <= 0.0 then
            Out_Buf (I) := 0;
         elsif Res >= 255.0 then
            Out_Buf (I) := 255;
         else
            Out_Buf (I) := Byte (Natural (Res));
         end if;

         pragma Loop_Invariant (I in 1 .. Out_Len);
         pragma Loop_Invariant (Out_Len <= Max_Block_Size);
      end loop;

      Status := Success;
   end Regenerate_Telemetry;

end Tactical_Model_Compress;
