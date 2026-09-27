with Interfaces; use Interfaces;

package body Tactical_TurboQuant with SPARK_Mode => On is

   Inv_Sqrt_32 : constant Real := 0.17677669529663688;

   subtype Work_Float  is Real range -1.0E8 .. 1.0E8;
   type Work_Vector_32 is array (Vector_Index) of Work_Float;

   --  TurboQuant (2025) Deterministik Isaret Vektorleri
   Sign_1 : constant Vector_32 :=
     (1.0, -1.0, -1.0,  1.0, -1.0,  1.0,  1.0, -1.0,
      1.0,  1.0, -1.0, -1.0,  1.0, -1.0,  1.0, -1.0,
     -1.0,  1.0, -1.0,  1.0,  1.0, -1.0, -1.0,  1.0,
      1.0, -1.0,  1.0, -1.0, -1.0,  1.0, -1.0,  1.0);

   Sign_2 : constant Vector_32 :=
     (-1.0,  1.0,  1.0, -1.0,  1.0, -1.0, -1.0,  1.0,
      -1.0, -1.0,  1.0,  1.0, -1.0,  1.0, -1.0,  1.0,
       1.0, -1.0,  1.0, -1.0, -1.0,  1.0,  1.0, -1.0,
      -1.0,  1.0, -1.0,  1.0,  1.0, -1.0,  1.0, -1.0);

   -------------------
   -- Popcount_Byte --
   -------------------

   function Popcount_Byte (B : Byte) return Natural is
      Count : Natural := 0;
      Val   : Byte := B;
   begin
      for Bit in 1 .. 8 loop
         if (Val and 1) = 1 then
            Count := Count + 1;
         end if;
         Val := Shift_Right (Val, 1);
         pragma Loop_Invariant (Count <= 8);
      end loop;
      return Count;
   end Popcount_Byte;

   ----------
   -- FWHT --
   ----------

   procedure FWHT (A : in out Work_Vector_32) is
      Step : Positive := 1;
      Jump : Positive;
      I    : Positive;
      U    : Real;
      V    : Real;
   begin
      for Stage in 1 .. 5 loop
         Jump := Step * 2;
         I    := 1;
         while I < 32 loop
            for J in 0 .. Step - 1 loop
               U := A (I + J);
               V := A (I + J + Step);
               A (I + J)        := U + V;
               A (I + J + Step) := U - V;
            end loop;
            I := I + Jump;
            pragma Loop_Invariant (I <= 33);
            pragma Loop_Invariant (I mod Jump = 1);
         end loop;
         Step := Step * 2;
         pragma Loop_Invariant (Step <= 32);
      end loop;
   end FWHT;

   -----------------
   -- FWHT_Rotate --
   -----------------

   procedure FWHT_Rotate
     (Input_Vec  : Vector_32;
      Output_Vec : out Rotated_Vector_32)
   is
      T : Work_Vector_32;
      Val : Real;
   begin
      for I in Vector_Index loop
         T (I) := Input_Vec (I) * Sign_1 (I);
      end loop;

      FWHT (T);

      for I in Vector_Index loop
         Val := T (I) * Inv_Sqrt_32;
         if Val > Rotated_Float'Last then
            Output_Vec (I) := Rotated_Float'Last;
         elsif Val < Rotated_Float'First then
            Output_Vec (I) := Rotated_Float'First;
         else
            Output_Vec (I) := Val;
         end if;
      end loop;
   end FWHT_Rotate;

   -------------------------
   -- FWHT_Inverse_Rotate --
   -------------------------

   procedure FWHT_Inverse_Rotate
     (Input_Vec  : Rotated_Vector_32;
      Output_Vec : out Vector_32)
   is
      T   : Work_Vector_32;
      Val : Real;
   begin
      for I in Vector_Index loop
         T (I) := Input_Vec (I);
      end loop;

      FWHT (T);

      for I in Vector_Index loop
         Val := (T (I) * Inv_Sqrt_32) * Sign_1 (I);
         if Val > Sensor_Float'Last then
            Output_Vec (I) := Sensor_Float'Last;
         elsif Val < Sensor_Float'First then
            Output_Vec (I) := Sensor_Float'First;
         else
            Output_Vec (I) := Val;
         end if;
      end loop;
   end FWHT_Inverse_Rotate;

   ---------------------
   -- Compress_Vector --
   ---------------------

   procedure Compress_Vector
     (Input_Vec : Vector_32;
      Packet    : out Packet_Bytes;
      Status    : out TQ_Status)
   is
      Rot_Vec   : Rotated_Vector_32;
      Max_Val   : Real := 0.0;
      Z         : Real;
      Recon_Z   : Real;
      Code      : Byte;
      Byte_Idx  : Positive;
      Shift     : Natural;
      Scale_Int : Word32;
      MSE_Recon : Rotated_Vector_32 := (others => 0.0);
      Residual  : Rotated_Vector_32;
      QJL_In    : Work_Vector_32;
      Proj_Val  : Real;
      Bit       : Byte;
      Bit_Shift : Natural;
   begin
      Packet := (others => 0);

      FWHT_Rotate (Input_Vec, Rot_Vec);

      for I in Vector_Index loop
         if abs (Rot_Vec (I)) > Max_Val then
            Max_Val := abs (Rot_Vec (I));
         end if;
      end loop;

      if Max_Val < 1.0E-6 then
         Status := Success;
         return;
      end if;

      if Max_Val > 400000.0 then
         Status := Invalid_Vector;
         return;
      end if;

      Scale_Int := Word32 (Natural (Max_Val * 10000.0));
      Packet (1) := Byte (Shift_Right (Scale_Int, 24) and 16#FF#);
      Packet (2) := Byte (Shift_Right (Scale_Int, 16) and 16#FF#);
      Packet (3) := Byte (Shift_Right (Scale_Int, 8) and 16#FF#);
      Packet (4) := Byte (Scale_Int and 16#FF#);

      --  Stage 1: 2-Bit Lloyd-Max Skaler Kuantalama
      for I in Vector_Index loop
         Z := Rot_Vec (I) / Max_Val;
         if Z < -0.5 then
            Code    := 0;
            Recon_Z := -0.75;
         elsif Z < 0.0 then
            Code    := 1;
            Recon_Z := -0.25;
         elsif Z < 0.5 then
            Code    := 2;
            Recon_Z := 0.25;
         else
            Code    := 3;
            Recon_Z := 0.75;
         end if;

         MSE_Recon (I) := Recon_Z * Max_Val;
         Residual (I)  := Rot_Vec (I) - MSE_Recon (I);

         Byte_Idx := 4 + ((I - 1) / 4) + 1;
         Shift    := ((I - 1) mod 4) * 2;
         Packet (Byte_Idx) := Packet (Byte_Idx) or Shift_Left (Code, Shift);
      end loop;

      --  Stage 2: 1-Bit QJL Artik Hata Projeksiyonu
      for I in Vector_Index loop
         QJL_In (I) := Residual (I) * Sign_2 (I);
      end loop;

      FWHT (QJL_In);

      for I in Vector_Index loop
         Proj_Val := QJL_In (I) * Inv_Sqrt_32;
         if Proj_Val >= 0.0 then
            Bit := 1;
         else
            Bit := 0;
         end if;

         Byte_Idx  := 12 + ((I - 1) / 8) + 1;
         Bit_Shift := (I - 1) mod 8;
         Packet (Byte_Idx) := Packet (Byte_Idx) or Shift_Left (Bit, Bit_Shift);
      end loop;

      Status := Success;
   end Compress_Vector;

   -----------------------
   -- Decompress_Vector --
   -----------------------

   procedure Decompress_Vector
     (Packet     : Packet_Bytes;
      Output_Vec : out Vector_32;
      Status     : out TQ_Status)
   is
      Scale_Int      : Word32;
      Max_Val        : Real;
      Byte_Idx       : Positive;
      Shift          : Natural;
      Bit_Shift      : Natural;
      Code           : Byte;
      Recon_Z        : Real;
      MSE_Recon      : Rotated_Vector_32;
      C_QJL          : Real;
      Bit            : Byte;
      QJL_Recon      : Work_Vector_32;
      Residual_Recon : Rotated_Vector_32 := (others => 0.0);
      Rot_Recon      : Rotated_Vector_32;
      Rot_Val        : Real;
   begin
      Scale_Int :=
        Shift_Left (Word32 (Packet (1)), 24) or
        Shift_Left (Word32 (Packet (2)), 16) or
        Shift_Left (Word32 (Packet (3)), 8)  or
        Word32 (Packet (4));

      Max_Val := Real (Scale_Int) / 10000.0;

      if Max_Val <= 1.0E-6 then
         Output_Vec := (others => 0.0);
         Status     := Success;
         return;
      end if;

      --  1. MSE Kuantalama Geri Acma
      for I in Vector_Index loop
         Byte_Idx := 4 + ((I - 1) / 4) + 1;
         Shift    := ((I - 1) mod 4) * 2;
         Code     := Shift_Right (Packet (Byte_Idx), Shift) and 2#11#;

         case Code is
            when 0 => Recon_Z := -0.75;
            when 1 => Recon_Z := -0.25;
            when 2 => Recon_Z := 0.25;
            when others => Recon_Z := 0.75;
         end case;

         MSE_Recon (I) := Recon_Z * Max_Val;
      end loop;

      --  2. QJL Artik Isaretler Geri Acma
      C_QJL := 0.035 * Max_Val;

      for I in Vector_Index loop
         Byte_Idx  := 12 + ((I - 1) / 8) + 1;
         Bit_Shift := (I - 1) mod 8;
         Bit       := Shift_Right (Packet (Byte_Idx), Bit_Shift) and 1;

         if Bit = 1 then
            QJL_Recon (I) := C_QJL;
         else
            QJL_Recon (I) := -C_QJL;
         end if;
      end loop;

      --  Ters QJL Projeksiyonu
      FWHT (QJL_Recon);

      for I in Vector_Index loop
         Residual_Recon (I) := (QJL_Recon (I) * Inv_Sqrt_32) * Sign_2 (I);
         Rot_Val := MSE_Recon (I) + Residual_Recon (I);
         if Rot_Val > Rotated_Float'Last then
            Rot_Recon (I) := Rotated_Float'Last;
         elsif Rot_Val < Rotated_Float'First then
            Rot_Recon (I) := Rotated_Float'First;
         else
            Rot_Recon (I) := Rot_Val;
         end if;
      end loop;

      --  Ters Ortogonal Rotasyon
      FWHT_Inverse_Rotate (Rot_Recon, Output_Vec);

      Status := Success;
   end Decompress_Vector;

   --------------------------
   -- Estimate_Dot_Product --
   --------------------------

   function Estimate_Dot_Product
     (Packet_A : Packet_Bytes;
      Packet_B : Packet_Bytes) return Real
   is
      Scale_Int_A : Word32;
      Scale_Int_B : Word32;
      Max_Val_A   : Real;
      Max_Val_B   : Real;
      Byte_Idx    : Positive;
      Shift       : Natural;
      Code_A      : Byte;
      Code_B      : Byte;
      Recon_Z_A   : Real;
      Recon_Z_B   : Real;
      MSE_Dot     : Real := 0.0;
      Diff_Byte   : Byte;
      Match_Bits  : Natural := 0;
      Corr        : Real;
      QJL_Dot     : Real;
   begin
      Scale_Int_A :=
        Shift_Left (Word32 (Packet_A (1)), 24) or
        Shift_Left (Word32 (Packet_A (2)), 16) or
        Shift_Left (Word32 (Packet_A (3)), 8)  or
        Word32 (Packet_A (4));

      Scale_Int_B :=
        Shift_Left (Word32 (Packet_B (1)), 24) or
        Shift_Left (Word32 (Packet_B (2)), 16) or
        Shift_Left (Word32 (Packet_B (3)), 8)  or
        Word32 (Packet_B (4));

      Max_Val_A := Real (Scale_Int_A) / 10000.0;
      Max_Val_B := Real (Scale_Int_B) / 10000.0;

      if Max_Val_A <= 1.0E-6 or else Max_Val_B <= 1.0E-6 then
         return 0.0;
      end if;

      --  Kademe 1: MSE Ic Carpimi
      for I in Vector_Index loop
         Byte_Idx := 4 + ((I - 1) / 4) + 1;
         Shift    := ((I - 1) mod 4) * 2;

         Code_A := Shift_Right (Packet_A (Byte_Idx), Shift) and 2#11#;
         case Code_A is
            when 0 => Recon_Z_A := -0.75;
            when 1 => Recon_Z_A := -0.25;
            when 2 => Recon_Z_A := 0.25;
            when others => Recon_Z_A := 0.75;
         end case;

         Code_B := Shift_Right (Packet_B (Byte_Idx), Shift) and 2#11#;
         case Code_B is
            when 0 => Recon_Z_B := -0.75;
            when 1 => Recon_Z_B := -0.25;
            when 2 => Recon_Z_B := 0.25;
            when others => Recon_Z_B := 0.75;
         end case;

         MSE_Dot := MSE_Dot +
           ((Recon_Z_A * Max_Val_A) * (Recon_Z_B * Max_Val_B));
      end loop;

      --  Kademe 2: QJL Artik Hata Korelasyonu (XOR + Popcount)
      for K in 13 .. 16 loop
         Diff_Byte  := Packet_A (K) xor Packet_B (K);
         Match_Bits := Match_Bits + (8 - Popcount_Byte (Diff_Byte));
         pragma Loop_Invariant (Match_Bits <= (K - 12) * 8);
      end loop;

      Corr := Real (2 * Match_Bits) - 32.0;
      QJL_Dot := (0.035 * Max_Val_A) * (0.035 * Max_Val_B) * Corr;

      return MSE_Dot + QJL_Dot;
   end Estimate_Dot_Product;

   -------------------------
   -- Compute_Dot_Product --
   -------------------------

   function Compute_Dot_Product
     (Vec_A : Vector_32;
      Vec_B : Vector_32) return Real
   is
      Sum : Real := 0.0;
   begin
      for I in Vector_Index loop
         Sum := Sum + (Vec_A (I) * Vec_B (I));
      end loop;
      return Sum;
   end Compute_Dot_Product;

end Tactical_TurboQuant;
