#requires -Version 5.1
<#
.SYNOPSIS
  Reproducible MetaEditor build for AlgoMultiAssetEA.
.DESCRIPTION
  Compiles exactly one MQ5 entry-point file with the MetaEditor installed beside
  the specified AMarkets terminal. Uses a separately specified MQL5 include root,
  captures the source-adjacent MetaEditor log, archives the previous log, validates
  the current compiler summary, and verifies the resulting EX5 timestamp/hash.

  This script does not launch terminal64.exe or MetaTester64.exe.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TerminalInstallRoot = 'C:\Program Files\AMarkets - MetaTrader 5',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectMql5Root = 'C:\Users\Ali\AppData\Roaming\MetaQuotes\Terminal\D0694EE1816B0E3A2D24B3606A663CE8\MQL5',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRelativePath = 'Experts\AlgoMultiAssetEA.mq5',

    # MetaEditor /include expects an MQL5 root (the parent of Include), not the Include folder itself.
    # By default, use the supplied terminal data-folder MQL5 root. Override only after verifying
    # that a different MQL5 root is the intended, version-matched include environment.
    [Parameter()]
    [string]$IncludeMql5Root = '',

    [Parameter()]
    [string]$ArchiveDirectoryRelativePath = 'tools\compile-logs',

    [Parameter()]
    [switch]$SyntaxCheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingDirectory {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label directory does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-VersionSummary {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path
    return [pscustomobject]@{
        Path           = $item.FullName
        FileVersion    = $item.VersionInfo.FileVersion
        ProductVersion = $item.VersionInfo.ProductVersion
        Length         = $item.Length
        LastWriteTime  = $item.LastWriteTime
        SHA256         = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Get-CompileSummary {
    param([AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines)

    $text = $Lines -join "`n"
    $errors = $null
    $warnings = $null
    $summaryFound = $false

    # Current MetaEditor logs commonly include: "Result: N errors, M warnings, ...".
    $resultMatch = [regex]::Match($text, '(?im)\b(\d+)\s+errors?\s*,\s*(\d+)\s+warnings?\b')
    if ($resultMatch.Success) {
        $errors = [int]$resultMatch.Groups[1].Value
        $warnings = [int]$resultMatch.Groups[2].Value
        $summaryFound = $true
    }
    else {
        $errorMatch = [regex]::Match($text, '(?im)^\s*Errors?\s*:\s*(\d+)\s*$')
        $warningMatch = [regex]::Match($text, '(?im)^\s*Warnings?\s*:\s*(\d+)\s*$')
        if ($errorMatch.Success -and $warningMatch.Success) {
            $errors = [int]$errorMatch.Groups[1].Value
            $warnings = [int]$warningMatch.Groups[1].Value
            $summaryFound = $true
        }
    }

    $errorLines = @($Lines | Where-Object { $_ -match '(?i)\berror\s*\d+\b|\berrors?\s*:' })
    $warningLines = @($Lines | Where-Object { $_ -match '(?i)\bwarning\s*\d+\b|\bwarnings?\s*:' })

    # If no summary exists, do not invent a zero-error result. Individual diagnostics
    # provide a lower bound, but the build remains unverified until the summary is found.
    if ($null -eq $errors) { $errors = $errorLines.Count }
    if ($null -eq $warnings) { $warnings = $warningLines.Count }

    return [pscustomobject]@{
        SummaryFound = $summaryFound
        Errors       = [int]$errors
        Warnings     = [int]$warnings
        ErrorLines   = $errorLines
        WarningLines = $warningLines
    }
}

try {
    $TerminalInstallRoot = Resolve-ExistingDirectory -Path $TerminalInstallRoot -Label 'MetaTrader installation'
    $ProjectMql5Root = Resolve-ExistingDirectory -Path $ProjectMql5Root -Label 'Project MQL5 data root'

    $metaEditor = Join-Path $TerminalInstallRoot 'metaeditor64.exe'
    $terminalExe = Join-Path $TerminalInstallRoot 'terminal64.exe'
    $testerExe = Join-Path $TerminalInstallRoot 'metatester64.exe'

    if (-not (Test-Path -LiteralPath $metaEditor -PathType Leaf)) {
        throw "MetaEditor compiler was not found: $metaEditor"
    }
    if (-not (Test-Path -LiteralPath $terminalExe -PathType Leaf)) {
        Write-Warning "terminal64.exe was not found beside MetaEditor: $terminalExe. Compilation can still proceed, but terminal identity cannot be cross-checked here."
    }
    if (-not (Test-Path -LiteralPath $testerExe -PathType Leaf)) {
        Write-Warning "metatester64.exe was not found beside MetaEditor: $testerExe. It is not required for compilation."
    }

    if ([string]::IsNullOrWhiteSpace($IncludeMql5Root)) {
        $IncludeMql5Root = $ProjectMql5Root
    }
    $IncludeMql5Root = Resolve-ExistingDirectory -Path $IncludeMql5Root -Label 'MQL5 include root'

    $includeDirectory = Join-Path $IncludeMql5Root 'Include'
    if (-not (Test-Path -LiteralPath $includeDirectory -PathType Container)) {
        throw "The /include root must contain an Include directory. Expected: $includeDirectory"
    }

    $sourcePath = Join-Path $ProjectMql5Root $SourceRelativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Main MQ5 source was not found: $sourcePath"
    }
    $sourcePath = (Resolve-Path -LiteralPath $sourcePath).Path

    $expectedHistoryHeader = Join-Path $IncludeMql5Root 'Include\Trade\HistoryOrderInfo.mqh'
    if (Test-Path -LiteralPath $expectedHistoryHeader -PathType Leaf) {
        $historyHash = (Get-FileHash -LiteralPath $expectedHistoryHeader -Algorithm SHA256).Hash
    }
    else {
        $historyHash = 'NOT_FOUND'
        Write-Warning "HistoryOrderInfo.mqh was not found under the selected /include root: $expectedHistoryHeader"
    }

    # Compare the selected include copy with the Standard Library shipped beside
    # this MetaEditor. A mismatch is diagnostic evidence, not an automatic repair.
    $installMql5Root = Join-Path $TerminalInstallRoot 'MQL5'
    $installHistoryHeader = Join-Path $installMql5Root 'Include\Trade\HistoryOrderInfo.mqh'
    $installHistoryHash = 'NOT_FOUND'
    if (Test-Path -LiteralPath $installHistoryHeader -PathType Leaf) {
        $installHistoryHash = (Get-FileHash -LiteralPath $installHistoryHeader -Algorithm SHA256).Hash
    }
    $historyCopiesMatch = ($historyHash -ne 'NOT_FOUND' -and $installHistoryHash -ne 'NOT_FOUND' -and $historyHash -eq $installHistoryHash)
    if ($historyHash -ne 'NOT_FOUND' -and $installHistoryHash -ne 'NOT_FOUND' -and -not $historyCopiesMatch) {
        Write-Warning 'The project-data and installation Standard Library copies of HistoryOrderInfo.mqh differ. The selected /include root is authoritative for this compile; inspect both versions before changing either copy.'
    }

    # Verify the terminal data folder's origin mapping when origin.txt is present.
    $dataRoot = Split-Path -Parent $ProjectMql5Root
    $originFile = Join-Path $dataRoot 'origin.txt'
    $originValue = $null
    if (Test-Path -LiteralPath $originFile -PathType Leaf) {
        $originValue = (Get-Content -LiteralPath $originFile -Raw).Trim()
        if ($originValue) {
            try {
                $originResolved = (Resolve-Path -LiteralPath $originValue -ErrorAction Stop).Path.TrimEnd('\')
                $installResolved = $TerminalInstallRoot.TrimEnd('\')
                if (-not [string]::Equals($originResolved, $installResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-Warning "origin.txt maps this data folder to '$originResolved', not '$installResolved'. Verify terminal identity before using the resulting EX5."
                }
            }
            catch {
                Write-Warning "Could not resolve origin.txt value '$originValue': $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Warning "No origin.txt found at '$originFile'. The installation/data-folder association is not independently verified."
    }

    $archiveDirectory = Join-Path $ProjectMql5Root $ArchiveDirectoryRelativePath
    if (-not (Test-Path -LiteralPath $archiveDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
    }

    # MetaEditor writes <source>.log beside the source when /log is supplied.
    $sourceLog = [System.IO.Path]::ChangeExtension($sourcePath, '.log')
    if (Test-Path -LiteralPath $sourceLog -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $archivedPreviousLog = Join-Path $archiveDirectory ("AlgoMultiAssetEA.previous-$stamp.log")
        Move-Item -LiteralPath $sourceLog -Destination $archivedPreviousLog
        Write-Host "Previous compile log preserved at: $archivedPreviousLog"
    }

    $ex5Path = [System.IO.Path]::ChangeExtension($sourcePath, '.ex5')
    $ex5BeforeHash = $null
    $ex5BeforeTime = $null
    if (Test-Path -LiteralPath $ex5Path -PathType Leaf) {
        $ex5BeforeHash = (Get-FileHash -LiteralPath $ex5Path -Algorithm SHA256).Hash
        $ex5BeforeTime = (Get-Item -LiteralPath $ex5Path).LastWriteTimeUtc
    }

    $metaEditorInfo = Get-VersionSummary -Path $metaEditor
    $compileStartUtc = [DateTime]::UtcNow
    $compileMode = if ($SyntaxCheckOnly) { '/s /log' } else { '/log' }

    # Quote each path explicitly. MetaEditor command-line arguments are documented
    # as /compile:"full path" /include:"MQL5 root" /log.
    $argumentLine = '/compile:"{0}" /include:"{1}" {2}' -f $sourcePath, $IncludeMql5Root, $compileMode

    Write-Host '=== AlgoMultiAssetEA MetaEditor Build ==='
    Write-Host "Install root : $TerminalInstallRoot"
    Write-Host "MetaEditor   : $($metaEditorInfo.Path)"
    Write-Host "File version : $($metaEditorInfo.FileVersion)"
    Write-Host "Product ver. : $($metaEditorInfo.ProductVersion)"
    Write-Host "Project root : $ProjectMql5Root"
    Write-Host "Include root : $IncludeMql5Root"
    Write-Host "Source       : $sourcePath"
    Write-Host "HistoryOrder : $expectedHistoryHeader"
    Write-Host "History SHA  : $historyHash"
    Write-Host "Install History SHA: $installHistoryHash"
    Write-Host "History copies match: $historyCopiesMatch"
    Write-Host "Origin       : $(if ($originValue) { $originValue } else { 'UNVERIFIED' })"
    Write-Host "Mode         : $(if ($SyntaxCheckOnly) { 'SYNTAX CHECK' } else { 'COMPILE' })"
    Write-Host "Arguments    : $argumentLine"
    Write-Host ''

    $process = Start-Process -FilePath $metaEditor -ArgumentList $argumentLine -WorkingDirectory $TerminalInstallRoot -Wait -PassThru -ErrorAction Stop
    $processExitCode = $process.ExitCode

    if (-not (Test-Path -LiteralPath $sourceLog -PathType Leaf)) {
        throw "MetaEditor did not create the expected fresh source log: $sourceLog (process exit code: $processExitCode)"
    }

    $logItem = Get-Item -LiteralPath $sourceLog
    if ($logItem.LastWriteTimeUtc -lt $compileStartUtc.AddSeconds(-2)) {
        throw "The source log is older than this build attempt; refusing to parse a stale log: $sourceLog"
    }

    $logLines = @(Get-Content -LiteralPath $sourceLog)
    $summary = Get-CompileSummary -Lines $logLines

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $archivedCurrentLog = Join-Path $archiveDirectory ("AlgoMultiAssetEA-$stamp.log")
    Copy-Item -LiteralPath $sourceLog -Destination $archivedCurrentLog

    $ex5Generated = $false
    $ex5AfterHash = $null
    $ex5AfterTime = $null
    if ((-not $SyntaxCheckOnly) -and (Test-Path -LiteralPath $ex5Path -PathType Leaf)) {
        $ex5Item = Get-Item -LiteralPath $ex5Path
        $ex5AfterTime = $ex5Item.LastWriteTimeUtc
        $ex5AfterHash = (Get-FileHash -LiteralPath $ex5Path -Algorithm SHA256).Hash
        $ex5Generated = ($ex5Item.Length -gt 0 -and $ex5AfterTime -ge $compileStartUtc.AddSeconds(-2))
    }

    Write-Host ''
    Write-Host '=== Build Result ==='
    Write-Host "MetaEditor exit code : $processExitCode"
    Write-Host "Compiler summary     : $(if ($summary.SummaryFound) { 'FOUND' } else { 'MISSING' })"
    Write-Host "Errors               : $($summary.Errors)"
    Write-Host "Warnings             : $($summary.Warnings)"
    Write-Host "Fresh log            : $sourceLog"
    Write-Host "Archived log         : $archivedCurrentLog"

    if ($summary.ErrorLines.Count -gt 0) {
        Write-Host "`nCompiler error lines:"
        $summary.ErrorLines | ForEach-Object { Write-Host "  $_" }
    }
    if ($summary.WarningLines.Count -gt 0) {
        Write-Host "`nCompiler warning lines:"
        $summary.WarningLines | ForEach-Object { Write-Host "  $_" }
    }

    if ($processExitCode -ne 0 -and -not $summary.SummaryFound) {
        throw "MetaEditor returned non-zero exit code $processExitCode and no compiler summary was found. Inspect the fresh source log: $sourceLog"
    }
    if ($processExitCode -ne 0) {
        Write-Warning "MetaEditor returned exit code $processExitCode, but the compiler summary reports $($summary.Errors) errors and $($summary.Warnings) warnings. Continuing based on the parsed summary."
    }

    if ($SyntaxCheckOnly) {
        if (-not $summary.SummaryFound) {
            throw 'Syntax-check log has no recognized compiler summary. Result is UNKNOWN, not PASSED.'
        }
        if ($summary.Errors -gt 0) { exit 1 }
        if ($summary.Warnings -gt 0) { exit 2 }
        Write-Host 'SYNTAX CHECK: PASSED (0 errors, 0 warnings).'
        exit 0
    }

    if (-not $summary.SummaryFound) {
        throw 'Compile log has no recognized errors/warnings summary. Refusing to infer success from MetaEditor process exit code.'
    }
    if ($summary.Errors -gt 0) {
        Write-Host "`nEX5 existing hash before: $ex5BeforeHash"
        Write-Host "EX5 after attempt hash : $ex5AfterHash"
        Write-Host 'COMPILE: FAILED'
        exit 1
    }
    if ($summary.Warnings -gt 0) {
        Write-Host 'COMPILE: PASSED WITH WARNINGS (warnings must be reviewed).'
        if ($ex5Generated) { Write-Host "EX5: $ex5Path" }
        exit 2
    }
    if (-not $ex5Generated) {
        throw "Compiler log reports zero errors/warnings, but a fresh non-empty EX5 was not verified: $ex5Path"
    }

    Write-Host "EX5 path             : $ex5Path"
    Write-Host "EX5 last write UTC   : $ex5AfterTime"
    Write-Host "EX5 SHA256           : $ex5AfterHash"
    Write-Host "EX5 hash unchanged   : $($ex5BeforeHash -and ($ex5BeforeHash -eq $ex5AfterHash))"
    Write-Host 'COMPILE: PASSED (0 errors, 0 warnings; fresh EX5 verified).'
    exit 0
}
catch {
    Write-Error $_
    exit 10
}
