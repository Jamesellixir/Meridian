import from contracts.models { HealthData, HealthEnvelope }
import from contracts.models { TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }
import from workspace.tasks { create_manual_task, read_tasks }
import from contracts.models { RunData, RunEnvelope, RunRecord, StepRecord, ProposalRecord, ActivityEntry, PreferenceDependency }
import from workspace.runs { _start, _get, _input, _cancel }
import from agent.coordinator { _advance }
import from contracts.models { WorkspaceData, WorkspaceEnvelope, EventRecord, NoteRecord, PreferenceRecord, ReceiptRecord }
import from workspace.records { _workspace, _manual_event, _task_status, _new_demo }
import from workspace.preferences { _save_preference, _change_preference }
import from workspace.replan { _replan }
import from agent.review { _review }

def:pub get_workspace(workspace_id: str, refresh_id: str = "") -> WorkspaceEnvelope { return _workspace(workspace_id); }
def:pub new_demo_workspace -> WorkspaceEnvelope { return _new_demo(); }
def:pub save_event(workspace_id: str, title: str, start: str, end: str, request_id: str, event_id: str = "", expected_version: int = 0, color: str = "blue") -> WorkspaceEnvelope { return _manual_event(workspace_id,title,start,end,request_id,event_id,expected_version,color); }
def:pub update_task_status(workspace_id: str, task_id: str, expected_version: int, status: str) -> WorkspaceEnvelope { return _task_status(workspace_id,task_id,expected_version,status); }
def:pub save_preference(workspace_id: str, value: str, request_id: str) -> WorkspaceEnvelope { return _save_preference(workspace_id,value,request_id); }
def:pub correct_preference(preference_id: str, expected_version: int, value: str) -> WorkspaceEnvelope { return _change_preference(preference_id,expected_version,value); }
def:pub forget_preference(preference_id: str, expected_version: int) -> WorkspaceEnvelope { return _change_preference(preference_id,expected_version,"",True); }
def:pub review_proposal(proposal_id: str, revision: int, payload_hash: str, decision: str) -> RunEnvelope { return _review(proposal_id,revision,payload_hash,decision); }
def:pub replan_run(run_id: str, expected_version: int) -> RunEnvelope { return _replan(run_id,expected_version); }

def:pub start_goal(text: str, workspace_id: str, request_id: str, parent_run_id: str = "") -> RunEnvelope { return _start(text,workspace_id,request_id,parent_run_id); }
def:pub get_run(run_id: str, refresh_id: str = "") -> RunEnvelope { return _get(run_id); }
def:pub advance_run(run_id: str, expected_version: int, request_id: str) -> RunEnvelope { return _advance(run_id,expected_version,request_id); }
def:pub provide_input(run_id: str, expected_version: int, text: str, request_id: str) -> RunEnvelope { return _input(run_id,expected_version,text,request_id); }
def:pub cancel_run(run_id: str, expected_version: int) -> RunEnvelope { return _cancel(run_id,expected_version); }

def:pub create_task(workspace_id: str, title: str, request_id: str) -> TaskEnvelope {
    return create_manual_task(workspace_id, title, request_id);
}

def:pub list_tasks(workspace_id: str) -> TasksEnvelope {
    return read_tasks(workspace_id);
}

def:pub get_health -> HealthEnvelope {
    return HealthEnvelope(ok=True, data=HealthData());
}

import from workspace.calendar_view { _calendar, CalendarView, CalendarDay, CalendarEnvelope }
def:pub get_calendar(workspace_id: str, month: str = "", refresh_id: str = "") -> CalendarEnvelope {
    try { return CalendarEnvelope(ok=True,data=_calendar(workspace_id,month)); }
    except Exception { return CalendarEnvelope(ok=False,error=APIError(code="VALIDATION_ERROR",message="Could not load that calendar month.")); }
}

import from workspace.soul { _save_soul }
def:pub save_soul(workspace_id: str, value: str, expected_version: int) -> WorkspaceEnvelope { return _save_soul(workspace_id,value,expected_version); }
