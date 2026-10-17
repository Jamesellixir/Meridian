sv import from app.api { get_health, HealthData, HealthEnvelope }
sv import from app.api { create_task, list_tasks, TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, APIError }
import from .planner { PlannerPanel }

def:pub FoundationShell -> JsxElement {
    has status: str = "Checking server...";
    has tasks: list[TaskRecord] = [];
    has title: str = "";
    has busy: bool = False;
    has loading: bool = True;
    has message: str = "";
    has request_id: str = "";
    async can with entry {
        try {
            result = await get_health();
            status = "Server connected - contract " + result.data.contract_version;
            loaded = await list_tasks("demo");
            if loaded.ok { tasks = loaded.data.tasks; }
            else { message = "Could not load tasks. Reload to try again."; }
        } except Exception {
            status = "Server connection failed";
            message = "Could not load tasks. Reload to try again.";
        }
        loading = False;
    }

    def change_title(event: ChangeEvent) {
        title = event.target.value;
        request_id = "";
    }

    async def save(event: FormEvent) -> None {
        event.preventDefault();
        if busy { return; }
        if not title.strip() or len(title.strip()) > 200 {
            message = "Enter a task title of 1 to 200 characters.";
            return;
        }
        busy = True;
        message = "";
        key = request_id;
        if not key {
            key = str(crypto.randomUUID()); # jac:ignore[E1032,W2001,W1051]
            request_id = key;
        }
        try {
            result = await create_task("demo", title, key);
            if result.ok and result.data.task is not None {
                saved = result.data.task;
                # Use the confirmed write response: Jac 0.34.24 may cache facade readers.
                tasks = [task for task in tasks if task.id != saved.id] + [saved];
                title = "";
                request_id = "";
                message = "Task saved.";
            } else {
                message = "Task was not saved. Check the title and try again.";
            }
        } except Exception {
            message = "Connection interrupted. Retry with the same title to safely check this save.";
        }
        busy = False;
    }

    return <main style={{"maxWidth": "720px", "margin": "48px auto", "padding": "24px", "fontFamily": "system-ui"}}>
        <h1>Meridian</h1>
        <p>Demo workspace</p>
        <p>{status}</p>
        <h2>Tasks</h2>
        <form onSubmit={save}>
            <label htmlFor="task-title">Task title</label>
            <input id="task-title" value={title} onChange={change_title} maxLength={200} disabled={busy or loading} />
            <button type="submit" disabled={busy or loading}>{"Saving..." if busy else "Add task"}</button>
        </form>
        <p role="status" aria-live="polite">{message}</p>
        {loading and <p>Loading tasks...</p>}
        {not loading and len(tasks) == 0 and <p>No tasks yet. Add your first task above.</p>}
        <ul>{for task in tasks { <li key={task.id}>{task.title}{" — "}{task.status}</li> }}</ul>
        <p>Tasks are saved locally. Plan previews appear below; action execution arrives in phase 4.</p>
        <PlannerPanel />
    </main>;
}
