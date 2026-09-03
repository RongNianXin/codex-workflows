<div align="center">

# Codex Workflows

**A documentation-first workflow kit for planning, execution, verification, and reliable handoffs in Codex Desktop.**

Personal workflow rules, Windows troubleshooting notes, and small local utilities.

[简体中文](README.md) | **English**

<!-- README-SOURCE-SHA256: 8e610b77566ecae65e1c899a1af57079cafa620fd8245fd9fd7941f42357f5ef -->

[![Repository quality](https://github.com/RongNianXin/codex-workflows/actions/workflows/repository-quality.yml/badge.svg)](https://github.com/RongNianXin/codex-workflows/actions/workflows/repository-quality.yml)
[![Last commit](https://img.shields.io/github/last-commit/RongNianXin/codex-workflows?label=last%20commit)](https://github.com/RongNianXin/codex-workflows/commits/main)
![License: MIT](https://img.shields.io/badge/license-MIT-2F855A.svg)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078D4.svg?logo=windows11&logoColor=white)

<br />

<img src="assets/repository-cover.png" alt="Codex Workflows repository cover" width="100%" />

</div>

<p align="center">
  <strong><a href="SHOWCASE.md">View real-world previews / 查看真实运行效果</a></strong>
</p>

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
| Install userscripts for ChatGPT on the web | [ChatGPT-Web](ChatGPT-Web/README.en.md) |

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
- Reviewable userscripts and setup notes for ChatGPT on the web.
- Repository checks for Markdown, PowerShell, rule-version consistency, and generated artifacts.

## Bilingual README contract

Every public directory that contains a tracked `README.md` also contains a `README.en.md`, with language links in both files. The Chinese page is the content source. The English page records a SHA-256 marker for the Chinese source, and the repository check scans every directory for missing pairs, broken language links, or an English page that has not been reviewed after its Chinese source changed.

This gate detects missing or stale pages; it cannot prove that a translation is semantically correct. Before committing, the maintainer must still compare the purpose, prerequisites, steps, commands, permissions, security boundaries, and limitations. Ambiguous product terms or behavior remain explicitly unverified.

## Optional local operator collaboration profile

The profile helps Codex remember verified technical preferences, current familiarity, effective collaboration patterns, and recurring operational mistakes. Its purpose is to reduce repeated explanations and add timely safeguards—not to build an identity file or infer permissions.

It is off by default. When a commander is first established for a project, Codex introduces it once after answering the main request. Only an explicit opt-in enables it; declining or ignoring the question keeps it off and suppresses repeated prompts in that project. When enabled, it performs a local review only at a stable major milestone, before a commander handoff, when the same collaboration issue recurs, or on request. It creates no scheduled job or background monitor.

Natural-language controls:

- Enable: `开启本地操作者协作画像`
- Pause or resume: `暂停本地操作者协作画像` / `继续本地操作者协作画像`
- Disable: `关闭本地操作者协作画像`
- Disable and delete local data: `关闭并删除本地操作者协作画像`
- Check safety status only: `查看本地操作者协作画像状态`

The privacy claims are auditable: the real profile stays in an exact `.gitignore`-excluded local path and must also be verified as untracked; it excludes identity, contact details, real projects, local paths, chat transcripts, sensitive attributes, and personality judgements; handoffs carry only state and a generic pointer, never the profile body or content hash; the active set is capped at 20 entries with expiry and supersession rules. Any derived public copy requires Codex to show the final sanitized payload first, followed by a second precise approval in a separate user message. `.gitignore` is not encryption or operating-system access control, so highly sensitive material still does not belong in the profile. See the [operator profile specification (Chinese)](总指挥工作流/第二代总指挥的工作模式/11-操作者协作画像规范.md). Deleting that public specification is not an off switch and does not delete local data.

## Current scope and limitations

- The workflow is Windows-first and documentation-heavy.
- The detailed rules are primarily in Chinese.
- It is a personal project, not an official standard or a guarantee of professional, legal, security, or business acceptance.
- Product behavior and third-party tooling can change; re-check time-sensitive instructions before relying on them.

## License

Released under the [MIT License](LICENSE).
