# Kilo Workflow Catalog and Composition Guide

Repository: `alimousavi007/AlgoMultiAssetEA`
Workflow directory: `.kilo/commands/`
Last reviewed against `main`: `40fd267fd2ad8c7104eab700ed7770d45fda4a8f` (2026-11-11).

## 1. How Kilo loads project Workflows

The current Kilo Code extension treats project Markdown files in `.kilo/commands/` as Workflows (slash commands). The filename without `.md` is the command name. For example, `.kilo/commands/ea-implement.md` is invoked as `/ea-implement`.

A composite Workflow in this repository is a **single invoked command** that reads the full Markdown instructions of its component Workflows and applies them sequentially in the same session. It does not assume that typing a second slash command from inside the first Workflow will recursively dispatch another Workflow. This keeps composition explicit and avoids relying on undocumented nested-command behavior.

## 2. Existing standalone Workflows

| Command | Purpose | Use when |
|---|---|---|
| `/docs-review` | Documentation review and improvement | Documentation is the primary deliverable |
| `/ea-implement` | EA implementation | A scoped code change is needed without the full combined pipeline |
| `/ea-investigate` | Read-only root-cause investigation | Diagnose a symptom without editing |
| `/ea-risk-review` | Read-only execution, risk, authority, and lifecycle review | Inspect risk-sensitive changes or behavior |
| `/git-delivery` | Git delivery gate | Inspect/prepare delivery; commit and push remain separately authorized |
| `/hybrid-lifecycle` | Hybrid lifecycle implementation or diagnosis | A lifecycle-specific change is needed |
| `/hybrid-lifecycle-review` | Read-only Hybrid lifecycle review | Independently inspect Setup/Attempt/submission/reconciliation |
| `/mt5-validate` | MT5 compile/test validation | Run only explicitly authorized validation stages |
| `/project-review` | General read-only project review | Review a bounded code/configuration/documentation scope |
| `/project-task` | General task router | A task does not fit a specialist Workflow |
| `/security-review` | Read-only security/privacy review | Review a changed trust, data, dependency, or execution boundary |

## 3. Composite Workflows added

| Command | Composition | Intended use |
|---|---|---|
| `/ea-implement-validate` | `ea-implement` → scoped independent review → `mt5-validate` | Default end-to-end implementation and authorized validation for EA code changes |
| `/ea-investigate-fix-validate` | `ea-investigate` → authorization/root-cause gate → `ea-implement` → `mt5-validate` | A reported EA defect where the user asks to diagnose and fix it |
| `/hybrid-lifecycle-implement-validate` | `ea-implement` + `hybrid-lifecycle` → Hybrid/risk review → `mt5-validate` | Setup/Attempt/authority/durable intent/reconciliation lifecycle changes |

## 4. Which command should I use?

- **Implement a normal EA feature/fix and verify it:** `/ea-implement-validate`
- **Diagnose a symptom only:** `/ea-investigate`
- **Diagnose and fix a symptom in one task:** `/ea-investigate-fix-validate`
- **Change Setup, Attempt, Coordinator, durable intent, or reconciliation behavior:** `/hybrid-lifecycle-implement-validate`
- **Review only:** choose `/project-review`, `/ea-risk-review`, `/hybrid-lifecycle-review`, or `/security-review` according to scope
- **Compile/test only:** `/mt5-validate`
- **Prepare Git delivery:** `/git-delivery`; it does not grant commit/push permission.

Do not invoke multiple slash commands in a single prompt and assume they will execute sequentially. Use the relevant composite command instead.

## 5. Composition and safety rules

1. Component files are the source of truth. Composite commands read and apply them; avoid copying their entire text into every composite.
2. A component file read by a composite is `APPLIED AS COMPONENT INSTRUCTIONS`, not a separately `INVOKED` Workflow.
3. Use only the specialist reviews relevant to the changed paths. Do not run duplicate broad audits.
4. Skills must be loaded through Kilo's actual Skill mechanism. Reading a Skill file is not equivalent to invoking the Skill.
5. Agents must be delegated through the actual Task/subagent mechanism. Verify their IDs and report whether they truly ran.
6. Compile, functional testing, Strategy Tester, terminal runtime, database mutation, and broker operations are distinct permissions. Apply `/mt5-validate` and do not infer authorization.
7. Preserve user changes. Never reset, clean, stash, discard, amend, force-push, commit, or push without the required explicit authorization.
8. Do not close or defer a known P0–P3 issue without a verified fix or an explicit approved architecture/policy disposition. A compile pass is not proof of runtime correctness.
9. If a required component Workflow cannot be read, stop with a precise blocker rather than silently skipping it.

## 6. Maintenance notes from the audit

- The repository uses `AGENTS.MD` (uppercase extension). Workflow references must preserve that exact casing for case-sensitive filesystems.
- `hybrid-lifecycle.md` must reference the existing `/hybrid-lifecycle-review` Workflow rather than claim it does not exist.
- New project Workflows belong in `.kilo/commands/`; no separate `.kilocode/workflows/` directory is required for the current Kilo command format.
