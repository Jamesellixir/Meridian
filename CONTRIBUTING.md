# Team workflow

Read the root README, shared specifications in `docs/`, and your workstream README before changing code. Share those files with any development environment used to implement the work. No project-specific agent prompt is required.

## Branches and ownership

- Lead: `codex/agent`; owns shared contracts, entry point, root manifests/configuration, coordinator, and integration.
- Teammate A: `codex/ui`; owns UI and presentation assets.
- Teammate B: `codex/workspace`; owns shared storage, workspace tools, schema/seed helpers, and module checks.

Only the lead edits shared contracts/configuration. Request a shared change from its owner, then update affected callers together. Preserve teammates' work; never discard changes to resolve a conflict. Do not force push. Branch names differ from the draft plan's `feat/*` names but retain its three ownership boundaries.

## Working loop

Clone the repository, switch to your assigned branch, and read the docs. Start implementation only after the shared runnable skeleton and executable contract v1 have merged. Pull your branch before work and bring current `main` into it before integration. Commit small working increments, push your branch, and open a PR targeting `main`.

Describe behavior, changed interfaces, checks actually run, and known gaps. The lead reviews and merges one PR at a time. Refresh each workstream from `main` after integration. Aim to integrate a small complete slice every 30–45 minutes.

The initial documentation baseline is bootstrapped directly on empty `main`; subsequent work follows PR review. Branch protection has not been configured, so this workflow is a team agreement rather than an enforced repository setting.

## Completion evidence

Check the changed module and inspect the diff. Cross-module changes also require the complete demonstration flow. Mark checks as passed, failed, or not run; a plan or development report is not execution evidence. Maintain the status in README/setup as implementation progresses.

Never commit credentials, local databases, real personal data, generated dependencies, or recordings containing secrets. Explain AI assistance as required by the competition; do not claim generated work was written manually or treat generation as verification.
