@echo off
setlocal

rem Find and stop the Harness web process directly; this batch file does not call Stop-Harness.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root='%~dp0'; $urlFile=Join-Path $root '.dsh\web-url.txt'; $servers=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^node(?:\.exe)?$' -and $_.CommandLine -match '(?i)apps[\\/]cli[\\/]src[\\/]bin\.ts' -and $_.CommandLine -match '(?i)\bweb\b' -and $_.CommandLine -match '(?i)--port\s+3081' }); if ($servers.Count -eq 0) { if (Test-Path -LiteralPath $urlFile) { Remove-Item -LiteralPath $urlFile -Force }; Write-Host 'The Harness server is already stopped.'; exit 0 }; $taskkill=Join-Path $env:SystemRoot 'System32\taskkill.exe'; foreach ($server in $servers) { Write-Host ('Stopping Harness server PID ' + $server.ProcessId + ' and its child processes...'); & $taskkill /PID $server.ProcessId /T /F; if ($LASTEXITCODE -ne 0) { throw ('Could not stop Harness server PID ' + $server.ProcessId + ' (taskkill exit code ' + $LASTEXITCODE + ').') } }; if (Test-Path -LiteralPath $urlFile) { Remove-Item -LiteralPath $urlFile -Force }; Write-Host 'Harness server and its child processes were stopped.'"
set "exitCode=%ERRORLEVEL%"
if not "%exitCode%"=="0" pause
exit /b %exitCode%
