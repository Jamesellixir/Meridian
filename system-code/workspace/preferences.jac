import json;
import from uuid { uuid4 }
import from contracts.models { WorkspaceEnvelope }
import from contracts.validation { valid_id }
import from workspace.planning { StoredConfirmedPreference }
import from workspace.records { _workspace, _workspace_error }
import from workspace.runs { StoredRun, _activity }

def _invalidate_availability(workspace_id: str) -> None {
    for run in [root -->][?:StoredRun] {
        if run.workspace_id != workspace_id or run.status == "cancelled" { continue; }
        proposals = json.loads(run.proposals_json);
        affected = False;
        for proposal in proposals {
            if proposal["kind"] in ["create_event","update_event"] {
                affected = True;
                if proposal["status"] == "pending" { proposal["status"] = "stale"; }
            }
        }
        if affected {
            run.proposals_json = json.dumps(proposals); run.version += 1;
            run.needs_replan = True;
            run.status = "waiting_for_input";
            run.questions_json = json.dumps(["Availability changed. Replan the event and review its new preview."]);
            _activity(run,"preference_changed","Event planning invalidated; committed events and unrelated outputs retained.");
        }
    }
}

def _save_preference(workspace_id: str, value: str, request_id: str) -> WorkspaceEnvelope {
    if not valid_id(workspace_id) or not valid_id(request_id) or value not in ["morning","anytime"] {
        return _workspace_error("VALIDATION_ERROR","Explicit availability must be morning or anytime with valid IDs.");
    }
    for preference in [root -->][?:StoredConfirmedPreference] {
        if preference.workspace_id == workspace_id and preference.request_id == request_id {
            if preference.value != value or not preference.confirmed { return _workspace_error("IDEMPOTENCY_CONFLICT","Request ID already used."); }
            return _workspace(workspace_id);
        }
        if preference.workspace_id == workspace_id and preference.key == "availability" and preference.confirmed {
            return _workspace_error("VERSION_CONFLICT","Availability exists. Correct its current version.");
        }
    }
    root ++> StoredConfirmedPreference(id=str(uuid4()),workspace_id=workspace_id,key="availability",value=value,request_id=request_id);
    _invalidate_availability(workspace_id);

    return _workspace(workspace_id);
}

def _change_preference(preference_id: str, expected_version: int, value: str, forget: bool = False) -> WorkspaceEnvelope {
    if not forget and value not in ["morning","anytime"] { return _workspace_error("VALIDATION_ERROR","Availability must be morning or anytime."); }
    for preference in [root -->][?:StoredConfirmedPreference] {
        if preference.id != preference_id { continue; }
        if preference.version != expected_version { return _workspace_error("VERSION_CONFLICT","Preference changed. Reload first."); }
        if not preference.confirmed { return _workspace_error("NOT_FOUND","Preference was forgotten."); }
        preference.value = "" if forget else value;
        preference.confirmed = not forget; preference.version += 1;
        _invalidate_availability(preference.workspace_id);

        return _workspace(preference.workspace_id);
    }
    return _workspace_error("NOT_FOUND","Preference not found.");
}
