---
description: Read-only code review for AlgoMultiAssetEA
---

# CODE REVIEW — FULL WORKFLOW

### TASK
این تغییر را Review کن:

[Diff / Commit / Files]

### RULE
هیچ کدی تغییر نده.
Commit / Push نکن.

### REVIEW

بررسی کن:

- Correctness
- Bugs
- Edge Cases
- Regression
- Architecture
- Dependencies / Callers
- Performance
- Error Handling
- Trading / Risk / Safety
- Unnecessary Changes

در صورت مرتبط بودن:

- MQL5 semantics
- Event flow
- Multi-Symbol
- State transitions
- Market data
- Execution pipeline

### FINDINGS

فقط Findingهای واقعی را گزارش کن.

Priority:

CRITICAL
HIGH
MEDIUM
LOW

هر Finding:

- File
- Line
- Problem
- Why it matters
- Suggested fix

Evidence-based باش.
Problem قطعی را از inference جدا کن.

### OUTPUT

## CRITICAL
[...]

## HIGH
[...]

## MEDIUM
[...]

## LOW
[...]

## VERDICT
APPROVE / APPROVE WITH COMMENTS / CHANGES REQUIRED