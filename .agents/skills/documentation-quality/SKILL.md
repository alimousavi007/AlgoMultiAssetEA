---
name: documentation-quality
description: Create, review, and maintain accurate technical documentation, READMEs, architecture notes, runbooks, API guides, and change reports. Use when documentation must match actual source, configuration, or verified behavior.
---

# Documentation Quality

## Source-backed accuracy
- Treat current source/configuration and official product documentation as primary evidence.
- Trace implementation before documenting behavior.
- Distinguish implemented, planned, proposed, deprecated, and unverified behavior.
- Verify referenced paths, symbols, commands, workflow names, Skill names, Agent IDs, versions, and tool schemas.
- Do not invent examples that imply unsupported APIs or successful operations.

## Structure
Choose a structure appropriate to the reader and task:
- purpose and scope;
- prerequisites and permissions;
- concepts and architecture;
- step-by-step procedure;
- examples and expected output;
- validation and acceptance criteria;
- troubleshooting and recovery;
- limitations, security, and references.

Avoid unnecessary sections for small documents. Prefer one canonical source and links over duplicated instructions.

## Maintainability
- Keep instructions actionable and concise.
- Mark version-sensitive behavior and last-verified dates where useful.
- Keep examples internally consistent and safe to copy.
- Explain destructive or external side effects before commands.
- Avoid embedding secrets, private paths, personal data, or production account details.
- Remove stale references only after confirming their replacement.

## Review checklist
Check accuracy, completeness for the intended audience, consistency, terminology, working links, copyable syntax, version compatibility, security/privacy, and alignment with actual acceptance criteria.

## Output
For reviews, list actionable defects and exact sections. For edits, summarize changed sections and facts that remain unverified. Do not claim documentation is fully current when external behavior has not been checked.
