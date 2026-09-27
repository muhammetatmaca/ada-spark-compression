with Tactical_Types; use Tactical_Types;

package Tactical_EML with SPARK_Mode => On is

   --  Odrzywolek (2026) EML Sheffer Operatoru: eml(x, y) = exp(x) - ln(y)
   --  Surekli matematikteki tum fonksiyonlari ureten tek ikili operator.
   function EML (X, Y : Real) return Real with
     Pre => Y >= 1.0E-20
            and then Y <= 1.0E20
            and then X <= 85.0
            and then X >= -85.0;

   --  EML ile Uretilen Dogal Ust: exp(x) = eml(x, 1)
   function EML_Exp (X : Real) return Real with
     Pre => X <= 85.0 and then X >= -85.0;

   --  EML ile Uretilen Euler Sabiti: e = eml(1, 1)
   function EML_Euler_Constant return Real;

   --  EML ile Uretilen Dogal Logaritma: ln(z) = eml(1, eml(eml(1, z), 1))
   function EML_Ln (Z : Real) return Real with
     Pre => Z > 1.0E-20 and then Z <= 1.0E10;

   --  EML Tek-Komutlu Sanal Makine (OISC RPN Yigini)
   type EML_Op is (Op_Const_1, Op_Var_X, Op_EML);
   type EML_Program is array (Positive range <>) of EML_Op;

   Max_Prog_Len : constant Positive := 32;
   Max_Stack    : constant Positive := 16;

   subtype Program_Index  is Positive range 1 .. Max_Prog_Len;
   subtype Program_Buffer is EML_Program (Program_Index);

   type Eval_Status is
     (Success, Stack_Underflow, Stack_Overflow, Domain_Error);

   --  EML Formulu Yorumlayicisi (Deterministik, statik yigin)
   procedure Execute_EML
     (Prog   : EML_Program;
      X_Val  : Real;
      Result : out Real;
      Status : out Eval_Status) with
     Pre => Prog'Length <= Max_Prog_Len
            and then Prog'First = 1;

end Tactical_EML;
