# Kilo Workflow Catalog and Composition Guide

Repository: `alimousavi007/AlgoMultiAssetEA`
Workflow directory: `.kilo/commands/`
Last reviewed against `main`: `6b8e4bfa9bbe682a7b29b8494381af39cf0f803f` (2026-11-12); unified workflow branch: `workflows/project-engineering-unified-2026-11-12`.

## 1. How Kilo loads project Workflows

The current Kilo Code extension treats project Markdown files in `.kilo/commands/` as Workflows (slash commands). The filename without `.md` is the command name. For example, `.kilo/commands/ea-implement.md` is invoked as `/ea-implement`.

A composite Workflow in this repository is a **single invoked command** that reads the full Markdown instructions of its component Workflows and applies them sequentially in the same session. It does not assume that typing a second slash command from inside the first Workflow will recursively dispatch another Workflow. This keeps composition explicit and avoids relying on undocumented nested-command behavior.

## 2. Existing standalone Workflows

| Command | Purpose | Use when |
|---|---|---|
| `/project-engineering` | Unified project task, security and documentation workflow | General work requiring one or more conditional modes |
| `/ea-implement` | EA implementation | A scoped code change is needed without the full combined pipeline |
| `/ea-investigate` | Read-only root-cause investigation | Diagnose a symptom without editing |
| `/ea-risk-review` | Read-only execution, risk, authority, and lifecycle review | Inspect risk-sensitive changes or behavior |
| `/git-delivery` | Git delivery gate | Inspect/prepare delivery; commit and push remain separately authorized |
| `/repo-update` | Safe local repository synchronization | Update the current branch or an explicitly named remote branch with fetch + fast-forward only |
| `/hybrid-lifecycle` | Hybrid lifecycle implementation or diagnosis | A lifecycle-specific change is needed |
| `/hybrid-lifecycle-review` | Read-only Hybrid lifecycle review | Independently inspect Setup/Attempt/submission/reconciliation |
| `/mt5-validate` | MT5 compile/test validation | Run only explicitly authorized validation stages |
| `/project-review` | General read-only project review | Review a bounded code/configuration/documentation scope |
| `/project-task` | Compatibility alias → `/project-engineering` | Legacy prompts only |
| `/security-review` | Compatibility alias → `/project-engineering` Security mode | Legacy prompts only |

## 3. Composite Workflows

| Command | Composition | Intended use |
|---|---|---|
| `/ea-implement-validate` | `ea-implement` → scoped independent review → `mt5-validate` | Default end-to-end implementation and authorized validation for EA code changes |
| `/ea-investigate-fix-validate` | `ea-investigate` → authorization/root-cause gate → `ea-implement` → `mt5-validate` | A reported EA defect where the user asks to diagnose and fix it |
| `/hybrid-lifecycle-implement-validate` | `ea-implement` + `hybrid-lifecycle` → Hybrid/risk review → `mt5-validate` | Setup/Attempt/authority/durable intent/reconciliation lifecycle changes |
| `/ea-quality-cycle` | `ea-implement` + `mt5-validate` → baseline compile → scoped audit → repair → justified refactor → regression repair → final compile/tests | Complete the compile/audit/repair/refactor cycle in one Kilo session |

## 4. Which command should I use?

- **Implement an EA change and complete the compile/audit/repair cycle:** `/ea-quality-cycle`
- **Implement a normal EA feature/fix with the shorter implementation and validation pipeline:** `/ea-implement-validate`
- **Diagnose a symptom only:** `/ea-investigate`
- **Diagnose and fix a symptom in one task:** `/ea-investigate-fix-validate`
- **Change Setup, Attempt, Coordinator, durable intent, or reconciliation behavior:** `/hybrid-lifecycle-implement-validate`
- **General investigation/implementation/review/security/docs:** `/project-engineering`, selecting only the required mode(s).
- **Review only:** choose `/project-review`, `/ea-risk-review`, or `/hybrid-lifecycle-review` for narrower specialist scopes
- **Compile/test only:** `/mt5-validate`
- **Safely update the local project from GitHub:** `/repo-update`. By default it updates only the current branch's verified upstream; an explicitly named remote branch can be supplied as an argument.
- **Prepare Git delivery:** `/git-delivery`; it does not grant commit/push permission.

Do not invoke multiple slash commands in a single prompt and assume they will execute sequentially. Use the relevant composite command instead.

## 5. Composition and safety rules

1. `.kilo/commands/project-engineering.md` is the canonical owner of the former project-task, security-review and docs-review responsibilities; the old files are compatibility aliases. Avoid maintaining duplicate procedures.
2. A component file read by a composite is `APPLIED AS COMPONENT INSTRUCTIONS`, not a separately `INVOKED` Workflow.
3. Use only the specialist reviews relevant to the changed paths. Do not run duplicate broad audits.
4. Skills must be loaded through Kilo's actual Skill mechanism. Reading a Skill file is not equivalent to invoking the Skill.
5. Agents must be delegated through the actual Task/subagent mechanism. Verify their IDs and report whether they truly ran.
6. Use `todowrite` for multi-step work and update it at meaningful transitions; do not claim its use unless it actually ran.
7. Inspect and reuse the appropriate tools under `tools/`; do not create duplicate compilers or validation harnesses.
8. Compile, functional testing, Strategy Tester, terminal runtime, database mutation, and broker operations are distinct permissions. `/ea-quality-cycle` authorizes compilation only; apply `/mt5-validate` and do not infer authorization for other stages.
9. Default compile acceptance is 0 errors and 0 warnings. An unrecognized summary, stale log, timeout, or unverified EX5 is not a pass.
10. A no-op assertion such as `Assert-True $true` is not test coverage. Do not rely on a test count without inspecting assertion behavior.
11. Preserve user changes. Never reset, clean, stash, discard, amend, force-push, commit, or push without the required explicit authorization.
12. Do not close or defer a known P0–P3 issue without a verified fix or an explicit approved architecture/policy disposition. A compile pass is not proof of runtime correctness.
13. If a required component Workflow cannot be read, stop with a precise blocker rather than silently skipping it.
14. `/repo-update` must preserve local changes and use fast-forward only. It stops on dirty worktrees, unverified upstreams, or divergent histories; it never commits, pushes, resets, cleans, or stashes.

## 6. Maintenance notes

- The repository uses `AGENTS.MD` (uppercase extension). Workflow references must preserve that exact casing for case-sensitive filesystems.
- `hybrid-lifecycle.md` must reference the existing `/hybrid-lifecycle-review` Workflow rather than claim it does not exist.
- Project Workflows belong in `.kilo/commands/`; the current Kilo command format does not require a separate `.kilocode/workflows/` directory.
- The compile-quality process is centralized in `/ea-quality-cycle` and the universal project rules. Do not copy the entire cycle into other Workflows.
