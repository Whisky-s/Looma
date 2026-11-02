!macro NSIS_HOOK_POSTINSTALL
  CreateShortcut "$DESKTOP\Looma.lnk" "$INSTDIR\Looma.exe"
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  Delete "$DESKTOP\Looma.lnk"
!macroend
