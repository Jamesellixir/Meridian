import "./mascot.css";
import "./assets/atlas.css";

# The CSS asset URL is bundled by the frontend pipeline.
# Presentational only: the parent supplies actual server state.
def:pub AgentMascot(status: str = "idle") -> JsxElement {
    state = status;
    if status == "queued" { state = "thinking"; }
    elif status == "running" { state = "working"; }
    elif status in ["waiting_for_approval", "waiting_for_input"] { state = "waiting"; }
    elif status == "completed" { state = "success"; }
    elif status == "failed" { state = "error"; }
    elif status == "cancelled" { state = "idle"; }
    elif status in ["approved", "approved_completed"] { state = "approval"; }
    if state not in ["idle", "thinking", "working", "waiting", "approval", "success", "error"] {
        state = "idle";
    }
    label = "Ready when you are";
    if state == "thinking" { label = "Thinking"; }
    elif state == "working" { label = "Working"; }
    elif state == "waiting" { label = "Waiting for your input" if status == "waiting_for_input" else "Waiting for your approval"; }
    elif state == "approval" { label = "Approved"; }
    elif state == "success" { label = "Completed"; }
    elif state == "error" { label = "Needs attention"; }
    return <figure data-state={state} className={"meridian-mascot is-" + state + (" approval-completed" if status == "approved_completed" else "")}>
        <div className="meridian-mascot__stage" aria-hidden="true">
            <div className="meridian-mascot__frame">
                <div className="meridian-mascot__character" />
            </div>
        </div>
        <figcaption role="status" aria-live="polite">
            <span className="meridian-mascot__indicator" />{label}
        </figcaption>
    </figure>;
}
