!macro NSIS_HOOK_POSTINSTALL
  CreateShortcut "$DESKTOP\Looma.lnk" "$INSTDIR\Looma.exe" "" "$INSTDIR\Looma.exe" 0
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  Delete "$DESKTOP\Looma.lnk"
!macroend
