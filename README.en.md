<div align="center">

# Codex Workflows

**A documentation-first workflow kit for planning, execution, verification, and reliable handoffs in Codex Desktop.**

Personal workflow rules, Windows troubleshooting notes, and small local utilities.

[简体中文](README.md) | **English**

[![Repository quality](https://github.com/RongNianXin/codex-workflows/actions/workflows/repository-quality.yml/badge.svg)](https://github.com/RongNianXin/codex-workflows/actions/workflows/repository-quality.yml)
[![Last commit](https://img.shields.io/github/last-commit/RongNianXin/codex-workflows?label=last%20commit)](https://github.com/RongNianXin/codex-workflows/commits/main)
![License: MIT](https://img.shields.io/badge/license-MIT-2F855A.svg)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D4.svg?logo=windows11&logoColor=white)

<br />

<img src="assets/repository-cover.png" alt="Codex Workflows repository cover" width="100%" />

</div>

> [!NOTE]
> This is an independent community experiment. It is not affiliated with or endorsed by OpenAI.

> [!TIP]
> **Maintenance status: active.** New workflows, troubleshooting notes, and local tools are added after verification. See the [changelog](CHANGELOG.md) and commit history for the actual record.

## Why this repository exists

Long Codex tasks can lose their exact stopping point, blur the boundary between local and remote authorization, or treat an old completion claim as current evidence. This repository turns those failure modes into explicit files and checks.

The core workflow covers:

- durable goals, checkpoints, and recovery state;
- single-writer commander handoffs without inheriting old permissions;
- verification evidence and human decision boundaries;
- Windows-first troubleshooting notes and small local tools.

The material is deliberately inspectable. Most of it is Markdown and PowerShell rather than a hosted service or opaque automation layer.

## Start here

| If you want to... | Open... |
| --- | --- |
| Use the commander workflow | [Operator manual (Chinese)](总指挥工作流/第二代总指挥的工作模式/01-操作者操作手册.md) |
| Understand the rule architecture | [Workflow overview (Chinese)](总指挥工作流/第二代总指挥的工作模式/00-第二代工作流总览.md) |
| Troubleshoot Codex Desktop or CC Switch | [Troubleshooting notes](故障排查与解决经验/) |
| Reuse a focused prompt | [Prompt collection](其他%20Codex%20技巧性提示词/) |
| Try a local helper | [Local utilities](实用小工具/) |
| Decide whether a Codex task is ready for handoff | [Session handoff assessment](实用小工具/Codex会话交接评估/README.en.md) |

The detailed manuals are currently written in Chinese. This page is an evaluation and navigation guide for English-speaking visitors.

## Quick start

1. Download or clone this repository.
2. Open the [operator manual](总指挥工作流/第二代总指挥的工作模式/01-操作者操作手册.md).
3. In the project you actually want Codex to work on, start a new Codex task and adapt this instruction:

   ```text
   Use <SECOND_GENERATION_COMMANDER_RULES_DIRECTORY> as this project's commander workflow rules. Read 01-操作者操作手册.md first, then load the other rules required for my goal and begin.
   ```

Use the target project's workspace, not this repository's workspace, unless you are maintaining the workflow itself.

## What is included

- A commander workflow for task intake, authorization, delegation, validation, state recovery, and handoff.
- Sanitized troubleshooting records for reproduced Codex Desktop and CC Switch issues.
- Reusable prompt patterns and Windows-oriented local utilities.
- Repository checks for Markdown, PowerShell, rule-version consistency, and generated artifacts.

## Current scope and limitations

- The workflow is Windows-first and documentation-heavy.
- The detailed rules are primarily in Chinese.
- It is a personal project, not an official standard or a guarantee of professional, legal, security, or business acceptance.
- Product behavior and third-party tooling can change; re-check time-sensitive instructions before relying on them.

## License

Released under the [MIT License](LICENSE).
