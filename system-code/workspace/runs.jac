import json;
import from uuid { uuid4 }
import from datetime { datetime, timedelta }
import from zoneinfo { ZoneInfo }
import from contracts.models { RunRecord, StepRecord, RunData, RunEnvelope, APIError, ProposalRecord, ActivityEntry, PreferenceDependency, ConversationTurn }
import from contracts.validation { valid_id }
import from workspace.records { _receipts }

node StoredRun {
    has id: str, workspace_id: str, goal: str, request_id: str,
        status: str = "queued", version: int = 1, stage: int = 0,
        spec_json: str = "", proposals_json: str = "[]", activity_json: str = "[]",
        questions_json: str = "[]", error_code: str = "", error_message: str = "", explanation: str = "",
        last_request_id: str = "", input_ids: list[str] = [], advance_ids: list[str] = [], initial_goal: str = "",
        attempt_id: (str | None) = None, lease_expires_at: (str | None) = None;
    has output_ids: list[str] = [], needs_replan: bool = False, context_json: str = "[]";
}

def _now -> str { return datetime.now(ZoneInfo("Asia/Colombo")).isoformat(); }

def _error(code: str, message: str) -> RunEnvelope {
    return RunEnvelope(ok=False, data=RunData(), error=APIError(code=code, message=message));
}

def _find(run_id: str) -> (StoredRun | None) {
    for run in [root -->][?:StoredRun] { if run.id == run_id { return run; } }
    return None;
}

def _view(run: StoredRun) -> RunEnvelope {
    steps: list[StepRecord] = [];
    for (index, name) in enumerate(["interpret", "read_workspace", "draft"]) {
        state = "completed" if index < run.stage else "queued";
        if run.status in ["failed", "cancelled", "waiting_for_input"] and index == min(run.stage, 2) { state = run.status; }
        if run.status == "running" and index == min(run.stage, 2) { state = "running"; }
        if run.status == "waiting_for_approval" and index == 2 { state = "waiting_for_approval"; }
        steps.append(StepRecord(id=name, status=state, depends_on_step_ids=[] if index == 0 else [["interpret", "read_workspace"][index - 1]]));
    }
    proposals = [ProposalRecord(id=p["id"], workspace_id=run.workspace_id, run_id=run.id, kind=p["kind"], payload=p["payload"], payload_hash=p["payload_hash"],status=p["status"],revision=p.get("revision",1),expected_target_version=p.get("expected_target_version"),
        preference_dependencies=[PreferenceDependency(id=d["id"],version=d["version"]) for d in p.get("preference_dependencies",[])]) for p in json.loads(run.proposals_json)];
    for proposal in proposals {
        if proposal.kind == "create_event" {
            steps[1].preference_dependencies = proposal.preference_dependencies;
            steps[2].preference_dependencies = proposal.preference_dependencies;
        }
    }
    activity = [ActivityEntry(sequence=a["sequence"], timestamp=a["timestamp"], step_id=a["step_id"], tool=a["tool"], outcome=a["outcome"]) for a in json.loads(run.activity_json)];
    error = APIError(code=run.error_code, message=run.error_message) if run.error_code else None;
    record = RunRecord(id=run.id, workspace_id=run.workspace_id, goal=run.goal, status=run.status,
        version=run.version, steps=steps, error=error, attempt_id=run.attempt_id, lease_expires_at=run.lease_expires_at,output_ids=run.output_ids);
    return RunEnvelope(ok=True, data=RunData(run=record, proposals=proposals, activity=activity, questions=json.loads(run.questions_json),explanation=run.explanation,receipts=_receipts(run.workspace_id,run.id),conversation=[ConversationTurn(user=t["user"],assistant=t["assistant"]) for t in json.loads(getattr(run,"context_json","[]"))]));
}

def _activity(run: StoredRun, tool: str, outcome: str) -> None {
    entries = json.loads(run.activity_json);
    entries.append({"sequence":len(entries)+1,"timestamp":_now(),"step_id":["interpret","read_workspace","draft"][min(run.stage,2)],"tool":tool,"outcome":outcome});
    run.activity_json = json.dumps(entries);
}

def _start(text: str, workspace_id: str, request_id: str, parent_run_id: str = "") -> RunEnvelope {
    text = text.strip();
    if not text or len(text) > 4000 or not valid_id(workspace_id) or not valid_id(request_id) {
        return _error("VALIDATION_ERROR","Use a goal of 1 to 4000 characters and valid workspace/request IDs.");
    }
    existing = [root -->][?:StoredRun];
    for run in existing {
        if run.workspace_id == workspace_id and run.request_id == request_id {
            if (run.initial_goal or run.goal) != text { return _error("IDEMPOTENCY_CONFLICT","Request ID already belongs to another goal."); }
            return _view(run);
        }
    }
    context: list[dict] = [];
    if parent_run_id {
        parent = _find(parent_run_id);
        if parent is None or parent.workspace_id != workspace_id { return _error("NOT_FOUND","Conversation not found in this workspace."); }
        context = json.loads(getattr(parent,"context_json","[]"))[-6:] + [{"user":parent.goal,"assistant":parent.explanation}];
    }
    # Local demo cost guard, persisted and not controllable through browser counters.
    if len([r for r in existing if r.workspace_id == workspace_id]) >= 100 { return _error("USAGE_LIMIT","This workspace has reached its 100-message demo limit. Open a new review workspace to continue."); }
    run = root ++> StoredRun(id=str(uuid4()),workspace_id=workspace_id,goal=text,initial_goal=text,request_id=request_id,context_json=json.dumps(context));
    _activity(run,"start_goal","Goal queued; no workspace actions executed.");
    return _view(run);
}

def _get(run_id: str) -> RunEnvelope {
    run = _find(run_id);
    if run is None { return _error("NOT_FOUND","Run not found."); }
    return _view(run);
}

def _claim(run_id: str, expected_version: int, request_id: str) -> RunEnvelope {
    run = _find(run_id);
    if run is None { return _error("NOT_FOUND","Run not found."); }
    if not valid_id(request_id) { return _error("VALIDATION_ERROR","Invalid request ID."); }
    if request_id in run.advance_ids { return _view(run); }
    if run.version != expected_version { return _error("VERSION_CONFLICT","Run changed. Reload its latest version."); }
    if run.status == "running" {
        if run.lease_expires_at and run.lease_expires_at < _now() {
            run.status = "failed"; run.error_code = "TOOL_ERROR";
            run.error_message = "The planning attempt was interrupted. Start a new goal.";
            run.version += 1; run.attempt_id = None; run.lease_expires_at = None;
            _activity(run,"advance_run","Interrupted attempt expired; no actions executed.");
            return _view(run);
        }
        return _error("RUN_BUSY","A planning stage is already running.");
    }
    if run.status != "queued" { return _view(run); }
    run.status = "running"; run.version += 1;
    run.last_request_id = request_id; run.attempt_id = str(uuid4());
    run.advance_ids = run.advance_ids + [request_id];
    run.lease_expires_at = (datetime.now(ZoneInfo("Asia/Colombo")) + timedelta(seconds=120)).isoformat();
    _activity(run,"advance_run","Bounded planning stage started.");
    commit();
    return _view(run);
}

def _finish(run_id: str, attempt_id: str, status: str, stage: int, spec_json: str = "",
    proposals_json: str = "[]", questions_json: str = "[]", error_code: str = "", error_message: str = "", explanation: str = "") -> RunEnvelope {
    run = _find(run_id);
    if run is None { return _error("NOT_FOUND","Run not found."); }
    if run.status != "running" or run.attempt_id != attempt_id {
        return _error("VERSION_CONFLICT","The planning attempt is no longer current.");
    }
    run.status = status; run.stage = stage; run.version += 1;
    if spec_json { run.spec_json = spec_json; }
    run.proposals_json = proposals_json; run.questions_json = questions_json;
    run.error_code = error_code; run.error_message = error_message;
    run.explanation = explanation;
    run.attempt_id = None; run.lease_expires_at = None;
    _activity(run,"planning", "Proposals ready for review; nothing executed." if status == "waiting_for_approval" else status);
    commit();
    return _view(run);
}

def _input(run_id: str, expected_version: int, text: str, request_id: str) -> RunEnvelope {
    run = _find(run_id);
    if run is None { return _error("NOT_FOUND","Run not found."); }
    if request_id in run.input_ids { return _view(run); }
    if run.version != expected_version { return _error("VERSION_CONFLICT","Run changed. Reload first."); }
    if run.status != "waiting_for_input" { return _error("INVALID_STATE","This run is not waiting for input."); }
    if run.stage >= 3 { return _error("INVALID_STATE","Use Replan pending actions to preserve already committed records. Start a new goal to change its content."); }
    if not valid_id(request_id) or not text.strip() or len(run.goal) + len(text) + 1 > 4000 or len(run.input_ids) >= 3 {
        return _error("VALIDATION_ERROR","Supply bounded clarification text; at most three rounds are supported.");
    }
    run.goal = run.goal + "\n" + text.strip();
    run.input_ids = run.input_ids + [request_id];
    run.status = "queued"; run.stage = 0; run.version += 1;
    run.spec_json = ""; run.questions_json = "[]"; run.last_request_id = "";
    _activity(run,"provide_input","Clarification queued for interpretation.");
    return _view(run);
}

def _cancel(run_id: str, expected_version: int) -> RunEnvelope {
    run = _find(run_id);
    if run is None { return _error("NOT_FOUND","Run not found."); }
    if run.status == "cancelled" { return _view(run); }
    if run.version != expected_version { return _error("VERSION_CONFLICT","Run changed. Reload first."); }
    if run.status == "completed" { return _error("INVALID_STATE","A completed run cannot be cancelled."); }
    run.status = "cancelled"; run.version += 1;
    run.attempt_id = None; run.lease_expires_at = None;
    # Pending previews are retained as stale, never executable.
    proposals = json.loads(run.proposals_json);
    for proposal in proposals {
        if proposal["status"] in ["pending","rejected"] { proposal["status"] = "stale"; }
    }
    run.proposals_json = json.dumps(proposals);
    _activity(run,"cancel_run","Run cancelled; previously committed records retained.");
    return _view(run);
}
