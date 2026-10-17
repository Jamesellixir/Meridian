# Meridian

A personal planning agent built for the Jac hackathon: calendar, tasks, notes, confirmed preferences, and reviewed actions in one workspace.

**Status:** documentation baseline only. Application implementation, runtime installation, model calls, persistence, and deployment have not been verified. The earlier working name was MKH Muse; this repository uses Meridian.

## Start here

Read [the product scope](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), and [contract v1](docs/CONTRACTS.md) before implementing a module. Then read your workstream README.

| Workstream | Branch | Owned application paths | Start here |
|---|---|---|---|
| Lead: coordinator and integration | `codex/agent` | `system-code/agent/`, `system-code/contracts/`, `system-code/app/`, root runtime configuration | [Agent](system-code/agent/README.md) |
| Teammate A: interface and presentation | `codex/ui` | `system-code/ui/`, `planning/demo/` | [UI](system-code/ui/README.md) |
| Teammate B: storage and workspace tools | `codex/workspace` | `system-code/workspace/` | [Workspace](system-code/workspace/README.md) |

Each contributor and their development environment uses these same project specifications. They are engineering documentation, not model prompts. Teammate names are pending; the lead owns integration and assigns the two remaining workstreams.

## First working milestone

Together, pin the event-supported Jac runtime, agree executable contract definitions, and establish a runnable skeleton. Verify one real server-side model call and one stored record. Then merge a complete flow: create a task in the UI, reload, and see the same task. Parallel implementation starts from that shared skeleton.

No installation or run commands are published yet: the lead must verify them with the selected runtime and record exact commands in [setup](docs/SETUP.md).

## Collaboration

`main` is the integration baseline; once the skeleton exists, keep it runnable. Contributors work on their assigned branch and open pull requests. The lead integrates one PR at a time. See [contributing](CONTRIBUTING.md). Every branch begins with the same documentation; a branch name identifies ownership, not a separate application.

## Demonstration and review

The intended demonstration plans a two-hour meetup, previews actions, approves and persists them, then revises the event after a confirmed morning-only preference. See [acceptance checks](docs/ACCEPTANCE.md) and [submission checklist](planning/demo/README.md). Planned behavior is not a claim of implemented functionality.

The supplied event brief requires at least 80% meaningful Jac code. Target above 90% authored application source, confirm the organisers' counting method, and do not use padding. AI-assisted development must follow event rules and any required disclosure; team members remain responsible for understanding and verifying their work.
