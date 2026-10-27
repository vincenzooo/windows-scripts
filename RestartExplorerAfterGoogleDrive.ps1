# RestartExplorerAfterGoogleDrive.ps1
# Aspetta che Google Drive for desktop sia attivo, poi riavvia explorer.exe

$timeoutSeconds = 120
$pollSeconds    = 2

# Nomi processo tipici (dipende dalla versione): GoogleDriveFS.exe è molto comune
$processNames   = @("GoogleDriveFS", "GoogleDrive")  # senza ".exe"

# (Opzionale) Se vuoi aspettare anche un percorso specifico, mettilo qui, es:
$readyPath = "G:\My Drive"
# oppure lascia $null per aspettare solo il processo
#$readyPath = $null

$sw = [Diagnostics.Stopwatch]::StartNew()

while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
    $found = $false

    foreach ($name in $processNames) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { $found = $true; break }
    }

    if ($found) {
        if (-not $readyPath -or (Test-Path $readyPath)) { break }
    }

    Start-Sleep -Seconds $pollSeconds
}

# Riavvia Explorer (shell + finestre + taskbar)
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Start-Process explorer.exe
