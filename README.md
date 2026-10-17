# Meridian

A personal planning agent built for the Jac hackathon: calendar, tasks, notes, confirmed preferences, and reviewed actions in one workspace.

**Status:** Rivith's coordinator/integration release is implemented locally on `codex/agent`, awaiting review and permission to push. It includes durable planning, exact approvals, receipts and preference-aware event revisions. Start with [the release review guide](docs/LEAD-REVIEW.md). The remote branch still contains the earlier phase 3 revision; `main` contains phase 2.

## Start here

Read [phase 1 setup](docs/PHASE-1.md) and [verification evidence](docs/VERIFICATION.md), followed by [the product scope](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), and [contract v1](docs/CONTRACTS.md). Then read your workstream README.

| Workstream | Branch | Owned application paths | Start here |
|---|---|---|---|
| Lead: coordinator and integration | `codex/agent` | `system-code/agent/`, `system-code/contracts/`, `system-code/app/`, root runtime configuration | [Agent](system-code/agent/README.md) |
| Teammate A: interface and presentation | `codex/ui` | `system-code/ui/`, `planning/demo/` | [UI](system-code/ui/README.md) |
| Teammate B: storage and workspace tools | `codex/workspace` | `system-code/workspace/` | [Workspace](system-code/workspace/README.md) |

Each contributor and their development environment uses these same project specifications. They are engineering documentation, not model prompts. Teammate names are pending; the lead owns integration and assigns the two remaining workstreams.

## First working milestone

The foundation pins Jac 0.34.24. The first persisted task flow is now implemented and verified locally, including reload and server restart. Both teammates should update from `main` and coordinate the phase 2 interface/storage changes before integrating their work.

See [setup](docs/SETUP.md) for runtime commands and the distinction between verified native Linux checks and container checks.

## Collaboration

`main` is the integration baseline; once the skeleton exists, keep it runnable. Contributors work on their assigned branch and open pull requests. The lead integrates one PR at a time. See [contributing](CONTRIBUTING.md). Every branch begins with the same documentation; a branch name identifies ownership, not a separate application.

## Demonstration and review

The intended demonstration plans a two-hour meetup, previews actions, approves and persists them, then revises the event after a confirmed morning-only preference. See [acceptance checks](docs/ACCEPTANCE.md) and [submission checklist](planning/demo/README.md). Planned behavior is not a claim of implemented functionality.

The supplied event brief requires at least 80% meaningful Jac code. Target above 90% authored application source, confirm the organisers' counting method, and do not use padding. AI-assisted development must follow event rules and any required disclosure; team members remain responsible for understanding and verifying their work.
