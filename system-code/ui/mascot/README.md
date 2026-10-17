# Meridian pose animation

Open `preview.html` directly in a browser; no installation required. Controls are manual animation previews, not real agent execution.

## Requested behaviors

- Thinking: hand resting against cheek, with thoughtful head/blink frames.
- Working: seated at a computer, hands typing on a keyboard.
- Approved: head nods down and up; torso remains standing.
- Success: standing character jumps vertically in the same spot.
- Error: head turns left and right to shake no.
- Idle/waiting: neutral standing pose. Waiting does not nod approval.

`assets/meridian-poses.png` is a transparent four-column/four-row atlas generated with built-in imagegen using the unchanged `assets/meridian-agent.png` as the identity reference. Rows are thinking, working, approval, error. CSS plays the four poses in each row; success uses the neutral standing frame and a vertical jump. The original reference is retained. These are discrete sprite frames, not a skeletal 3D model.

## Jac integration

`PlannerPanel` renders `<AgentMascot status={mascot_state()} />`. The CSS embeds the atlas through `assets/atlas.css`; no shared static registration is required. Jac 0.34.24 leaves CSS image URLs uncopied and attempts to decode direct PNG imports as UTF-8, so this source artwork is embedded as a data URI. The PNG remains the editable source; the encoded asset is excluded from meaningful source-language metrics. Real requests show working, planning advancement shows thinking, and server run states select waiting/input/completed/failed poses. Validation and network errors shake the head. Successful manual saves jump only after the server confirms the write.

Review approval nods only after a successful response includes a receipt matching the exact proposal ID and revision idempotency key. On the final approved action, two nod cycles precede the completion jump. Pending approval stays neutral. Starting another operation clears the previous presentation outcome. No simulated tool activity is introduced.

The component does not decide or perform approvals, tool calls, or writes. Feed actual server state. Reduced-motion preferences freeze pose frames and disable jumping.

## Verification

Browser checks passed in headless Chrome/Playwright: seven controls, correct row selection, four distinct frame offsets for each pose, vertical-only success jump, reduced-motion override, and no browser errors. The thinking/working/nodding/shaking contact sheet was visually inspected. Original image remains unchanged. No root configuration, backend, dependencies, or shared contracts are changed by this component.

The project uses pinned Jac 0.34.24 in Docker/WSL. Focused compilation and live browser verification results are recorded in local continuation notes outside Git. The standalone HTML controls remain a presentation preview, not an execution demo.
