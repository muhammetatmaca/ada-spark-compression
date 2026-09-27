with Ada.Numerics.Generic_Elementary_Functions;

package body Tactical_EML with SPARK_Mode => On is

   package Math is new Ada.Numerics.Generic_Elementary_Functions (Real);

   function Safe_Exp (X : Real) return Real with
     Pre  => X <= 85.0 and then X >= -85.0,
     Post => Safe_Exp'Result >= 0.0 and then Safe_Exp'Result <= 2.0E37
   is
      Val : constant Real := Math.Exp (X);
   begin
      if Val > 2.0E37 then
         return 2.0E37;
      elsif Val < 0.0 then
         return 0.0;
      else
         return Val;
      end if;
   end Safe_Exp;

   function Safe_Log (Y : Real) return Real with
     Pre  => Y >= 1.0E-20 and then Y <= 1.0E20,
     Post => Safe_Log'Result >= -50.0 and then Safe_Log'Result <= 50.0
   is
      Val : constant Real := Math.Log (Y);
   begin
      if Val > 50.0 then
         return 50.0;
      elsif Val < -50.0 then
         return -50.0;
      else
         return Val;
      end if;
   end Safe_Log;

   function EML (X, Y : Real) return Real is
   begin
      return Safe_Exp (X) - Safe_Log (Y);
   end EML;

   --  Odrzywolek (2026) Denklem 4a: exp(x) = eml(x, 1)
   function EML_Exp (X : Real) return Real is
   begin
      return EML (X, 1.0);
   end EML_Exp;

   --  Euler Sabiti: e = eml(1, 1)
   function EML_Euler_Constant return Real is
   begin
      return EML (1.0, 1.0);
   end EML_Euler_Constant;

   --  Odrzywolek (2026) Denklem 5: ln(z) = eml(1, eml(eml(1, z), 1))
   function EML_Ln (Z : Real) return Real is
      Step1 : Real;
      Step2 : Real;
   begin
      Step1 := EML (1.0, Z);
      if Step1 < -85.0 then
         Step1 := -85.0;
      elsif Step1 > 85.0 then
         Step1 := 85.0;
      end if;

      Step2 := EML (Step1, 1.0);
      if Step2 < 1.0E-20 then
         Step2 := 1.0E-20;
      elsif Step2 > 1.0E20 then
         Step2 := 1.0E20;
      end if;

      return EML (1.0, Step2);
   end EML_Ln;

   procedure Execute_EML
     (Prog   : EML_Program;
      X_Val  : Real;
      Result : out Real;
      Status : out Eval_Status)
   is
      Stack : array (1 .. Max_Stack) of Real := (others => 0.0);
      SP    : Natural := 0;
      A     : Real;
      B     : Real;
   begin
      Result := 0.0;

      for I in Prog'Range loop
         case Prog (I) is
            when Op_Const_1 =>
               if SP >= Max_Stack then
                  Status := Stack_Overflow;
                  return;
               end if;
               SP := SP + 1;
               Stack (SP) := 1.0;

            when Op_Var_X =>
               if SP >= Max_Stack then
                  Status := Stack_Overflow;
                  return;
               end if;
               SP := SP + 1;
               Stack (SP) := X_Val;

            when Op_EML =>
               if SP < 2 then
                  Status := Stack_Underflow;
                  return;
               end if;
               B := Stack (SP);
               A := Stack (SP - 1);
               SP := SP - 1;

               if B < 1.0E-20 or else B > 1.0E20
                 or else A > 85.0 or else A < -85.0
               then
                  Status := Domain_Error;
                  return;
               end if;

               Stack (SP) := EML (A, B);
         end case;

         pragma Loop_Invariant (SP <= Max_Stack);
         pragma Loop_Invariant (I in Prog'Range);
      end loop;

      if SP = 1 then
         Result := Stack (1);
         Status := Success;
      else
         Status := Stack_Underflow;
      end if;
   end Execute_EML;

end Tactical_EML;
