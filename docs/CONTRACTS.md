# Contract v1 — implementation baseline

Shared DTOs and validators live in `system-code/contracts/`. The local lead release implements health, run lifecycle, exact proposal review, workspace snapshots, manual task create/status, manual event create/update, confirmed availability save/correct/forget and targeted event replanning. See [the review guide](LEAD-REVIEW.md). Richer manual note/calendar/task editing is a teammate extension; no unrestricted commit route is exposed.

## Common conventions

Responses: `{ok: true, data: ..., error: null}` or `{ok: false, data: null, error: {code, message, retryable}}`. Use snake_case fields, stable server-generated string IDs, integer versions starting at 1, explicit `null` for absent optional values, and `[]` for empty collections. Timestamps use ISO 8601 with an offset. Duration is in minutes.

Every operation resolves a workspace and validates record membership server-side. This contract does not establish authentication or production multi-user isolation. Record that design before enabling shared remote use.

## UI to application

| Operation | Input | Result data |
|---|---|---|
| `start_goal` | `text, workspace_id, request_id` | `run_id, run` snapshot; repeat request returns existing run |
| `advance_run` | `run_id, expected_version, request_id` | One bounded stage and its checkpoint |
| `get_run` | `run_id` | Run, steps, outputs, proposals, public activity |
| `provide_input` | `run_id, expected_version, text, request_id` | Clarification/revision accepted into the run |
| `cancel_run` | `run_id, expected_version` | Cancellation state; already committed outputs retained |
| `get_workspace` | `workspace_id` | Calendar, tasks, notes, confirmed preferences |
| `review_proposal` | `proposal_id, revision, payload_hash, decision` (`approve` or `reject`) | Proposal status and receipt or null |
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
| Run | `id, workspace_id, goal, status, steps, output_ids, error, version, attempt_id, lease_expires_at` |
| Step | `id, status, depends_on_step_ids, preference_dependencies[{id,version}], output_ids` |
| Preference | `id, workspace_id, key, value, source, confirmed, version` |
| Event | `id, workspace_id, title, start, end, timezone, goal_id, version` |
| Task | `id, workspace_id, title, status, goal_id, due_at, version` |
| Note | `id, workspace_id, title, body, goal_id, version` |
| Proposal | `id, workspace_id, run_id, kind, payload, payload_hash, revision, expected_target_version, preference_dependencies, status` |
| Receipt | `id, workspace_id, proposal_id, record_ids, committed_at, idempotency_key` |

Manual records may have `goal_id: null`; task `due_at` is nullable. Create proposals have `expected_target_version: null`; update payloads include the target ID. MVP proposal kinds: `create_event`, `update_event`, `create_task`, `create_note`. Preference changes are explicit user operations, not automatic model memory writes.

Run statuses: `queued, running, waiting_for_input, waiting_for_approval, completed, failed, cancelled`. Proposal statuses: `pending, rejected, committed, stale`. Step statuses: `queued, running, waiting_for_input, waiting_for_approval, completed, failed, cancelled, stale`. Task statuses: `todo, in_progress, done`. A rejected action is not a successful output; the run waits for a revised plan or explicit cancellation. Mark a run completed only when its required accepted outputs exist and no required proposal is pending. Status transitions are enforced in the later coordinator phase; the current DTOs do not themselves authorize transitions or writes.

## Phase 1 provider compatibility

Jac 0.34.24's native byLLM schema generation raises an AttributeError for this imported GoalSpec metadata on a live provider call. The verified adapter therefore requests text and strictly decodes a JSON object into the shared Jac GoalSpec, rejecting extra fields, incorrect scalar/list types and invalid planning intents. It makes at most two calls, with a 30-second timeout and 1024 output-token limit per call. Provider errors propagate without repair retries. No framework files are patched.

Minimum error codes: `VALIDATION_ERROR`, `NOT_FOUND`, `VERSION_CONFLICT`, `STALE_PROPOSAL`, `CALENDAR_CONFLICT`, `NO_AVAILABLE_SLOT`, `PROVIDER_ERROR`, `TOOL_ERROR`, `CANCELLED`. Preserve the proposal on failed commit; return an actionable error and require new review when its content must change.
# Implemented phase 2 task endpoints

`create_task(workspace_id, title, request_id)` returns `TaskEnvelope`; `list_tasks(workspace_id)` returns `TasksEnvelope`. Details, error rules and verified boundaries are in [phase 2](PHASE-2.md). Other operations below remain planned unless explicitly marked implemented.

## Local release additions

- `review_proposal(proposal_id, revision, payload_hash, decision)` returns `RunEnvelope`, including durable `receipts` and committed output IDs. Payload comes only from authoritative storage.
- `replan_run(run_id, expected_version)` returns fresh pending previews; a committed event becomes an `update_event` with the same target ID and expected version.
- `get_workspace(workspace_id, refresh_id="")` returns `WorkspaceEnvelope`: events, tasks, notes, confirmed preferences and receipts.
- `save_event(workspace_id, title, start, end, request_id, event_id="", expected_version=0)` creates or updates a manual event. Existing target versions are required for updates.
- `update_task_status(workspace_id, task_id, expected_version, status)` enforces the current task version.
- `save_preference(workspace_id, value, request_id)`, `correct_preference(preference_id, expected_version, value)`, and `forget_preference(preference_id, expected_version)` manage explicitly confirmed availability (`morning` or `anytime`), returning `WorkspaceEnvelope`.
- `new_demo_workspace()` returns an isolated synthetic workspace without deleting prior data.

Cancellation retains committed outputs/receipts and stales only unfinished previews. Clarification is limited to pre-proposal planning; after partial execution, use replan or a new goal rather than silently recreating committed notes/tasks. Approval conflicts return application `VERSION_CONFLICT` or runtime HTTP 409; reload/retry the same review packet to recover the original receipt. Multi-action goals may partially commit, as each approved action has its own atomic receipt.
