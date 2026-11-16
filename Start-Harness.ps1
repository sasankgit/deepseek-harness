$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$env:DSH_HOME = Join-Path $root '.dsh'
$env:PATH = (Join-Path $root 'tools') + ';' + $env:PATH
$urlFile = Join-Path $env:DSH_HOME 'web-url.txt'
$trayScript = Join-Path $root 'Tray-Harness.ps1'

if (-not (Test-Path -LiteralPath $trayScript)) {
    throw "Harness tray monitor not found: $trayScript"
}
$powershellExe = (Get-Command powershell.exe).Source
$trayArguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $trayScript + '"'
Start-Process -FilePath $powershellExe -ArgumentList $trayArguments -WindowStyle Hidden | Out-Null

$listener = New-Object System.Net.Sockets.TcpClient
$portIsBusy = $false
try {
    $listener.Connect('127.0.0.1', 3081)
    $portIsBusy = $true
}
catch [System.Net.Sockets.SocketException] {
    $portIsBusy = $false
}
finally {
    $listener.Dispose()
}

if ($portIsBusy) {
    if (Test-Path -LiteralPath $urlFile) {
        $existingUrl = (Get-Content -LiteralPath $urlFile -Raw).Trim()
        if ($existingUrl -match '^http://127\.0\.0\.1:3081/\?token=[A-Za-z0-9_-]+$') {
            try {
                Invoke-WebRequest -Uri $existingUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
                Write-Host "Harness is already running: $existingUrl"
                Start-Process $existingUrl
                exit 0
            }
            catch {
                throw "Port 3081 is occupied, but the recorded Harness URL did not respond: $($_.Exception.Message)"
            }
        }
    }
    throw "Port 3081 is already in use and no valid Harness URL is recorded in $urlFile."
}

$pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmCommand) {
    $pnpmFallback = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\fallback'
    if (Test-Path -LiteralPath (Join-Path $pnpmFallback 'pnpm.cmd')) {
        $env:PATH = $pnpmFallback + ';' + $env:PATH
        $pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
    }
}
if (-not $pnpmCommand) {
    throw 'pnpm was not found. Install pnpm or add it to PATH, then relaunch the harness.'
}

$env:LM_STUDIO_API_KEY = if ($env:LM_STUDIO_API_KEY) { $env:LM_STUDIO_API_KEY } else { 'lm-studio' }

$firecrawlFile = Join-Path $root 'firecrawl.env'
if (-not (Test-Path -LiteralPath $firecrawlFile)) {
    throw "Firecrawl key file missing: $firecrawlFile"
}
$firecrawlKey = (Get-Content -LiteralPath $firecrawlFile -Raw).Trim()
if ($firecrawlKey -match '^(?:FIRECRAWL_API_KEY|FIRECRAWL_KEY)=(.*)$') {
    $firecrawlKey = $Matches[1].Trim().Trim('"').Trim("'")
}
if (-not $firecrawlKey.StartsWith('fc-')) {
    throw 'firecrawl.env must contain a Firecrawl API key, either as a raw value or FIRECRAWL_API_KEY=value.'
}
$env:FIRECRAWL_API_KEY = $firecrawlKey

if (-not $env:NGROK_API_KEY) {
    $ngrokFile = Join-Path $root 'ngrok.env'
    if (Test-Path -LiteralPath $ngrokFile) {
        $ngrokKey = (Get-Content -LiteralPath $ngrokFile -Raw).Trim()
        if ($ngrokKey -match '^NGROK_API_KEY=(.*)$') {
            $ngrokKey = $Matches[1].Trim().Trim('"').Trim("'")
        }
        if ($ngrokKey) { $env:NGROK_API_KEY = $ngrokKey }
    }
}

Push-Location $root
try {
    & $pnpmCommand.Source dsh web --port 3081 2>&1 | ForEach-Object {
        $line = "$_"
        Write-Output $line
        if ($line -match '(http://127\.0\.0\.1:3081/\?token=[A-Za-z0-9_-]+)') {
            [System.IO.File]::WriteAllText($urlFile, $Matches[1])
        }
    }
    $launcherExitCode = $LASTEXITCODE
    if ($launcherExitCode -ne 0) { exit $launcherExitCode }
}
finally {
    Pop-Location
}
