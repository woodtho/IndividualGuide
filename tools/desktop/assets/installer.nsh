; NSIS supplies the shared French installer controls. The explicit choice and
; application preference are Canadian French (fr-CA), not a browser OS guess.
!include FileFunc.nsh

!macro customHeader
  !define /redef MUI_LANGDLL_WINDOWTITLE "Individual Guide - Language / Langue"
  !define /redef MUI_LANGDLL_INFO "Choose your language / Choisissez votre langue"
  !define /redef MUI_LANGDLL_ALWAYSSHOW
  !define /redef MUI_LANGDLL_ALLLANGUAGES
  !define /redef MUI_LANGDLL_LANGUAGES `"English" "${LANG_ENGLISH}" "Français (Canada)" "${LANG_FRENCH}" `
  LangString igLanguageSaveFailed ${LANG_ENGLISH} "The language choice could not be saved. Please run Setup again."
  LangString igLanguageSaveFailed ${LANG_FRENCH} "Impossible d'enregistrer la langue choisie. Veuillez relancer le programme d'installation."
!macroend

!macro customInit
  ; Documented unattended-install option; interactive installs show the chooser.
  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/LANG=" $1
  ${IfNot} ${Errors}
    ${If} $1 == "fr-CA"
      StrCpy $LANGUAGE ${LANG_FRENCH}
    ${ElseIf} $1 == "en-CA"
      StrCpy $LANGUAGE ${LANG_ENGLISH}
    ${EndIf}
  ${EndIf}
!macroend

!macro customInstall
  ; Background updates must preserve the user's later in-app language choice.
  ${If} ${Silent}
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/LANG=" $1
    ${If} ${Errors}
      Goto ig_language_done
    ${EndIf}
  ${EndIf}
  StrCpy $2 "en-CA"
  ${If} $LANGUAGE == ${LANG_FRENCH}
    StrCpy $2 "fr-CA"
  ${EndIf}
  ; A new installation gets a new preference revision. Later in-app choices
  ; persist until another interactive installation explicitly chooses a language.
  System::Call 'kernel32::GetTickCount() i .r0'
  ClearErrors
  FileOpen $1 "$INSTDIR\installation-language.json" w
  ${If} ${Errors}
    MessageBox MB_OK|MB_ICONSTOP "$(igLanguageSaveFailed)"
    Abort
  ${EndIf}
  FileWrite $1 '{$\"locale$\":$\"$2$\",$\"installation$\":$\"${VERSION}-$0$\"}'
  FileClose $1
  ig_language_done:
!macroend
