# Codex session handoff assessment

[简体中文](README.md)

Save frequently used task IDs and query local Codex turns, file size, compaction and handoff guidance with one click. **Recommended version: Windows desk 0.2.0-dev.9.** No commands are required for everyday use. Source sessions are read-only; data is not uploaded.

## Download and start

1. [Download the standalone Windows ZIP](https://github.com/RongNianXin/codex-workflows/releases/download/windows-sessiondesk-v0.2.0-dev.9/Windows-SessionDesk-0.2.0-dev.9.zip), extract it completely, and double-click the root `Start-SessionDesk.cmd`. You do not need to clone the repository. Do not open the HTML by itself.
2. If you cloned the repository, double-click [Start-SessionDesk.cmd](Start-SessionDesk.cmd). The default branch provides source for the same version.
3. Save a task ID and select Query / Refresh. The conversation name and local project are detected automatically. Basic and detailed reports have separate areas, with Simplified Chinese and English available.

Uses built-in Windows PowerShell 5.1 and a browser. Windows Edge is tested; macOS and other browsers are not. This remains a development preview, without a claim of comprehensive device or very-large-log compatibility.

`windows-local` contains the application, not temporary files. Use the launcher in this directory. Personal tasks and history stay in its `.local` folder and are excluded from distribution.

## Everyday use

- No fixed saved-task count limit; regression covers 20 tasks. Search, arrow ordering and stable project grouping are available, with order saved to disk.
- Each task retains its latest successful basic output and detailed report per language. Reopening shows the original query time and a historical-snapshot notice; statistics update only on a new query.
- **Closing the page does not stop the background service.** Select Exit tool at the top of the page when finished to stop this tool and its unfinished queries, without stopping Codex conversations. Bilingual hover help explains the button. Close the page after the prominent exit confirmation and use the launcher to restore saved tasks and results.
- An interrupted or failed refresh does not turn old history into a new success. Previously saved history remains available after reopening. A visible result does not mean the AI is currently running.

See the [Windows desk guide](windows-local/README.en.md) for storage, invalidation rules and bilingual maintenance. [Real-world previews](../../SHOWCASE.md) collects redacted screenshots.

## Upgrading and older versions

Stop the old tool and back up its `windows-local/.local` directory before copying it to the corresponding location in the new folder. Do not overwrite another existing data set. It contains task lists, history and reports, so retain it before deleting a program folder. dev.5 and earlier cannot reconstruct basic output that was never saved; full history starts with successful dev.6 queries.

Old HTML prototypes and synthetic demos are retired from the current distribution. Their development stages remain in Git history. This page recommends the current Windows version only. The command-line analyzer remains available for scripting and independent checks; it is the same statistical implementation.

## Command line and validation

- The [command-line quick guide](查看当前任务本地对话文件大小.md) (Chinese) uses the same `check-codex-session.ps1`. Chinese is the default; add `-Language en-US` for English.
- `compatibility-fixtures.json` contains synthetic regression cases for the repository’s JSON field-order checks, not user data.
- Release preparation includes 41 isolated synthetic interaction checks, repository quality checks and ZIP verification. The operator reported successful dev.9 manual use. Automated regression does not prove exhaustive real-session, macOS or all-device support.

## Statistics and privacy

Results are engineering guidance, not official thresholds or live status. Segment baselines, truncated input, actively written logs and missing counts can affect completeness. A result is a reading snapshot, not an atomic live ledger. Names and projects depend on Codex local record formats and may require adaptation when those formats change.

Detailed reports and history can contain complete user input and local paths. They remain in `.local` and must not be published without review. ZIP files exclude private state. The service listens only on loopback and validates a random connection token. Exit does not stop other programs or Codex tasks. Preserve the analyzer’s integrity warnings; missing Token counts must not be treated as zero.

<!-- README-SOURCE-SHA256: d7f53796b374468c3c6d779153c8433f2a0d4026ef7d2bcdb3e79e4cdf6911a6 -->
