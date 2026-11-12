@echo off
setlocal
set "lifeos_release=%~dp0build\windows\x64\runner\Release"
if not exist "%lifeos_release%\lifeos.exe" (
  echo LifeOS has not been built here yet. Run Build-Windows.cmd first.
  pause
  exit /b 1
)
start "" /D "%lifeos_release%" "%lifeos_release%\lifeos.exe"
