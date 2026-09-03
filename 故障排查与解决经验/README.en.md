# Troubleshooting notes

[简体中文](README.md) | **English**

<!-- README-SOURCE-SHA256: 1c735d72e6f25673235151c78e26483945584d83add611329b3171b7c5734941 -->

This directory contains reproduced, reviewed, and sanitized troubleshooting notes for Codex and related tools. Each note should state the symptoms, applicable environment, possible cause, diagnostic steps, expected result, rollback path, and any remaining uncertainty.

## Current contents

- [CC Switch long-task disconnections and quick handling for 401, 502, 503, and 504 errors](<CC Switch 长任务断联与 401 502 503 504 快速处理.md>)
- [Codex conversations becoming invisible after switching CC Switch accounts](<CC switch 切换账号后，无法共享对话/CC Switch 切换账号后无法共享对话——原理、恢复与长期配置.md>)
- [Old Codex conversations failing to continue after switching CC Switch accounts](<CC switch切换账号后，旧的对话无法继续/Codex 切换账号后旧对话无法继续.md>)
- [Bulk migration tool for historical Codex tasks](<CC switch切换账号后，旧的对话无法继续/codex-bulk-session-migration/README.en.md>)
- [Codex archive failure on Windows caused by extended-length paths](<对话无法归档/Codex 对话无法归档：thread-store 文件路径缺失.md>)
- [Recovery procedure for Codex `thread not found`](<thread not found/thread-not-found-恢复方案.md>)
- [Related projects, licenses, and implementation differences](<相关项目、许可证与差异说明.md>)

The linked case reports are currently written in Chinese. This page provides an English diagnostic map without pretending that every detailed article has already been translated.

## Identify the failure class first

| Symptom | Check first | Relevant note |
| --- | --- | --- |
| A task disappears from the list after switching providers, although its JSONL still exists | Visibility or bucketing differences in `model_provider`, the state database, or an index | [Conversation visibility after switching accounts](<CC switch 切换账号后，无法共享对话/CC Switch 切换账号后无法共享对话——原理、恢复与长期配置.md>) |
| The task remains visible, but continuing it returns `invalid_encrypted_content`, `could not be verified`, or an organization mismatch | Encrypted reasoning or compaction state bound to the old account, model, or upstream provider cannot be replayed | [Old conversation cannot continue](<CC switch切换账号后，旧的对话无法继续/Codex 切换账号后旧对话无法继续.md>) |
| Opening, resuming, or typing in a long task becomes noticeably slow | Distinguish local session size and accumulated compactions from proxy/network issues, process resources, and a version-specific regression | [Codex session handoff assessment](<../实用小工具/Codex会话交接评估/README.en.md>) |
| Archiving on Windows returns `thread-store` / `os error 2`, although the session file exists | The `rollout_path` in `state_5.sqlite` may use the `\\?\` extended-length path prefix | [Archive failure](<对话无法归档/Codex 对话无法归档：thread-store 文件路径缺失.md>) |
| The task record still exists, but its original task shows `thread not found` | Check archive state, then send a side-effect-free verification message by task ID to reload it | [`thread not found` recovery](<thread not found/thread-not-found-恢复方案.md>) |
| You want to reduce cross-provider continuation failures before switching CC Switch | Use a pre-switch process gate, backup, candidate conversion, validation, atomic replacement, and rollback transaction | [Bulk historical-task migration](<CC switch切换账号后，旧的对话无法继续/codex-bulk-session-migration/README.en.md>) |

Seeing a task in history and continuing it across providers are different problems. Normalizing `model_provider` can repair visibility, but it cannot transform ciphertext produced for another account, organization, or upstream provider.

## Safety boundaries

- These notes are not official fixes from OpenAI or CC Switch. Whether the current releases still use the same session structures remains unverified.
- Ciphertext migration is a last resort. Restore the original account and provider first. If migration is unavoidable, validate a copy before creating an offline backup, installing the change, and retaining a rollback manifest.
- Do not remove `encrypted_content` by deleting matching text lines. Unknown structures must fail closed rather than be guessed away.
- Session size, compaction count, and context ratios are diagnostic signals. None of them alone proves the cause of latency, cost, or model degradation.
- Share only versions, error codes, counts, sizes, timestamps, and sanitized hashes. Do not upload raw JSONL, databases, prompts, tool output, absolute paths, or credentials.
- When citing third-party projects, state their licenses, implementation differences, and whether source code was copied. Do not describe independent work as an official collaboration or original work from this repository.

## Related public issues

- [CC Switch #4464: encrypted content cannot be decrypted after unified history migration](https://github.com/farion1231/cc-switch/issues/4464)
- [CC Switch #3866: migration changes JSONL mtime and disrupts resume ordering](https://github.com/farion1231/cc-switch/issues/3866)
- [OpenAI Codex #17541: encrypted content cannot be decrypted after a model/provider change](https://github.com/openai/codex/issues/17541)
- [OpenAI Codex #25290: persisted encrypted reasoning or compaction data prevents replay](https://github.com/openai/codex/issues/25290)
- [OpenAI Codex #25390: severe latency after opening large local tasks on Windows](https://github.com/openai/codex/issues/25390)

Troubleshooting documents must not contain real accounts, task IDs, absolute user paths, credentials, chat transcripts, or generated local scan reports. Historical versions and third-party behavior describe the environment at the time and must be revalidated before use.
