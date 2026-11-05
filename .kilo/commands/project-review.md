---
description: Read-only, scope-limited review of code, configuration, architecture, or documentation
---

# Project Review — Read Only

## 1. Scope and baseline
- Establish the exact target: diff, files, workflow, configuration, document, or behavior.
- Inspect current branch/HEAD/status and the complete relevant diff when repository changes are under review.
- Separate pre-existing user changes from the reviewed change.
- Read `AGENTS.md` and only applicable rules/Skills.

## 2. Review method
- Review correctness against the stated requirement and observable behavior.
- Trace dependencies, consumers, lifecycle, error paths, and compatibility where relevant.
- For configuration, validate names, paths, schema, permissions, precedence, and whether referenced tools/resources exist.
- For documentation, check factual accuracy, contradictions, missing prerequisites, stale references, and whether instructions are executable.
- For code, check control flow, types, state, error handling, concurrency, security, and regressions relevant to the patch.
- Use official documentation for platform/tool contracts and credible secondary sources only for corroboration.

## 3. Findings standard
Report only actionable findings with:
- ID and severity (`P0`–`P3`);
- confidence (`CONFIRMED`, `CONDITIONAL`, `UNVERIFIED`);
- exact file/section/line;
- triggering condition;
- evidence;
- concrete impact;
- introduced/pre-existing/unknown status;
- smallest correction.

Do not turn style preferences or hypothetical edge cases into defects. Do not claim runtime behavior from static inspection.

## 4. Boundaries
- Read-only: no edits, compilation, tests, terminal launch, DB writes, broker actions, staging, commit, or push.
- Do not expand into unrelated modules.
- Do not repeat a previous review of unchanged material unless new evidence justifies it.

## 5. Output
Findings first, highest severity first. Then reviewed scope, exclusions, sources, actual Skills/Agents invoked, and evidence limitations. If no issue is found, state `NO CONFIRMED FINDING IN THE REVIEWED SCOPE`.
