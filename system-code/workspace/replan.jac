import json;
import from uuid { uuid4 }
import from datetime { datetime }
import from zoneinfo { ZoneInfo }
import from contracts.models { RunEnvelope }
import from agent.model { decode_goal }
import from workspace.runs { _find, _view, _error, _activity }
import from workspace.planning { StoredCalendarEvent, _planning_context }
import from workspace.reviews { _digest }

def _replan(run_id: str, expected_version: int) -> RunEnvelope {
    run = _find(run_id);
    if run is None { return _error("NOT_FOUND","Run not found."); }
    if run.version != expected_version { return _error("VERSION_CONFLICT","Run changed. Reload first."); }
    if run.status in ["running","cancelled","failed"] or not run.spec_json or run.stage < 1 {
        return _error("INVALID_STATE","This run cannot be replanned now.");
    }
    previous: list[dict] = json.loads(run.proposals_json);
    workspace_id = run.workspace_id;
    identity = run.id;
    events = [item.record for item in [root -->][?:StoredCalendarEvent] if item.record.workspace_id == workspace_id and item.record.goal_id == identity];
    if len(events) > 1 { return _error("TOOL_ERROR","Multiple session events need manual review."); }
    event = events[0] if events else None;
    try {
        spec = decode_goal(run.spec_json);
        context = _planning_context(run.workspace_id,run.goal,spec.duration_minutes,datetime.now(ZoneInfo("Asia/Colombo")).isoformat(),event.id if event is not None else "");
    } except Exception { return _error("TOOL_ERROR","Availability cannot be safely calculated."); }
    # Supersede only unfinished previews. Committed records and their receipts stay intact.
    for proposal in previous {
        if proposal["status"] in ["pending","rejected"] { proposal["status"] = "stale"; }
    }
    if not context["slots"] {
        run.proposals_json = json.dumps(previous); run.version += 1; run.status = "waiting_for_input";
        run.needs_replan = True;
        run.questions_json = json.dumps(["No free slot satisfies the current availability. Change the constraint or calendar."]);
        _activity(run,"replan","No available slot; no records changed.");  return _view(run);
    }
    additions: list[dict] = [];
    for kind in ["create_note","create_task"] {
        # Clone the most recent preview for each original action, preserving distinct tasks.
        seen: set[str] = set();
        for proposal in previous[::-1] {
            if proposal["kind"] != kind { continue; }
            marker = json.dumps(proposal["payload"],sort_keys=True);
            if marker in seen { continue; }
            seen.add(marker);
            if any(p["kind"] == kind and p["payload"] == proposal["payload"] and p["status"] == "committed" for p in previous) { continue; }
            additions.append({"id":str(uuid4()),"kind":kind,"payload":proposal["payload"],"revision":proposal.get("revision",1)+1,
                "payload_hash":_digest(kind,proposal["payload"]),"status":"pending","preference_dependencies":[]});
        }
    }
    slot = context["slots"][0];
    payload = {"workspace_id":run.workspace_id,"title":spec.title,"start":slot["start"],"end":slot["end"],"timezone":slot["timezone"],"goal_id":run.id};
    kind = "update_event" if event is not None else "create_event";
    if event is not None { payload["id"] = event.id; }
    revision = 1 + max([p.get("revision",1) for p in previous if p["kind"] in ["create_event","update_event"]] or [0]);
    additions.append({"id":str(uuid4()),"kind":kind,"payload":payload,"payload_hash":_digest(kind,payload),"revision":revision,
        "expected_target_version":event.version if event is not None else None,"status":"pending","preference_dependencies":context["preference_dependencies"]});
    run.proposals_json = json.dumps(previous + additions); run.version += 1; run.stage = 3; run.status = "waiting_for_approval";
    run.needs_replan = False;
    run.questions_json = "[]"; run.error_code = ""; run.error_message = "";
    run.explanation = "Replanned against current calendar and confirmed availability. Existing committed notes/tasks are preserved; the event update keeps its ID.";
    _activity(run,"replan","Fresh previews require fresh approval; no records changed.");
    return _view(run);
}
