$ErrorActionPreference = 'Stop'

$mutex = New-Object System.Threading.Mutex($false, 'Local\DeepSeekHarnessTrayMonitor')
$ownsMutex = $false
try { $ownsMutex = $mutex.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $ownsMutex = $true }
if (-not $ownsMutex) {
    $mutex.Dispose()
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:root = $PSScriptRoot
$script:urlFile = Join-Path $PSScriptRoot '.dsh\web-url.txt'
$script:startScript = Join-Path $PSScriptRoot 'Start-Harness.ps1'
$script:stopScript = Join-Path $PSScriptRoot 'Stop-Harness.ps1'
$script:statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:openItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Open Harness'
$script:startItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Start Harness'
$script:stopItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Stop Harness'
$script:exitItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Exit tray monitor'
$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:menu = New-Object System.Windows.Forms.ContextMenuStrip
$script:timer = New-Object System.Windows.Forms.Timer
$script:currentUrl = $null

function Get-RunningHarnessUrl {
    if (-not (Test-Path -LiteralPath $script:urlFile)) { return $null }
    $url = (Get-Content -LiteralPath $script:urlFile -Raw).Trim()
    if ($url -notmatch '^http://127\.0\.0\.1:3081/\?token=[A-Za-z0-9_-]+$') { return $null }

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1', 3081)
        return $url
    }
    catch [System.Net.Sockets.SocketException] {
        return $null
    }
    finally {
        $client.Dispose()
    }
}

function Update-HarnessTrayState {
    $url = Get-RunningHarnessUrl
    $script:currentUrl = $url
    $isRunning = [bool]$url
    if ($isRunning) {
        $script:statusItem.Text = 'DeepSeek Harness: Running'
        $script:notifyIcon.Text = 'DeepSeek Harness is running'
        $script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
    }
    else {
        $script:statusItem.Text = 'DeepSeek Harness: Stopped'
        $script:notifyIcon.Text = 'DeepSeek Harness is stopped'
        $script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
    }
    $script:openItem.Enabled = $isRunning
    $script:stopItem.Enabled = $isRunning
    $script:startItem.Enabled = -not $isRunning
}

$script:menu.Items.Add($script:statusItem) | Out-Null
$script:menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$script:menu.Items.Add($script:openItem) | Out-Null
$script:menu.Items.Add($script:startItem) | Out-Null
$script:menu.Items.Add($script:stopItem) | Out-Null
$script:menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$script:menu.Items.Add($script:exitItem) | Out-Null
$script:notifyIcon.Text = 'DeepSeek Harness status'
$script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:notifyIcon.ContextMenuStrip = $script:menu
$script:notifyIcon.Visible = $true
$script:timer.Interval = 2000
$script:timer.Add_Tick({ Update-HarnessTrayState })

$script:openItem.Add_Click({
    if ($script:currentUrl) { Start-Process $script:currentUrl }
})

$script:startItem.Add_Click({
    $powershell = (Get-Command powershell.exe).Source
    $arguments = '-NoProfile -NoExit -ExecutionPolicy Bypass -File "' + $script:startScript + '"'
    Start-Process -FilePath $powershell -ArgumentList $arguments
})

$script:stopItem.Add_Click({
    try {
        $powershell = (Get-Command powershell.exe).Source
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:stopScript + '"'
        $stopProcess = Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        if ($stopProcess.ExitCode -ne 0) { throw "Stop script exited with code $($stopProcess.ExitCode)." }
        Update-HarnessTrayState
    }
    catch {
        $script:notifyIcon.BalloonTipTitle = 'DeepSeek Harness'
        $script:notifyIcon.BalloonTipText = "Could not stop Harness: $($_.Exception.Message)"
        $script:notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
        $script:notifyIcon.ShowBalloonTip(5000)
    }
})

$script:exitItem.Add_Click({
    $script:timer.Stop()
    $script:notifyIcon.Visible = $false
    $script:notifyIcon.Dispose()
    $script:menu.Dispose()
    [System.Windows.Forms.Application]::ExitThread()
})

try {
    Update-HarnessTrayState
    $script:timer.Start()
    [System.Windows.Forms.Application]::Run()
}
finally {
    $script:timer.Dispose()
    $script:notifyIcon.Visible = $false
    $script:notifyIcon.Dispose()
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
