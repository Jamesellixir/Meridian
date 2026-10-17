# Shared DTOs. Workspace persistence implementations remain owned by workspace/.
obj APIError {
    has code: str, message: str, retryable: bool = False;
}

obj Envelope {
    has ok: bool, data: (dict | None) = None, error: (APIError | None) = None;
}

obj GoalRequest {
    has text: str, workspace_id: str, request_id: str;
}

obj HealthData {
    has service: str = "Meridian", phase: str = "coordinator",
        contract_version: str = "1.0.0", jac_version: str = "0.34.24";
}
obj HealthEnvelope {
    has ok: bool, data: HealthData, error: (APIError | None) = None;
}

obj GoalSpec {
    has title: str,
        duration_minutes: int,
        missing_information: list[str],
        constraints: list[str],
        intent: str, reply: str = "";
}

obj PreferenceDependency { has id: str, version: int; }
obj CandidateSlot { has start: str, end: str, timezone: str = "Asia/Colombo"; }
obj TaskDraft { has title: str, due_at: (str | None) = None; }
obj PlanDraft {
    has note_title: str,
        note_body: str,
        tasks: list[TaskDraft],
        selected_slot_index: (int | None) = None,
        explanation: str = "";
}

obj StepRecord {
    has id: str, status: str = "queued",
        depends_on_step_ids: list[str] = [],
        preference_dependencies: list[PreferenceDependency] = [],
        output_ids: list[str] = [];
}

obj RunRecord {
    has id: str, workspace_id: str, goal: str,
        status: str = "queued", version: int = 1,
        steps: list[StepRecord] = [], output_ids: list[str] = [],
        error: (APIError | None) = None,
        attempt_id: (str | None) = None, lease_expires_at: (str | None) = None;
}

obj EventRecord {
    has id: str, workspace_id: str, title: str, start: str, end: str,
        timezone: str = "Asia/Colombo", goal_id: (str | None) = None, version: int = 1, color: str = "blue";
}
obj TaskRecord {
    has id: str, workspace_id: str, title: str,
        status: str = "todo", goal_id: (str | None) = None,
        due_at: (str | None) = None, version: int = 1;
}
obj TaskData { has task: (TaskRecord | None) = None; }
obj TasksData { has tasks: list[TaskRecord] = []; }
obj TaskEnvelope { has ok: bool, data: TaskData, error: (APIError | None) = None; }
obj TasksEnvelope { has ok: bool, data: TasksData, error: (APIError | None) = None; }
obj NoteRecord {
    has id: str, workspace_id: str, title: str, body: str,
        goal_id: (str | None) = None, version: int = 1;
}
obj PreferenceRecord {
    has id: str, workspace_id: str, key: str, value: str, source: str,
        confirmed: bool = False, version: int = 1;
}
obj ProposalRecord {
    has id: str, workspace_id: str, run_id: str, kind: str, payload: dict,
        payload_hash: str, revision: int = 1,
        expected_target_version: (int | None) = None,
        preference_dependencies: list[PreferenceDependency] = [],
        status: str = "pending";
}
obj ReceiptRecord {
    has id: str, workspace_id: str, proposal_id: str, record_ids: list[str],
        committed_at: str, idempotency_key: str;
}
obj ActivityEntry {
    has sequence: int, timestamp: str, step_id: str, tool: str,
        outcome: str, record_ids: list[str] = [];
}

obj ConversationTurn { has user: str, assistant: str; }

obj RunData {
    has run: (RunRecord | None) = None,
        proposals: list[ProposalRecord] = [], activity: list[ActivityEntry] = [],
        questions: list[str] = [], explanation: str = "", receipts: list[ReceiptRecord] = [], conversation: list[ConversationTurn] = [];
}
obj RunEnvelope { has ok: bool, data: RunData, error: (APIError | None) = None; }

obj WorkspaceData {
    has workspace_id: str = "", events: list[EventRecord] = [], tasks: list[TaskRecord] = [],
        notes: list[NoteRecord] = [], preferences: list[PreferenceRecord] = [], receipts: list[ReceiptRecord] = [];
}
obj WorkspaceEnvelope { has ok: bool, data: WorkspaceData, error: (APIError | None) = None; }


def success(data: dict) -> Envelope { return Envelope(ok=True, data=data); }
def failure(code: str, message: str, retryable: bool = False) -> Envelope {
    return Envelope(ok=False, error=APIError(code=code, message=message, retryable=retryable));
}
