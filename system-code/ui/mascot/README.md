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

`AgentMascot.cl.jac` imports the shared CSS. Render `<AgentMascot image_src={served_pose_atlas_url} status={run.status} />` using the URL of **meridian-poses.png**, not the original reference image. Actual asset registration and application mounting remain with the shared skeleton owner.

Maps queued/running/waiting_for_approval/completed/failed/cancelled to thinking/working/waiting/success/error/idle. Explicit `approval` or `approved` selects the nod; `approved` is a presentation input, not a newly invented run status. A parent may supply it only after a genuine approval outcome, never merely when review is pending. Unknown input falls back to idle.

The component does not decide or perform approvals, tool calls, or writes. Feed actual server state. Reduced-motion preferences freeze pose frames and disable jumping.

## Verification

Browser checks passed in headless Chrome/Playwright: seven controls, correct row selection, four distinct frame offsets for each pose, vertical-only success jump, reduced-motion override, and no browser errors. The thinking/working/nodding/shaking contact sheet was visually inspected. Original image remains unchanged. No root configuration, backend, dependencies, or shared contracts are changed by this component.

The merged foundation now pins Jac 0.34.24 (see `docs/PHASE-1.md`). This Windows workstation has no installed WSL distribution or Docker executable, so the mascot's Jac compilation/integration remains unverified. Run the project checks and verify the component in the pinned runtime before integration. The existing CI checks `main.jac`, which does not yet import the mascot; a green foundation check alone does not prove mascot compilation. The HTML preview uses a small demonstration-only JavaScript controller.
