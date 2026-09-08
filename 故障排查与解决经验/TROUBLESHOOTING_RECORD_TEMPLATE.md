# Troubleshooting record template

Copy this file when opening a new record. Keep evidence-free reports as local drafts. Do not present an inference as a verified fix.

| Field | Record |
| --- | --- |
| Case ID | `TRB-<three digits>` |
| Resolution | **Resolved / Partially resolved / Unresolved / Retired** |
| Tool status | No tool / Read-only diagnostic / Available / Suspended / Retired |
| Last verified | `YYYY-MM-DD` |
| Evidence boundary | State the samples, platforms, versions, and limits of the conclusion |

> Safe first action: state what the reader should do first and which actions must stop.

## Symptom in one sentence

Include the error signature, visible behavior, and failure stage.

## Current resolution status

For unresolved cases, say explicitly that no verified solution is currently available. For partial or resolved cases, state the verified scope and remaining limitations.

## Environment and error signature

- Operating system:
- Product and version:
- Authentication, network, or deployment mode:
- Searchable error code or exact short phrase:
- First recorded / last reproduced:

## Confirmed facts, inference, and open questions

Separate facts supported by logs, code, tests, official documentation, or stable reproduction from reasonable inferences and unresolved questions.

## Investigation

Record each action, its purpose, expected result, and observed result. Preserve failed approaches and explain why they are no longer recommended.

## Fix or workaround

Give the shortest safe path. For file, database, remote, cost-bearing, or irreversible changes, include prerequisites, backup, stop conditions, and rollback.

## Validation and rollback

- Validation command or action:
- Pass criteria:
- Items not validated:
- Rollback entry and conditions:

## Evidence register

| ID | Source type | Date | Claim supported | Visibility | Pointer or sanitized hash |
| --- | --- | --- | --- | --- | --- |
| `E01` | Log / code / test / official source / observation |  |  | Public / local private |  |

Raw conversations, databases, credentials, full logs, real task IDs, and absolute paths stay in the local private evidence area. Public notes use placeholders and minimal sanitized excerpts.

## Companion tool

Keep source, tests, build instructions, and executables with this case. Record the tool state, platforms, dependencies, entry point, build provenance or hash, and known limitations. Update both the case and root index whenever the tool state changes.

## Revalidation conditions

List product, data-format, configuration, environment, or evidence changes that invalidate the conclusion.

## Revision history

| Date | Change | Basis |
| --- | --- | --- |
|  | Initial record |  |
