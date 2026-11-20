@echo off
setlocal
set "SCRIPT=%~dp0Start-AlifRetail.ps1"
if not exist "%SCRIPT%" (
  echo ALIF Retail launcher script was not found.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -LaunchClient
if errorlevel 1 (
  echo.
  echo ALIF Retail did not start. Review the error above.
  pause
  exit /b 1
)
endlocal
