import from uuid { uuid4 }
import from contracts.models { TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }
import from contracts.validation { valid_id }

# Storage stays behind the workspace facade. Public demo endpoints use one local root.
node StoredTask {
    has id: str, workspace_id: str, title: str, request_id: str;
    has status: str = "todo", goal_id: (str | None) = None, due_at: (str | None) = None, version: int = 1;

    def to_record -> TaskRecord {
        return TaskRecord(id=self.id, workspace_id=self.workspace_id, title=self.title,
            status=self.status,goal_id=self.goal_id,due_at=self.due_at,version=self.version);
    }
}

def create_manual_task(workspace_id: str, title: str, request_id: str) -> TaskEnvelope {
    normalized = title.strip();
    if not valid_id(workspace_id) or not valid_id(request_id) or not normalized or len(normalized) > 200 {
        return TaskEnvelope(ok=False, data=TaskData(), error=APIError(code="VALIDATION_ERROR", message="Use valid workspace/request IDs and a task title of 1 to 200 characters."));
    }
    for task in [root -->][?:StoredTask] {
        if task.workspace_id == workspace_id and task.request_id == request_id {
            if task.title != normalized {
                return TaskEnvelope(ok=False, data=TaskData(), error=APIError(code="IDEMPOTENCY_CONFLICT", message="This request ID was already used for another task."));
            }
            return TaskEnvelope(ok=True, data=TaskData(task=task.to_record()));
        }
    }
    created = root ++> StoredTask(id=str(uuid4()), workspace_id=workspace_id, title=normalized, request_id=request_id);
    return TaskEnvelope(ok=True, data=TaskData(task=created.to_record()));
}

def read_tasks(workspace_id: str) -> TasksEnvelope {
    if not valid_id(workspace_id) {
        return TasksEnvelope(ok=False, data=TasksData(), error=APIError(code="VALIDATION_ERROR", message="Invalid workspace ID."));
    }
    return TasksEnvelope(ok=True, data=TasksData(tasks=[task.to_record() for task in [root -->][?:StoredTask] if task.workspace_id == workspace_id]));
}
