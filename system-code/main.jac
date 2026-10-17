# Register server endpoints and their DTOs explicitly in the entry module.
import from app.api { get_health, HealthData, HealthEnvelope }
import from app.api { create_task, list_tasks, TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }
import from app.api { start_goal, get_run, advance_run, provide_input, cancel_run, RunData, RunEnvelope, RunRecord, StepRecord, ProposalRecord, ActivityEntry, PreferenceDependency }

cl {
    import from ui.shell { FoundationShell }
    def:pub app -> JsxElement { return <FoundationShell />; }
}
