# Storage and workspace tools — teammate B

Branch: `codex/workspace`. Own this directory, schema/seed helpers, and meaningful workspace checks. Read [contracts](../../docs/CONTRACTS.md) and [architecture](../../docs/ARCHITECTURE.md). Request shared contract/configuration changes from the lead.

## Build order

1. Agree the shared facade and persistence capability with the lead. Use one Jac graph/state persistence system for records, runs, proposals, and receipts.
2. Implement calendar/task/note CRUD, explicit confirmed preference save/correct/forget, and stable IDs/versions. Return workspace identity on records.
3. Find slots against busy intervals; validate end after start; reject overlaps while allowing adjacent events. Default timezone is Asia/Colombo.
4. Expose run/proposal load/save service calls. Enforce expected revisions and provide atomic approved-action/receipt persistence and idempotent retries.
5. Share validation between explicit manual writes and coordinator-approved dispatch. Do not expose an unrestricted model/browser commit path.
6. Provide a repeatable synthetic demo reset and verify restart persistence, conflict checks, stale updates, and duplicate retries.

Completion: manual and agent operations see the same durable records; duplicate commits produce one event and the original receipt; a clean reset works. Never commit a running database or real credentials. Report any unsupported transaction guarantee to the lead before integration.
