# Coordinator and integration — lead

Branch: `codex/agent`. Own this directory, `../contracts/`, `../app/`, root runtime/dependency files, and final integration. Read [shared contracts](../../docs/CONTRACTS.md) and [architecture](../../docs/ARCHITECTURE.md).

## Build order

1. Establish the runnable Jac skeleton with teammates. Pin runtime and freeze executable contract v1. Own all shared-file edits.
2. Verify one real server-side model call; bound time/tool iterations and expose failure/cancellation.
3. Read workspace records through its facade and generate typed action proposals. Never write storage directly.
4. Enforce exact content/revision approval server-side and dispatch validated actions with idempotency keys.
5. Persist runs/proposals through the workspace service. Track preference versions per step; invalidate affected proposals and propose revisions to committed events.
6. Integrate UI and workspace modules frequently; run the complete meetup flow before release.

Completion: a fresh goal uses a real model and tools, approved records survive reload, receipts are visible, failures are honest, and correcting availability revises only affected work. Share the exact same runnable skeleton with both teammates before they implement against it.
