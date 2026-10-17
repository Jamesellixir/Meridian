# Workstream 2: next implementation slices

Baseline reviewed: `main` at `c88914d`, incorporating agent commits `3d11d98` and `d94301a`. `codex/workspace` still points to the original documentation baseline in this fetch. Branches can change; fetch again before the next work session.

## Ready now

- Shared Jac runtime: 0.34.24. Root composition, contracts, and configuration exist; use the lead's commands in `docs/PHASE-1.md`.
- `ui/shell.jac` is mounted by `main.jac`. It calls real `get_health`, `create_task(workspace_id, title, request_id)` and `list_tasks(workspace_id)` RPC functions.
- The manual-task flow uses confirmed write responses, preserves the request ID on uncertain retries, and avoids duplicate visible rows. Retain this behavior when redesigning the UI.
- The mascot preview has thinking, seated computer work, approval nodding, jumping success and error head shaking. Its Jac component is not yet mounted or compiled in the pinned runtime.

## Your next work, in order

1. On this workstation, establish the documented Docker/WSL Linux runtime or use an already configured team machine. Neither Docker nor an installed WSL runtime was available during this review. Run the documented foundation check and tests without invoking the paid live-model check. Never delete a teammate's runtime volume.
2. Compile and mount the mascot in the Jac UI, confirming the supported static-asset URL. Test its own module as well as `main.jac`; current CI does not import it. Keep the manual animation controls in the standalone preview only. Bind dashboard motion to actual loading/save/error outcomes, and later real run states.
3. Extend the mounted task page into one Jac dashboard. Start with the real task list/form and health/error/empty/loading states. Preserve IDs, idempotent request IDs and reload behavior. Show unavailable panels honestly; do not fabricate records or execution.
4. Once the lead publishes executable endpoints, add goal submission, public activity and clarification/cancellation controls; then calendar, notes, and confirmed-memory panels. The new planned run status `waiting_for_input` needs a distinct helpful message, not a success animation.
5. Add exact per-write proposal previews tied to revision and `payload_hash`, approve/reject, before/after event changes, individual receipts, and stale/conflict feedback. Waiting for approval must not play the approved nod. Show partial outcomes honestly.
6. Wire preference correction/forgetting to actual affected-work results. Verify that an approved event stays unchanged until its revision is approved and unrelated tasks/notes remain.
7. Complete the real demo recording, slides and written description only after integrated acceptance checks pass. The current files are drafts.

## Teammate dependencies

Only health and task create/list are implemented application endpoints in this snapshot. `start_goal`, `advance_run`, `get_run`, `provide_input`, `cancel_run`, `get_workspace`, proposal review, calendar/notes/memory operations remain planned. Request executable bindings from the lead; do not derive routes from logical contract names. Shared storage, transaction/receipt behavior and preference invalidation remain workspace/lead responsibilities.

## Current verification boundary

The lead documents 14 passing foundation/task tests and browser/restart persistence checks. They have not been rerun locally. The standalone mascot browser checks pass locally; its Jac integration and the full meetup flow are not verified. Keep these evidence sources separate in the pitch and PR.
