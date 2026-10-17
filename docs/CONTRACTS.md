# Contract v1 — implementation baseline

Logical names below are not established routes or Jac syntax. The lead translates them into executable definitions in `system-code/contracts/`; both teammates agree those definitions before parallel implementation. Changes require coordinated updates to definitions, callers, and this document.

## Common conventions

Responses: `{ok: true, data: ..., error: null}` or `{ok: false, data: null, error: {code, message, retryable}}`. Use snake_case fields, stable server-generated string IDs, integer versions starting at 1, explicit `null` for absent optional values, and `[]` for empty collections. Timestamps use ISO 8601 with an offset. Duration is in minutes.

Every operation resolves a workspace and validates record membership server-side. This contract does not establish authentication or production multi-user isolation. Record that design before enabling shared remote use.

## UI to application

| Operation | Input | Result data |
|---|---|---|
| `start_goal` | `text, workspace_id` | `run_id, run` snapshot |
| `get_run` | `run_id` | Run, steps, outputs, proposals, public activity |
| `get_workspace` | `workspace_id` | Calendar, tasks, notes, confirmed preferences |
| `review_proposal` | `proposal_id, revision, decision` (`approve` or `reject`) | Proposal status and receipt or null |
| `correct_preference` | `preference_id, expected_version, value` | Updated preference, affected run IDs |
| Manual record operations | Workspace, explicit payload/ID, expected version for updates | Validated record or error |

Manual calendar/task/note/preference operation names and supported fields must be frozen by the lead with the workspace owner in executable contract v1 before the UI integrates. They use the same validation as agent writes. The UI does not infer routes from these logical names.

## Coordinator to workspace

- `read_workspace`, `read_preferences`: current authoritative records.
- `find_free_slots(start, end, duration_minutes, timezone, constraints)`: conflict-free candidate intervals, or an empty result with an explanation.
- `validate_action(kind, payload, expected_record_version)`: validation result, without mutation.
- `commit_action(approved_action, idempotency_key)`: persisted receipt; accepts only a server-validated approval through the coordinator dispatcher.
- `save_run/load_run`, `save_proposal/load_proposal`: shared storage; updates enforce expected versions/revisions.
- `save_preference/correct_preference/forget_preference`: explicit confirmation, versioning, and dependency invalidation.

Workspace identity is explicit or supplied by a validated server context on every service call. Browser requests cannot manufacture `approved_action` or call an unrestricted commit endpoint.

## Records

| Record | Minimum fields |
|---|---|
| Run | `id, workspace_id, goal, status, steps, output_ids, error, version` |
| Step | `id, status, depends_on_step_ids, preference_dependencies[{id,version}], output_ids` |
| Preference | `id, workspace_id, key, value, source, confirmed, version` |
| Event | `id, workspace_id, title, start, end, timezone, goal_id, version` |
| Task | `id, workspace_id, title, status, goal_id, due_at, version` |
| Note | `id, workspace_id, title, body, goal_id, version` |
| Proposal | `id, workspace_id, run_id, kind, payload, revision, expected_target_version, status` |
| Receipt | `id, workspace_id, proposal_id, record_ids, committed_at, idempotency_key` |

Manual records may have `goal_id: null`; task `due_at` is nullable. Create proposals have `expected_target_version: null`; update payloads include the target ID. MVP proposal kinds: `create_event`, `update_event`, `create_task`, `create_note`. Preference changes are explicit user operations, not automatic model memory writes.

Run statuses: `queued, running, waiting_for_approval, completed, failed, cancelled`. Proposal statuses: `pending, rejected, committed, stale`. Step statuses: `queued, running, waiting_for_approval, completed, failed, cancelled, stale`. Task statuses: `todo, in_progress, done`. A rejected action is not a successful output; the run waits for a revised plan or explicit cancellation. Mark a run completed only when its required accepted outputs exist and no required proposal is pending.

Minimum error codes: `VALIDATION_ERROR`, `NOT_FOUND`, `VERSION_CONFLICT`, `STALE_PROPOSAL`, `CALENDAR_CONFLICT`, `NO_AVAILABLE_SLOT`, `PROVIDER_ERROR`, `TOOL_ERROR`, `CANCELLED`. Preserve the proposal on failed commit; return an actionable error and require new review when its content must change.
