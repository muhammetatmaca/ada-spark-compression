with Interfaces;    use Interfaces;
with Tactical_Types; use Tactical_Types;

package ARINC661_Protocol with SPARK_Mode => On is

   subtype Word16 is Interfaces.Unsigned_16;

   --  ARINC 661 Standart Komut ve Olay Tanimlayicilari
   A661_CMD_SET_PARAMETER : constant Word16 := 16#D001#;
   A661_EVT_SELECTION     : constant Word16 := 16#2001#;

   --  ARINC 661 Standart Parametre Kimlikleri (Parameter IDs)
   A661_PARAM_VALUE   : constant Word16 := 16#0001#;
   A661_PARAM_STRING  : constant Word16 := 16#0002#;
   A661_PARAM_VISIBLE : constant Word16 := 16#0003#;

   --  Definition File (tactical_mfd_df.xml) Widget Kimlikleri
   WID_HEADER_TITLE      : constant Word16 := 1001;
   WID_STANAG_MAGIC      : constant Word16 := 1002;
   WID_CRC_STATUS        : constant Word16 := 1003;
   WID_SCRUB_STATUS      : constant Word16 := 1004;

   WID_ACTIVE_ALGO       : constant Word16 := 2001;
   WID_RAW_BYTES         : constant Word16 := 2002;
   WID_COMP_BYTES        : constant Word16 := 2003;
   WID_COMP_RATIO        : constant Word16 := 2004;
   WID_BANDWIDTH_BAR     : constant Word16 := 2005;
   WID_TURBO_ACCURACY    : constant Word16 := 2006;
   WID_LAYA_BOTTLENECK   : constant Word16 := 2007;

   WID_BTN_ALGO_1        : constant Word16 := 3001;
   WID_BTN_ALGO_3        : constant Word16 := 3002;
   WID_BTN_ALGO_4        : constant Word16 := 3003;
   WID_BTN_ALGO_5        : constant Word16 := 3004;
   WID_BTN_ALGO_6        : constant Word16 := 3005;
   WID_BTN_ALGO_7        : constant Word16 := 3006;
   WID_BTN_ALGO_8        : constant Word16 := 3007;
   WID_BTN_ZEROIZE       : constant Word16 := 3008;

   --  1. ARINC 661 Ikili Mesajini Baslatma (Header: Size, App_ID)
   procedure Init_A661_Message
     (Msg_Buf : in out Output_Buffer;
      Msg_Len : out Natural;
      App_ID  : Word16) with
     Post => Msg_Len = 6 and then Msg_Len <= Msg_Buf'Length;

   --  2. Katman Blogu Baslatma (Layer Header)
   procedure Start_Layer
     (Msg_Buf  : in out Output_Buffer;
      Msg_Len  : in out Natural;
      Layer_ID : Word16) with
     Pre  => Msg_Len >= 6 and then Msg_Len <= Msg_Buf'Length - 4,
     Post => Msg_Len = Msg_Len'Old + 4;

   --  3. Sayisal Parametre Guncelleme (Numeric Parameter: e.g. Ratio, Bytes)
   procedure Append_Numeric_Param
     (Msg_Buf   : in out Output_Buffer;
      Msg_Len   : in out Natural;
      Widget_ID : Word16;
      Value     : Word32) with
     Pre  => Msg_Len >= 6 and then Msg_Len <= Msg_Buf'Length - 10,
     Post => Msg_Len = Msg_Len'Old + 10;

   --  4. Metin Parametre Guncelleme (String Parameter: e.g. Status Label)
   procedure Append_String_Param
     (Msg_Buf   : in out Output_Buffer;
      Msg_Len   : in out Natural;
      Widget_ID : Word16;
      Str       : String) with
     Pre  => Msg_Len >= 6
             and then Str'Length <= 32
             and then Msg_Len <= Msg_Buf'Length - (8 + Str'Length),
     Post => Msg_Len = Msg_Len'Old + 8 + Str'Length;

   --  5. Mesaj Boyutunu Sonlandirma (Finalize Length in Header)
   procedure Finalize_A661_Message
     (Msg_Buf : in out Output_Buffer;
      Msg_Len : Natural) with
     Pre => Msg_Len >= 6 and then Msg_Len <= Msg_Buf'Length;

   --  6. Kokpit CDS Buton Olayini Cozme (Parse CDS Event: A661_EVT_SELECTION)
   procedure Parse_A661_Event
     (In_Buf    : Byte_Array;
      In_Len    : Natural;
      Widget_ID : out Word16;
      Event_ID  : out Word16;
      Valid     : out Boolean) with
     Pre => In_Buf'First = 1 and then In_Len <= In_Buf'Length;

   --  7. Tam Taktik Aviyonik Telemetri Cercevesi Olusturma
   procedure Build_A661_Telemetry_Frame
     (Raw_Bytes   : Natural;
      Comp_Bytes  : Natural;
      Algo_ID     : Byte;
      CRC_Valid   : Boolean;
      Turbo_Acc   : Natural;
      Msg_Buf     : in out Output_Buffer;
      Msg_Len     : out Natural);

end ARINC661_Protocol;
