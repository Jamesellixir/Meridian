# Architecture and behavior

These are logical boundaries, not verified Jac import paths or automatic HTTP routes. The lead maps them to the event-supported Jac version.

## Request flow

UI → application facade → coordinator → workspace facade → shared persistence.

Manual edits use explicit application/workspace operations with the same business validation as agent tools. The UI never accesses storage directly. The coordinator never writes the database directly. Only the workspace module owns persistence.

| Module | Responsibility |
|---|---|
| `app/` | Entry point, handler registration, composition, workspace context |
| `contracts/` | Executable schemas and facade definitions agreed by all contributors |
| `agent/` | Model connection, bounded run lifecycle, proposals, approval dispatch, dependency tracking |
| `ui/` | Dashboard, manual tools, public activity, action previews, receipts |
| `workspace/` | Jac graph/state persistence, records, validation, conflict detection, atomic revisions and retries |
| `tests/` | Checks grouped by owner and integrated demo checks |

## Approval and persistence

An agent proposal holds the exact intended payload and revision. Approval binds to that content, revision, workspace, and expected target version. Recheck status, payload, record versions, and calendar availability on the server immediately before committing. Changed content requires fresh review. A rejected or stale proposal cannot execute.

For the MVP, each proposal describes one write. A goal can have several proposals; show each status and receipt. Do not imply a whole goal committed atomically if only some actions succeeded. The lead must document any later batch semantics before implementation.

The workspace service commits an approved action and its receipt together where supported. It owns the atomic revision/idempotency check: retrying the same approved action returns the original receipt, while reuse of a key for different content is rejected. If the chosen persistence cannot guarantee this, report the limitation and resolve it before claiming the acceptance check passes.

## Memory and replanning

Store only explicitly confirmed preferences as authoritative memory. Track preference ID/version on each dependent step, including the original availability constraint in the demo. Correcting a preference increments its version, marks dependent unfinished proposals stale, and requests a revised proposal. For a committed event, propose an update against its existing ID/version; do not create a duplicate or change it before approval. Forgetting a preference also invalidates dependent pending work; do not continue relying on its old value.

## Calendar and run rules

Use timezone-aware timestamps; default to `Asia/Colombo`. Resolve “next week” relative to the run's current date and show exact dates. The team must agree the demo's week boundary and meaning of “morning” and show those constraints in the preview. Use intervals `[start,end)`: end must exceed start, overlap is rejected, and adjacent events are allowed.

Bound tool iterations and execution time; expose cancellation and provider/tool errors. Public activity shows tool names, outcomes, and receipts, not private model reasoning. Keep credentials server-side; never include them in source, browser bundles, logs, or recordings. Use synthetic demo data. Deployment and external account integrations are separate decisions.
