Scriptname ANDR_KO_Quest_MCMScript extends MCM_ConfigBase

; Global Variables ---------------------------------------
GlobalVariable Property ANDR_KO_GLOB_RecoverHours Auto					; fRecoverHours
GlobalVariable Property ANDR_KO_GLOB_DownHealthTreshold Auto			; fDownHealthTreshold
GlobalVariable Property ANDR_KO_GLOB_AllowNotifications Auto			; bAllowNotifications
GlobalVariable Property ANDR_KO_GLOB_NotOnlyTeamMates Auto				; bNotOnlyTeamMates
GlobalVariable Property ANDR_KO_GLOB_RescueGenericNPCs Auto			; bRescueGenericNPCs, read by the SKSE plugin

; Not bound in the plugin: resolved on first use
GlobalVariable Function GetRescueGenericNPCs()
   If ANDR_KO_GLOB_RescueGenericNPCs == None
      ANDR_KO_GLOB_RescueGenericNPCs = Game.GetFormFromFile(0xFB7, "Death Timer - Immersive Bleedout.esp") As GlobalVariable
   EndIf
   Return ANDR_KO_GLOB_RescueGenericNPCs
EndFunction

;--- Functions ------------------------------------------------------------

; Returns version of this script.
Int Function GetVersion()
   return 1 ;MCM Helper
EndFunction

; Event raised when a config menu is first initialized.
Event OnConfigInit()
   parent.OnConfigInit()
   LoadSettings()
EndEvent

; Event raised when an MCM setting is changed.
Event OnSettingChange(string a_ID)
   parent.OnSettingChange(a_ID)

   If (a_ID == "fRecoverHours:General")
      ANDR_KO_GLOB_RecoverHours.SetValue(GetModSettingFloat(a_ID))

   ElseIf (a_ID == "bAllowNotifications:General")
      ANDR_KO_GLOB_AllowNotifications.SetValue(GetModSettingBool(a_ID) As Int)

   ElseIf (a_ID == "bRescueGenericNPCs:General")
      GetRescueGenericNPCs().SetValue(GetModSettingBool(a_ID) As Int)

   EndIf
EndEvent

; Event raised when a new page is selected, including the initial empty page.
Event OnPageSelect(string a_page)
   parent.OnPageSelect(a_page)
EndEvent

; Event raised when a config menu is opened.
Event OnConfigOpen()
   parent.OnConfigOpen()
EndEvent

Event OnGameReload()
   parent.OnGameReload()
   Utility.Wait(1.0)
   self.LoadSettings()
EndEvent

Function LoadSettings()
   SetModSettingFloat("fRecoverHours:General", ANDR_KO_GLOB_RecoverHours.GetValue() As Int)
   SetModSettingBool("bAllowNotifications:General", ANDR_KO_GLOB_AllowNotifications.GetValue() As Int)
   ; The menu checkbox is the source of truth here (the other way round, the save's value could
   ; overwrite a checkbox the player had ticked and leave the two out of sync)
   GetRescueGenericNPCs().SetValue(GetModSettingBool("bRescueGenericNPCs:General") As Int)
   ; No longer a menu option: always on. Non-followers must still be knocked out for the
   ; two-path design (protected non-followers take the knocked-out path), and this also resets
   ; saves where the old toggle had been switched off.
   ANDR_KO_GLOB_NotOnlyTeamMates.SetValue(1)
   ; No longer a menu option: fixed at 10 (health a knocked-out NPC may drift up to before being pinned
   ; back to 0.5). Also resets saves where the old slider had been changed.
   ANDR_KO_GLOB_DownHealthTreshold.SetValue(10.0)
EndFunction