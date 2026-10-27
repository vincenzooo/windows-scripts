<#
.SYNOPSIS
    Genera uno snapshot della struttura di una directory.

.DESCRIPTION
    Lo script analizza ricorsivamente una directory e genera due file:

    1. <Output>_table.txt
       Tabella TSV (colonne separate da TAB) contenente:
       - Percorso relativo
       - Nome file
       - Dimensione in byte
       - Data di creazione
       - Data dell'ultima modifica

    2. <Output>_tree.txt
       Rappresentazione gerarchica delle cartelle e dei file,
       incluse le cartelle vuote.

    La directory originale non viene modificata.

    Se uno qualsiasi dei file di output esiste già, lo script
    termina senza scrivere nulla, a meno che sia specificato -f.

    ATTENZIONE:
    - I file nascosti e di sistema possono non essere inclusi.
    - Le cartelle vuote compaiono nell'albero ma non nella tabella.
    - Se l'output si trova nella directory analizzata, eventuali
      snapshot precedenti potrebbero essere inclusi nell'elenco.
    - La generazione dei due file non è atomica: un'interruzione
      potrebbe lasciare un output incompleto.

.PARAMETER c
    Commento facoltativo da inserire nella prima riga
    di entrambi i file di output.
    Alias: -Comment

    La prima riga contiene sempre:
    TIMESTAMP yyyy-MM-dd HH:mm:ss | nome_script.ps1

    Se specificato, viene aggiunto:
    | commento

.PARAMETER Root
    Directory da analizzare ricorsivamente.
    Default: directory corrente (.)

.PARAMETER Output
    Percorso e nome base dei file generati, senza estensione.
    Default: snapshot nella directory corrente.

    Esempio:
        C:\Backup\archivio

    Genera:
        C:\Backup\archivio_table.txt
        C:\Backup\archivio_tree.txt

.PARAMETER f
    Forza la sovrascrittura dei file di output esistenti.
    Alias: -Force

    Senza questo flag, lo script termina con errore se almeno
    uno dei due file di output esiste già.

.PARAMETER t
    Aggiunge un timestamp al nome dei file di output.
    Alias: -Timestamp

    Formato del suffisso: _YYMMDD_HHMMSS

    Esempio:
        snapshot_table_261027_104530.txt
        snapshot_tree_261027_104530.txt

    Il timestamp è identico per entrambi i file ed è
    lo stesso riportato nella prima riga.

    Se il parametro non è specificato, i nomi rimangono:
        snapshot_table.txt
        snapshot_tree.txt

.PARAMETER Help
    Visualizza una guida sintetica ed esce senza eseguire lo snapshot.
    Alias: -h

.EXAMPLE
    .\take_snapshot.ps1

    Analizza la directory corrente e genera:
    snapshot_table.txt e snapshot_tree.txt

.EXAMPLE
    .\take_snapshot.ps1 "D:\Documenti"

    Analizza D:\Documenti e salva i risultati nella directory corrente.

.EXAMPLE
    .\take_snapshot.ps1 "D:\Documenti" "C:\Backup\documenti_2026"

    Specifica directory di origine e nome base completo di output.

.EXAMPLE
    .\take_snapshot.ps1 "D:\Documenti" "C:\Backup\documenti_2026" -f

    Come sopra, ma sovrascrive eventuali output esistenti.

.EXAMPLE
    .\take_snapshot.ps1 -h

    Visualizza la guida sintetica.

.EXAMPLE
    Get-Help .\take_snapshot.ps1 -Full

    Mostra la documentazione completa di PowerShell.

.NOTES
    Compatibile con Windows PowerShell 5.1 e PowerShell 7.
    Richiede il comando TREE di Windows.
#>

param(
    [Parameter(Position=0)]
    [string]$Root = ".",

    [Parameter(Position=1)]
    [string]$Output = "snapshot",

    [Alias("Force")]
    [switch]$f,

    [Alias("Comment")]
    [string]$c = "",

    [Alias("Timestamp")]
    [switch]$t,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Help sintetico
if ($Help) {
    Write-Host @"
USO:
    .\take_snapshot.ps1 [Root] [Output] [-f] [-c "Commento"] [-h]

PARAMETRI:
    Root     Directory da analizzare (default: directory corrente)
    Output   Percorso e nome base (default: snapshot)
    -c TEXT  Aggiunge un commento all'intestazione (alias: -Comment), include timestamp
    -f       Sovrascrive gli output esistenti (alias: -Force)
    -t       Aggiunge timestamp ai nomi dei file (_YYMMDD_HHMMSS)
    -h       Mostra questo help (alias: -Help)

OUTPUT:
    <Output>_table.txt    Tabella delimitata da TAB
    <Output>_tree.txt     Albero di cartelle e file

ESEMPI:
    .\take_snapshot.ps1
    .\take_snapshot.ps1 "D:\Dati"
    .\take_snapshot.ps1 "D:\Dati" "C:\Backup\dati"
    .\take_snapshot.ps1 "D:\Dati" "C:\Backup\dati" -f
    .\take_snapshot.ps1 "D:\Dati" "C:\Backup\dati" -t
    .\take_snapshot.ps1 "D:\Dati" "C:\Backup\dati" -c "# Situazione al 27 ottobre"

DOCUMENTAZIONE COMPLETA:
    Get-Help .\take_snapshot.ps1 -Full
"@
    exit 0
}

# Verifica e risolve la directory di origine
$Root = (Resolve-Path -LiteralPath $Root).Path

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Root non è una directory: $Root"
}

# Rimuove il separatore finale, eccetto per radici come C:\
$Root = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
$rootPrefix = $Root.TrimEnd('\') + '\'

# Risolve il nome base di output
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)

$outputDir = Split-Path -Path $Output -Parent
$outputName = Split-Path -Path $Output -Leaf

if ([string]::IsNullOrWhiteSpace($outputName)) {
    throw "Nome di output non valido."
}

# Acquisisce un unico timestamp per entrambi i file
$now = Get-Date
$timestamp = $now.ToString("yyyy-MM-dd HH:mm:ss")

# Suffisso opzionale per i nomi dei file
$timeSuffix = ""

if ($t) {
    $timeSuffix = "_" + $now.ToString("yyMMdd_HHmmss")
}

$tableFile = Join-Path $outputDir "${outputName}_table${timeSuffix}.txt"
$treeFile  = Join-Path $outputDir "${outputName}_tree${timeSuffix}.txt"

# Verifica preventiva dei file già esistenti
$existingFiles = @($tableFile, $treeFile) |
    Where-Object { Test-Path -LiteralPath $_ }

if ($existingFiles.Count -gt 0 -and -not $f) {
    throw (
        "File di output già esistenti:`n" +
        ($existingFiles -join "`n") +
        "`nUsare -f per autorizzare la sovrascrittura."
    )
}

# Crea la directory di destinazione
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# Genera intestazione comune ai due file
$scriptName = Split-Path -Leaf $PSCommandPath

$header = "# TIMESTAMP $timestamp | $scriptName"

if (-not [string]::IsNullOrWhiteSpace($c)) {
    $header += " | $c"
}

# Genera tabella TSV con intestazione personalizzata
$header | Out-File -LiteralPath $tableFile -Encoding UTF8

Get-ChildItem -LiteralPath $Root -Recurse -File |
    Select-Object @{
        Name = "PercorsoRelativo"
        Expression = {
            $_.FullName.Substring($rootPrefix.Length)
        }
    }, Name, Length, CreationTime, LastWriteTime |
    ConvertTo-Csv -Delimiter "`t" -NoTypeInformation |
    Out-File -LiteralPath $tableFile -Append -Encoding UTF8

# Genera struttura ad albero con intestazione
$header | Out-File -LiteralPath $treeFile -Encoding UTF8

cmd /c tree "$Root" /F /A |
    Out-File -LiteralPath $treeFile -Append -Encoding UTF8

Write-Host "Snapshot completato."
Write-Host "Tabella: $tableFile"
Write-Host "Albero:  $treeFile"