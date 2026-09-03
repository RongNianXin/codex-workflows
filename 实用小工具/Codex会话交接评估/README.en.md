# Codex session handoff assessment

[简体中文](README.md)

<!-- README-SOURCE-SHA256: e757f418547c29a8b0f29642821a28649aae49fd2006f1143aed91c5728ba1cd -->

This directory provides a read-only PowerShell tool for assessing a local Codex task before handing work to a new task. It reports session size, detected turns, compaction count, recent context usage, and a heuristic handoff recommendation. It also writes a Markdown report with token and local file composition details.

The Chinese repository rules remain the normative source. This English file covers the public entry point for this tool and is not a line-by-line English mirror of the repository.

The [real-world preview page](../../SHOWCASE.md) includes the owner-approved terminal screenshot. Its task ID is redacted, while local directory labels, the task name, and runtime statistics remain visible by explicit permission.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7
- A Codex task stored on the same computer
- The task ID to inspect

The script does not modify the source session and does not access the network.

## Run in English

Open PowerShell in this directory and replace `<TASK_ID>`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\check-codex-session.ps1" -TaskId "<TASK_ID>" -Language en-US
```

To use PowerShell 7 instead:

```powershell
pwsh -NoProfile -File ".\check-codex-session.ps1" -TaskId "<TASK_ID>" -Language en-US
```

The default language is Simplified Chinese. Existing commands without `-Language` continue to work. You can also select Chinese explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\check-codex-session.ps1" -TaskId "<TASK_ID>" -Language zh-CN
```

Each run uses one language for both terminal output and the generated Markdown report. Task names, user input, session paths, and other source data are preserved as recorded and are never translated.

## Report location

An English run writes its default report under the current user's local application data directory:

```text
CodexSessionHandoffAssessment\Reports\<TASK_ID>-detailed-analysis-report.md
```

Use `-ReportPath` to choose another Markdown path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\check-codex-session.ps1" -TaskId "<TASK_ID>" -Language en-US -ReportPath ".\report.md"
```

The report is written as UTF-8 with BOM and replaces the previous report at the same path only after write-back verification succeeds.

## Reading the result

- Session storage describes whether local segments are active, archived, or mixed. It does not prove that the Codex app is currently running.
- Milestones show file size after every fifth identified turn before the latest turn. The latest turn is shown separately.
- The handoff score uses local file size and compaction count. Recent context usage is shown as an observation but is not part of the score.
- Thresholds in this tool are local heuristics, not official OpenAI limits.
- A high score should not interrupt an unsafe or incomplete step. Finish the stage or stop at a clear handoff point first.

## Privacy and accuracy

The terminal does not print conversation bodies, tool output, or image contents. The detailed report may include complete user input from the three highest-token turns, local paths, or other sensitive information. Review and redact it before sharing.

Codex JSONL files are implementation data rather than a stable public API. The script reports warnings when records cannot be parsed, session files change during scanning, or multiple storage segments require special handling. Runtime depends on session size, disk speed, antivirus software, and synchronization software; a fixed completion time cannot be guaranteed.
