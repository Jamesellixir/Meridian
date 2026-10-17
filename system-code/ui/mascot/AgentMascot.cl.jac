import "./mascot.css";

# image_src is the served 4x4 pose-atlas URL, not the original reference image.
# Presentational only: the parent supplies actual server state.
def:pub AgentMascot(image_src: str, status: str = "idle") -> JsxElement {
    state = status;
    if status == "queued" { state = "thinking"; }
    elif status == "running" { state = "working"; }
    elif status == "waiting_for_approval" { state = "waiting"; }
    elif status == "completed" { state = "success"; }
    elif status == "failed" { state = "error"; }
    elif status == "cancelled" { state = "idle"; }
    elif status == "approved" { state = "approval"; }
    if state not in ["idle", "thinking", "working", "waiting", "approval", "success", "error"] {
        state = "idle";
    }
    label = "Ready when you are";
    if state == "thinking" { label = "Thinking"; }
    elif state == "working" { label = "Working"; }
    elif state == "waiting" { label = "Waiting for your approval"; }
    elif state == "approval" { label = "Approved"; }
    elif state == "success" { label = "Completed"; }
    elif state == "error" { label = "Needs attention"; }
    return <figure className={"meridian-mascot is-" + state}>
        <div className="meridian-mascot__stage" aria-hidden="true">
            <div className="meridian-mascot__frame">
                <img className="meridian-mascot__character" src={image_src}
                    alt="" draggable={false} />
            </div>
        </div>
        <figcaption role="status" aria-live="polite">
            <span className="meridian-mascot__indicator" />{label}
        </figcaption>
    </figure>;
}
