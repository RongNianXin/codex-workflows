# English entry: the commander workflow

This page is a compact orientation for English-speaking visitors. The Chinese manuals remain the canonical rule source and change more frequently than this overview.

## What it is

The commander workflow turns a natural-language goal into a controlled sequence of intake, authorization, execution, evidence-based validation, and resumable handoff. It is designed for Codex work in a local project, with explicit boundaries for files, permissions, remote services, and irreversible actions.

## Minimal route

1. Read the [English overview](../../../README.en.md) and the [Chinese operator manual](../01-操作者操作手册.md).
2. In the project that Codex should modify, start a task and point it to the workflow directory.
3. State the goal, allowed scope, exclusions, and acceptance evidence.
4. Let the commander separate planning from execution, preserve a checkpoint, and report what was actually verified.

## Core ideas

- **Single accountable commander:** one window owns intake, ordering, and final reporting.
- **Authorization is scoped:** local edits, remote writes, deployment, and external communication are separate permissions.
- **Evidence beats claims:** “planned”, “executed”, and “verified” are different states.
- **Handoff preserves continuity:** a snapshot records the next safe action; it does not grant new permissions or transfer code by itself.
- **Cross-task messages use two channels:** “no reply” means no reply to the source, never no visible feedback to the operator.

## Keeping this page stable

Use this page as an orientation and vocabulary map, not as a translated replacement for the manuals. When a rule matters to the current task, follow the linked Chinese source and re-check its current version. Translations for a release or a specific scenario can be generated on demand without maintaining a full parallel manual.

## Selected source documents

- [Operator manual](../01-操作者操作手册.md)
- [Core rules](../02-总指挥核心规则.md)
- [State, goal changes and handoff](../04-状态、目标变更与交接规范.md)
- [Authorization and risk levels](../09-自动化授权与风险分级.md)
- [Independent review standard](EXECUTION_AND_INDEPENDENT_REVIEW.md)
