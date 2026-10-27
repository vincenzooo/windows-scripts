# FreezeExplorerUntilDrive.ps1
# Sospende SOLO i processi "explorer.exe" che sono figli del processo explorer "shell" (finestre cartelle),
# aspetta Google Drive pronto, poi li riprende e forza un refresh.

$PsSuspend = "C:\ScriptsVC\PsSuspend.exe"
if (-not (Test-Path $PsSuspend)) { exit 1 }

$timeoutSeconds = 180
$pollSeconds    = 2

# Processi tipici di Google Drive for desktop
$driveProcessNames = @("GoogleDriveFS", "GoogleDrive")

# Se Drive monta una lettera, mettila qui (consigliato). Altrimenti lascia $null
# $readyPath = "G:\"   # <-- cambia o metti $null

# Trova explorer.exe "figli" (tipicamente quelli delle finestre cartelle quando è abilitato il processo separato)
$procs = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" |
         Select-Object ProcessId, ParentProcessId

$pidSet = @($procs.ProcessId)
$childExplorerPids = $procs |
    Where-Object { $pidSet -contains $_.ParentProcessId } |
    Select-Object -ExpandProperty ProcessId -Unique

if (-not $childExplorerPids -or $childExplorerPids.Count -eq 0) {
    # Non c'è un processo separato per le finestre cartelle (o nessuna finestra aperta)
    exit 0
}

# Sospendi le finestre cartelle (non il desktop/taskbar)
foreach ($pid in $childExplorerPids) {
    & $PsSuspend -accepteula $pid | Out-Null
}

# Aspetta che Google Drive sia pronto (processo + opzionale path montato)
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
    $driveUp = Get-Process -Name $driveProcessNames -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($driveUp) {
        if (-not $readyPath -or (Test-Path $readyPath)) { break }
    }
    Start-Sleep -Seconds $pollSeconds
}

# Riprendi le finestre cartelle
foreach ($pid in $childExplorerPids) {
    & $PsSuspend -r $pid | Out-Null
}

# (Opzionale ma utile) forza refresh delle finestre già aperte
try {
    $shell = New-Object -ComObject Shell.Application
    foreach ($w in @($shell.Windows())) {
        try {
            if ($w.FullName -and $w.FullName.ToLower().EndsWith("\explorer.exe")) {
                $w.Refresh()
            }
        } catch {}
    }
} catch {}
# Fine FreezeExplorerUntilDrive.ps1