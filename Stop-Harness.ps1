$ErrorActionPreference = 'Stop'

$env:DSH_HOME = Join-Path $PSScriptRoot '.dsh'
$urlFile = Join-Path $env:DSH_HOME 'web-url.txt'
$port = 3081
$serverPids = @(
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
)

if ($serverPids.Count -eq 0) {
    if (Test-Path -LiteralPath $urlFile) {
        Remove-Item -LiteralPath $urlFile -Force
    }
    Write-Host 'The Harness server is already stopped.'
    exit 0
}

$harnessPids = @()
foreach ($serverProcessId in $serverPids) {
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$serverProcessId" -ErrorAction SilentlyContinue
    $commandLine = [string]$processInfo.CommandLine
    $isHarnessCommand = $processInfo.Name -match '^node(?:\.exe)?$' -and
        $commandLine -match '(?i)apps[\\/]cli[\\/]src[\\/]bin\.ts' -and
        $commandLine -match '(?i)(^|\s|["''])web(["'']|\s|$)' -and
        $commandLine -match '(?i)(--port\s+["'']?3081|3081["'']?)'

    if ($isHarnessCommand) {
        $harnessPids += [int]$serverProcessId
        continue
    }

    $urlIsAuthenticated = $false
    if (Test-Path -LiteralPath $urlFile) {
        $harnessUrl = (Get-Content -LiteralPath $urlFile -Raw).Trim()
        if ($harnessUrl -match '^http://127\.0\.0\.1:3081/\?token=[A-Za-z0-9_-]+$') {
            try {
                Invoke-WebRequest -Uri $harnessUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
                $urlIsAuthenticated = $true
            }
            catch {
                $urlIsAuthenticated = $false
            }
        }
    }

    if ($urlIsAuthenticated) {
        $harnessPids += [int]$serverProcessId
        continue
    }

    $name = if ($processInfo) { $processInfo.Name } else { 'unknown process' }
    throw "Port $port is owned by PID $serverProcessId ($name), but it could not be verified as DeepSeek Harness. No process was stopped."
}

if ($harnessPids.Count -eq 0) {
    Write-Host 'No verified Harness server was found; nothing was stopped.'
    exit 0
}

$taskkill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
foreach ($harnessProcessId in ($harnessPids | Select-Object -Unique)) {
    $process = Get-Process -Id $harnessProcessId -ErrorAction Stop
    Write-Host "Stopping Harness server PID $harnessProcessId ($($process.ProcessName)) and its child processes..."
    & $taskkill /PID $harnessProcessId /T /F | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Could not stop Harness server PID $harnessProcessId (taskkill exit code $LASTEXITCODE)."
    }
}

if (Test-Path -LiteralPath $urlFile) {
    Remove-Item -LiteralPath $urlFile -Force
}
Write-Host 'Harness server and its child processes were stopped. LM Studio remains running.'
