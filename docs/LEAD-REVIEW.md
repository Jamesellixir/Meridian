# Rivith's release review

This local revision completes the coordinator, contracts, exact approvals, integration and verification work. It is **not pushed**. The existing branch is `codex/agent`; the remote still contains the earlier phase 3 revision. Review the local working-tree changes and running application before approving publication.

The earlier repository numbered phases 1–3 only. The following eight delivery gates reconcile the remaining agreed responsibilities without expanding the product scope.

| Phase | Deliverable | Review evidence |
|---|---|---|
| 1 | Pinned Jac foundation and shared contracts | Existing foundation/model checks |
| 2 | Persisted manual task | Create/list and restart checks |
| 3 | Bounded coordinator and durable previews | Real model, typed decoding, checkpoints and cancellation |
| 4 | Exact approval and atomic receipts | Hash/revision checks, rejection, retries, calendar revalidation |
| 5 | Preference-aware replanning | Same-event revision, fresh approval, unrelated outputs preserved |
| 6 | Application/workspace integration | Real calendar, tasks, notes, preferences, receipts and review controls |
| 7 | Failure, conflict and restart verification | Automated tests plus opt-in live concurrency/restart evidence |
| 8 | Review and teammate handoff | This guide, executable contracts, local diff and running preview |

## Review in the app

Open `http://localhost:8000/`. Everything runs locally; GitHub does not host this Jac server.

1. Click **New review workspace**. This creates isolated synthetic data with a busy Monday morning and an explicitly confirmed anytime preference. Existing workspaces are retained.
2. Use the supplied two-hour meetup goal. Click **Start plan**, then **Continue plan** for each of the two bounded stages. Inspect the agenda, preparation tasks and available event preview.
3. Reject one action to confirm no record/receipt appears. **Replan pending actions** produces fresh reviewable previews while preserving anything already committed.
4. Approve the pending actions individually. Receipts appear only for committed records. A run completes only when its required actions are committed and availability does not need replanning.
5. Click **Confirm morning only**. The event must not move silently. Click **Replan pending actions**, inspect the before/after event preview, then approve **update_event**. The same event ID advances to its next version; notes/tasks stay unchanged.
6. Reload the page. Confirm records and receipts remain. **Forget availability** removes the authoritative preference and invalidates dependent unfinished planning.

The manual task and busy-event forms use the same workspace as the coordinator. Event timestamps require explicit ISO offsets, for example `2026-10-19T09:00:00+05:30`. Conflict checks use half-open intervals; adjacent events are allowed.

## Architecture and teammate boundary

The UI calls `app/api.jac`. Coordinator review validates the packet, then the workspace service rechecks authoritative content, versions, preference dependencies and calendar availability. The workspace commits the action, its receipt and proposal/run status together. Private underscore-prefixed dispatchers are not public API routes.

Keep existing graph type identities stable. Teammates should extend the shared `StoredTask`, `StoredCalendarEvent`, `StoredNote`, `StoredConfirmedPreference`, `StoredRun` and `StoredReceipt` types rather than creating another database or parallel record set. The lead's integration UI is intentionally simple; presentation styling, the pitch/video, and richer manual editing remain teammate work.

The supported availability rules are `anytime` and `morning`, with the documented Asia/Colombo week/time policy. Unsupported constraints stop planning. Replanning is deterministic against current storage; it does not spend another model call. This is a single-user local demo, not an authenticated public service.

## Verification commands

From the repository root:

```sh
docker compose up -d
docker compose run --rm --no-deps meridian test -d tests/
docker compose run --rm --no-deps meridian check main.jac app/api.jac agent/coordinator.jac agent/review.jac workspace/actions.jac workspace/reviews.jac workspace/records.jac workspace/preferences.jac workspace/replan.jac workspace/runs.jac workspace/planning.jac ui/planner.jac ui/shell.jac
```

The optional `checks/release_live.jac` check requires `MERIDIAN_REVIEW_RUN` naming a synthetic `review-*` workspace run with a pending task. It sends concurrent identical approvals and verifies one task, one receipt, stable replay and an inaccessible private dispatcher. It does not call the model. The local run passed. Jac 0.34.24 can wrap write conflicts before its HTTP mapper; the approval service explicitly aborts that losing unit of work and returns `VERSION_CONFLICT`, then an exact retry recovers the winner's receipt. No framework files were patched.

Code changes need `docker compose restart meridian`. Keep both named volumes; deleting them removes graph data or installed packages. The reviewed foundation's runtime setup and provider bounds still apply. Never put API keys in the browser or repository.

## Publication boundary

No new commit, push, merge, PR update or public deployment is authorized until Rivith approves this local revision. After approval, commit the reviewed changes and push `codex/agent`; integrate with `main` only when requested. CI cannot validate unpushed changes, so report local checks separately from the older remote runs.

## Verified local outcome

- **29 automated tests passed**, plus the opt-in live concurrency test.
- All 14 application modules covered by the CI check command passed local checks; the final UI also passed after its review-state adjustment.
- A real model generated a note, four preparation tasks and an event in an isolated synthetic review workspace. Concurrent identical approvals created one task/receipt per proposal.
- The browser approved the agenda and event, confirmed morning-only availability, displayed the old/new event times, and approved the revision.
- Raw API checks confirmed the event retained its ID and advanced from version 1 to 2, four task IDs and one note ID stayed unchanged, seven receipts existed, and the run was completed.
- A subsequent Docker restart preserved the completed run version, the revised event ID/version, all four task IDs, the note ID and all seven receipt IDs.
- New review workspaces preserve previous data. Rejection, forgotten preferences, stale target versions, no morning slot, interrupted runs and retained committed outputs are covered by tests.

The compatibility fix for write conflicts is limited to the pinned runtime's approval transaction. No provider retries or model calls occur while committing reviewed actions. The runtime remains local and single-user; public authentication/hosting and the team's final pitch/video are outside this lead release.
