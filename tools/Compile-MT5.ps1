# ============================================================
# Compile-MT5.ps1 — PowerShell build tool for AlgoMultiAssetEA
# Compiles Experts/AlgoMultiAssetEA.mq5 using MetaEditor CLI.
# Compatible with Windows PowerShell 5.1. No external dependencies.
# ============================================================

[CmdletBinding()]
param(
    [string]$MT5InstallPath = "C:\Program Files\AMarkets - MetaTrader 5",
    [string]$SourceRelativePath = "Experts\AlgoMultiAssetEA.mq5",
    [string]$LogRelativePath = "tools\compile.log"
)

# ------------------------------------------------------------------
# 1. Detect project root from script location (not CWD)
# ------------------------------------------------------------------
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$projectRoot = Resolve-Path -Path (Join-Path $scriptDir "..") -ErrorAction Stop
$projectRoot = $projectRoot.Path

Write-Host "Project root: $projectRoot"
Write-Host ""

# ------------------------------------------------------------------
# 2. Resolve absolute paths
# ------------------------------------------------------------------
$sourcePath = Join-Path $projectRoot $SourceRelativePath
$logPath    = Join-Path $projectRoot $LogRelativePath
$mt5Path    = Resolve-Path -Path $MT5InstallPath -ErrorAction SilentlyContinue
$compiler   = Join-Path $mt5Path "metaeditor64.exe"
$mql5Root   = Join-Path $mt5Path "MQL5"

# ------------------------------------------------------------------
# 3. Verify MT5 installation
# ------------------------------------------------------------------
if (-not $mt5Path) {
    Write-Host "ERROR: MT5 installation not found at: $MT5InstallPath" -ForegroundColor Red
    exit 2
}

if (-not (Test-Path -Path $compiler)) {
    # Search limited to the Installation Directory
    Write-Host "WARNING: metaeditor64.exe not found at default path. Searching installation directory..." -ForegroundColor Yellow
    $found = Get-ChildItem -Path $mt5Path -Filter "metaeditor64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $compiler = $found.FullName
        Write-Host "Found metaeditor64.exe at: $compiler" -ForegroundColor Green
    } else {
        Write-Host "ERROR: metaeditor64.exe not found in installation directory." -ForegroundColor Red
        exit 3
    }
}

if (-not (Test-Path -Path $mql5Root)) {
    Write-Host "WARNING: MQL5 root not found at: $mql5Root" -ForegroundColor Yellow
    $mql5Arg = ""
} else {
    $mql5Arg = "/include:""$mql5Root"""
}

# ------------------------------------------------------------------
# 4. Verify source file
# ------------------------------------------------------------------
if (-not (Test-Path -Path $sourcePath)) {
    Write-Host "ERROR: Source file not found: $sourcePath" -ForegroundColor Red
    exit 4
}

# ------------------------------------------------------------------
# 5. Preserve previous compile log if it exists
# ------------------------------------------------------------------
$prevLogContent = $null
if (Test-Path -Path $logPath) {
    $prevLogContent = Get-Content -Path $logPath -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------
# 6. Display compile parameters
# ------------------------------------------------------------------
Write-Host "=== MT5 Compile Tool ===" -ForegroundColor Cyan
Write-Host "MetaEditor:  $compiler"
Write-Host "Source MQ5:  $sourcePath"
Write-Host "MQL5 Root:   $mql5Root"
Write-Host "Compile log: $logPath"
Write-Host "Start time:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# ------------------------------------------------------------------
# 7. Capture EX5 state before compile
# ------------------------------------------------------------------
$ex5Path = [System.IO.Path]::ChangeExtension($sourcePath, ".ex5")
$ex5Before = $null
if (Test-Path -Path $ex5Path) {
    $ex5Before = (Get-Item -Path $ex5Path).LastWriteTime
}

# ------------------------------------------------------------------
# 8. Run MetaEditor compilation (capture stderr to temp file)
# ------------------------------------------------------------------
$compileStart = Get-Date
$metaEditorError = $false
$metaEditorErrorMsg = ""

$stdoutTemp = [System.IO.Path]::GetTempFileName()
$stderrTemp = [System.IO.Path]::GetTempFileName()

$compileArgs = @(
    "/compile:""$sourcePath"""
)
if ($mql5Arg) {
    $compileArgs += $mql5Arg
}
$compileArgs += "/log"

try {
    $process = Start-Process -FilePath $compiler -ArgumentList ($compileArgs -join " ") -Wait -PassThru -RedirectStandardOutput $stdoutTemp -RedirectStandardError $stderrTemp
    $exitCode = $process.ExitCode
} catch {
    $metaEditorError = $true
    $metaEditorErrorMsg = $_.Exception.Message
    Write-Host "ERROR: MetaEditor execution failed: $metaEditorErrorMsg" -ForegroundColor Red
    Remove-Item -Path $stdoutTemp, $stderrTemp -ErrorAction SilentlyContinue
    exit 5
}

$compileEnd = Get-Date
$compileDuration = ($compileEnd - $compileStart).TotalSeconds

# ------------------------------------------------------------------
# 9. Read compile output from temp files
# ------------------------------------------------------------------
$stdoutContent = ""
$stderrContent = ""

if (Test-Path -Path $stdoutTemp) {
    $stdoutContent = Get-Content -Path $stdoutTemp -ErrorAction SilentlyContinue
}
if (Test-Path -Path $stderrTemp) {
    $stderrContent = Get-Content -Path $stderrTemp -ErrorAction SilentlyContinue
}

Remove-Item -Path $stdoutTemp, $stderrTemp -ErrorAction SilentlyContinue

# Combine all output for parsing
$allOutput = ($stdoutContent + $stderrContent)

# Also try to find MetaEditor's log file
$logContent = ""
$logReadOk = $false
$logPathUsed = $logPath

if (Test-Path -Path $logPath) {
    $logContent = Get-Content -Path $logPath -ErrorAction SilentlyContinue
    $logReadOk = $true
} else {
    $altLogPath1 = [System.IO.Path]::ChangeExtension($sourcePath, ".log")
    $altLogPath2 = Join-Path (Split-Path -Parent $sourcePath) "compile.log"
    $altLogPath3 = Join-Path $mql5Root "Logs\compile.log"
    foreach ($alt in $altLogPath1, $altLogPath2, $altLogPath3) {
        if (Test-Path -Path $alt) {
            $logContent = Get-Content -Path $alt -ErrorAction SilentlyContinue
            $logReadOk = $true
            $logPathUsed = $alt
            break
        }
    }
}

if (-not $logReadOk) {
    Write-Host "WARNING: No compile log found. Using stderr/stdout output for error parsing." -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# 10. Parse output for Errors and Warnings
# ------------------------------------------------------------------
$errorCount = 0
$warningCount = 0
$hasSummary = $false
$compileResult = "UNKNOWN"
$compileMessages = @()

# Parse from MetaEditor output (stdout+stderr) and log file
$parseSources = @($allOutput)
if ($logReadOk -and $logContent) {
    $parseSources += $logContent
}

foreach ($src in $parseSources) {
    foreach ($line in $src) {
        if ($line -match "Errors:\s*(\d+)") {
            $errorCount = [int]$Matches[1]
            $hasSummary = $true
        }
        if ($line -match "Warnings:\s*(\d+)") {
            $warningCount = [int]$Matches[1]
            $hasSummary = $true
        }
        if ($line -match ":\s*error\s+\d+") {
            $compileMessages += $line
        }
    }
}

# If no summary found in output, check exit code
if (-not $hasSummary) {
    if ($exitCode -eq 0) {
        $compileResult = "PASSED"
        $hasSummary = $true
    } else {
        $compileResult = "FAILED"
        $hasSummary = $true
    }
} elseif ($errorCount -gt 0) {
    $compileResult = "FAILED"
} else {
    $compileResult = "PASSED"
}

# ------------------------------------------------------------------
# 11. Check EX5 generation
# ------------------------------------------------------------------
$ex5After = $null
$ex5NewlyGenerated = $false
if (Test-Path -Path $ex5Path) {
    $ex5After = (Get-Item -Path $ex5Path).LastWriteTime
    if ($ex5Before -and $ex5After -gt $ex5Before) {
        $ex5NewlyGenerated = $true
    } elseif (-not $ex5Before) {
        $ex5NewlyGenerated = $true
    }
}

# ------------------------------------------------------------------
# 12. Display results
# ------------------------------------------------------------------
Write-Host ""
Write-Host "=== Compile Results ===" -ForegroundColor Cyan
Write-Host "End time:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Duration:      $([Math]::Round($compileDuration, 2)) seconds"
Write-Host "Errors:        $errorCount"
Write-Host "Warnings:      $warningCount"
Write-Host "Result:        $compileResult"
Write-Host "EX5 generated: $ex5NewlyGenerated"
Write-Host "EX5 path:      $ex5Path"
Write-Host "Log path:      $logPath"
Write-Host ""

if ($compileMessages.Count -gt 0) {
    Write-Host "=== Compiler Messages ===" -ForegroundColor Cyan
    $compileMessages | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

# ------------------------------------------------------------------
# 13. Exit code
# ------------------------------------------------------------------
if ($metaEditorError) {
    Write-Host "EXIT: MetaEditor execution failure" -ForegroundColor Red
    exit 5
}

if ($errorCount -gt 0) {
    Write-Host "EXIT: Compilation failed with $errorCount error(s)" -ForegroundColor Red
    exit 1
}

if (-not $ex5NewlyGenerated) {
    Write-Host "WARNING: EX5 file was not newly generated." -ForegroundColor Yellow
    exit 3
}

if ($warningCount -gt 0) {
    Write-Host "EXIT: Compilation passed with $warningCount warning(s)" -ForegroundColor Yellow
    exit 0
}

Write-Host "EXIT: Compilation succeeded with zero errors and zero warnings." -ForegroundColor Green
exit 0