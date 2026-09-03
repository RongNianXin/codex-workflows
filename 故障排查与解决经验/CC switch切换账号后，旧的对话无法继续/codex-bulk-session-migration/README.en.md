# Codex historical-task bulk migration package

[简体中文](README.md) | **English**

<!-- README-SOURCE-SHA256: fc127ece67dfda25c2b0acdacf02ed07505e93cc49c01a6c7e2e031c40419842 -->

## Current status

- The public package includes conversion, structural validation, backup, atomic replacement, and rollback procedures.
- Locally generated scan reports may contain absolute paths and real task IDs. They are excluded by `.gitignore` and are not runtime dependencies of the installer.
- Before installation, you can run two read-only or temporary-file self-tests. The installer revalidates every candidate and original file before applying changes.

## Purpose

The package scans only Codex tasks that are currently unarchived. It removes hidden reasoning and compaction ciphertext that is bound to the original provider and cannot be verified after an account or API-provider change. User messages, visible AI responses, tool calls, and other non-encrypted structures are preserved. Archived tasks under `archived_sessions` are not scanned, backed up, or modified.

This addresses compatibility when continuing the same visible task. It does not and cannot convert the original provider's hidden reasoning ciphertext for another provider.

## Public validation result

Local tests confirmed that fail-closed protection is active, expected encrypted fields are removed, non-encrypted structure digests remain unchanged, and manually created backups are not treated as live tasks. These results do not replace validation against the current Codex release and your own backup.

## Installation

1. Exit Codex completely, including any taskbar or system-tray process.
2. Exit CC Switch completely, including its system-tray process.
3. Double-click `安装批量迁移.cmd`.
4. Do not restart Codex until the window reports installation success and shows the backup directory.
5. Open the task that previously failed and send a short message. Then switch to another provider and test the same task again.

If only one task needs repair, open PowerShell in this directory and select it by exact task UUID:

```powershell
node install_bulk_codex_migration.mjs --apply --task "00000000-0000-0000-0000-000000000000"
```

Replace the example UUID with the real task ID at the end of the session filename, but never post that ID in a public issue. The tool requires exactly one matching file in the current unarchived-session directory and refuses ambiguous input. Do not use a selector such as `last`: copying or migrating files may have changed modification times, so "most recently modified" is not a reliable identity rule.

The installer refuses to run if it detects Codex, ChatGPT, CC Switch, or related Codex background processes. It enumerates only current unarchived tasks under `.codex\sessions` and does not enter `.codex\archived_sessions`. It then generates and validates candidate files, forces candidate data to disk, backs up the affected unarchived tasks plus Codex configuration/state databases and the CC Switch database, and atomically replaces each target. Original access time, modification time, and file permissions are restored so the migration does not alter `codex resume` ordering signals or access boundaries. Any detectable apply failure automatically restores files that were already replaced.

Before applying changes, run `node safety_tests.mjs` and `node install_bulk_codex_migration.mjs --self-test`. The first verifies visible messages, attachment metadata, and fail-closed handling of unknown encrypted structures. The second only enumerates and validates unarchived task paths; it does not read or modify task contents.

## Rollback

After Codex and CC Switch have been completely closed, double-click `回滚最近一次批量迁移.cmd`. Before restoration, the rollback tool backs up the post-migration state so evidence is not destroyed by an overwrite.

## Backup location

`<USER_HOME>\Documents\Codex\CodexSessionBackups\bulk-<TIMESTAMP>`

Each installation directory contains `manifest.json`, copies of the original task files, and any Codex/CC Switch configuration and database files that existed at the time. Use the rollback script for restoration rather than replacing only `config.toml`. Restoring configuration alone does not restore task history and may create an inconsistent configuration/history state.

## Known limitations

This migration handles only ciphertext already present in unarchived tasks at runtime. Archived tasks remain unchanged. If they are later returned to the current list and must continue under another account, run the tool again. A provider can also write new hidden ciphertext, so switching later to a provider that cannot decrypt it may reproduce the failure.

Long-term automatic compatibility requires the same offline cleanup, backup, and validation transaction in the CC Switch provider-switching flow, or upstream support for cross-provider state conversion. Setting only `model_provider = "custom"` does not change ciphertext ownership.

This tool is not derived from or packaged from `codex-session-cleaner` or `codex-rescue`, and it does not copy their source code. See the [related-project, license, and implementation-difference notes](<../../相关项目、许可证与差异说明.md>) for details.
