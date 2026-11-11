#requires -Version 5.1
<#
.SYNOPSIS
  Hardened validation harness for AlgoMultiAssetEA.
.DESCRIPTION
  Performs a comprehensive, reproducible validation of the AlgoMultiAssetEA project.
  Validates compilation, project structure, configuration integrity, critical invariants,
  and Strategy Tester readiness without launching the terminal or submitting orders.

  This script may create validation-log archives and the optional JSON report.
  It does not launch the terminal/tester, mutate trading databases, connect to a broker,
  or execute trades. Compilation invokes MetaEditor only when -SkipCompile is not supplied.

  Exit codes:
    0  - All validations PASSED
    1  - Compilation FAILED (errors)
    2  - Compilation PASSED WITH WARNINGS (warnings must be reviewed)
    3  - Project structure/configuration validation FAILED
    4  - Critical invariant validation FAILED
    5  - Strategy Tester readiness validation FAILED
    6  - Standard Library consistency FAILED
    7  - Terminal data folder origin verification FAILED
    10 - Script execution error (unexpected exception)
    11 - JSON report validation FAILED
    12 - Compilation timeout
    13 - Compilation log parsing FAILED
    14 - Fresh EX5 verification FAILED
    15 - INI validation FAILED
    16 - SET validation FAILED
    17 - Invariant check FAILED

  Status values (used internally and in JSON report):
    PASSED              - Validation succeeded
    FAILED              - Validation failed (required check)
    WARNING             - Validation produced warnings (configurable acceptance)
    SKIPPED             - Validation skipped by user flag
    NOT_APPLICABLE      - Validation not applicable (no configured artifact)
    NOT_VERIFIED        - Validation could not be determined (missing evidence)
    ACCEPTED_WARNING    - Warning explicitly accepted via policy reference
#>
# Remove CmdletBinding to avoid automatic -WhatIf/-Confirm parameters that conflict with custom implementation
param(
    # MetaTrader 5 terminal installation root (contains metaeditor64.exe, terminal64.exe)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TerminalInstallRoot = 'C:\Program Files\AMarkets - MetaTrader 5',

    # Project MQL5 data root (contains Experts/, Include/, etc.)
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectMql5Root = 'C:\Users\Ali\AppData\Roaming\MetaQuotes\Terminal\D0694EE1816B0E3A2D24B3606A663CE8\MQL5',

    # MQL5 include root for compilation (parent of Include/ directory)
    [Parameter()]
    [string]$IncludeMql5Root = '',

    # Relative path to the main MQ5 entry point from ProjectMql5Root
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRelativePath = 'Experts\AlgoMultiAssetEA.mq5',

    # Archive directory for validation logs (relative to ProjectMql5Root)
    [Parameter()]
    [string]$ArchiveDirectoryRelativePath = 'tools\validation-logs',

    # Skip compilation validation (use existing EX5 if present)
    [Parameter()]
    [switch]$SkipCompile,

    # Run Strategy Tester readiness checks (INI/SET/profile validation only, no launch)
    [Parameter()]
    [switch]$ValidateTesterReadiness,

    # Path to Strategy Tester INI template for validation
    [Parameter()]
    [string]$TesterIniTemplatePath = '',

    # Path to SET file for validation
    [Parameter()]
    [string]$SetFilePath = '',

    # Fail on any compiler warning (treat warnings as errors)
    [Parameter()]
    [switch]$WarningsAsErrors,

    # Maximum allowed compiler warnings when not treating as errors
    [Parameter()]
    [int]$MaxAllowedWarnings = 0,

    # Output validation summary as JSON to this path
    [Parameter()]
    [string]$JsonReportPath = '',

    # Verbose output for diagnostics
    [Parameter()]
    [switch]$DetailedOutput,

    # Compilation timeout in seconds (0 = no timeout)
    [Parameter()]
    [int]$CompileTimeoutSeconds = 120,

    # Warning acceptance policy reference (documented justification for ACCEPTED_WARNING)
    [Parameter()]
    [string]$WarningAcceptancePolicy = '',

    # Required SET files (comma-separated relative paths from ProjectMql5Root)
    [Parameter()]
    [string]$RequiredSetFiles = 'Experts\AlgoMultiAssetEA.set',

    # Optional SET files (comma-separated relative paths from ProjectMql5Root)
    [Parameter()]
    [string]$OptionalSetFiles = 'profiles\AlgoMultiAssetEA.set',

    # Enable strict mode: treat NOT_VERIFIED as FAILED
    [Parameter()]
    [switch]$StrictMode,

    # WhatIf mode: show what would be done without making changes (custom parameter to avoid common parameter conflict)
    [Parameter()]
    [switch]$WhatIfMode,

    # Confirm mode: prompt before each write operation
    [Parameter()]
    [switch]$Confirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Type Definitions and Constants

# Validation status enum (mirrors the comment block above)
$ValidationStatus = @{
    PASSED              = 'PASSED'
    FAILED              = 'FAILED'
    WARNING             = 'WARNING'
    SKIPPED             = 'SKIPPED'
    NOT_APPLICABLE      = 'NOT_APPLICABLE'
    NOT_VERIFIED        = 'NOT_VERIFIED'
    ACCEPTED_WARNING    = 'ACCEPTED_WARNING'
}

# Exit code mapping
$ExitCodes = @{
    SUCCESS                 = 0
    COMPILE_FAILED          = 1
    COMPILE_WARNINGS        = 2
    STRUCTURE_FAILED        = 3
    INVARIANT_FAILED        = 4
    TESTER_READINESS_FAILED = 5
    STDLIB_FAILED           = 6
    ORIGIN_FAILED           = 7
    SCRIPT_ERROR            = 10
    JSON_FAILED             = 11
    COMPILE_TIMEOUT         = 12
    COMPILE_PARSE_FAILED    = 13
    FRESH_EX5_FAILED        = 14
    INI_VALIDATION_FAILED   = 15
    SET_VALIDATION_FAILED   = 16
    INVARIANT_CHECK_FAILED  = 17
    STRICT_VERIFICATION_FAILED = 18
}

# Manual ShouldProcess check for write operations (since we don't use SupportsShouldProcess at script level)
function Test-ShouldProcess {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Action
    )
    if ($WhatIfMode) {
        Write-Host "WhatIf: Would $Action on $Target"
        return $false
    }
    if ($Confirm) {
        $response = Read-Host "Confirm $Action on $Target? [y/n]"
        if ($response -ne 'y' -and $response -ne 'Y') {
            return $false
        }
    }
    return $true
}

# Helper to get UTC timestamp in ISO 8601 with offset
function Get-UtcTimestamp {
    return [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffK')
}

#endregion

#region Result Object Model

function New-ValidationResult {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('PASSED','FAILED','SKIPPED','WARNING','NOT_APPLICABLE','NOT_VERIFIED','ACCEPTED_WARNING','WOULD_RUN')][string]$Status,
        [Parameter(Mandatory)][ValidateSet('INFO','LOW','MEDIUM','HIGH','CRITICAL')][string]$Severity = 'INFO',
        [string]$Message = '',
        [string[]]$Evidence = @(),
        [string[]]$SourcePaths = @(),
        [string]$StartedAtUtc = (Get-UtcTimestamp),
        [string]$CompletedAtUtc = (Get-UtcTimestamp),
        [int]$DurationMs = 0,
        [string]$FailureReason = '',
        [string]$NotApplicableReason = '',
        [string]$AcceptanceReference = '',
        [int]$ExitCode = 0
    )
    return [pscustomobject]@{
        Id                   = $Id
        Name                 = $Name
        Status               = $Status
        Severity             = $Severity
        Message              = $Message
        Evidence             = $Evidence
        SourcePaths          = $SourcePaths
        StartedAtUtc         = $StartedAtUtc
        CompletedAtUtc       = $CompletedAtUtc
        DurationMs           = $DurationMs
        FailureReason        = $FailureReason
        NotApplicableReason  = $NotApplicableReason
        AcceptanceReference  = $AcceptanceReference
        ExitCode             = $ExitCode
    }
}

function Update-ValidationResult {
    param(
        [Parameter(Mandatory)][int]$Index,
        [Parameter(Mandatory)][ValidateSet('PASSED','FAILED','SKIPPED','WARNING','NOT_APPLICABLE','NOT_VERIFIED','ACCEPTED_WARNING','WOULD_RUN')][string]$Status,
        [ValidateSet('INFO','LOW','MEDIUM','HIGH','CRITICAL')][string]$Severity = '',
        [string]$Message = '',
        [string[]]$Evidence = @(),
        [string]$FailureReason = '',
        [string]$NotApplicableReason = '',
        [string]$AcceptanceReference = '',
        [int]$ExitCode = -1
    )
    $completedAt = Get-UtcTimestamp
    $startedAt = $validationResults[$Index].StartedAtUtc
    $durationMs = 0
    try {
        $startDt = [DateTimeOffset]::Parse($startedAt)
        $endDt = [DateTimeOffset]::Parse($completedAt)
        $durationMs = [math]::Round(($endDt - $startDt).TotalMilliseconds)
    } catch { }

    $newExitCode = if ($ExitCode -ge 0) { $ExitCode } else { $validationResults[$Index].ExitCode }

    $validationResults[$Index] = [pscustomobject]@{
        Id                   = $validationResults[$Index].Id
        Name                 = $validationResults[$Index].Name
        Status               = $Status
        Severity             = if ($Severity) { $Severity } else { $validationResults[$Index].Severity }
        Message              = if ($Message) { $Message } else { $validationResults[$Index].Message }
        Evidence             = if ($Evidence.Count -gt 0) { $Evidence } else { $validationResults[$Index].Evidence }
        SourcePaths          = $validationResults[$Index].SourcePaths
        StartedAtUtc         = $startedAt
        CompletedAtUtc       = $completedAt
        DurationMs           = $durationMs
        FailureReason        = if ($FailureReason) { $FailureReason } else { $validationResults[$Index].FailureReason }
        NotApplicableReason  = if ($NotApplicableReason) { $NotApplicableReason } else { $validationResults[$Index].NotApplicableReason }
        AcceptanceReference  = if ($AcceptanceReference) { $AcceptanceReference } else { $validationResults[$Index].AcceptanceReference }
        ExitCode             = $newExitCode
    }
}

#endregion

#region Helper Functions

function Resolve-ExistingDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label directory does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label file does not exist: $Path"
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

function Get-FileHashSafe {
    param([Parameter(Mandatory)][string]$Path)
    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch {
        return $null
    }
}

# Parses MetaEditor compilation log and returns structured result
function Test-FreshEx5Artifact {
    param(
        [AllowNull()][string]$BeforeHash,
        [switch]$BeforeArtifactExists,
        [datetime]$BeforeWriteTimeUtc = [datetime]::MinValue,
        [AllowNull()][string]$AfterHash,
        [Parameter(Mandatory)][datetime]$AfterWriteTimeUtc,
        [Parameter(Mandatory)][datetime]$CompileStartUtc,
        [Parameter(Mandatory)][long]$Length
    )
    $timestampAfterCompile = ($AfterWriteTimeUtc -ge $CompileStartUtc.AddSeconds(-2))
    $hashChanged = ($BeforeArtifactExists -and -not [string]::IsNullOrWhiteSpace($BeforeHash) -and -not [string]::IsNullOrWhiteSpace($AfterHash) -and $BeforeHash -ne $AfterHash)
    $timestampUpdated = ($BeforeArtifactExists -and $AfterWriteTimeUtc -gt $BeforeWriteTimeUtc)
    $artifactChanged = (-not $BeforeArtifactExists -or $hashChanged -or $timestampUpdated)
    return [pscustomobject]@{
        IsFresh = [bool]($Length -gt 0 -and $timestampAfterCompile -and $artifactChanged)
        HashChanged = [bool]$hashChanged
        TimestampUpdated = [bool]$timestampUpdated
        TimestampAfterCompile = [bool]$timestampAfterCompile
        ArtifactChanged = [bool]$artifactChanged
    }
}

function Get-StandardLibraryConsistency {
    param(
        [Parameter(Mandatory)][string]$ProjectFilePath,
        [Parameter(Mandatory)][string]$InstallFilePath
    )
    $projectExists = Test-Path -LiteralPath $ProjectFilePath -PathType Leaf
    $installExists = Test-Path -LiteralPath $InstallFilePath -PathType Leaf
    $projectHash = if ($projectExists) { Get-FileHashSafe -Path $ProjectFilePath } else { $null }
    $installHash = if ($installExists) { Get-FileHashSafe -Path $InstallFilePath } else { $null }
    if (-not $projectExists) {
        $status='FAILED'
        $message=if ($installExists) { 'Project Standard Library copy not found (mandatory)' } else { 'Both Standard Library copies missing' }
        $failureReason='Project Standard Library copy missing'
    }
    elseif (-not $installExists) {
        $status='WARNING'; $message='Installation Standard Library copy not found'; $failureReason='Installation copy missing'
    }
    elseif ($projectHash -eq $installHash) {
        $status='PASSED'; $message='Standard Library copies match'; $failureReason=''
    }
    else {
        $status='WARNING'; $message='Standard Library copies differ'; $failureReason='Hash mismatch between project and installation copies'
    }
    return [pscustomobject]@{
        Status=$status; Message=$message; FailureReason=$failureReason
        ProjectExists=$projectExists; InstallExists=$installExists
        ProjectHash=$projectHash; InstallHash=$installHash
    }
}

function Parse-CompileLog {
    param([Parameter(Mandatory)][string[]]$Lines)

    $cleanLines = @($Lines | Where-Object { $_ -and $_.Trim() })
    $text = $cleanLines -join "`n"
    $errors = $null
    $warnings = $null
    $summaryFound = $false
    $rawSummary = ''

    $resultMatch = [regex]::Match($text, '(?im)\bResult\s*:\s*(\d+)\s+errors?\s*,\s*(\d+)\s+warnings?\b')
    if ($resultMatch.Success) {
        $errors = [int]$resultMatch.Groups[1].Value
        $warnings = [int]$resultMatch.Groups[2].Value
        $summaryFound = $true
        $rawSummary = $resultMatch.Value
    }
    else {
        $combinedMatch = [regex]::Match($text, '(?im)^\s*Errors?\s*:\s*(\d+)\s*,\s*Warnings?\s*:\s*(\d+)\s*$')
        if ($combinedMatch.Success) {
            $errors = [int]$combinedMatch.Groups[1].Value
            $warnings = [int]$combinedMatch.Groups[2].Value
            $summaryFound = $true
            $rawSummary = $combinedMatch.Value.Trim()
        }
        else {
            $errorMatch = [regex]::Match($text, '(?im)^\s*Errors?\s*:\s*(\d+)\s*$')
            $warningMatch = [regex]::Match($text, '(?im)^\s*Warnings?\s*:\s*(\d+)\s*$')
            if ($errorMatch.Success -and $warningMatch.Success) {
                $errors = [int]$errorMatch.Groups[1].Value
                $warnings = [int]$warningMatch.Groups[1].Value
                $summaryFound = $true
                $rawSummary = "Errors: $errors, Warnings: $warnings"
            }
        }
    }

    $diagnosticLines = @($cleanLines | Where-Object {
        $_ -notmatch '(?i)^\s*(?:Result\s*:\s*)?\d+\s+errors?\s*,\s*\d+\s+warnings?\b' -and
        $_ -notmatch '(?i)^\s*Errors?\s*:\s*\d+\s*(?:,\s*Warnings?\s*:\s*\d+\s*)?$' -and
        $_ -notmatch '(?i)^\s*Warnings?\s*:\s*\d+\s*$'
    })
    $errorLines = @($diagnosticLines | Where-Object { $_ -match '(?i)(?:\berror\b\s*\d+\b|:\s*error\s*:|^\s*error\s*:|:\s*error\s+[^:])' })
    $warningLines = @($diagnosticLines | Where-Object { $_ -match '(?i)(?:\bwarning\b\s*\d+\b|:\s*warning\s*:|^\s*warning\s*:|:\s*warning\s+[^:])' })

    if ($null -eq $errors) { $errors = $errorLines.Count }
    if ($null -eq $warnings) { $warnings = $warningLines.Count }

    return [pscustomobject]@{
        SummaryFound = [bool]$summaryFound
        RawSummary = $rawSummary
        Errors = [int]$errors
        Warnings = [int]$warnings
        ErrorLines = $errorLines
        WarningLines = $warningLines
    }
}

# Parses INI file content into sections and key-value pairs
function Parse-IniContent {
    param([Parameter(Mandatory)][string]$Content)

    $result = @{}
    $currentSection = ''

    $lines = $Content -split "`r?`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }
        # Section header
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $matches[1].Trim()
            if (-not $result.ContainsKey($currentSection)) {
                $result[$currentSection] = @{}
            }
        }
        # Key=Value
        elseif ($trimmed -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if (-not $result.ContainsKey($currentSection)) {
                $result[$currentSection] = @{}
            }
            $result[$currentSection][$key] = $value
        }
    }
    return $result
}

# Validates Strategy Tester INI structure per official MT5 documentation
function Validate-TesterIni {
    param(
        [Parameter(Mandatory)][hashtable]$ParsedIni,
        [Parameter(Mandatory)][string]$FilePath
    )

    $issues = @()
    $warnings = @()

    # [Tester] section is mandatory
    if (-not $ParsedIni.ContainsKey('Tester')) {
        $issues += "Missing required section: [Tester]"
        return [pscustomobject]@{ Valid = $false; Issues = $issues; Warnings = $warnings }
    }

    $tester = $ParsedIni['Tester']

    # Only Expert is truly required per MT5 docs; others have documented defaults
    if (-not $tester.ContainsKey('Expert') -or [string]::IsNullOrWhiteSpace($tester['Expert'])) {
        $issues += "Missing or empty required key in [Tester]: Expert"
    }

    # Validate keys if present (optional keys with documented defaults)
    $optionalKeys = @('ExpertParameters', 'Symbol', 'Period', 'Model', 'Deposit', 'Leverage', 'FromDate', 'ToDate', 'ExecutionMode', 'Optimization', 'OptimizationCriterion', 'ForwardMode', 'ForwardDate', 'Report', 'ReplaceReport', 'ShutdownTerminal')

    # Validate date format (YYYY.MM.DD or YYYY.MM.DD HH:MM) if present
    foreach ($dateKey in @('FromDate', 'ToDate', 'ForwardDate')) {
        if ($tester.ContainsKey($dateKey)) {
            $dateVal = $tester[$dateKey]
            if (-not ($dateVal -match '^\d{4}\.\d{2}\.\d{2}( \d{2}:\d{2})?$')) {
                $issues += "Invalid date format for ${dateKey}: '$dateVal' (expected YYYY.MM.DD or YYYY.MM.DD HH:MM)"
            }
        }
    }

    # Validate Model (0=Every tick, 1=Control points, 2=Open prices only, 3=Math calc, 4=Real ticks)
    if ($tester.ContainsKey('Model')) {
        $model = $tester['Model']
        if ($model -notin @('0','1','2','3','4')) {
            $issues += "Invalid Model value: '$model' (must be 0, 1, 2, 3, or 4)"
        }
    }

    # Validate Deposit and Leverage are numeric if present
    foreach ($numKey in @('Deposit', 'Leverage')) {
        if ($tester.ContainsKey($numKey)) {
            $val = $tester[$numKey]
            # Leverage can be ratio like "1:100" or just number
            if ($numKey -eq 'Leverage') {
                if (-not ($val -match '^(\d+(\.\d+)?|(\d+:\d+))$')) {
                    $issues += "Invalid Leverage value: '$val' (must be numeric or ratio like 1:100)"
                }
            }
            else {
                if (-not ($val -match '^\d+(\.\d+)?$')) {
                    $issues += "Invalid $numKey value: '$val' (must be numeric)"
                }
            }
        }
    }

    # Validate Period if present (standard MT5 timeframe constants)
    if ($tester.ContainsKey('Period')) {
        $period = $tester['Period']
        $validPeriods = @('1','5','15','30','60','240','1440','10080','43200')
        if ($period -notin $validPeriods) {
            $warnings += "Non-standard Period value: '$period' (standard: $($validPeriods -join ','))"
        }
    }

    # Optimization section validation if present
    if ($ParsedIni.ContainsKey('Optimization')) {
        $opt = $ParsedIni['Optimization']
        foreach ($optKey in @('Optimization', 'Criterion', 'ForwardMode', 'ForwardPass')) {
            if ($opt.ContainsKey($optKey) -and [string]::IsNullOrWhiteSpace($opt[$optKey])) {
                $warnings += "Empty optimization key: $optKey"
            }
        }
    }

    # Unknown keys as compatibility warnings
    $knownKeys = @('Expert','ExpertParameters','Symbol','Period','Model','Deposit','Leverage','FromDate','ToDate','ExecutionMode','Optimization','OptimizationCriterion','ForwardMode','ForwardDate','Report','ReplaceReport','ShutdownTerminal')
    foreach ($key in $tester.Keys) {
        if ($knownKeys -inotcontains $key) {
            $warnings += "Unknown key in [Tester] section (may be build-specific): $key"
        }
    }

    return [pscustomobject]@{
        Valid   = ($issues.Count -eq 0)
        Issues  = $issues
        Warnings = $warnings
    }
}

# Validates SET file structure (supports both constant and optimization formats)
function Validate-SetFile {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$FilePath
    )

    $issues = @()
    $warnings = @()

    # SET files have two formats:
    # 1. Constant: ParameterName=Value
    # 2. Optimization: ParameterName=Value||Description||Type||Min||Max||Step
    $lines = $Content -split "`r?`n"
    $hasValidAssignment = $false
    $lineNum = 0
    $paramCount = 0

    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }
        # Basic assignment check: ParameterName=Value...
        if ($trimmed -match '^[A-Za-z_][A-Za-z0-9_]*\s*=') {
            $hasValidAssignment = $true
            $paramCount++

            # Check format: constant vs optimization
            $parts = $trimmed.Split('=', 2)
            if ($parts.Count -eq 2) {
                $valuePart = $parts[1].Trim()
                if ($valuePart -match '\|\|') {
                    # Optimization format - validate structure
                    $optParts = $valuePart -split '\|\|'
                    if ($optParts.Count -lt 6) {
                        $warnings += "Line ${lineNum}: Optimization parameter may have incomplete fields (expected 6 '||' separated values): $trimmed"
                    }
                    else {
                        # Validate numeric fields for optimization
                        $min = $optParts[3].Trim()
                        $max = $optParts[4].Trim()
                        $step = $optParts[5].Trim()
                        if ($min -and -not ($min -match '^-?\d+(\.\d+)?$')) {
                            $issues += "Line ${lineNum}: Invalid Min value in optimization: $min"
                        }
                        if ($max -and -not ($max -match '^-?\d+(\.\d+)?$')) {
                            $issues += "Line ${lineNum}: Invalid Max value in optimization: $max"
                        }
                        if ($step -and -not ($step -match '^\d+(\.\d+)?$')) {
                            $issues += "Line ${lineNum}: Invalid Step value in optimization: $step"
                        }
                    }
                }
                else {
                    # Constant format - just validate value is present
                    if (-not $valuePart) {
                        $warnings += "Line ${lineNum}: Constant parameter has empty value: $trimmed"
                    }
                }
            }
        }
    }

    if (-not $hasValidAssignment) {
        $issues += "No valid parameter assignments found"
    }

    return [pscustomobject]@{
        Valid     = ($issues.Count -eq 0)
        Issues    = $issues
        Warnings  = $warnings
        ParamCount = $paramCount
    }
}

# Scans source files for broker mutation calls using token-based analysis
function Scan-BrokerMutations {
    param(
        [Parameter(Mandatory)][string[]]$SourceFiles,
        [Parameter()][string]$ApprovedBoundaryPattern = 'TradeExecutor\.mqh',  # File pattern for approved boundary
        [Parameter()][string[]]$ApprovedTradeClasses = @('TradeExecutor')  # Approved class names that may call broker mutation APIs
    )

    $results = @()
    $unauthorizedCalls = @()

    # Known broker mutation APIs from MQL5 Standard Library
    $mutationMethods = @(
        'OrderSend', 'OrderSendAsync',
        'Buy', 'Sell', 'BuyLimit', 'SellLimit', 'BuyStop', 'SellStop',
        'PositionOpen', 'PositionClose', 'PositionClosePartial', 'PositionModify',
        'OrderOpen', 'OrderDelete', 'OrderModify'
    )

    # CTrade and known project trade wrapper classes
    $tradeClasses = @('CTrade', 'CTradeExt', 'CTradeWrapper', 'TradeExecutor')

    foreach ($file in $SourceFiles) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            continue
        }
        $content = Get-Content -LiteralPath $file -Raw

        # Step 1: Remove comments and string literals, track line mapping
        $processed = Remove-CommentsAndStrings -Content $content
        $cleanLines = $processed.CleanContent -split "`r?`n"
        $lineMap = $processed.LineMap  # Maps clean line index to original line number

        # Step 2: Find variable declarations to track types
        $varTypes = @{}  # variable name -> type
        Find-VariableTypes -Lines $cleanLines -VarTypes $varTypes -TradeClasses $tradeClasses

        # Step 3: Scan for method calls using regex Match for position tracking
        $methodCallRegex = [regex]'\b(\w+)\.(\w+)\s*\('
        for ($i = 0; $i -lt $cleanLines.Count; $i++) {
            $line = $cleanLines[$i]
            $origLineNum = $lineMap[$i]

            $match = $methodCallRegex.Match($line)
            while ($match.Success) {
                $receiver = $match.Groups[1].Value
                $method = $match.Groups[2].Value

                # Check if this is a known mutation method
                $isMutation = $mutationMethods -contains $method

                if ($isMutation) {
                    # Determine receiver type
                    $receiverType = 'Unknown'
                    if ($varTypes.ContainsKey($receiver)) {
                        $receiverType = $varTypes[$receiver]
                    }
                    elseif ($receiver -in $tradeClasses) {
                        $receiverType = $receiver  # Static class call like CTrade.Buy()
                    }
                    elseif ($receiver -match '^m_') {
                        $receiverType = 'MemberVariable'  # Likely a class member
                    }

                    # Authorization: file matches approved boundary pattern OR receiver type is in approved trade classes list
                    $isFileAuthorized = $file -match $ApprovedBoundaryPattern
                    $isClassAuthorized = $ApprovedTradeClasses -contains $receiverType
                    $isAuthorized = $isFileAuthorized -or $isClassAuthorized
                    $isTradeClass = $tradeClasses -contains $receiverType
                    $isLikelyTradeCall = $isTradeClass -or $receiverType -eq 'MemberVariable'

                    $callInfo = [pscustomobject]@{
                        File            = $file
                        Line            = $origLineNum
                        Receiver        = $receiver
                        ReceiverType    = $receiverType
                        Method          = $method
                        IsTradeClass    = $isTradeClass
                        IsLikelyTradeCall = $isLikelyTradeCall
                        Authorized      = $isAuthorized
                        Code            = (Get-OriginalLine -File $file -Line $origLineNum).Trim()
                    }
                    $results += $callInfo

                    if (-not $isAuthorized -and $isLikelyTradeCall) {
                        $unauthorizedCalls += $callInfo
                    }
                    elseif (-not $isAuthorized -and -not $isLikelyTradeCall -and $receiverType -ne 'Unknown') {
                        # Non-trade class calling trade-like method - flag for review
                        $callInfo | Add-Member -MemberType NoteProperty -Name 'ReviewNeeded' -Value $true
                    }
                }

                # Continue searching rest of line using Match object position
                $line = $line.Substring($match.Index + $match.Length)
                $match = $methodCallRegex.Match($line)
            }
        }
    }

    return [pscustomobject]@{
        AllCalls          = $results
        UnauthorizedCalls = $unauthorizedCalls
    }
}

# Removes comments and string literals from source code, returns clean content and line mapping
function Remove-CommentsAndStrings {
    param([string]$Content)

    $lines = $Content -split "`r?`n"
    $cleanLines = @()
    $lineMap = @()  # clean line index -> original line number
    $inBlockComment = $false
    $cleanLineBuilder = ''

    for ($origLineNum = 0; $origLineNum -lt $lines.Count; $origLineNum++) {
        $line = $lines[$origLineNum]
        $i = 0
        $len = $line.Length
        $lineClean = ''

        while ($i -lt $len) {
            $ch = $line[$i]

            if ($inBlockComment) {
                if ($ch -eq '*' -and $i + 1 -lt $len -and $line[$i + 1] -eq '/') {
                    $inBlockComment = $false
                    $i += 2
                }
                else {
                    $i++
                }
            }
            elseif ($ch -eq '/' -and $i + 1 -lt $len) {
                $next = $line[$i + 1]
                if ($next -eq '/') {
                    # Line comment - skip rest of line
                    break
                }
                elseif ($next -eq '*') {
                    # Block comment start
                    $inBlockComment = $true
                    $i += 2
                }
                else {
                    $lineClean += $ch
                    $i++
                }
            }
            elseif ($ch -eq '"' -or $ch -eq "'") {
                # String literal - skip until closing quote (handling escapes)
                $quote = $ch
                $lineClean += ' '  # Replace with space to preserve column alignment
                $i++
                while ($i -lt $len) {
                    if ($line[$i] -eq '\\' -and $i + 1 -lt $len) {
                        $i += 2  # Skip escaped char
                    }
                    elseif ($line[$i] -eq $quote) {
                        $i++
                        break
                    }
                    else {
                        $i++
                    }
                }
            }
            else {
                $lineClean += $ch
                $i++
            }
        }

        if ($lineClean.Trim().Length -gt 0 -or -not $inBlockComment) {
            $cleanLines += $lineClean
            $lineMap += ($origLineNum + 1)  # 1-based line numbers
        }
    }

    return [pscustomobject]@{
        CleanContent = $cleanLines -join "`n"
        LineMap      = $lineMap
    }
}

# Finds variable declarations and their types
function Find-VariableTypes {
    param([string[]]$Lines, [hashtable]$VarTypes, [string[]]$TradeClasses)

    # Patterns for variable declarations: Type name = ... or Type name;
    # Also: CTrade name; or CTrade name = ...
    foreach ($line in $Lines) {
        # Match: Type identifier [= ...] [, identifier ...];
        if ($line -match '\b(CTrade\w*|CTrade|TradeExecutor)\s+(\w+)\s*[=;,]') {
            $type = $matches[1]
            $varName = $matches[2]
            $VarTypes[$varName] = $type
        }
        # Match: Type identifier [, identifier ...];
        if ($line -match '\b(CTrade\w*|CTrade|TradeExecutor)\s+(\w+)\s*;') {
            $type = $matches[1]
            $varName = $matches[2]
            $VarTypes[$varName] = $type
        }
    }
}

function Get-OriginalLine {
    param([string]$File, [int]$Line)
    $lines = Get-Content -LiteralPath $File
    if ($Line -ge 1 -and $Line -le $lines.Count) {
        return $lines[$Line - 1]
    }
    return ''
}

# Kills a process and its entire tree with fallback for older .NET versions
function Kill-ProcessTree {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 5
    )

    if (Test-ShouldProcess -Target "Kill process tree" -Action "Terminate PID $($Process.Id) and children") {
        try {
            # Try modern .NET Kill(entireProcessTree: true) first (available in .NET 5+/Core 3.1+)
            $killMethod = $Process.GetType().GetMethod('Kill', @([bool]))
            if ($killMethod) {
                $killMethod.Invoke($Process, @($true))
                # Wait for process to exit with timeout
                $Process.WaitForExit($TimeoutSeconds * 1000)
                return
            }
        }
        catch { }

        # Fallback: use taskkill.exe /T /F for the exact PID
        try {
            $taskkill = 'taskkill.exe'
            $args = "/PID $($Process.Id) /T /F"
            $result = Start-Process -FilePath $taskkill -ArgumentList $args -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
            if ($result.ExitCode -eq 0) {
                return
            }
        }
        catch { }

        # Last resort: try standard Kill (no tree)
        try {
            $Process.Kill()
            $Process.WaitForExit($TimeoutSeconds * 1000)
        }
        catch { }
    }
    else {
        Write-Host "WhatIf: Would kill process tree for PID $($Process.Id)"
    }
}

function Write-ValidationStep {
    param(
        [Parameter(Mandatory)][string]$StepName,
        [Parameter(Mandatory)][ValidateSet('START','PASS','FAIL','SKIP','WARN','NOT_APPLICABLE','NOT_VERIFIED')][string]$Status,
        [string]$Detail = ''
    )
    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    $prefix = switch ($Status) {
        'START'             { '[>>]' }
        'PASS'              { '[OK]' }
        'FAIL'              { '[!!]' }
        'SKIP'              { '[--]' }
        'WARN'              { '[!!]' }
        'NOT_APPLICABLE'    { '[NA]' }
        'NOT_VERIFIED'      { '[?]' }
    }
    $msg = "$timestamp $prefix $StepName"
    if ($Detail) { $msg += " - $Detail" }
    Write-Host $msg
}

# Atomic JSON write with validation
function Write-JsonReport {
    param(
        [Parameter(Mandatory)][pscustomobject]$Report,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $tempPath = [System.IO.Path]::ChangeExtension($Path, '.tmp')
    try {
        $json = $Report | ConvertTo-Json -Depth 10 -Compress
        $json | Set-Content -LiteralPath $tempPath -Encoding UTF8 -Force

        # Validate by reading back
        $readBack = Get-Content -LiteralPath $tempPath -Raw -Encoding UTF8
        $parsed = $readBack | ConvertFrom-Json -ErrorAction Stop

        # Verify required fields
        $requiredFields = @('ValidationStartUtc', 'ValidationEndUtc', 'DurationSeconds', 'OverallExitCode', 'Summary', 'Results', 'Environment')
        foreach ($field in $requiredFields) {
            if (-not $parsed.PSObject.Properties.Match($field)) {
                throw "JSON validation failed: missing required field '$field'"
            }
        }

        # Verify count consistency
        $totalResults = $parsed.Results.Count
        $sumCounts = $parsed.Summary.Passed + $parsed.Summary.Failed + $parsed.Summary.Warning + $parsed.Summary.Skipped + $parsed.Summary.NotApplicable + $parsed.Summary.NotVerified + $parsed.Summary.AcceptedWarning
        if ($totalResults -ne $sumCounts) {
            throw "JSON validation failed: count mismatch (total=$totalResults, sum=$sumCounts)"
        }

        # Atomic replace
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
        return $true
    }
    catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw "JSON report write/validation failed: $($_.Exception.Message)"
    }
}

# Aggregates exit code from all results using deterministic priority table
function Get-AggregatedExitCode {
    param(
        [Parameter(Mandatory)][pscustomobject[]]$Results,
        [switch]$StrictMode
    )

    # Define priority order for statuses (higher number = higher priority)
    $statusPriority = @{
        'FAILED'             = 100
        'NOT_VERIFIED'       = 50   # Only in strict mode
        'WARNING'            = 20
        'ACCEPTED_WARNING'   = 10
        'PASSED'             = 0
        'SKIPPED'            = 0
        'NOT_APPLICABLE'     = 0
    }

    # Define severity priority within FAILED status
    $severityPriority = @{
        'CRITICAL' = 100
        'HIGH'     = 50
        'MEDIUM'   = 20
        'LOW'      = 10
        'INFO'     = 0
    }

    # Find highest priority status
    $maxStatusPriority = -1
    $maxSeverityPriority = -1
    $selectedExitCode = 0
    $selectedStatus = ''

    foreach ($r in $Results) {
        $statusPri = $statusPriority[$r.Status]
        if ($null -eq $statusPri) { $statusPri = -1 }

        # Skip NOT_VERIFIED unless strict mode
        if ($r.Status -eq 'NOT_VERIFIED' -and -not $StrictMode) {
            $statusPri = 0
        }

        if ($statusPri -gt $maxStatusPriority) {
            $maxStatusPriority = $statusPri
            $maxSeverityPriority = $severityPriority[$r.Severity]
            $selectedExitCode = $r.ExitCode
            $selectedStatus = $r.Status
        }
        elseif ($statusPri -eq $maxStatusPriority) {
            $sevPri = $severityPriority[$r.Severity]
            if ($null -eq $sevPri) { $sevPri = 0 }
            if ($sevPri -gt $maxSeverityPriority) {
                $maxSeverityPriority = $sevPri
                $selectedExitCode = $r.ExitCode
                $selectedStatus = $r.Status
            }
        }
    }

    # In strict mode, NOT_VERIFIED as highest priority maps to STRICT_VERIFICATION_FAILED (18)
    if ($StrictMode -and $selectedStatus -eq 'NOT_VERIFIED') {
        return 18  # $ExitCodes.STRICT_VERIFICATION_FAILED
    }

    return $selectedExitCode
}

#endregion

#region Global State

$validationResults = @()
$validationStartUtc = Get-UtcTimestamp
$validationStartDt = [DateTimeOffset]::UtcNow
$scriptError = $null

#endregion

#region Main Execution

try {
    Write-Host '=== AlgoMultiAssetEA Validation Harness ==='
    Write-Host "Started at (UTC) : $validationStartUtc"
    Write-Host ''

    # =========================================================================
    # STEP 1: Environment Resolution
    # =========================================================================
    $stepStart = [DateTimeOffset]::UtcNow
    $result = New-ValidationResult -Id 'ENV-001' -Name 'EnvironmentResolution' -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message 'Resolving environment paths'
    $validationResults += $result

    Write-ValidationStep 'Environment Resolution' 'START'

    try {
        $TerminalInstallRoot = Resolve-ExistingDirectory -Path $TerminalInstallRoot -Label 'MetaTrader installation'
        $ProjectMql5Root = Resolve-ExistingDirectory -Path $ProjectMql5Root -Label 'Project MQL5 data root'

        $metaEditor = Join-Path $TerminalInstallRoot 'metaeditor64.exe'
        $terminalExe = Join-Path $TerminalInstallRoot 'terminal64.exe'
        $testerExe = Join-Path $TerminalInstallRoot 'metatester64.exe'

        if (-not (Test-Path -LiteralPath $metaEditor -PathType Leaf)) {
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "MetaEditor compiler was not found: $metaEditor" -FailureReason 'MetaEditor not found' -Severity 'CRITICAL' -ExitCode $ExitCodes.SCRIPT_ERROR
        }
        else {
            if (-not (Test-Path -LiteralPath $terminalExe -PathType Leaf)) {
                Write-Warning "terminal64.exe was not found beside MetaEditor: $terminalExe. Terminal identity cannot be cross-checked."
            }
            if (-not (Test-Path -LiteralPath $testerExe -PathType Leaf)) {
                Write-Warning "metatester64.exe was not found beside MetaEditor: $testerExe. Strategy Tester validation will be limited."
            }

            if ([string]::IsNullOrWhiteSpace($IncludeMql5Root)) {
                $IncludeMql5Root = $ProjectMql5Root
            }
            $IncludeMql5Root = Resolve-ExistingDirectory -Path $IncludeMql5Root -Label 'MQL5 include root'

            $includeDirectory = Join-Path $IncludeMql5Root 'Include'
            if (-not (Test-Path -LiteralPath $includeDirectory -PathType Container)) {
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "The /include root must contain an Include directory. Expected: $includeDirectory" -FailureReason 'Include directory missing' -Severity 'CRITICAL' -ExitCode $ExitCodes.SCRIPT_ERROR
            }
            else {
                $sourcePath = Join-Path $ProjectMql5Root $SourceRelativePath
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Main MQ5 source was not found: $sourcePath" -FailureReason 'Source file missing' -Severity 'CRITICAL' -ExitCode $ExitCodes.SCRIPT_ERROR
                }
                else {
                    $sourcePath = (Resolve-Path -LiteralPath $sourcePath).Path

                    $ex5Path = [System.IO.Path]::ChangeExtension($sourcePath, '.ex5')

                    $metaEditorInfo = Get-VersionSummary -Path $metaEditor

                    Write-ValidationStep 'Environment Resolution' 'PASS' "MetaEditor: $($metaEditorInfo.FileVersion), Project: $ProjectMql5Root"
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "Environment resolved successfully" -Evidence @(
                        "MetaEditor: $($metaEditorInfo.FileVersion) at $metaEditor",
                        "Project root: $ProjectMql5Root",
                        "Include root: $IncludeMql5Root",
                        "Source: $sourcePath"
                    )
}
        }
    }
}
catch {
        Write-ValidationStep 'Environment Resolution' 'FAIL' $_.Exception.Message
        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message $_.Exception.Message -FailureReason $_.Exception.Message -Severity 'CRITICAL' -ExitCode $ExitCodes.SCRIPT_ERROR
        # Do not throw - let aggregation handle exit code
    }

    # =========================================================================
    # STEP 2: Standard Library Consistency Check (VH-03)
    # =========================================================================
    $result = New-ValidationResult -Id 'STD-001' -Name 'StandardLibraryConsistency' -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message 'Checking Standard Library consistency'
    $validationResults += $result
    Write-ValidationStep 'Standard Library Consistency' 'START'

    $expectedHistoryHeader = Join-Path $IncludeMql5Root 'Include\Trade\HistoryOrderInfo.mqh'
    $installHistoryHeader = Join-Path (Join-Path $TerminalInstallRoot 'MQL5') 'Include\Trade\HistoryOrderInfo.mqh'
    $libraryCheck = Get-StandardLibraryConsistency -ProjectFilePath $expectedHistoryHeader -InstallFilePath $installHistoryHeader
    $evidence = @(
        "Project file: $expectedHistoryHeader (Exists: $($libraryCheck.ProjectExists), Hash: $(if ($libraryCheck.ProjectHash) { $libraryCheck.ProjectHash } else { 'N/A' }))",
        "Install file: $installHistoryHeader (Exists: $($libraryCheck.InstallExists), Hash: $(if ($libraryCheck.InstallHash) { $libraryCheck.InstallHash } else { 'N/A' }))"
    )

    switch ($libraryCheck.Status) {
        'PASSED' {
            Write-ValidationStep 'Standard Library Consistency' 'PASS' $libraryCheck.Message
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message $libraryCheck.Message -Evidence $evidence
        }
        'WARNING' {
            Write-ValidationStep 'Standard Library Consistency' 'WARN' $libraryCheck.Message
            $status = if ($WarningsAsErrors) { 'FAILED' } else { 'WARNING' }
            $exitCode = if ($WarningsAsErrors) { $ExitCodes.STDLIB_FAILED } else { 0 }
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status $status -Message $libraryCheck.Message -Evidence $evidence -FailureReason $libraryCheck.FailureReason -ExitCode $exitCode
        }
        'FAILED' {
            Write-ValidationStep 'Standard Library Consistency' 'FAIL' $libraryCheck.Message
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message $libraryCheck.Message -Evidence $evidence -FailureReason $libraryCheck.FailureReason -ExitCode $ExitCodes.STDLIB_FAILED
        }
        default { throw "Unexpected Standard Library check status: $($libraryCheck.Status)" }
    }

    # STEP 3: Terminal Data Folder Origin Verification
    # =========================================================================
    $result = New-ValidationResult -Id 'ORG-001' -Name 'TerminalDataFolderOrigin' -Status 'NOT_VERIFIED' -Severity 'MEDIUM' -Message 'Verifying terminal data folder origin'
    $validationResults += $result
    Write-ValidationStep 'Terminal Data Folder Origin' 'START'

    $dataRoot = Split-Path -Parent $ProjectMql5Root
    $originFile = Join-Path $dataRoot 'origin.txt'
    $originValue = $null
    $originVerified = $false

    if (Test-Path -LiteralPath $originFile -PathType Leaf) {
        $originValue = (Get-Content -LiteralPath $originFile -Raw).Trim()
        if ($originValue) {
            try {
                $originResolved = (Resolve-Path -LiteralPath $originValue -ErrorAction Stop).Path.TrimEnd('\')
                $installResolved = $TerminalInstallRoot.TrimEnd('\')
                if ([string]::Equals($originResolved, $installResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $originVerified = $true
                    Write-ValidationStep 'Terminal Data Folder Origin' 'PASS' "origin.txt maps to $installResolved"
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message 'Terminal data folder origin verified' -Evidence @("origin.txt: $originValue", "Resolved: $originResolved")
                }
                else {
                    Write-ValidationStep 'Terminal Data Folder Origin' 'WARN' "origin.txt maps to '$originResolved', not '$installResolved'"
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message 'Terminal data folder origin mismatch' -Evidence @("origin.txt: $originValue", "Resolved: $originResolved", "Expected: $installResolved") -FailureReason 'Origin path mismatch'
                }
            }
            catch {
                Write-ValidationStep 'Terminal Data Folder Origin' 'WARN' "Could not resolve origin.txt value: $($_.Exception.Message)"
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message 'Origin.txt unresolvable' -Evidence @("origin.txt: $originValue", "Error: $($_.Exception.Message)") -FailureReason 'Origin resolution failed'
            }
        }
        else {
            Write-ValidationStep 'Terminal Data Folder Origin' 'WARN' 'origin.txt exists but is empty'
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message 'origin.txt empty' -Evidence @('origin.txt exists but empty')
        }
    }
    else {
        Write-ValidationStep 'Terminal Data Folder Origin' 'WARN' "No origin.txt found at '$originFile'"
        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message 'origin.txt not found' -Evidence @("Expected path: $originFile") -FailureReason 'origin.txt missing'
    }

    # =========================================================================
    # STEP 4: Project Structure Validation
    # =========================================================================
    $result = New-ValidationResult -Id 'STR-001' -Name 'ProjectStructure' -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message 'Validating project structure'
    $validationResults += $result
    Write-ValidationStep 'Project Structure Validation' 'START'

    $requiredPaths = @(
        @{ Path = 'Experts\AlgoMultiAssetEA.mq5'; Type = 'Leaf'; Label = 'Main EA entry point' },
        @{ Path = 'Include\AlgoSystem\Types.mqh'; Type = 'Leaf'; Label = 'Core type definitions' },
        @{ Path = 'Include\AlgoSystem\Constants.mqh'; Type = 'Leaf'; Label = 'System constants' },
        @{ Path = 'Include\AlgoSystem\Interfaces.mqh'; Type = 'Leaf'; Label = 'Interface contracts' },
        @{ Path = 'Include\AlgoSystem\Config.mqh'; Type = 'Leaf'; Label = 'Configuration definitions' },
        @{ Path = 'Include\AlgoSystem\Logger.mqh'; Type = 'Leaf'; Label = 'Logging infrastructure' },
        @{ Path = 'Include\AlgoSystem\MarketData.mqh'; Type = 'Leaf'; Label = 'Market data layer' },
        @{ Path = 'Include\AlgoSystem\Indicators.mqh'; Type = 'Leaf'; Label = 'Indicator wrappers' },
        @{ Path = 'Include\AlgoSystem\RegimeEngine.mqh'; Type = 'Leaf'; Label = 'Regime detection' },
        @{ Path = 'Include\AlgoSystem\SignalEngine.mqh'; Type = 'Leaf'; Label = 'Signal generation' },
        @{ Path = 'Include\AlgoSystem\RiskEngine.mqh'; Type = 'Leaf'; Label = 'Risk evaluation' },
        @{ Path = 'Include\AlgoSystem\PortfolioRisk.mqh'; Type = 'Leaf'; Label = 'Portfolio risk' },
        @{ Path = 'Include\AlgoSystem\TradeExecutor.mqh'; Type = 'Leaf'; Label = 'Trade execution' },
        @{ Path = 'Include\AlgoSystem\PositionManager.mqh'; Type = 'Leaf'; Label = 'Position management' },
        @{ Path = 'Include\AlgoSystem\StateManager.mqh'; Type = 'Leaf'; Label = 'State persistence' },
        @{ Path = 'Include\AlgoSystem\ExecutionLedger.mqh'; Type = 'Leaf'; Label = 'Execution ledger' },
        @{ Path = 'Include\AlgoSystem\HybridTypes.mqh'; Type = 'Leaf'; Label = 'Hybrid strategy types' },
        @{ Path = 'Include\AlgoSystem\HybridEngine.mqh'; Type = 'Leaf'; Label = 'Hybrid strategy engine' },
        @{ Path = 'Include\AlgoSystem\HybridDashboard.mqh'; Type = 'Leaf'; Label = 'Hybrid dashboard' },
        @{ Path = 'Include\AlgoSystem\NewsRiskService.mqh'; Type = 'Leaf'; Label = 'News risk service' },
        @{ Path = 'Include\AlgoSystem\Dashboard.mqh'; Type = 'Leaf'; Label = 'Main dashboard' },
        @{ Path = 'Include\AlgoSystem\Statistics.mqh'; Type = 'Leaf'; Label = 'Statistics tracking' },
        @{ Path = 'Include\AlgoSystem\TesterFitness.mqh'; Type = 'Leaf'; Label = 'Tester fitness' },
        @{ Path = 'Include\AlgoSystem\Optimization.mqh'; Type = 'Leaf'; Label = 'Optimization support' },
        @{ Path = 'Include\AlgoSystem\Robustness.mqh'; Type = 'Leaf'; Label = 'Robustness checks' },
        @{ Path = 'Include\AlgoSystem\WalkForward.mqh'; Type = 'Leaf'; Label = 'Walk-forward analysis' },
        @{ Path = 'Include\AlgoSystem\VolumeProfile.mqh'; Type = 'Leaf'; Label = 'Volume profile' },
        @{ Path = 'Include\AlgoSystem\Utilities.mqh'; Type = 'Leaf'; Label = 'Utilities' },
        @{ Path = 'Include\AlgoSystem\TrendStrategy.mqh'; Type = 'Leaf'; Label = 'Trend strategy' },
        @{ Path = 'Include\AlgoSystem\BreakoutStrategy.mqh'; Type = 'Leaf'; Label = 'Breakout strategy' },
        @{ Path = 'Include\AlgoSystem\MomentumStrategy.mqh'; Type = 'Leaf'; Label = 'Momentum strategy' },
        @{ Path = 'Include\AlgoSystem\MomentumEngine.mqh'; Type = 'Leaf'; Label = 'Momentum engine' },
        @{ Path = 'Include\AlgoSystem\MeanReversionStrategy.mqh'; Type = 'Leaf'; Label = 'Mean reversion strategy' },
        @{ Path = 'Include\AlgoSystem\RelativeValueStrategy.mqh'; Type = 'Leaf'; Label = 'Relative value strategy' },
        @{ Path = 'Include\AlgoSystem\BiasEngine.mqh'; Type = 'Leaf'; Label = 'Bias engine' },
        @{ Path = 'Include\AlgoSystem\DivergenceEngine.mqh'; Type = 'Leaf'; Label = 'Divergence engine' },
        @{ Path = 'Include\AlgoSystem\LiquidityEngine.mqh'; Type = 'Leaf'; Label = 'Liquidity engine' },
        @{ Path = 'Include\AlgoSystem\SessionFilter.mqh'; Type = 'Leaf'; Label = 'Session filter' }
    )

    $missingPaths = @()
    foreach ($req in $requiredPaths) {
        $fullPath = Join-Path $ProjectMql5Root $req.Path
        if (-not (Test-Path -LiteralPath $fullPath -PathType $req.Type)) {
            $missingPaths += [pscustomobject]@{
                Path  = $req.Path
                Label = $req.Label
            }
        }
    }

    if ($missingPaths.Count -gt 0) {
        Write-ValidationStep 'Project Structure Validation' 'FAIL' "$($missingPaths.Count) required files missing"
        foreach ($m in $missingPaths) { Write-Host "  MISSING: $($m.Path) - $($m.Label)" }
        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "$($missingPaths.Count) required files missing" -Evidence @($missingPaths | ForEach-Object { "$($_.Path) - $($_.Label)" }) -FailureReason 'Missing required project files' -Severity 'CRITICAL' -ExitCode $ExitCodes.STRUCTURE_FAILED
        # Do not throw - let aggregation handle exit code
    }
    else {
        Write-ValidationStep 'Project Structure Validation' 'PASS' "All $($requiredPaths.Count) required files present"
        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "All required files verified" -Evidence @("Total files checked: $($requiredPaths.Count)")
    }

    # =========================================================================
    # STEP 5: Configuration File Validation (VH-07)
    # =========================================================================
    $result = New-ValidationResult -Id 'CFG-001' -Name 'ConfigurationValidation' -Status 'NOT_VERIFIED' -Severity 'MEDIUM' -Message 'Validating configuration files'
    $validationResults += $result
    $cfgParentIndex = $validationResults.Count - 1
    Write-ValidationStep 'Configuration Validation' 'START'

    $requiredSetFiles = $RequiredSetFiles -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $optionalSetFiles = $OptionalSetFiles -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    $allConfigIssues = @()
    $validatedRequired = 0
    $validatedOptional = 0

    # Validate required SET files
    foreach ($relPath in $requiredSetFiles) {
        $fullPath = Join-Path $ProjectMql5Root $relPath
        $fileResult = New-ValidationResult -Id "CFG-SET-$([System.IO.Path]::GetFileNameWithoutExtension($relPath))" -Name "SetFile:$relPath" -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message "Validating required SET file: $relPath"
        $validationResults += $fileResult

        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            try {
                $content = Get-Content -LiteralPath $fullPath -Raw
                $validation = Validate-SetFile -Content $content -FilePath $fullPath
                if ($validation.Valid) {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "Required SET file valid: $relPath" -Evidence @("Path: $fullPath")
                    $validatedRequired++
                }
                else {
                    $issues = $validation.Issues -join '; '
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Required SET file invalid: $relPath" -Evidence @("Path: $fullPath", "Issues: $issues") -FailureReason $issues -Severity 'HIGH' -ExitCode $ExitCodes.SET_VALIDATION_FAILED
                    $allConfigIssues += "Required SET ${relPath}: $issues"
                }
            }
            catch {
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Required SET file read error: $relPath" -Evidence @("Path: $fullPath", "Error: $($_.Exception.Message)") -FailureReason $_.Exception.Message -Severity 'HIGH' -ExitCode $ExitCodes.SET_VALIDATION_FAILED
                $allConfigIssues += "Required SET ${relPath}: Read error - $($_.Exception.Message)"
            }
        }
        else {
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Required SET file missing: $relPath" -Evidence @("Expected path: $fullPath") -FailureReason 'Required SET file not found' -Severity 'CRITICAL' -ExitCode $ExitCodes.SET_VALIDATION_FAILED
            $allConfigIssues += "Required SET file missing: $relPath"
        }
    }

    # Validate optional SET files
    foreach ($relPath in $optionalSetFiles) {
        $fullPath = Join-Path $ProjectMql5Root $relPath
        $fileResult = New-ValidationResult -Id "CFG-SET-OPT-$([System.IO.Path]::GetFileNameWithoutExtension($relPath))" -Name "SetFile:$relPath" -Status 'NOT_VERIFIED' -Severity 'LOW' -Message "Validating optional SET file: $relPath"
        $validationResults += $fileResult

        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            try {
                $content = Get-Content -LiteralPath $fullPath -Raw
                $validation = Validate-SetFile -Content $content -FilePath $fullPath
                if ($validation.Valid) {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "Optional SET file valid: $relPath" -Evidence @("Path: $fullPath")
                    $validatedOptional++
                }
                else {
                    $issues = $validation.Issues -join '; '
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message "Optional SET file has issues: $relPath" -Evidence @("Path: $fullPath", "Issues: $issues") -FailureReason $issues
                    $allConfigIssues += "Optional SET ${relPath}: $issues"
                }
            }
            catch {
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message "Optional SET file read error: $relPath" -Evidence @("Path: $fullPath", "Error: $($_.Exception.Message)") -FailureReason $_.Exception.Message
                $allConfigIssues += "Optional SET ${relPath}: Read error - $($_.Exception.Message)"
            }
        }
        else {
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'NOT_APPLICABLE' -Message "Optional SET file not present: $relPath" -Evidence @("Expected path: $fullPath") -NotApplicableReason 'Optional file not configured'
        }
    }

    # Overall configuration status
    if ($allConfigIssues.Count -gt 0) {
        $hasRequiredFailure = $validationResults | Where-Object { $_.Name -like 'SetFile:*' -and $_.Severity -eq 'HIGH' -and $_.Status -eq 'FAILED' }
        if ($hasRequiredFailure) {
            Write-ValidationStep 'Configuration Validation' 'FAIL' "$($allConfigIssues.Count) issue(s) including required file failures"
            Update-ValidationResult -Index $cfgParentIndex -Status 'FAILED' -Message "Configuration validation failed" -Evidence $allConfigIssues -FailureReason 'Required SET file validation failed' -Severity 'HIGH' -ExitCode $ExitCodes.SET_VALIDATION_FAILED
            # Do not throw - let aggregation handle exit code
        }
        else {
            Write-ValidationStep 'Configuration Validation' 'WARN' "$($allConfigIssues.Count) issue(s) in optional files"
            Update-ValidationResult -Index $cfgParentIndex -Status 'WARNING' -Message "Configuration validation has warnings" -Evidence $allConfigIssues -FailureReason 'Optional SET file issues'
        }
    }
    else {
        $totalValidated = $validatedRequired + $validatedOptional
        if ($totalValidated -eq 0 -and $requiredSetFiles.Count -eq 0) {
            Write-ValidationStep 'Configuration Validation' 'NOT_APPLICABLE' 'No SET files configured'
            Update-ValidationResult -Index $cfgParentIndex -Status 'NOT_APPLICABLE' -Message 'No SET files configured for validation' -NotApplicableReason 'No required or optional SET files specified'
        }
        else {
            Write-ValidationStep 'Configuration Validation' 'PASS' "All $totalValidated SET file(s) valid ($validatedRequired required, $validatedOptional optional)"
            Update-ValidationResult -Index $cfgParentIndex -Status 'PASSED' -Message "All configuration files valid" -Evidence @("Required: $validatedRequired, Optional: $validatedOptional")
        }
    }

    # =========================================================================
    # STEP 6: Compilation Validation (VH-04, VH-08)
    # =========================================================================
    if (-not $SkipCompile) {
        $result = New-ValidationResult -Id 'CMP-001' -Name 'Compilation' -Status 'NOT_VERIFIED' -Severity 'CRITICAL' -Message 'Compiling project with MetaEditor'
        $validationResults += $result
        Write-ValidationStep 'Compilation Validation' 'START'

        $archiveDirectory = Join-Path $ProjectMql5Root $ArchiveDirectoryRelativePath
        if (-not (Test-Path -LiteralPath $archiveDirectory -PathType Container)) {
            if (Test-ShouldProcess -Target $archiveDirectory -Action 'Create archive directory') {
                New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
            }
        }

        $sourceLog = [System.IO.Path]::ChangeExtension($sourcePath, '.log')

        # Archive previous log if exists
        if (Test-Path -LiteralPath $sourceLog -PathType Leaf) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
            $archivedPreviousLog = Join-Path $archiveDirectory ("AlgoMultiAssetEA.validation-previous-$stamp.log")
            if (Test-ShouldProcess -Target $sourceLog -Action "Archive to $archivedPreviousLog") {
                Move-Item -LiteralPath $sourceLog -Destination $archivedPreviousLog
                Write-Host "Previous compile log preserved at: $archivedPreviousLog"
            }
        }

        $ex5BeforeHash = $null
        $ex5BeforeTime = $null
        if (Test-Path -LiteralPath $ex5Path -PathType Leaf) {
            $ex5BeforeHash = Get-FileHashSafe $ex5Path
            $ex5BeforeTime = (Get-Item -LiteralPath $ex5Path).LastWriteTimeUtc
        }

        $compileStartUtc = [DateTimeOffset]::UtcNow
        $argumentLine = '/compile:"{0}" /include:"{1}" /log' -f $sourcePath, $IncludeMql5Root

Write-Host '=== AlgoMultiAssetEA Compilation (Validation) ==='
        Write-Host "MetaEditor   : $($metaEditorInfo.Path)"
        Write-Host "File version : $($metaEditorInfo.FileVersion)"
        Write-Host "Source       : $sourcePath"
        Write-Host "Include root : $IncludeMql5Root"
        Write-Host "Arguments    : $argumentLine"
        Write-Host ''

        # Execute MetaEditor with timeout (guarded by ShouldProcess)
        $process = $null
        $processExitCode = -1
        $timedOut = $false

        $shouldCompile = $true
        if (Test-ShouldProcess -Target "MetaEditor compilation" -Action "Compile $sourcePath with MetaEditor") {
            try {
                $process = Start-Process -FilePath $metaEditor -ArgumentList $argumentLine -WorkingDirectory $TerminalInstallRoot -PassThru -ErrorAction Stop

                if ($CompileTimeoutSeconds -gt 0) {
                    $waitResult = $process.WaitForExit($CompileTimeoutSeconds * 1000)
                    if (-not $waitResult) {
                        $timedOut = $true
                        # Kill process tree with fallback
                        try {
                            $proc = Get-Process -Id $process.Id -ErrorAction Stop
                            Kill-ProcessTree -Process $proc
                        } catch { }
                        # Do not throw - catch block will handle timeout
                    }
                }
                else {
                    $process.WaitForExit()
                }

                $processExitCode = $process.ExitCode
            }
            catch {
                if ($timedOut) {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Compilation timed out after $CompileTimeoutSeconds seconds" -FailureReason 'Compilation timeout' -Severity 'CRITICAL' -ExitCode $ExitCodes.COMPILE_TIMEOUT
                }
                else {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message $_.Exception.Message -FailureReason $_.Exception.Message -Severity 'CRITICAL' -ExitCode $ExitCodes.SCRIPT_ERROR
                }
                # Do not throw - let aggregation handle exit code
            }
        }
        else {
            Write-Host "WhatIf: Would compile $sourcePath with MetaEditor"
            # In WhatIf mode, skip actual compilation
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WOULD_RUN' -Message "Compilation would run (WhatIf mode)" -NotApplicableReason 'WhatIf specified'
            $shouldCompile = $false
        }

        # Verify fresh log was created
        if (-not (Test-Path -LiteralPath $sourceLog -PathType Leaf)) {
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "MetaEditor did not create compilation log" -FailureReason 'Missing compilation log' -Severity 'CRITICAL' -ExitCode $ExitCodes.COMPILE_FAILED
            # Do not throw - let aggregation handle exit code
        }
        else {
            $logItem = Get-Item -LiteralPath $sourceLog
            if ($logItem.LastWriteTimeUtc -lt $compileStartUtc.AddSeconds(-2)) {
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Compilation log is stale (older than compile start)" -FailureReason 'Stale compilation log' -Severity 'CRITICAL' -ExitCode $ExitCodes.COMPILE_FAILED
                # Do not throw - let aggregation handle exit code
            }
            else {
                $logLines = @(Get-Content -LiteralPath $sourceLog -Encoding UTF8)
                if ($logLines.Count -eq 0) {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Compilation log is empty" -FailureReason 'Empty compilation log' -Severity 'CRITICAL' -ExitCode $ExitCodes.COMPILE_PARSE_FAILED
                    # Do not throw - let aggregation handle exit code
                }
                else {
                    $summary = Parse-CompileLog -Lines $logLines

                    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
                    $archivedCurrentLog = Join-Path $archiveDirectory ("AlgoMultiAssetEA.validation-$stamp.log")
                    if (Test-ShouldProcess -Target $sourceLog -Action "Archive to $archivedCurrentLog") {
                        Copy-Item -LiteralPath $sourceLog -Destination $archivedCurrentLog
                    }

                    # Verify EX5 freshness (VH-08)
                    $ex5Generated = $false
                    $ex5AfterHash = $null
                    $ex5AfterTime = $null
                    if (Test-Path -LiteralPath $ex5Path -PathType Leaf) {
                        $ex5Item = Get-Item -LiteralPath $ex5Path
                        $ex5AfterTime = $ex5Item.LastWriteTimeUtc
                        $ex5AfterHash = Get-FileHashSafe $ex5Path
                        $freshness = Test-FreshEx5Artifact -BeforeHash $ex5BeforeHash -BeforeArtifactExists:($null -ne $ex5BeforeTime) -BeforeWriteTimeUtc $ex5BeforeTime -AfterHash $ex5AfterHash -AfterWriteTimeUtc $ex5AfterTime -CompileStartUtc $compileStartUtc.UtcDateTime -Length $ex5Item.Length
                        $ex5Generated = $freshness.IsFresh
                    }

                    Write-Host ''
                    Write-Host '=== Compilation Result ==='
                    Write-Host "MetaEditor exit code : $processExitCode"
                    Write-Host "Compiler summary     : $(if ($summary.SummaryFound) { 'FOUND' } else { 'MISSING' })"
                    Write-Host "Errors               : $($summary.Errors)"
                    Write-Host "Warnings             : $($summary.Warnings)"
                    Write-Host "Raw summary          : $($summary.RawSummary)"
                    Write-Host "Fresh log            : $sourceLog"
                    Write-Host "Archived log         : $archivedCurrentLog"
                    Write-Host "EX5 generated        : $ex5Generated"
                    if ($ex5AfterHash) { Write-Host "EX5 hash             : $ex5AfterHash" }
                    if ($ex5BeforeHash) { Write-Host "EX5 hash unchanged   : $($ex5BeforeHash -eq $ex5AfterHash)" }

                    if ($summary.ErrorLines.Count -gt 0) {
                        Write-Host "`nCompiler error lines:"
                        $summary.ErrorLines | ForEach-Object { Write-Host "  $_" }
                    }
                    if ($summary.WarningLines.Count -gt 0) {
                        Write-Host "`nCompiler warning lines:"
                        $summary.WarningLines | ForEach-Object { Write-Host "  $_" }
                    }

                    # Determine compilation status
                    $compileFailed = $false
                    $compileWarnings = $false
                    $compileNotVerified = $false

                    if ($processExitCode -ne 0 -and -not $summary.SummaryFound) {
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "MetaEditor exit code $processExitCode with no compiler summary" -FailureReason 'Non-zero exit code and missing summary' -Severity 'CRITICAL' -Evidence @("Exit code: $processExitCode", "Log lines: $($logLines.Count)") -ExitCode $ExitCodes.COMPILE_FAILED
                        # Do not throw - let aggregation handle exit code
                    }
                    if ($processExitCode -ne 0) {
                        Write-Warning "MetaEditor returned exit code $processExitCode, but compiler summary reports $($summary.Errors) errors and $($summary.Warnings) warnings."
                    }

                    if (-not $summary.SummaryFound) {
                        $compileNotVerified = $true
                        Write-Warning "Compiler summary not found in log. Treating as NOT_VERIFIED."
                    }

                    if ($summary.Errors -gt 0) {
                        $compileFailed = $true
                    }
                    elseif ($summary.Warnings -gt 0) {
                        if ($WarningsAsErrors -or $summary.Warnings -gt $MaxAllowedWarnings) {
                            $compileFailed = $true
                            Write-Host "COMPILE: FAILED (warnings treated as errors: $($summary.Warnings) > $MaxAllowedWarnings)"
                        }
                        else {
                            $compileWarnings = $true
                            Write-Host "COMPILE: PASSED WITH WARNINGS ($($summary.Warnings) warning(s), max allowed: $MaxAllowedWarnings)"
                        }
                    }
                    else {
                        Write-Host 'COMPILE: PASSED (0 errors, 0 warnings)'
                    }

                    # Fresh EX5 verification (VH-08) - ALWAYS required when compilation runs
                    if (-not $ex5Generated) {
                        $msg = "Fresh EX5 not verified after compilation (ex5Generated=$ex5Generated, path=$ex5Path)"
                        if ($compileFailed -or $compileWarnings) {
                            # If compilation had errors/warnings, EX5 might not be generated - that's expected
                            Write-Host "EX5 not freshly generated (expected due to compilation issues)"
                        }
                        else {
                            # Clean compilation but no fresh EX5 = FAILURE
                            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message $msg -FailureReason 'Fresh EX5 missing after clean compilation' -Severity 'CRITICAL' -Evidence @(
                                "EX5 path: $ex5Path",
                                "EX5 before hash: $ex5BeforeHash",
                                "EX5 after hash: $ex5AfterHash",
                                "EX5 before time: $ex5BeforeTime",
                                "EX5 after time: $ex5AfterTime",
                                "Compile start UTC: $compileStartUtc"
                            ) -ExitCode $ExitCodes.FRESH_EX5_FAILED
                            # Do not throw - let aggregation handle exit code
                        }
                    }
                    else {
                        Write-Host "EX5 path             : $ex5Path"
                        Write-Host "EX5 last write UTC   : $ex5AfterTime"
                        Write-Host "EX5 SHA256           : $ex5AfterHash"
                        $hashUnchanged = $ex5BeforeHash -and ($ex5BeforeHash -eq $ex5AfterHash)
                        $timeUnchanged = $ex5BeforeTime -and ($ex5BeforeTime -eq $ex5AfterTime)
                        Write-Host "EX5 hash unchanged   : $hashUnchanged"
                        Write-Host "EX5 time unchanged   : $timeUnchanged"
                        # F-03: Fresh EX5 requires EITHER hash change OR timestamp update
                        # Deterministic compilation may produce identical hash but updated timestamp
                        if ($hashUnchanged -and $timeUnchanged) {
                            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "EX5 hash and timestamp unchanged after compilation - file not regenerated" -FailureReason 'EX5 hash and timestamp both match previous build' -Severity 'CRITICAL' -Evidence @(
                                "EX5 before hash: $ex5BeforeHash",
                                "EX5 after hash: $ex5AfterHash",
                                "EX5 before time: $ex5BeforeTime",
                                "EX5 after time: $ex5AfterTime"
                            ) -ExitCode $ExitCodes.FRESH_EX5_FAILED
                            # Do not throw - let aggregation handle exit code
                        }
                        elseif ($hashUnchanged -and -not $timeUnchanged) {
                            Write-Host "EX5 hash unchanged but timestamp updated - deterministic compilation verified"
                        }
                    }

                    # Final status determination
                    if ($compileFailed) {
                        Write-ValidationStep 'Compilation Validation' 'FAIL' "$($summary.Errors) error(s), $($summary.Warnings) warning(s)"
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Compilation failed" -Evidence @(
                            "Errors: $($summary.Errors)",
                            "Warnings: $($summary.Warnings)",
                            "Exit code: $processExitCode",
                            "Summary found: $($summary.SummaryFound)"
                        ) -FailureReason 'Compilation errors detected' -Severity 'CRITICAL' -ExitCode $ExitCodes.COMPILE_FAILED
                    }
                    elseif ($compileNotVerified) {
                        Write-ValidationStep 'Compilation Validation' 'NOT_VERIFIED' 'Compiler summary not found in log'
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'NOT_VERIFIED' -Message 'Compilation log missing recognized summary' -FailureReason 'Unrecognized log format' -Severity 'HIGH' -ExitCode $ExitCodes.COMPILE_PARSE_FAILED
                    }
                    elseif ($compileWarnings) {
                        $status = if ($WarningAcceptancePolicy) { 'ACCEPTED_WARNING' } else { 'WARNING' }
                        Write-ValidationStep 'Compilation Validation' 'WARN' "$($summary.Warnings) warning(s) (within tolerance)"
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status $status -Message "Compilation passed with warnings" -Evidence @("Warnings: $($summary.Warnings)", "Max allowed: $MaxAllowedWarnings") -AcceptanceReference $WarningAcceptancePolicy -ExitCode $ExitCodes.COMPILE_WARNINGS
                    }
                    else {
                        Write-ValidationStep 'Compilation Validation' 'PASS' '0 errors, 0 warnings, fresh EX5 verified'
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message 'Clean compilation with fresh EX5' -Evidence @(
                            "EX5 hash: $ex5AfterHash",
                            "EX5 time: $ex5AfterTime"
                        )
                    }
                }
            }
        }
    }
    else {
        Write-ValidationStep 'Compilation Validation' 'SKIP' 'Skipped per -SkipCompile flag'
        $result = New-ValidationResult -Id 'CMP-001' -Name 'Compilation' -Status 'SKIPPED' -Severity 'INFO' -Message 'Compilation skipped by user flag' -NotApplicableReason '-SkipCompile specified'
        $validationResults += $result
    }

    # =========================================================================
    # STEP 7: Critical Invariant Validation (VH-06, VH-09)
    # =========================================================================
    $result = New-ValidationResult -Id 'INV-001' -Name 'CriticalInvariants' -Status 'NOT_VERIFIED' -Severity 'CRITICAL' -Message 'Validating critical architectural invariants'
    $validationResults += $result
    Write-ValidationStep 'Critical Invariant Validation' 'START'

    $invariantIssues = @()
    $invariantChecks = @()

    # Collect all relevant source files for scanning
    $allSourceFiles = @()
    $allSourceFiles += Join-Path $ProjectMql5Root 'Experts\AlgoMultiAssetEA.mq5'
    $includeDir = Join-Path $ProjectMql5Root 'Include\AlgoSystem'
    if (Test-Path -LiteralPath $includeDir -PathType Container) {
        $allSourceFiles += Get-ChildItem -LiteralPath $includeDir -Filter '*.mqh' -File | ForEach-Object { $_.FullName }
    }

    # 1. Broker mutation boundary check (VH-06)
    $mutationScan = $null
    try {
        $mutationScan = Scan-BrokerMutations -SourceFiles $allSourceFiles -ApprovedTradeClasses @('TradeExecutor')
    }
    catch {
        Write-Host "SCANNER ERROR: $($_.Exception.Message)"
        Write-Host "SCANNER STACK: $($_.ScriptStackTrace)"
        throw
    }
    $unauthorizedCount = $mutationScan.UnauthorizedCalls.Count
    $totalCalls = $mutationScan.AllCalls.Count

    $check = [pscustomobject]@{
        Id          = 'INV-001-MUT'
        Name        = 'BrokerMutationBoundary'
        Description = 'All broker mutation calls must be within TradeExecutor boundary'
        TotalCalls  = $totalCalls
        Unauthorized = $unauthorizedCount
        Found       = ($unauthorizedCount -eq 0)
    }
    $invariantChecks += $check

    if ($unauthorizedCount -gt 0) {
        foreach ($call in $mutationScan.UnauthorizedCalls) {
            $invariantIssues += "UNAUTHORIZED broker mutation: $($call.Receiver).$($call.Method) in $($call.File):$($call.Line) - $($call.Code)"
        }
    }
    else {
        $invariantIssues += "OK: All $totalCalls broker mutation calls are within approved boundary (TradeExecutor)"
    }

    # 2. Main EA required handlers
    $eaPath = Join-Path $ProjectMql5Root 'Experts\AlgoMultiAssetEA.mq5'
    if (Test-Path -LiteralPath $eaPath -PathType Leaf) {
        $eaContent = Get-Content -LiteralPath $eaPath -Raw

        $requiredHandlers = @(
            @{ Name = 'OnInit';        Pattern = '(?m)^\s*int\s+OnInit\s*\(' }
            @{ Name = 'OnDeinit';      Pattern = '(?m)^\s*void\s+OnDeinit\s*\(' }
            @{ Name = 'OnTick';        Pattern = '(?m)^\s*void\s+OnTick\s*\(' }
            @{ Name = 'OnTradeTransaction'; Pattern = '(?m)^\s*(void|int)\s+OnTradeTransaction\s*\(' }
        )

        foreach ($h in $requiredHandlers) {
            $found = $eaContent -match $h.Pattern
            $check = [pscustomobject]@{
                Id          = "INV-001-HND-$($h.Name)"
                Name        = "Handler:$($h.Name)"
                Description = "Main EA must have $($h.Name) handler"
                Found       = $found
            }
            $invariantChecks += $check
            if (-not $found) {
                $invariantIssues += "MISSING handler: $($h.Name) in main EA"
            }
        }

        # 3. Required includes in main EA
        $requiredIncludes = @(
            'RiskEngine.mqh',
            'PortfolioRisk.mqh',
            'TradeExecutor.mqh',
            'ExecutionLedger.mqh',
            'StateManager.mqh',
            'HybridTypes.mqh'
        )

        foreach ($inc in $requiredIncludes) {
            $pattern = '#include\s*[<"].*' + $inc + '[\">]'
            $found = $eaContent -match $pattern
            $check = [pscustomobject]@{
                Id          = "INV-001-INC-$([System.IO.Path]::GetFileNameWithoutExtension($inc))"
                Name        = "Include:$inc"
                Description = "Main EA must include $inc"
                Found       = $found
            }
            $invariantChecks += $check
            if (-not $found) {
                $invariantIssues += "MISSING include: $inc in main EA"
            }
        }
    }

    # 4. HybridTypes critical types
    $hybridTypesPath = Join-Path $ProjectMql5Root 'Include\AlgoSystem\HybridTypes.mqh'
    if (Test-Path -LiteralPath $hybridTypesPath -PathType Leaf) {
        $hybridContent = Get-Content -LiteralPath $hybridTypesPath -Raw
        $requiredTypes = @('TradePlan', 'FeatureContext', 'GateResults', 'HybridDecision', 'ENUM_SETUP_STATE', 'ENUM_DECISION_STATUS', 'ENUM_HYBRID_REGIME', 'ENUM_BIAS_DIRECTION')
        foreach ($t in $requiredTypes) {
            $found = $hybridContent -match "(?m)\b(enum|struct)\s+$t\b"
            $check = [pscustomobject]@{
                Id          = "INV-001-TYP-$t"
                Name        = "Type:$t"
                Description = "HybridTypes.mqh must define $t"
                Found       = $found
            }
            $invariantChecks += $check
            if (-not $found) {
                $invariantIssues += "MISSING type in HybridTypes.mqh: $t"
            }
        }
    }
    else {
        $invariantIssues += "HybridTypes.mqh not found"
    }

    # 5. ExecutionLedger critical definitions
    $ledgerPath = Join-Path $ProjectMql5Root 'Include\AlgoSystem\ExecutionLedger.mqh'
    if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
        $ledgerContent = Get-Content -LiteralPath $ledgerPath -Raw
        $requiredDefs = @(
            @{ Name = 'ENUM_EXEC_ATTEMPT_STATE'; Pattern = '(?m)\bENUM_EXEC_ATTEMPT_STATE\b' }
            @{ Name = 'ExecutionAttemptRecord';  Pattern = '(?m)\bExecutionAttemptRecord\b' }
            @{ Name = 'SchemaVersion';           Pattern = '(?m)\b(m_schema_version|SCHEMA_VERSION)\b' }
        )
        foreach ($d in $requiredDefs) {
            $found = $ledgerContent -match $d.Pattern
            $check = [pscustomobject]@{
                Id          = "INV-001-LED-$($d.Name)"
                Name        = "Ledger:$($d.Name)"
                Description = "ExecutionLedger.mqh must define $($d.Name)"
                Found       = $found
            }
            $invariantChecks += $check
            if (-not $found) {
                $invariantIssues += "MISSING definition in ExecutionLedger.mqh: $($d.Name)"
            }
        }
    }
    else {
        $invariantIssues += "ExecutionLedger.mqh not found"
    }

    # Report invariant results
    $failedChecks = @($invariantChecks | Where-Object { -not $_.Found })
    $passedChecks = @($invariantChecks | Where-Object { $_.Found })

    if ($failedChecks.Count -gt 0) {
        Write-ValidationStep 'Critical Invariant Validation' 'FAIL' "$($failedChecks.Count) of $($invariantChecks.Count) invariant checks failed"
        foreach ($issue in $invariantIssues) { Write-Host "  $issue" }
        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "$($failedChecks.Count) invariant checks failed" -Evidence @($invariantChecks | ForEach-Object { "$($_.Name): $(if ($_.Found) { 'PASS' } else { 'FAIL' }) - $($_.Description)" }) -FailureReason 'Critical architectural invariants violated' -Severity 'CRITICAL' -ExitCode $ExitCodes.INVARIANT_CHECK_FAILED
        # Do not throw - let aggregation handle exit code
    }
    else {
        Write-ValidationStep 'Critical Invariant Validation' 'PASS' "All $($invariantChecks.Count) invariant checks passed"
        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message 'All critical invariants satisfied' -Evidence @($invariantChecks | ForEach-Object { "$($_.Name): PASS - $($_.Description)" })
    }

    # =========================================================================
    # STEP 8: Strategy Tester Readiness Validation (VH-01, VH-02)
    # =========================================================================
    if ($ValidateTesterReadiness) {
        $result = New-ValidationResult -Id 'TST-001' -Name 'TesterReadiness' -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message 'Validating Strategy Tester readiness'
        $validationResults += $result
        Write-ValidationStep 'Strategy Tester Readiness' 'START'

        $testerIssues = @()
        $subResults = @()

        # Validate INI template if provided (VH-01)
        if ($TesterIniTemplatePath) {
            $iniResult = New-ValidationResult -Id 'TST-001-INI' -Name 'TesterIniTemplate' -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message "Validating Tester INI: $TesterIniTemplatePath"
            $validationResults += $iniResult

            if (Test-Path -LiteralPath $TesterIniTemplatePath -PathType Leaf) {
                try {
                    $iniContent = Get-Content -LiteralPath $TesterIniTemplatePath -Raw
                    $parsedIni = Parse-IniContent -Content $iniContent
                    $validation = Validate-TesterIni -ParsedIni $parsedIni -FilePath $TesterIniTemplatePath
                    if ($validation.Valid) {
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "Tester INI structure valid" -Evidence @("File: $TesterIniTemplatePath", "Sections: $($parsedIni.Keys -join ', ')")
                        Write-ValidationStep 'Tester INI Template' 'PASS' 'Structure validated'
                    }
                    else {
                        $issues = $validation.Issues -join '; '
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Tester INI validation failed" -Evidence @("File: $TesterIniTemplatePath", "Issues: $issues") -FailureReason $issues -Severity 'HIGH'
                        $testerIssues += $validation.Issues
                        Write-ValidationStep 'Tester INI Template' 'FAIL' "$($validation.Issues.Count) issue(s)"
                        foreach ($issue in $validation.Issues) { Write-Host "  $issue" }
                    }
                }
                catch {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Tester INI parse error" -Evidence @("File: $TesterIniTemplatePath", "Error: $($_.Exception.Message)") -FailureReason $_.Exception.Message -Severity 'HIGH'
                    $testerIssues += "INI parse error: $($_.Exception.Message)"
                }
            }
            else {
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Tester INI template not found" -Evidence @("Path: $TesterIniTemplatePath") -FailureReason 'INI file missing' -Severity 'HIGH'
                $testerIssues += "Tester INI template not found: $TesterIniTemplatePath"
            }
        }
        else {
            $iniResult = New-ValidationResult -Id 'TST-001-INI' -Name 'TesterIniTemplate' -Status 'SKIPPED' -Severity 'INFO' -Message 'No INI template provided' -NotApplicableReason '-TesterIniTemplatePath not specified'
            $validationResults += $iniResult
            Write-ValidationStep 'Tester INI Template' 'SKIP' 'No template provided'
        }

        # Validate SET file if provided (VH-02, VH-07)
        if ($SetFilePath) {
            $setResult = New-ValidationResult -Id 'TST-001-SET' -Name 'TesterSetFile' -Status 'NOT_VERIFIED' -Severity 'HIGH' -Message "Validating Tester SET: $SetFilePath"
            $validationResults += $setResult

            if (Test-Path -LiteralPath $SetFilePath -PathType Leaf) {
                try {
                    $setContent = Get-Content -LiteralPath $SetFilePath -Raw
                    $validation = Validate-SetFile -Content $setContent -FilePath $SetFilePath
                    if ($validation.Valid) {
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "Tester SET file valid" -Evidence @("File: $SetFilePath")
                        Write-ValidationStep 'Tester SET File' 'PASS' 'Format validated'
                    }
                    else {
                        $issues = $validation.Issues -join '; '
                        Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Tester SET validation failed" -Evidence @("File: $SetFilePath", "Issues: $issues") -FailureReason $issues -Severity 'HIGH'
                        $testerIssues += $validation.Issues
                        Write-ValidationStep 'Tester SET File' 'FAIL' "$($validation.Issues.Count) issue(s)"
                        foreach ($issue in $validation.Issues) { Write-Host "  $issue" }
                    }
                }
                catch {
                    Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "Tester SET read error" -Evidence @("File: $SetFilePath", "Error: $($_.Exception.Message)") -FailureReason $_.Exception.Message -Severity 'HIGH'
                    $testerIssues += "SET read error: $($_.Exception.Message)"
                }
            }
            else {
                Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'FAILED' -Message "SET file not found" -Evidence @("Path: $SetFilePath") -FailureReason 'SET file missing' -Severity 'HIGH'
                $testerIssues += "SET file not found: $SetFilePath"
            }
        }
        else {
            $setResult = New-ValidationResult -Id 'TST-001-SET' -Name 'TesterSetFile' -Status 'SKIPPED' -Severity 'INFO' -Message 'No SET file provided' -NotApplicableReason '-SetFilePath not specified'
            $validationResults += $setResult
            Write-ValidationStep 'Tester SET File' 'SKIP' 'No SET file provided'
        }

        # Check for tester profile directory (VH-02 - corrected path)
        $profileResult = New-ValidationResult -Id 'TST-001-PRF' -Name 'TesterProfileDirectory' -Status 'NOT_VERIFIED' -Severity 'MEDIUM' -Message 'Checking Strategy Tester profile directory'
        $validationResults += $profileResult

        # Correct path: MQL5\Profiles\Tester under terminal DATA folder (not install root)
        $terminalDataRoot = Split-Path -Parent $ProjectMql5Root
        $testerProfilesDir = Join-Path $terminalDataRoot 'MQL5\Profiles\Tester'

        if (Test-Path -LiteralPath $testerProfilesDir -PathType Container) {
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'PASSED' -Message "Tester profile directory found" -Evidence @("Path: $testerProfilesDir")
            Write-ValidationStep 'Tester Profile Directory' 'PASS' "Found: $testerProfilesDir"
        }
        else {
            Update-ValidationResult -Index ($validationResults.Count - 1) -Status 'WARNING' -Message "Tester profile directory not found (may be created on first use)" -Evidence @("Expected: $testerProfilesDir", "Data root: $terminalDataRoot") -FailureReason 'Profile directory missing'
            $testerIssues += "Strategy Tester profiles directory not found: $testerProfilesDir"
            Write-ValidationStep 'Tester Profile Directory' 'WARN' "Not found: $testerProfilesDir"
        }

        # Overall tester readiness status
        if ($testerIssues.Count -gt 0) {
            $hasFailure = $validationResults | Where-Object { $_.Name -like 'TST-001-*' -and $_.Status -eq 'FAILED' }
            if ($hasFailure) {
                Write-ValidationStep 'Strategy Tester Readiness' 'FAIL' "$($testerIssues.Count) issue(s) including failures"
                Update-ValidationResult -Index ($validationResults.Count - 4) -Status 'FAILED' -Message "Strategy Tester readiness validation failed" -Evidence $testerIssues -FailureReason 'Tester readiness check failed' -Severity 'HIGH' -ExitCode $ExitCodes.TESTER_READINESS_FAILED
                # Do not throw - let aggregation handle exit code
            }
            else {
                Write-ValidationStep 'Strategy Tester Readiness' 'WARN' "$($testerIssues.Count) warning(s)"
                Update-ValidationResult -Index ($validationResults.Count - 4) -Status 'WARNING' -Message "Strategy Tester readiness has warnings" -Evidence $testerIssues -FailureReason 'Tester readiness warnings'
            }
        }
        else {
            Write-ValidationStep 'Strategy Tester Readiness' 'PASS' 'All readiness checks passed'
            Update-ValidationResult -Index ($validationResults.Count - 4) -Status 'PASSED' -Message 'Strategy Tester configuration validated' -Evidence @('INI valid', 'SET valid', 'Profile directory accessible')
        }
    }
    else {
        Write-ValidationStep 'Strategy Tester Readiness' 'SKIP' 'Skipped (use -ValidateTesterReadiness to enable)'
        $result = New-ValidationResult -Id 'TST-001' -Name 'TesterReadiness' -Status 'SKIPPED' -Severity 'INFO' -Message 'Tester readiness validation skipped' -NotApplicableReason '-ValidateTesterReadiness not specified'
        $validationResults += $result
    }

    # =========================================================================
    # STEP 9: Generate Summary Report (VH-10, VH-11)
    # =========================================================================
    Write-Host ''
    Write-Host '=== Validation Summary ==='
    $validationEndDt = [DateTimeOffset]::UtcNow
    $validationEndUtc = Get-UtcTimestamp
    $duration = $validationEndDt - $validationStartDt
    Write-Host "Duration           : $($duration.TotalSeconds.ToString('F2')) seconds"

    # Count statuses
    $statusCounts = @{}
    foreach ($status in $ValidationStatus.Values) {
        $statusCounts[$status] = @($validationResults | Where-Object { $_.Status -eq $status }).Count
    }

    Write-Host "PASSED             : $($statusCounts['PASSED'])"
    Write-Host "FAILED             : $($statusCounts['FAILED'])"
    Write-Host "WARNING            : $($statusCounts['WARNING'])"
    Write-Host "ACCEPTED_WARNING   : $($statusCounts['ACCEPTED_WARNING'])"
    Write-Host "SKIPPED            : $($statusCounts['SKIPPED'])"
    Write-Host "NOT_APPLICABLE     : $($statusCounts['NOT_APPLICABLE'])"
    Write-Host "NOT_VERIFIED       : $($statusCounts['NOT_VERIFIED'])"
    Write-Host ''

    foreach ($r in $validationResults) {
        $statusIcon = switch ($r.Status) {
            'PASSED'             { '[OK]' }
            'FAILED'             { '[!!]' }
            'WARNING'            { '[!!]' }
            'ACCEPTED_WARNING'   { '[AW]' }
            'SKIPPED'            { '[--]' }
            'NOT_APPLICABLE'     { '[NA]' }
            'NOT_VERIFIED'       { '[?]' }
        }
        Write-Host "$statusIcon $($r.Id) $($r.Name): $($r.Status) - $($r.Message)"
    }

    # Determine overall exit code (VH-05)
    $overallExitCode = Get-AggregatedExitCode -Results $validationResults -StrictMode:$StrictMode
    Write-Host "Overall exit code  : $overallExitCode"

    # JSON Report Output (VH-10) - guarded by ShouldProcess
    if ($JsonReportPath) {
        $report = [pscustomobject]@{
            Version             = '1.0.0'
            ValidationStartUtc  = $validationStartUtc
            ValidationEndUtc    = $validationEndUtc
            DurationSeconds     = $duration.TotalSeconds
            OverallExitCode     = $overallExitCode
            Summary             = @{
                Passed             = $statusCounts['PASSED']
                Failed             = $statusCounts['FAILED']
                Warning            = $statusCounts['WARNING']
                AcceptedWarning    = $statusCounts['ACCEPTED_WARNING']
                Skipped            = $statusCounts['SKIPPED']
                NotApplicable      = $statusCounts['NOT_APPLICABLE']
                NotVerified        = $statusCounts['NOT_VERIFIED']
            }
            Results             = $validationResults
            Environment         = @{
                TerminalInstallRoot = $TerminalInstallRoot
                ProjectMql5Root     = $ProjectMql5Root
                IncludeMql5Root     = $IncludeMql5Root
                MetaEditorVersion   = if ($metaEditorInfo) { $metaEditorInfo.FileVersion } else { 'Unknown' }
                SourcePath          = if ($sourcePath) { $sourcePath } else { 'Unknown' }
                PowerShellVersion   = $PSVersionTable.PSVersion.ToString()
                HarnessVersion      = '1.0.0'
            }
        }

        if (Test-ShouldProcess -Target "Write JSON report" -Action "Write validation report to $JsonReportPath") {
            try {
                $success = Write-JsonReport -Report $report -Path $JsonReportPath
                if ($success) {
                    Write-Host "`nJSON report written and validated: $JsonReportPath"
                }
            }
            catch {
                Write-Error "JSON report validation failed: $($_.Exception.Message)"
                $overallExitCode = $ExitCodes.JSON_FAILED
            }
        }
        else {
            Write-Host "WhatIf: Would write JSON report to $JsonReportPath"
        }
    }

    exit $overallExitCode
}
finally {
    # Ensure JSON report is written even on unhandled exceptions
    if ($JsonReportPath -and -not $scriptError) {
        # Already handled above
    }
    elseif ($JsonReportPath -and $scriptError -and $validationResults.Count -gt 0) {
        # Script crashed but we have some results - try to write report
        $validationEndDt = [DateTimeOffset]::UtcNow
        $validationEndUtc = Get-UtcTimestamp
        $duration = $validationEndDt - $validationStartDt
        $overallExitCode = Get-AggregatedExitCode -Results $validationResults -StrictMode:$StrictMode
        
        $report = [pscustomobject]@{
            Version             = '1.0.0'
            ValidationStartUtc  = $validationStartUtc
            ValidationEndUtc    = $validationEndUtc
            DurationSeconds     = $duration.TotalSeconds
            OverallExitCode     = $overallExitCode
            Summary             = @{
                Passed             = @($validationResults | Where-Object { $_.Status -eq 'PASSED' }).Count
                Failed             = @($validationResults | Where-Object { $_.Status -eq 'FAILED' }).Count
                Warning            = @($validationResults | Where-Object { $_.Status -eq 'WARNING' }).Count
                AcceptedWarning    = @($validationResults | Where-Object { $_.Status -eq 'ACCEPTED_WARNING' }).Count
                Skipped            = @($validationResults | Where-Object { $_.Status -eq 'SKIPPED' }).Count
                NotApplicable      = @($validationResults | Where-Object { $_.Status -eq 'NOT_APPLICABLE' }).Count
                NotVerified        = @($validationResults | Where-Object { $_.Status -eq 'NOT_VERIFIED' }).Count
            }
            Results             = $validationResults
            Environment         = @{
                TerminalInstallRoot = if ($TerminalInstallRoot) { $TerminalInstallRoot } else { 'Unknown' }
                ProjectMql5Root     = if ($ProjectMql5Root) { $ProjectMql5Root } else { 'Unknown' }
                IncludeMql5Root     = if ($IncludeMql5Root) { $IncludeMql5Root } else { 'Unknown' }
                MetaEditorVersion   = if ($metaEditorInfo) { $metaEditorInfo.FileVersion } else { 'Unknown' }
                SourcePath          = if ($sourcePath) { $sourcePath } else { 'Unknown' }
                PowerShellVersion   = $PSVersionTable.PSVersion.ToString()
                HarnessVersion      = '1.0.0'
            }
        }
        
        try {
            Write-JsonReport -Report $report -Path $JsonReportPath | Out-Null
            Write-Host "`nJSON report written (after script error): $JsonReportPath"
        }
        catch {
            Write-Warning "Failed to write JSON report after script error: $($_.Exception.Message)"
        }
    }
}
catch {
    $scriptError = $_
    Write-Error $_
    $validationResults += New-ValidationResult -Id 'ERR-001' -Name 'ScriptExecution' -Status 'FAILED' -Severity 'CRITICAL' -Message $_.Exception.Message -FailureReason $_.Exception.Message -ExitCode $ExitCodes.SCRIPT_ERROR
    # Exit code handled in finally block
    throw
}