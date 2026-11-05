---
description: Read-only security and privacy review of a scoped code or configuration change
---

# Security Review — Read Only

## 1. Scope
Identify the exact application surface, files, data flows, dependencies, and threat boundaries. Read `AGENTS.md`, `.kilo/rules/core.md`, and `.agents/skills/security-review/SKILL.md`.

## 2. Review
Inspect only relevant risks:
- secrets, credentials, tokens, and sensitive data exposure;
- authentication, authorization, ownership, and permission boundaries;
- input validation, parsing, serialization, and injection surfaces;
- filesystem paths, unsafe file operations, and path traversal;
- process execution, shell quoting, and command injection;
- network destinations, TLS, trust boundaries, and data exfiltration;
- dependency provenance, version pinning, maintenance, and license;
- logging, telemetry, retention, and privacy;
- concurrency, race conditions, and unsafe state transitions;
- failure handling, fallback behavior, and privilege escalation.

For this trading system, also consider execution authorization, account identity, durable state, broker-side effects, and the risk of a security defect causing unintended orders. Do not confuse trading-risk review with a complete security review.

## 3. Evidence
For each finding include severity, confidence, exact file/line, threat precondition, attack/failure path, impact, evidence, and minimal mitigation. Separate confirmed vulnerabilities from hardening recommendations.

## 4. Boundaries
Read-only. Do not exploit, scan production, fuzz external systems, access secrets, submit broker requests, modify files, or install tools. Any active testing requires separate explicit authorization and a defined target.

## 5. Output
Return a concise threat summary, prioritized findings, reviewed scope, exclusions, sources, and actual Skills/Agents invoked. If no vulnerability is confirmed, say so without claiming the system is secure in general.
