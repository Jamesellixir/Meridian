# Working demo storyboard - draft

Status: proposed demonstration, not a record of implemented behavior. Every step below is unverified until exercised against the integrated application. Record the final video only with live services and actual persisted outputs; do not present development mocks as working execution.

Product and repository name: Meridian. MKH Muse is the historical working name.

| Sequence | Show | Evidence required before recording |
| --- | --- | --- |
| 1. Establish the workspace | A resettable demo workspace with manually entered busy events and a visible Asia/Colombo timezone. | Reset and saved busy events work; use test data without credentials or private information. |
| 2. Enter the goal | "Plan our two-hour AI meetup next week; create an agenda and preparation tasks, and find a free slot." Supply missing facts when requested. | A real server-side model call and bounded coordinator flow, not a prerecorded result. |
| 3. Inspect progress and outputs | Actual tool activity, individual agenda-note, task, and event proposals, with saved outputs shown only after their approvals. | Activity reflects real outcomes; records have stable server IDs. No claim of web research. |
| 4. Review and approve | Review each proposed note, task, and event write separately. Show the event title, date/time, and timezone; approve each displayed revision. | Server checks each reviewed revision and current constraints, returning an individual committed result and receipt. Show partial outcomes honestly. |
| 5. Reload | Show the saved event, note, and tasks after reload. | Reads return persisted records from the shared workspace; rehearse server-restart persistence too. |
| 6. Correct memory | Confirm/correct availability to "We can only meet in the morning." Show affected scheduling work. | Updated confirmed preference/version identifies affected work; unrelated agenda/tasks are retained. |
| 7. Review a revision | Show old versus proposed event time. The saved event stays unchanged while review is pending. Approve the replacement and inspect its receipt. | New revision is checked and committed; no silent movement of an approved event. |
| 8. Close with evidence | Show final saved records and briefly state the Jac implementation and verified limitations. | Only measured/tested claims; reference the submitted repository and final artifacts. |

## Alternate results

If no morning slot is available, show the real no-slot result and request a constraint change; do not fabricate a successful schedule. Rehearse rejection, stale approval, conflict, retry, and provider/tool failure. Use a brief verified example if it fits the video, and retain evidence for judging questions.

## Recording readiness

- Complete the sequence against the integrated application with mocks disabled.
- Confirm the demo reset, provider availability, receipt visibility, and reload behavior.
- Set explicit demo dates from the run date; avoid stale prerecorded "next week" values.
- Hide credentials and private data. Keep the actual outcome visible rather than replacing failures with success claims.
- Confirm organiser video/upload requirements when supplied; this draft assumes no unannounced duration limit.
- Submit the working video by 17:30 Sri Lanka time on 17 October 2026; target readiness by 17:00.

Verification record: not run; no video recorded or submitted during workspace setup.
