import from contracts.models { HealthData, HealthEnvelope }
import from contracts.models { TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }
import from workspace.tasks { create_manual_task, read_tasks }
import from contracts.models { RunData, RunEnvelope, RunRecord, StepRecord, ProposalRecord, ActivityEntry, PreferenceDependency }
import from workspace.runs { _start, _get, _input, _cancel }
import from agent.coordinator { _advance }

def:pub start_goal(text: str, workspace_id: str, request_id: str) -> RunEnvelope { return _start(text,workspace_id,request_id); }
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
