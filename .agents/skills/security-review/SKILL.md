---
name: security-review
description: Review application code, configuration, dependencies, data flows, and automation for security and privacy risks. Use for authentication, authorization, secrets, input handling, filesystem/process/network access, supply-chain, logging, or privilege-boundary changes.
---

# Security Review

## Purpose
Provide a scoped, evidence-backed security assessment. This Skill is review guidance, not authorization to perform active testing.

## Threat model first
Identify assets, trust boundaries, actors, entry points, sensitive data, privileges, external services, and realistic attacker capabilities. State assumptions. Do not perform a generic checklist unrelated to the actual system.

## Review areas
Select relevant areas:
- authentication and authorization enforcement;
- secrets and sensitive-data handling;
- input validation, injection, parsing, and serialization;
- filesystem/path safety and file permissions;
- process execution and shell argument handling;
- network destinations, TLS, and external data transfer;
- dependency provenance, pinning, maintenance, and license;
- logging, telemetry, privacy, and retention;
- concurrency, race conditions, and state integrity;
- error handling, insecure fallbacks, and privilege escalation.

For trading software, include account/authority identity, execution permissions, persistent ledger integrity, and unintended broker-side effects when they are in scope.

## Evidence standard
A finding must identify the vulnerable code/configuration, preconditions, reachable path, impact, and evidence. Distinguish:
- confirmed vulnerability;
- conditional vulnerability requiring stated assumptions;
- defense-in-depth recommendation;
- unverified concern.

Do not claim a system is secure merely because no issue was found in a limited review.

## Active testing boundary
Do not scan, exploit, fuzz, attack, access secrets, or test production systems unless the user separately authorizes a defined target and method. Do not change files or install tools during a read-only review.

## Output
Prioritize findings by impact and exploitability. Include exact file/line, threat scenario, impact, confidence, minimal mitigation, reviewed scope, exclusions, and evidence limitations.
