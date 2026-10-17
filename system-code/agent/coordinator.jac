import json;
import hashlib;
import from uuid { uuid4 }
import from datetime { datetime }
import from zoneinfo { ZoneInfo }
import from contracts.models { RunEnvelope, GoalSpec }
import from agent.model { create_live_model, interpret_with, decode_goal }
import from agent.planner { _draft_with }
import from workspace.runs { _find, _get, _view, _claim, _finish, _activity }
import from workspace.planning { _planning_context }

def _advance(run_id: str, expected_version: int, request_id: str) -> RunEnvelope {
    prior = _find(run_id);
    if prior is not None and request_id in prior.advance_ids { return _view(prior); }
    claim = _claim(run_id,expected_version,request_id);
    if not claim.ok or claim.data.run is None or claim.data.run.status != "running" { return claim; }
    record = claim.data.run;
    attempt = record.attempt_id;
    assert attempt is not None;
    stored = _find(run_id);
    assert stored is not None;
    stage = stored.stage;
    today = datetime.now(ZoneInfo("Asia/Colombo")).date().isoformat();
    try { model = create_live_model(); }
    except Exception {
        return _finish(run_id,attempt,"failed",stage,error_code="PROVIDER_ERROR",error_message="Planning provider is not configured. No actions executed.");
    }
    try {
        if stage == 0 {
            spec = interpret_with(model,record.goal,today,"Asia/Colombo");
            encoded = json.dumps({"title":spec.title,"duration_minutes":spec.duration_minutes,
                "missing_information":spec.missing_information,"constraints":spec.constraints,"intent":spec.intent});
            if spec.intent != "plan_session" or spec.missing_information {
                questions = spec.missing_information or ["Please describe one planning session, including duration and next week or one ISO date."];
                return _finish(run_id,attempt,"waiting_for_input",0,spec_json=encoded,questions_json=json.dumps(questions));
            }
            return _finish(run_id,attempt,"queued",1,spec_json=encoded);
        }
        spec = decode_goal(stored.spec_json);
        context = _planning_context(record.workspace_id,record.goal,spec.duration_minutes,datetime.now(ZoneInfo("Asia/Colombo")).isoformat());
        _activity(stored,"read_workspace","Read tasks, calendar and confirmed preferences; found " + str(len(context["slots"])) + " candidate slots.");
        if not context["slots"] {
            return _finish(run_id,attempt,"waiting_for_input",1,questions_json=json.dumps(["No supported free slot. Supply next week or one future YYYY-MM-DD date within 60 days, or change availability."]));
        }
        # Unknown constraints must not be silently discarded by the deterministic tool.
        supported = ["next week","morning","morning only","only mornings","asia/colombo"];
        for constraint in spec.constraints {
            if constraint.strip().lower() not in supported {
                return _finish(run_id,attempt,"waiting_for_input",1,questions_json=json.dumps(["This constraint needs a supported scheduling rule: " + constraint[:200]]));
            }
        }
        draft = _draft_with(model,record.goal,context);
        if draft.selected_slot_index is None {
            return _finish(run_id,attempt,"waiting_for_input",1,questions_json=json.dumps(["No slot was selected. Please clarify your availability."]));
        }
        actions: list[dict] = [{"kind":"create_note","payload":{"workspace_id":record.workspace_id,"title":draft.note_title,"body":draft.note_body,"goal_id":run_id}}];
        for task in draft.tasks {
            actions.append({"kind":"create_task","payload":{"workspace_id":record.workspace_id,"title":task.title,"due_at":None,"goal_id":run_id}});
        }
        slot = context["slots"][draft.selected_slot_index];
        actions.append({"kind":"create_event","payload":{"workspace_id":record.workspace_id,"title":spec.title,"start":slot["start"],"end":slot["end"],"timezone":slot["timezone"],"goal_id":run_id}});
        proposals: list[dict] = [];
        for action in actions {
            canonical = json.dumps(action,sort_keys=True,separators=(",",":"),ensure_ascii=False);
            proposals.append({"id":str(uuid4()),"kind":action["kind"],"payload":action["payload"],
                "payload_hash":hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
                "status":"pending","preference_dependencies":context["preference_dependencies"] if action["kind"] == "create_event" else []});
        }
        return _finish(run_id,attempt,"waiting_for_approval",3,proposals_json=json.dumps(proposals),
            explanation="Available slot: " + (slot["start"] as str) + " to " + (slot["end"] as str) + " (" + (slot["timezone"] as str) + "). Agenda and tasks use supplied information.");
    } except ValueError {
        return _finish(run_id,attempt,"failed",stage,error_code="VALIDATION_ERROR",error_message="Planning data or model output failed validation. No actions executed.");
    } except Exception {
        return _finish(run_id,attempt,"failed",stage,error_code="PROVIDER_ERROR",error_message="Planning provider failed or timed out. No actions executed; start a new goal to retry.");
    }
}
