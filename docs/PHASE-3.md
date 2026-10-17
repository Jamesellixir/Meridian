# Phase 3: durable coordinator and planning previews

Phase 2 is merged into `main` through PR #2 at `c88914d`; both GitHub checks passed before merge. Phase 3 is built on `codex/agent` for review. All new application and test source is Jac 0.34.24.

## Implemented flow

`start_goal → advance_run (interpret) → advance_run (read workspace and draft) → waiting_for_approval`.

The first advance interprets a session goal with the real server-side model adapter. The second reads authoritative workspace tasks, calendar entries and confirmed preferences through the workspace facade, computes candidate slots deterministically, and requests a typed agenda/task draft. It persists pending note/task/event proposals and their hashes. No calendar/task/note action executes in this phase, and a run with pending proposals is never labeled completed.

| Endpoint | Input | Behavior |
|---|---|---|
| `start_goal` | text, workspace_id, request_id | Creates or recovers the same durable run; different text with an existing key conflicts |
| `advance_run` | run_id, expected_version, request_id | Claims and runs one bounded stage; duplicate stage requests do not call the model again |
| `get_run` | run_id, optional refresh_id | Returns run, steps, questions, proposals, explanation and public activity |
| `provide_input` | run_id, expected_version, text, request_id | Adds clarification and queues interpretation again |
| `cancel_run` | run_id, expected_version | Cancels the run and retains pending proposals as stale |

These routes return `RunEnvelope` with `RunData`. The Jac transport wraps raw HTTP results under `data.result`. The browser's optional refresh token avoids the pinned runtime's 60-second reader cache; it does not change stored data. Browser storage contains only the last run ID; graph state remains authoritative.

## Persistence and execution boundaries

`workspace/runs.jac` owns run storage, stage claims, versions, request identities and durable JSON checkpoints. A claim commits before a model call, with a unique attempt ID and 120-second lease. Invalid/stale versions fail. An expired interrupted attempt becomes failed on a fresh advance request, rather than repeating paid work automatically. A cancelled attempt cannot publish its result. Jac's configured `on_conflict = "fail"` prevents automatic replay of paid calls on write conflicts.

There are at most two provider calls per stage, each limited to 30 seconds, with 1024 interpretation or 2048 drafting output tokens. Provider failures do not trigger output-repair retries. At most three clarification rounds and 30 stored runs per local root limit demo usage. The cap is persistent; do not delete real data to bypass it. These application bounds do not replace provider account spending limits.

Model output is untrusted JSON: exact field allowlists, string/list/scalar limits, task counts, duplicate task detection and valid supplied slot indices are enforced. The model has no arbitrary tool execution, storage access or approval path. Public activity reports operations and outcomes, not private model reasoning or raw provider errors.

## Scheduling and teammate integration

The supported demo policy is explicit: Asia/Colombo; “next week” means the following Monday–Friday, 09:00–17:00. “Morning” limits the window to 09:00–12:00. One explicit future ISO date within 60 days is also supported. Candidates start on half-hour boundaries, exclude elapsed time and overlapping busy events, and allow adjacent intervals. At most eight candidates reach the model. Unrecognized extracted constraints and unsupported confirmed preferences block planning; absent availability requests clarification.

`workspace/planning.jac` defines stable `StoredCalendarEvent(record: EventRecord)` and `StoredConfirmedPreference` nodes. Subsequent manual calendar/preference tools must reuse these types or provide an explicit migration. Reads filter workspace membership and use only confirmed preferences; relevant versions appear on scheduling/draft steps and event proposals. The manual task facade remains unchanged. Calendar editing UI, approval commits/receipts and preference correction/replanning are later phases.

## Runtime and verification

Run `docker compose up -d` from the repository root. The dependency service installs Jac's declared capabilities before the app starts. Both services share the persistent package cache as well as graph volume: the standalone Jac executable otherwise installs dependencies into an ephemeral container cache. The first setup may take several minutes. After source changes use `docker compose restart meridian`. Never remove volumes to refresh code.

The automated suite passes **23 tests**. Eight changed server/client modules also pass explicit `jac check`. Coverage includes the real endpoint flow with a mocked provider, restoration through a fresh server context, retries, clarification, stale versions, cancellation, sanitized failures, expired attempts, malformed drafts, busy/adjacent slots, elapsed time and scoped confirmed preferences. The test-only storage fixture lives under `checks/` and is not registered in the application. CI checks the changed modules explicitly as well as running the full suite.

Real browser verification called the configured provider, submitted clarification, and produced six pending proposals: an agenda note, four preparation tasks and an event for 19 October 2026, 09:00–11:00 Asia/Colombo. A raw API read confirmed that state and the unchanged four manual tasks. The initial tests were written before the coordinator routes and failed before implementation. Live testing additionally caught and repaired package-cache isolation, unnecessary clarification questions and checkpoint persistence after a stage claim. `pip check` reports no broken requirements.

After a Docker server restart, a fresh raw API read returned the same run version, all six proposal IDs and payload hashes, and all four original manual task IDs. No proposed action was executed. The browser also restores the last run from its stored ID.

This remains a loopback-only single-user deployment at `http://localhost:8000/`. GitHub hosts the source, not this Jac server. Authentication, public hosting and multi-user authorization require a separate deployment design.
