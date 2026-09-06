# Windows session query desk

[简体中文](README.md)

<!-- README-SOURCE-SHA256: 8f3e56ebf56a05fe1fcb0fe646126df810974c88510d983b32c0994d4907f544 -->

Version: `0.2.0-dev.2`. Save tasks, click to query, and read the original analyzer output and detailed report on the right. **This build only uses isolated synthetic data. It does not read real sessions.**

## Usage

1. Extract the complete package and double-click the root `Start-SessionDesk.cmd`. In a repository checkout, use the launcher in this directory. The background service opens the default browser; Windows Edge was tested.
2. Enter the required task ID. Project and conversation name are optional. To try it, expand “Use a synthetic test ID”, fill sample 1, then save.
3. Click “Query / Refresh” on that task. The right pane shows the original script output; “View detailed report” opens the local report. Samples 1 and 2 have synthetic logs; sample 3 tests missing logs.
4. Save more IDs. Each row shows the project on the left, the conversation name on the right, and the ID below. Search by any of these fields. There is no fixed task-count limit; 20 tasks were tested. Very large lists have not been performance-tested.
5. Adding a duplicate ID shows an error and preserves the existing record. To change a saved task, click its “Edit” button. The ID is fixed during editing; a successful save returns the form to add mode.
6. Choose “简体中文” or “English” at the top. UI, errors, query output and reports use that language. Switching clears old results and queries the selected task again. Language switching is unavailable while queries are running. Names, projects, log content and paths are source data and are not translated.
7. Stop the local service and launch it again: tasks and the language setting remain saved. Closing the browser neither deletes the list nor automatically stops the service.

No command line or new dependencies are required. The application uses Windows PowerShell 5.1; Node and Playwright are development-test tools only. If device policy prevents startup, do not change global policy or elevate privileges. Share the startup error text, not real logs.

## Names and projects

A name is filled or updated only after a successful query when the original analyzer finds a valid indexed name without parsing warnings. A changed name triggers a three-second notification. If that task is being edited, its name field briefly receives an amber outline, without continuous flashing. The previous name is retained locally and visible in the result and edit panels, so verification does not depend on the transient notification. Only the most recent replaced name is retained, not a full version history.

Missing logs, absent names and index-read errors do not overwrite existing names. A failed name save is reported separately: successful analysis does not imply successful persistence. If a detected name exceeds 80 characters, the saved name is retained; the full detected name remains available in the report.

The original analyzer has no reliable project-name field. Project is therefore entered manually, never guessed from a name or path. Project and ID distinguish conversations with matching names.

## Local storage and isolation

Each instance stores data in this directory's `.local/` folder; the default instance is `main`:

- `main/tasks.json`: tasks and language settings. Writes use a temporary file and atomic replacement to prevent partial content from replacing the complete list. An invalid file stops startup rather than being cleared.
- Legacy schema 1 lists are backed up as `tasks.schema1.<random-id>.bak` before migration to schema 2. Names and IDs are retained; project fields start empty. Before upgrading, stop the old service, copy the old package's `windows-local/.local` into the same location in the new package, then launch the new version. Do not run two copies of the data at once. To roll back, stop the new version and restore `tasks.json` from the pre-migration backup before launching the old version. Subsequent changes are not written back to that backup.
- `main/reports/`: local reports and name-reading metadata. Deleting a list entry does not delete its report.
- `main/fixtures/` and `main/runtime/`: generated synthetic logs and the isolated copy of the original analyzer.
- `main/connection.json`: the current service's random access token; removed on shutdown.

Persistence does not depend on browser storage. Service restart was tested; the operating system was not restarted. Deleting the extracted directory also deletes its data. `.local` is local-only: do not commit or distribute it, because it may contain custom names, IDs, paths and connection tokens.

Any standard UUID can be saved, but queries only accept the three synthetic all-zero-prefix IDs ending in 1, 2 or 3. Other IDs are rejected without falling back to real directories. The original script's four user-directory expressions are replaced with the fixed fixture directory and reverse-checked against the source. The service fixes report paths. The original analyzer file and statistical algorithms are unchanged, and there is no real-data mode switch.

## Local service boundaries

- Listens only on `127.0.0.1`; validates Host, Origin and a random access token; no cross-origin access.
- Clients cannot supply commands or file paths. Only one writer can own a state directory. Saved-task capacity is independent of query concurrency.
- At most two queries run simultaneously. Repeated requests for a running task in the same language reuse that query. A 120-second timeout terminates the child process started by this service; shutdown also terminates unfinished children.
- New queries clear old displays. Results belong to a task, run identifier and language; reports are available only for the current successful query. No automatic refresh, per-query cancellation or system autostart is provided.
- Output describes the latest query snapshot, not live AI activity. Reports may contain local fixture paths and should not be published as unreviewed screenshots.

## Bilingual maintenance and verification

UI text is centralized in `desk.html` under `messages`, with Chinese and English supplied together for every key. When functionality or Chinese wording changes, review the English in the same change, update the Chinese `I18N-SOURCE-SHA256` marker, and regress both languages. Tests check complete pairs and the Chinese source fingerprint; the fingerprint cannot prove translation accuracy, so semantic comparison remains necessary. Service errors must also be maintained in both languages. Queries and reports use the original analyzer's language catalog rather than a separate statistical translation layer.

With existing Node, Playwright and Edge, run:

```sh
node .github/scripts/Test-WindowsSessionDesk.cjs
```

Tests create only isolated synthetic instances and install nothing. Coverage includes 20 saved tasks, duplicate-add rejection, editing and deletion, legacy migration, restart, empty and conflicting names, bilingual output and reports, concurrency, stale-result clearing on failure, input and access restrictions, narrow screens and shutdown. Both languages are compared character-for-character with direct execution of the same isolated script. The original script must remain unchanged, with zero page errors and zero external HTTP requests.

macOS, other browsers, real data, very large logs or task lists, operating-system restart and installation signing remain unverified. This is still a Windows isolated validation build.
