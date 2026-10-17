# Acceptance and verification

The local lead release passes its coordinator/approval/replanning checks; see [release review evidence](LEAD-REVIEW.md). Earlier phase-specific evidence remains historical. Final presentation/video and public-hosting readiness are separate team deliverables.

| Check | Expected evidence |
|---|---|
| First slice — passed locally | UI-created task survives reload and server restart; stable UUID confirmed by API |
| Complete goal | Real model input produces agenda/tasks/event proposals; approved records exist in storage |
| Exact approval | Changed payload/revision cannot reuse approval; forged direct commit is rejected |
| Denial | Rejected proposal performs no write |
| Retry | Same approved action committed twice yields one record and original receipt |
| Stale target | Concurrent record edit causes version error and fresh review |
| Calendar conflict | Busy event added after preview blocks conflicting commit |
| Adjacent events | One event may start exactly when another ends |
| No slot | Impossible constraints yield a clear request to change them |
| Memory revision | Morning-only correction invalidates the dependent proposal and proposes updating the same event; unrelated notes/tasks remain |
| Forgotten memory | Pending work cannot use the deleted preference silently |
| Reload/restart | Records, runs, proposals, and receipts remain consistent |
| Failure/cancellation | Provider/tool failure and cancellation are visible; no fabricated success |
| Demo reset | Synthetic baseline can be restored without credentials or personal data |
| Submission readiness | Clean clone runs using documented commands; meaningful Jac proportion and artifact links checked |

Test high-risk storage/approval behavior at the service boundary and the full flow through the UI. Inspect stored records as well as visible success messages. No screenshot or generated report alone proves persistence or idempotency.
