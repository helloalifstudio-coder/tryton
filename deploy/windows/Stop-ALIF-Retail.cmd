@echo off
setlocal
set "SCRIPT=%~dp0Stop-AlifRetail.ps1"
if not exist "%SCRIPT%" (
  echo ALIF Retail shutdown script was not found.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
if errorlevel 1 (
  echo.
  echo ALIF Retail services could not be stopped. Review the error above.
  pause
  exit /b 1
)
endlocal
