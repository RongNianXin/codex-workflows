# Codex historical-task bulk migration package

[简体中文](README.md) | **English**

<!-- README-SOURCE-SHA256: 243511c2df10478bae667dbd5c0cbc50c5c1260161cc75b6e6f4b7820b4541c2 -->

## Current status

- **Installation against real sessions is suspended.** `--apply` fails before scanning, backing up, or modifying any real task.
- The previous version validated each file independently. It did not prove that a child's `history_base.end_byte_offset` still identifies the same byte prefix after its parent is rewritten.
- The public package currently retains the transformation source, synthetic tests, and rollback support for existing backups so the design can be reviewed and repaired.
- Locally generated scan reports may contain absolute paths and real task IDs. They are excluded by `.gitignore` and are not runtime dependencies of the installer.
- The self-test and lineage tests use only synthetic values or temporary directories. They do not enumerate real session contents.

## Purpose

The package scans only Codex tasks that are currently unarchived. It removes hidden reasoning and compaction ciphertext that is bound to the original provider and cannot be verified after an account or API-provider change. User messages, visible AI responses, tool calls, and other non-encrypted structures are preserved. Archived tasks under `archived_sessions` are not scanned, backed up, or modified.

This addresses compatibility when continuing the same visible task. It does not and cannot convert the original provider's hidden reasoning ciphertext for another provider.

## Public validation result

Local tests confirmed that fail-closed protection is active, expected encrypted fields are removed, non-encrypted structure digests remain unchanged, and manually created backups are not treated as live tasks. These results do not replace validation against the current Codex release and your own backup.

## Installation status

Do not use `安装批量迁移.cmd` against real tasks. The entry point now reports the risk and exits.

The old exact-task command is also suspended and cannot bypass the gate:

```powershell
node install_bulk_codex_migration.mjs --apply --task "00000000-0000-0000-0000-000000000000"
```

Re-enabling installation requires proof that every referenced parent exists; every offset is a non-negative safe integer within bounds; each parent candidate is byte-identical to its source before every referenced cutoff; and archived or out-of-set parents are explicitly included. No real-data validation has been performed, so the gate remains closed.

Available checks:

```powershell
node safety_tests.mjs
node lineage_tests.mjs
node install_bulk_codex_migration.mjs --self-test
```

The first verifies visible-content preservation and fail-closed handling of unknown ciphertext. The second creates wholly synthetic fixtures in a temporary directory for no-lineage, parent-child, multi-level, multiple-child, out-of-set, out-of-range, repeated-check, and restored-original cases. The third checks synthetic process names, the task selector, and temporary-file metadata without reading real sessions.

## Rollback

After Codex and CC Switch have been completely closed, double-click `回滚最近一次批量迁移.cmd`. Before restoration, the rollback tool backs up the post-migration state so evidence is not destroyed by an overwrite.

## Backup location

`<USER_HOME>\Documents\Codex\CodexSessionBackups\bulk-<TIMESTAMP>`

Each installation directory contains `manifest.json`, copies of the original task files, and any Codex/CC Switch configuration and database files that existed at the time. Use the rollback script for restoration rather than replacing only `config.toml`. Restoring configuration alone does not restore task history and may create an inconsistent configuration/history state.

## Known limitations

The previous migration handled only ciphertext in currently unarchived tasks and ignored cross-file pagination lineage. Even after lineage validation is repaired, a provider may write new hidden ciphertext and a later switch to an incompatible provider may reproduce the failure. Long-term compatibility still requires upstream support for cross-provider state conversion. Setting only `model_provider = "custom"` does not change ciphertext ownership.

This tool is not derived from or packaged from `codex-session-cleaner` or `codex-rescue`, and it does not copy their source code. See the [related-project, license, and implementation-difference notes](<../../相关项目、许可证与差异说明.md>) for details.
