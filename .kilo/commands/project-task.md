---
description: General evidence-led workflow for any scoped project task
---

# Project Task — General Workflow

Use for tasks that do not fit a more specific workflow. If a specialist workflow clearly applies (for example `/ea-investigate`, `/ea-implement`, `/ea-risk-review`, `/mt5-validate`, `/git-delivery`, or `/hybrid-lifecycle`), prefer that workflow instead of duplicating it.

## 1. Classify the requested outcome
Choose the smallest matching task type:
- answer/research;
- investigate/diagnose;
- implement/change;
- review;
- documentation;
- test/validation;
- release/delivery;
- external integration.

Do not convert a simple answer or transformation into a multi-stage engineering process.

## 2. Establish scope and baseline
- Read `AGENTS.MD` and applicable `.kilo/rules/`.
- Inspect only the relevant files, dependencies, configuration, and evidence.
- Inspect Git state before editing or delivery.
- Preserve all pre-existing user changes and untracked files.
- Identify assumptions, constraints, and what is explicitly not authorized.

## 3. Select resources
Use Kilo's actual Skill mechanism for relevant Skills; do not merely list their names.
Use the Task/subagent mechanism for distinct specialist questions only.
Prefer:
- `explore` for read-only discovery;
- `code-reviewer` for independent code correctness;
- `risk-auditor` for trading risk/execution;
- `mt5-tester-operator` only for explicitly authorized MT5 tester operations;
- `web-browser` only when its MCP server is actually connected.

Record `INVOKED`, `APPLIED FROM FILE`, or `UNAVAILABLE` accurately.

## 4. Investigate and define acceptance
- Trace the actual producer, consumer, caller, state transition, and side effect.
- Use official sources for API/tool/platform contracts; use credible secondary sources only as corroboration.
- Define observable acceptance criteria and negative cases for non-trivial changes.
- If root cause or requirements remain uncertain, identify the exact missing evidence or decision; do not patch a guess.

## 5. Execute the smallest useful action
- Make only changes required by the request.
- Preserve interfaces, user work, approved architecture, and unrelated behavior.
- Do not install dependencies or external tools without a concrete need and compatibility/security review.
- Do not perform unauthorized shell, network, compile, test, database, broker, or Git delivery actions.

## 6. Review and verify
- Inspect the complete diff.
- Use a distinct read-only reviewer when it materially improves correctness or safety.
- Run only authorized, relevant checks.
- Separate static review, compilation, functional tests, tester runs, runtime evidence, and external-system evidence.
- Report every acceptance criterion as `PASSED`, `FAILED`, `NOT RUN`, or `BLOCKED`.

## 7. Report
In Persian unless requested otherwise:
- result and scope;
- evidence and root cause, if applicable;
- changes and affected files;
- acceptance results;
- actual Workflow/Skill/Agent/tool usage;
- sources consulted;
- checks run/not run;
- remaining risks and next dependency.

Do not add a generic follow-up audit when the requested task is complete.
