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
