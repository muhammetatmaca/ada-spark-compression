with Ada.Text_IO;         use Ada.Text_IO;
with Interfaces;          use Interfaces;
with Tactical_Types;     use Tactical_Types;
with Tactical_Container; use Tactical_Container;

procedure Tactical_Folder_Test is
   Dir_In       : constant String :=
     "C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio";
   Arch_Out     : constant String :=
     "C:\Users\muham\Desktop\Muhammet-Atmaca-Portfolio.tact";
   Dir_Extract  : constant String :=
     "C:\Users\muham\Desktop\portfolio_verified";

   Total_Raw    : Word32;
   Total_Comp   : Word32;
   N_Files      : Natural;
   Extr_Count   : Natural;
   Stat         : Container_Status;
begin
   Put_Line ("========================================================");
   Put_Line ("  STANAG-MIL TACTICAL KLASOR ARSIVLEME & SIKISTIRMA     ");
   Put_Line ("  HEDEF KLASOR : " & Dir_In);
   Put_Line ("  CIKTI ARSIVI : " & Arch_Out);
   Put_Line ("========================================================");

   --  1. Klasörü Sıkıştır ve .tact Arşivine Paketle
   Archive_Directory
     (Dir_Path     => Dir_In,
      Archive_Path => Arch_Out,
      Total_Raw    => Total_Raw,
      Total_Comp   => Total_Comp,
      File_Count   => N_Files,
      Status       => Stat);

   if Stat /= Success then
      Put_Line ("[-] Hata: Klasor arsivleme basarisiz: " &
                Container_Status'Image (Stat));
      return;
   end if;

   Put_Line ("[+] Arsivlenen Dosya Sayisi : " & Natural'Image (N_Files));
   Put_Line ("[+] Toplam Ham Boyut        : " & Word32'Image (Total_Raw) &
             " bayt (" & Natural'Image (Natural (Total_Raw / 1024)) & " KB)");
   Put_Line ("[+] Toplam Sikistirilmis    : " & Word32'Image (Total_Comp) &
             " bayt (" & Natural'Image (Natural (Total_Comp / 1024)) & " KB)");

   if Total_Raw > 0 then
      Put_Line ("[+] Sikistirma Orani        : " &
                Natural'Image (Natural (Total_Raw / Total_Comp)) & ":1 (" &
                Natural'Image (100 - Natural (Total_Comp * 100 / Total_Raw)) &
                "% Tasarruf)");
   end if;

   Put_Line ("[+] STANAG Konteyner        : " & Arch_Out & " OLUSTURULDU.");
   Put_Line ("");
   Put_Line ("--- %100 BIT-EXACT GERI ACMA VE CRC-32 DOGRULAMA TESTI ---");

   --  2. Arşivi Geri Aç ve CRC-32 Kontrolü Yap
   Extract_Directory
     (Archive_Path => Arch_Out,
      Target_Dir   => Dir_Extract,
      File_Count   => Extr_Count,
      Status       => Stat);

   if Stat = Success then
      Put_Line ("[+] Geri Acilan Dosya Sayisi: " &
                Natural'Image (Extr_Count));
      Put_Line ("[+] CRC-32 Butunluk Denetimi: TUM DOSYALARDA %100 BASARILI.");
      Put_Line ("[+] Dogrulama Dizini        : " & Dir_Extract);
      Put_Line
        ("[+] %100 Kayipsiz (Bit-Exact) Klasor Restorasyonu Onaylandi.");
   else
      Put_Line ("[-] Hata: Geri acma veya CRC hatasi: " &
                Container_Status'Image (Stat));
   end if;

   Put_Line ("========================================================");
end Tactical_Folder_Test;
