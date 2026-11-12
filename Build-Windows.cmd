@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\build-windows.ps1" -Run
if errorlevel 1 (
  echo.
  echo Build did not complete. Read the error above; no working release is claimed.
  pause
  exit /b 1
)
