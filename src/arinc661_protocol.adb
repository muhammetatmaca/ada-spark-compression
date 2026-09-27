package body ARINC661_Protocol with SPARK_Mode => On is

   -----------------------
   -- Init_A661_Message --
   -----------------------

   procedure Init_A661_Message
     (Msg_Buf : in out Output_Buffer;
      Msg_Len : out Natural;
      App_ID  : Word16)
   is
   begin
      Msg_Buf (1 .. 4) := (others => 0);
      Msg_Buf (5)      := Byte (Shift_Right (App_ID, 8) and 16#FF#);
      Msg_Buf (6)      := Byte (App_ID and 16#FF#);
      Msg_Len          := 6;
   end Init_A661_Message;

   -----------------
   -- Start_Layer --
   -----------------

   procedure Start_Layer
     (Msg_Buf  : in out Output_Buffer;
      Msg_Len  : in out Natural;
      Layer_ID : Word16)
   is
   begin
      Msg_Buf (Msg_Len + 1) := 0;
      Msg_Buf (Msg_Len + 2) := 4;
      Msg_Buf (Msg_Len + 3) := Byte (Shift_Right (Layer_ID, 8) and 16#FF#);
      Msg_Buf (Msg_Len + 4) := Byte (Layer_ID and 16#FF#);
      Msg_Len               := Msg_Len + 4;
   end Start_Layer;

   --------------------------
   -- Append_Numeric_Param --
   --------------------------

   procedure Append_Numeric_Param
     (Msg_Buf   : in out Output_Buffer;
      Msg_Len   : in out Natural;
      Widget_ID : Word16;
      Value     : Word32)
   is
      P : constant Natural := Msg_Len;
   begin
      --  Command: A661_CMD_SET_PARAMETER
      Msg_Buf (P + 1) := Byte (Shift_Right (A661_CMD_SET_PARAMETER, 8));
      Msg_Buf (P + 2) := Byte (A661_CMD_SET_PARAMETER and 16#FF#);

      --  Target Widget ID
      Msg_Buf (P + 3) := Byte (Shift_Right (Widget_ID, 8));
      Msg_Buf (P + 4) := Byte (Widget_ID and 16#FF#);

      --  Parameter ID: A661_PARAM_VALUE
      Msg_Buf (P + 5) := Byte (Shift_Right (A661_PARAM_VALUE, 8));
      Msg_Buf (P + 6) := Byte (A661_PARAM_VALUE and 16#FF#);

      --  Numeric Value (Word32, Big-Endian)
      Msg_Buf (P + 7)  := Byte (Shift_Right (Value, 24) and 16#FF#);
      Msg_Buf (P + 8)  := Byte (Shift_Right (Value, 16) and 16#FF#);
      Msg_Buf (P + 9)  := Byte (Shift_Right (Value, 8) and 16#FF#);
      Msg_Buf (P + 10) := Byte (Value and 16#FF#);

      Msg_Len := P + 10;
   end Append_Numeric_Param;

   -------------------------
   -- Append_String_Param --
   -------------------------

   procedure Append_String_Param
     (Msg_Buf   : in out Output_Buffer;
      Msg_Len   : in out Natural;
      Widget_ID : Word16;
      Str       : String)
   is
      P       : constant Natural := Msg_Len;
      Str_Len : constant Word16  := Word16 (Str'Length);
   begin
      --  Command: A661_CMD_SET_PARAMETER
      Msg_Buf (P + 1) := Byte (Shift_Right (A661_CMD_SET_PARAMETER, 8));
      Msg_Buf (P + 2) := Byte (A661_CMD_SET_PARAMETER and 16#FF#);

      --  Target Widget ID
      Msg_Buf (P + 3) := Byte (Shift_Right (Widget_ID, 8));
      Msg_Buf (P + 4) := Byte (Widget_ID and 16#FF#);

      --  Parameter ID: A661_PARAM_STRING
      Msg_Buf (P + 5) := Byte (Shift_Right (A661_PARAM_STRING, 8));
      Msg_Buf (P + 6) := Byte (A661_PARAM_STRING and 16#FF#);

      --  String Length
      Msg_Buf (P + 7) := Byte (Shift_Right (Str_Len, 8));
      Msg_Buf (P + 8) := Byte (Str_Len and 16#FF#);

      for I in Str'Range loop
         Msg_Buf (P + 8 + (I - Str'First + 1)) :=
           Byte (Character'Pos (Str (I)));
      end loop;

      Msg_Len := P + 8 + Str'Length;
   end Append_String_Param;

   ---------------------------
   -- Finalize_A661_Message --
   ---------------------------

   procedure Finalize_A661_Message
     (Msg_Buf : in out Output_Buffer;
      Msg_Len : Natural)
   is
      Len_W32 : constant Word32 := Word32 (Msg_Len);
   begin
      Msg_Buf (1) := Byte (Shift_Right (Len_W32, 24) and 16#FF#);
      Msg_Buf (2) := Byte (Shift_Right (Len_W32, 16) and 16#FF#);
      Msg_Buf (3) := Byte (Shift_Right (Len_W32, 8) and 16#FF#);
      Msg_Buf (4) := Byte (Len_W32 and 16#FF#);
   end Finalize_A661_Message;

   ----------------------
   -- Parse_A661_Event --
   ----------------------

   procedure Parse_A661_Event
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Widget_ID : out Word16;
      Event_ID  : out Word16;
      Valid     : out Boolean)
   is
   begin
      if In_Len < 6 then
         Widget_ID := 0;
         Event_ID  := 0;
         Valid     := False;
         return;
      end if;

      --  ARINC 661 Event Format: [Layer:2B][Widget:2B][Event:2B]
      Widget_ID := Shift_Left (Word16 (In_Buf (3)), 8) or
                   Word16 (In_Buf (4));
      Event_ID  := Shift_Left (Word16 (In_Buf (5)), 8) or
                   Word16 (In_Buf (6));
      Valid     := True;
   end Parse_A661_Event;

   ---------------------------------
   -- Build_A661_Telemetry_Frame --
   ---------------------------------

   procedure Build_A661_Telemetry_Frame
     (Raw_Bytes   : Natural;
      Comp_Bytes  : Natural;
      Algo_ID     : Byte;
      CRC_Valid   : Boolean;
      Turbo_Acc   : Natural;
      Msg_Buf     : in out Output_Buffer;
      Msg_Len     : out Natural)
   is
      Savings : Natural := 0;
   begin
      Init_A661_Message (Msg_Buf, Msg_Len, 101);

      --  Katman 1: Sistem & CRC Durumu
      Start_Layer (Msg_Buf, Msg_Len, 1);
      if CRC_Valid then
         Append_String_Param (Msg_Buf, Msg_Len, WID_CRC_STATUS,
                              "CRC: OK");
      else
         Append_String_Param (Msg_Buf, Msg_Len, WID_CRC_STATUS,
                              "CRC: ERR");
      end if;

      --  Katman 2: Aviyonik Metrikler & Gostergeler
      Start_Layer (Msg_Buf, Msg_Len, 2);
      Append_Numeric_Param (Msg_Buf, Msg_Len, WID_RAW_BYTES,
                            Word32 (Raw_Bytes));
      Append_Numeric_Param (Msg_Buf, Msg_Len, WID_COMP_BYTES,
                            Word32 (Comp_Bytes));

      if Raw_Bytes > 0 and then Comp_Bytes <= Raw_Bytes then
         Savings := 100 - (Comp_Bytes * 100) / Raw_Bytes;
      end if;

      Append_Numeric_Param (Msg_Buf, Msg_Len, WID_BANDWIDTH_BAR,
                            Word32 (Savings));
      Append_Numeric_Param (Msg_Buf, Msg_Len, WID_ACTIVE_ALGO,
                            Word32 (Algo_ID));
      Append_Numeric_Param (Msg_Buf, Msg_Len, WID_TURBO_ACCURACY,
                            Word32 (Turbo_Acc));

      Finalize_A661_Message (Msg_Buf, Msg_Len);
   end Build_A661_Telemetry_Frame;

end ARINC661_Protocol;
