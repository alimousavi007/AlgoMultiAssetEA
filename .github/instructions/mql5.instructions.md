---
applyTo: "**/*.mq5,**/*.mqh"
---

# MQL5 File Instructions

These rules apply when working with MQL5 source files.

## Before Editing

Inspect:

- the current file
- related includes
- callers
- dependent types
- configuration
- runtime flow

Do not rewrite existing logic without understanding its current behavior.

## Compiler Safety

Before changing a function call:

- inspect the actual function signature
- inspect argument count
- inspect argument types
- inspect return type
- inspect overloads if any

Do not guess signatures.

## Market Data

Always guard:

- insufficient bars
- unsynchronized series
- stale data
- invalid handles
- CopyBuffer failures
- CopyRates failures
- invalid shifts
- invalid prices

## Multi-Symbol

Do not assume chart OnTick automatically services all managed symbols.

Consider:

- OnTimer
- symbol-specific processing
- synchronization
- freshness
- runtime state

## Trading

Normalize:

- prices
- volume

against the actual symbol specification.

Respect:

- minimum volume
- maximum volume
- volume step
- digits
- tick size
- stops level
- freeze level

Inspect actual trade retcodes.

Do not interpret a successful function call as proof that a trade was successfully executed.

## Risk

If a required risk value cannot be calculated safely:

NO-TRADE.

Never bypass risk logic to make a signal executable.

## Testing

Do not claim successful compilation or runtime verification without evidence.

Static reasoning must be clearly separated from actual execution evidence.