# Windows session query desk

[简体中文](README.md)

<!-- README-SOURCE-SHA256: b2d6d13e37433374136094396264a871641dd29865e5f7b3aa8585a0cf03a323 -->

Version: `0.2.0-dev.1`. This first version implements “save a name and ID → query a task → display the original script output.” **It is fixed to isolated synthetic data and does not read real sessions.** It is separate from the earlier A/B file-selection demo.

## Use

1. Extract the delivery completely and double-click the root `Start-SessionDesk.cmd`. In a repository checkout, use the file with that name in this directory. It starts a background service and opens the default browser. Only Windows Edge was tested.
2. Enter a conversation label and task ID, then save. For initial testing, expand the fixture-ID helper, fill sample one, and save. Samples one and two have synthetic logs; sample three deliberately has none.
3. Click the task's query/refresh button. The right pane displays the original script's basic information, file resources, and handoff advice. The report button displays the local Markdown report as text.
4. Add more tasks, search names or IDs, rename, or delete. Saving an existing ID updates it; matching names are distinguished by ID.
5. Exit the local service from the page and launch again to restore the list. Closing the browser does not exit the service or delete the list.

No log selection, command line, or new dependency installation is required for use. Built-in Windows PowerShell 5.1 runs the service and analyzer. Node and Playwright are development-test dependencies only. If device policy blocks startup, do not change global execution policy or elevate privileges; provide the displayed error text without real logs.

## Storage and data boundaries

Instance data lives under this directory's `.local/`; the default instance is `main`:

- `main/tasks.json`: persistent labels and IDs, written through a temporary file and atomic replacement. Invalid existing data stops startup without silently resetting it.
- `main/reports/`: local analyzer reports. Deleting a task does not delete its reports. Preserve the data directory before updating or moving the software.
- `main/fixtures/` and `main/runtime/`: generated synthetic logs and an isolated analyzer copy.
- `main/connection.json`: credentials for the current service run, removed on exit; it is not the saved task list.

The list is disk-backed rather than browser-cache-backed and is intended to survive normal shutdown and system restart. Service restart recovery was tested; the operating system was not rebooted. Deleting the extracted directory deletes its contained data. Lists and reports are local-only and must not be committed or uploaded. Do not forward a populated `.local` directory: it can contain custom names, IDs, paths, and connection credentials.

Any canonical ID can be saved, but queries accept only the three all-zero fixture IDs ending in `1`, `2`, and `3`. Other IDs are explicitly rejected with no fallback to real directories. Samples one and two run the analyzer; sample three exercises the same isolated discovery path and returns a missing-log error.

Exactly four user-directory expressions are replaced with the isolated directory, and reverse substitution is checked against the original source. The report path is fixed explicitly. Neither the algorithm nor the real user-profile environment is modified, and no real-data switch exists. Output reflects the script's latest read, not live model activity. Report paths identify local isolated directories and should not be published in unchecked screenshots.

## Local service limits

- Listens only on `127.0.0.1`; validates Host, Origin, and a random access token, with no cross-origin access.
- Exposes task-list management, a fixed analyzer query, reports for current successful queries, and shutdown. Clients cannot supply a command or file path.
- Only one service writes a state directory. At most two queries run concurrently; duplicate requests for a running task reuse that query. Analyzer children exceeding 120 seconds are terminated.
- New queries clear the task's old display. Task and run identifiers keep results associated correctly while switching tasks. Reports require a current successful query.
- Shutdown terminates active analyzer children. Startup at login, scheduled refresh, and individual-query cancellation are not implemented.

## Verification and limitations

Twenty integration checks passed on existing Windows PowerShell 5.1 and headless Edge 149: non-elevated loopback startup, one writer, access restrictions, saved tasks/search/rename, duplicate queries, concurrent result assignment, missing-log failure, reports, restart recovery, and shutdown. The right-pane text exactly matched direct execution of the same isolated analyzer. The original analyzer was unchanged; there were no page errors or external HTTP requests.

Developers with existing Node, Playwright, and Edge can run from the repository root:

```sh
node .github/scripts/Test-WindowsSessionDesk.cjs
```

Expect 20 passing checks, empty `errors`, and `external: 0`. The test starts and stops isolated instances without installing dependencies. Preserve the first error on failure rather than modifying the original analyzer or weakening assertions. Screenshots stay in a Git-ignored directory.

macOS, other default browsers, real sessions, very large logs, OS restart, device-policy differences, and signed installation remain unverified. This version validates the interface and local execution path, not real-data production use.
