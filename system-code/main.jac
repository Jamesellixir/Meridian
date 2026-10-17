# Register server endpoints and their DTOs explicitly in the entry module.
import from app.api { get_health, HealthData, HealthEnvelope }
import from app.api { create_task, list_tasks, TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }

cl {
    import from ui.shell { FoundationShell }
    def:pub app -> JsxElement { return <FoundationShell />; }
}
