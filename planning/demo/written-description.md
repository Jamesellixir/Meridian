# Submission description - draft, not ready to submit

Status: submission draft, not ready to submit. The merged foundation and manual task slice are documented as verified by the lead in `docs/PHASE-1.md` and `docs/PHASE-2.md`. This workstation has verified the standalone mascot preview only; it has not rerun the Jac foundation or integrated mascot checks. Full agent/calendar/memory/approval behavior remains planned. Update this document against the final working revision before submission.

## Proposed product

Meridian is a personal-agent prototype intended to turn a goal into separately reviewed agenda, preparation-task, and calendar-event writes in its own workspace. Users can also operate the same calendar, tasks, notes, and confirmed-memory tools manually.

## Intended innovation

When a user corrects a confirmed preference, the system should identify work that depended on its earlier version and propose a checked revision. In the meetup demonstration, a morning-only correction changes the affected scheduling proposal while retaining unrelated agenda and preparation tasks. A committed event should require a newly reviewed proposal before it changes. Exact action previews and persisted receipts make outcomes inspectable.

## Jac/Jaseci use - complete after verification

- Frontend: Jac 0.34.24 foundation and persisted manual-task shell exist. Mascot pose animation has a standalone browser-verified preview; Jac compilation and dashboard mounting remain pending on this workstation.
- Agent/model/tool orchestration: owned by workstream 1; describe only actual integrated capabilities and the provider used, without credentials.
- Shared graph/state persistence and workspace services: owned by workstream 3; describe the implemented model and storage after verification.
- Dependency-aware revision and approval: record the actual implemented relationships, revision checks, and receipt behavior.
- Language proportion: not measured. Event minimum is 80% meaningful Jac; team target is above 90% authored application source. Record the organiser-accepted counting method and final result here.
- Jac Hammer hosting: optional and not configured by this setup. Add a working URL only if deployed and tested.

## Evidence to add

- Submitted repository URL: https://github.com/Jamesellixir/Meridian
- Tested merged commit/release: not available.
- Clean-clone startup and exact runtime/dependencies: lead's commands and pinned runtime are in `docs/PHASE-1.md`; not rerun on this workstation, which lacks Docker/WSL.
- Working demo video link: not available.
- Final pitch deck link: not available.
- Available evidence: lead reports manual-task create/list/retry/reload/restart checks in `docs/PHASE-2.md`; local standalone mascot controls and motion checks passed. Full goal-to-output, exact approval/receipt, preference correction/revision, forgotten-memory invalidation, stale/conflict handling, and approved-action duplicate-retry scenarios remain pending.

## Limits and final review

Core scope is internal workspace tools. External calendar/email/OAuth, browser automation, live web research, and a separate multi-agent framework are not core capabilities. Do not claim them or unsupported always-on execution. Clearly label any remaining limitation and remove unimplemented feature claims from the final description.

Complete and submit this description with the repository, working demo video, and pitch deck by 17:30 Sri Lanka time on 17 October 2026, using the organiser-provided submission link. Nothing has been submitted by this setup.
