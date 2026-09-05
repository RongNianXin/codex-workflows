# Codex session handoff assessment

[简体中文](README.md)

<!-- README-SOURCE-SHA256: afdf9c9dc6cc3ecab3dcc2bf8048e97d5fad3bfd4863c8f4c16564c2af55d9bb -->

This directory provides a read-only PowerShell tool for assessing a local Codex task before handing work to a new task. It reports session size, detected turns, compaction count, recent context usage, and a heuristic handoff recommendation. It also writes a Markdown report with token and local file composition details.

The Chinese repository rules remain the normative source. This English file covers the public entry point for this tool and is not a line-by-line English mirror of the repository.

The [real-world preview page](../../SHOWCASE.md) includes the owner-approved terminal screenshot. Its task ID is redacted, while local directory labels, the task name, and runtime statistics remain visible by explicit permission.

## Local task panel prototype

[Download or open the single-file prototype](task-panel-prototype.html). Save the HTML file locally and open it in a modern browser. No terminal, server, or dependency installation is required. GitHub normally shows the source first; download the file before opening it.

Six fixed fictional tasks demonstrate search by name/ID/project, duplicate-name identification, favorites, individual queries, batch refresh and cancellation, summaries, cache timestamps, and a detailed report dialog. All queries and metrics are simulated. The page does not read real sessions or connect to the PowerShell analyzer.

Click a star to save a favorite, then use the query or refresh button. Select tasks to refresh a batch. The “资料整理” example fails on its first query and succeeds on retry. Expand the demo settings to expire the current result or reset all examples. Failure and cancellation preserve earlier successful results. Batch refresh includes selected tasks hidden by the current filter; the button shows the total, and the clear-selection button lets you start again.

Favorites and results are saved only in the current browser's local storage, without conversation text. Results expire after five minutes for demonstration purposes. Storage behavior for local files varies by browser; changing browsers or moving the file may prevent records from carrying over. If storage is unavailable, the page shows a warning and remains usable for the current visit.

The same HTML interface is intended for Windows and macOS browsers. Only headless Edge on Windows has been tested; macOS/Safari has not been tested on a real device. This does not establish cross-platform compatibility for real data access. Integration still requires a file-selection and permission design, an analyzer output contract, and verification of cache invalidation, large logs, and sensitive report handling.

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
