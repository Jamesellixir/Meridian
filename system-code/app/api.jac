import from contracts.models { HealthData, HealthEnvelope }
import from contracts.models { TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }
import from workspace.tasks { create_manual_task, read_tasks }

def:pub create_task(workspace_id: str, title: str, request_id: str) -> TaskEnvelope {
    return create_manual_task(workspace_id, title, request_id);
}

def:pub list_tasks(workspace_id: str) -> TasksEnvelope {
    return read_tasks(workspace_id);
}

def:pub get_health -> HealthEnvelope {
    return HealthEnvelope(ok=True, data=HealthData());
}
