## Current experience update (17 October 2026)

The current local changes add a light conversational layout, prominent animated mascot, month calendar with persisted event colors/editing, task completion, and an editable personal-memory panel labelled soul.md. Personal memory is stored in the shared workspace, not a separate file. Availability retains its existing scheduling contract.

Chat now uses the server model with bounded durable conversation context and confirmed personal preferences. Session planning still requires exact per-write approval and real receipts. Live browser checks verified calendar/task/memory persistence and contextual chat. A live model-backed plan, approvals, morning-only replan and idempotent approval replay also passed. These changes are local and uncommitted. Background reminder notifications and full Google Calendar parity are not implemented.

Use `JAC_TEST_JOBS=0` for serial Jac regression checks on constrained hosts. Older verification/quick-help descriptions below are historical and superseded by this update.

# Interface and presentation — teammate A

Branch: `codex/ui`. Own this directory and `planning/demo/`. Read [product scope](../../docs/PRODUCT.md), [contracts](../../docs/CONTRACTS.md), and [architecture](../../docs/ARCHITECTURE.md). Request shared contract/configuration changes from the lead.

## Build order

1. After the shared skeleton exists, build one dashboard using supported Jac frontend facilities.
2. Provide goal input, conversation, public run timeline, calendar agenda, tasks, notes, and confirmed-memory inspect/edit/forget controls.
3. Show exact action payloads and before/after event changes, approve/reject controls, receipts, stale-review messages, loading/empty states, and errors.
4. Route manual edits and agent requests through the application facade. Keep business validation and prompts on the server.
5. Temporary mocks must match the shared contracts, be visibly labelled, and use one switch. Disable them for integration and the final recording.
6. Prepare demo storyboard, pitch content, and written description while final reliability work proceeds.

Completion: users can enter the meetup goal, review each proposed write, deny or approve it, reload actual records, and correct a preference. The interface must distinguish real persisted success from pending/mock activity. A time-ordered agenda is sufficient; no drag-and-drop calendar is required.

## Current interface

The application remains authored in Jac, with `shell.jac` mounting `PlannerPanel`. `dashboard.css` supplies the selected warm palette and Apple-inspired typography/surfaces; `chat.css` supplies the routed chat layout. Shared contracts, runtime configuration and persistence implementation are unchanged.

Routes: `#home`, `#tasks`, `#calendar`, `#notes`, `#memory`, `#activity`, `#history`. Only the selected page renders. Browser Back and direct page refresh work. Home contains the animated mascot, planning conversation and composer; action previews and receipts live on Activity & reviews.

Sending a goal creates its server run and advances the supported two bounded coordinator stages automatically, stopping at clarification, approval, failure or completion. No proposed write is approved automatically. Clarifications use `provide_input`; new messages start separate plans. Interrupted requests preserve their idempotency key; server revisions and receipt checks remain authoritative.

Provider failures stay in the server-backed conversation and reappear after reload. Missing provider configuration is explained separately from validation errors; generic provider errors are described as possibly involving credentials, quota, provider availability or connectivity. The running environment was verified to lack OPENAI_API_KEY. The UI cannot supply or repair server credentials.

History retains only server run IDs in browser localStorage (`meridian-run-index`, alongside the existing selected-run ID). It retrieves goals, public activity, questions, explanations and errors with `get_run`. It is a navigation index for this browser, not another message database or an account-wide history endpoint. Multiple entries survive reload; existing older runs require their IDs to be known. Cross-device/server-wide enumeration requires a shared facade extension from its owner.

Verified in pinned Jac 0.34.24: shell/planner compilation (2 passed with warnings), desktop/mobile layouts, route isolation, browser Back, direct refresh, real missing-provider feedback and persistence, multiple live history entries/reopening, task validation, and no browser errors. A clearly isolated test-only transport fixture verifies exactly two advances followed by a stop for approval; it does not establish live model/approval success. Earlier live task/calendar/preference checks are recorded in local continuation notes. Complete live model-backed approval/replanning remains pending server credential configuration.

The [mascot](mascot/README.md) remains driven by actual requests, server run states and committed receipts. Local test scripts/screenshots and downloaded design references stay outside Git.

## Friendly interface help and status presentation

`chat_presenter.jac` provides built-in interface help for exact greetings, capability/identity/how-to questions, wellbeing and thanks. For example, `hi, what can u do?` answers directly without starting a planner/model request. A mixed request such as `Hi, plan a two-hour meetup next week` still uses the shared planner. This is fixed interface help, not a general-purpose model chatbot. Help turns are session-only UI state; only actual server plans enter durable plan history. General open-ended conversation requires a lead-owned facade extension.

Main chat uses SVG badges, friendly activity labels, brief entrance animation and real-request-only loading indicators. Reduced-motion preferences disable animation. Raw tool identifiers are available under technical details on Activity & reviews. Validation errors suggest a valid session request; they do not automatically blame API credentials.

The running model key was rechecked as present, without reading it. Focused Jac compilation and live browser quick-help checks passed. An isolated, labelled provider transport fixture verified error presentation without a paid model call; no live model-success claim is made.
