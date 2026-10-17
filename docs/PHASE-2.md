# Phase 2: first persisted manual task

The completed slice is UI → application facade → workspace service → Jac graph → reload and restart. Application and test source is Jac 0.34.24. Phase 1 is published on `main` through PR #1; phase 2 is prepared on `codex/agent` for review.

## Implemented contract

| Operation | Request | Application response |
|---|---|---|
| `POST /function/create_task` | `workspace_id`, `title`, `request_id` | `{ok, data: {task}, error}` |
| `POST /function/list_tasks` | `workspace_id` | `{ok, data: {tasks}, error}` |

Jac wraps these application responses in its transport envelope under `data.result`. Jac frontend RPC calls unwrap transport automatically. Raw API clients can use the tested `app/transport.jac` adapter.

Task titles are trimmed and limited to 1–200 characters. Workspace/request identifiers follow the shared identifier rules. Records expose stable UUIDs, workspace identity, `todo` status and version 1; optional goal/due fields retain the shared contract defaults. Repeating a request ID with the same normalized title returns the original task. Reusing it with a different title returns `IDEMPOTENCY_CONFLICT`. The key is scoped to its workspace.

`workspace/tasks.jac` owns the persistent `StoredTask` nodes and record projection. `app/api.jac` delegates; the UI does not query or write storage. Keep this node's module/class identity stable when extending storage, or declare an explicit Jac schema alias. The same named runtime volume used in phase 1 holds the graph. Do not delete the volume to refresh source code.

## Interface behavior

The demo workspace provides a labeled task input, keyboard form submission, disabled controls during loading/save, empty/loading messages, validation and recoverable connection errors. A successful save adds the server-returned record immediately and clears the input. An uncertain network retry keeps its request ID while the title is unchanged. A page reload reads tasks again from the server.

Jac 0.34.24 can classify an imported facade writer as a cached reader. Consequently, the UI updates from the confirmed save response instead of immediately rereading the potentially cached list. It replaces any matching stable task ID before inserting, so a retry cannot duplicate a visible row. No runtime patch or browser storage database is used.

## Verification

Tests were written first and failed before the endpoints existed. `docker compose run --rm meridian check main.jac` passes. `docker compose run --rm meridian test -d tests/` passes all **14 tests**, including three new endpoint tests covering create/list, trimming/defaults, workspace filtering, retry identity, changed-content conflict and invalid input without writes. Tests use temporary isolated storage.

The running browser rejected a blank title, created synthetic tasks, showed the confirmed result immediately and retained tasks after reload. A UI-created task also remained after restarting the Docker service; a raw API read confirmed its stable UUID. Existing phase 1 checks and model behavior remain covered. Phase 1's two GitHub CI runs passed before PR #1 was merged.

## Boundaries for the next phase

This is a local, single-user demo bound to `127.0.0.1:8000`. Workspace filtering is organization, not user authorization. Public endpoints share the guest root; do not expose this runtime publicly. Authentication and a hosted deployment need a separate implementation decision. Concurrent exactly-once approval execution is a later workspace transaction requirement; sequential task retries do not establish that stronger guarantee. Coordinator planning, task editing/deletion, notes/calendar/preferences and approval dispatch remain later work.
