# Product scope

## Purpose

Meridian turns a user goal into a practical plan using its own calendar, tasks, notes, and confirmed preferences. Those records can also be managed manually in the same interface.

The distinguishing behavior is dependency-aware revision: correcting a confirmed preference identifies affected unfinished proposals and proposes changes while preserving unrelated work. A committed event never moves silently. The user sees a before/after preview and explicitly approves its replacement.

## Core demonstration

1. Enter busy calendar events manually in a fresh demonstration workspace.
2. Ask: “Plan our two-hour AI meetup next week; create an agenda and preparation tasks, and find a free slot.”
3. Produce an agenda, preparation tasks, and a conflict-free event proposal based on supplied information. Preview all proposed writes before committing them.
4. Approve the reviewed proposal. Show receipts, reload, and inspect the persisted records.
5. Correct the confirmed preference to “We can only meet in the morning.” Show which event depends on that preference and preview a replacement. Preserve the agenda and unrelated tasks.
6. Approve the replacement and verify stored state. If no morning slot exists, request a constraint change instead of inventing availability.

## Included

- One coordinator with bounded model/tool execution and visible public activity.
- Internal calendar, task management, agenda notes, and versioned confirmed preferences.
- Exact action previews, rejection, server-side approval checks, and durable receipts.
- Shared persistence for manual edits, agent tools, runs, proposals, and receipts.
- A single dashboard with loading, empty, failure, and stale-review states.

## Outside the core

Google Calendar, email, OAuth, browser automation, external plugins, a separate multi-agent framework, voice, drag-and-drop scheduling, and background monitoring. Live search is optional only after the core works and a real API is available. Without search, label agendas as based on user information. Calendar-file export is optional.

## Delivery order

Shared skeleton and contracts → persisted manual task → complete meetup flow → one availability correction and event revision → failure/retry checks → recording and submission.

If time is short, use one model plan with deterministic validated tools. Implement one availability constraint and its affected event before considering a generic dependency engine. Freeze features by 15:30 Sri Lanka time; reserve the final period for verification and submission.
