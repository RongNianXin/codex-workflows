# Windows session query desk

[简体中文](README.md)

<!-- README-SOURCE-SHA256: 8a52a4053ef03a59ced04c55877bdcc7fb6314a07856d73bdf6e6182d6d1fe9b -->

Version: `0.2.0-dev.3`. **Real local session queries are enabled.** Enter a task ID, save it, and query to view the original analyzer's statistics and report. Source sessions are read-only. No data is uploaded and no dependencies are installed.

## Usage

1. Extract the complete package to a short path and double-click the root `Start-SessionDesk.cmd`; in a checkout, use the launcher in this directory. Do not open HTML directly. Windows PowerShell 5.1 starts the background service and opens the default browser; Windows Edge was tested.
2. Enter the required task ID and save. Names and projects are no longer entered manually. There is no fixed task-count limit; regression covers 20 tasks, not very large lists. Duplicate IDs are rejected without replacing saved records.
3. Click Query / Refresh, then read the output or View detailed report. Only local log files matching that ID and passing session-identity checks are analyzed, across active and archived directories. Cloud tasks are not queried; missing local logs produce an explicit failure.
4. Search by project, name or ID, view existing results, or remove list entries. Each row displays project on the left, name on the right and ID below.
5. Choose Simplified Chinese or English at the top. Prompts, statistics and reports switch together; names, projects, paths and log content are not translated. Switching is unavailable during a running query, and regenerates the selected task's result afterward.
6. Click Stop local service when finished. Closing the browser does not stop the background service. Stopping it does not delete saved tasks.

Share startup error text, not real logs. Do not change global execution policy or elevate privileges. Deep paths may cause file-not-found errors in legacy PowerShell; extract to a shorter path.

## Name and project synchronization

Conversation names come from the last valid matching entry in the local `session_index.jsonl`. Projects come from explicit task-to-local-project assignments and project names in `.codex-global-state.json`. The default source is `.codex` in the user profile; a configured `CODEX_HOME` takes precedence. Project names are never guessed from folders, log content or manual labels.

While visible, the page checks metadata—descriptive information such as names and projects—about every three seconds. Renaming does not rerun log analysis. After Codex saves a rename to disk, the list, result heading, output name field and open report's name field update together. Project-name case changes also update. Old names inside historical log content remain historical text; there is no global replacement. The original report on disk remains the query-time snapshot; page name/project fields use the latest available metadata, while statistics retain their original query time.

These are locally observed desktop formats, not a guaranteed stable public interface. Remote projects, unassigned tasks, missing files, corrupt or truncated records, and renames not yet saved by Codex may prevent fresh metadata. Existing labels are retained with an explicit unavailable/stale-information notice; new tasks show unavailable values. A last-known label is not confirmed current membership. The desk never writes back to Codex metadata files.

## Data and compatibility

Instance data lives in this directory's `.local/`, with `main` as the default instance:

- `main/tasks.json` stores IDs, last-known names/projects and language. Writes use atomic replacement; corrupt files are not cleared.
- Schema 1 and 2 lists are accepted. Schema 1 is copied exactly to `tasks.schema1.<random-id>.bak` before migration. Old manual labels are historical values until replaced by detected metadata. Manual metadata editing is removed.
- Before upgrading, stop the old service and copy its `.local` to the new package's `windows-local/.local`. Do not overwrite an existing new list. Independently retained backups may also be restored. To roll back, stop the service and restore the pre-migration backup; later additions are not automatically merged into that backup.
- `main/reports/` contains original analyzer reports and metadata. Reports may include complete user inputs from high-usage turns and local paths. They stay local; removing a task entry does not remove its reports.
- `main/runtime/` holds an analyzer runtime copy. Original source and algorithms are unchanged. `main/connection.json` holds the current service token and is removed on exit.

`.local` is private and must not be distributed in ZIPs, committed or published. Persistence uses disk, not browser storage. Service restart was tested, not operating-system reboot. Deleting the program directory also deletes its data; back up first.

## Execution boundaries

- Listens only on `127.0.0.1`, validating Host, Origin and a random token. Clients cannot supply scripts, commands or file paths.
- Only saved, well-formed IDs can be queried. Logs are filtered by ID and their session identity is checked. Codex logs and metadata remain read-only.
- One writer per data directory; at most two simultaneous queries, independent of list capacity. Repeated requests for a running task in the same language reuse its job. A 120-second timeout or service shutdown terminates only analyzer children started by this service.
- Queries clear old displays and bind results to a task and run identifier. Failed queries cannot open old reports. Metadata updates and statistical updates are separate; this is not a live AI execution monitor.
- Statistical policy is unchanged. The original script's integrity notices and known limits still apply. An active session can change while being read; output is a reading snapshot, not an atomically frozen live ledger.

## Maintenance, packaging and verification

UI text is centralized in `desk.html` under `messages`, with paired Chinese and English values. Chinese edits require English review and an updated `I18N-SOURCE-SHA256`. Service errors and documentation also require paired updates. The fingerprint detects Chinese changes but cannot replace semantic review.

With existing Node, Playwright and Edge:

```sh
node .github/scripts/Test-WindowsSessionDesk.cjs
```

Regression always uses isolated synthetic data. It covers ID-only entry, 20 saved tasks, duplicate rejection, migration backups, name/project changes, updates to an already-open report, unchanged statistics, bilingual behavior, stale-output clearing, truncated metadata, access restrictions, narrow screens and shutdown. The real-mode branch is tested with an explicitly synthetic `CODEX_HOME`, never the developer's real sessions.

Package with:

```powershell
pwsh -File .github/scripts/Build-WindowsSessionDesk.ps1
```

Before packaging, the script verifies entry paths, PIDs and connection tokens for old desk services under this checkout's tool and release directories, then requests graceful shutdown. If safe shutdown fails, packaging stops with instructions to click Stop local service in the old page. It never kills PowerShell processes indiscriminately. Exactly ten program/documentation files are packaged, excluding `.local`; existing packages are not overwritten. Old copies outside the checkout must be stopped manually in their own pages.

A real task's name and project sources were confirmed read-only. Host approval blocked automated verification of real log statistics, so real statistical acceptance is not claimed. The operator can actively enter their own ID in this build and compare output with the original script. Report errors or redacted summaries, not raw report content. macOS, cloud/remote tasks, very large logs or lists, operating-system restart and device-policy differences remain unverified.
