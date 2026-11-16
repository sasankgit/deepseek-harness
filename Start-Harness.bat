@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Harness.ps1"
exit /b %ERRORLEVEL%
