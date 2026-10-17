import json;
import from uuid { uuid4 }
import from datetime { datetime, timedelta, time }
import from zoneinfo { ZoneInfo }
import from contracts.models { WorkspaceData, WorkspaceEnvelope, APIError, NoteRecord, EventRecord, ReceiptRecord, PreferenceRecord }
import from contracts.validation { valid_id, validate_event }
import from workspace.tasks { StoredTask, read_tasks }
import from workspace.planning { StoredCalendarEvent, StoredConfirmedPreference }

node StoredNote { has record: NoteRecord; }
node StoredReceipt { has record: ReceiptRecord, run_id: str; }
node StoredEventRequest { has workspace_id: str, request_id: str, fingerprint: str; }

def _workspace_error(code: str, message: str) -> WorkspaceEnvelope {
    return WorkspaceEnvelope(ok=False,data=WorkspaceData(),error=APIError(code=code,message=message));
}

def _receipts(workspace_id: str, run_id: str = "") -> list[ReceiptRecord] {
    return [item.record for item in [root -->][?:StoredReceipt] if item.record.workspace_id == workspace_id and (not run_id or item.run_id == run_id)];
}

def _workspace(workspace_id: str) -> WorkspaceEnvelope {
    if not valid_id(workspace_id) { return _workspace_error("VALIDATION_ERROR","Invalid workspace ID."); }
    return WorkspaceEnvelope(ok=True,data=WorkspaceData(workspace_id=workspace_id,
        events=[item.record for item in [root -->][?:StoredCalendarEvent] if item.record.workspace_id == workspace_id],
        tasks=read_tasks(workspace_id).data.tasks,
        notes=[item.record for item in [root -->][?:StoredNote] if item.record.workspace_id == workspace_id],
        preferences=[PreferenceRecord(id=p.id,workspace_id=p.workspace_id,key=p.key,value=p.value,source=p.source,confirmed=p.confirmed,version=p.version) for p in [root -->][?:StoredConfirmedPreference] if p.workspace_id == workspace_id and p.confirmed],
        receipts=_receipts(workspace_id)));
}

def _event_conflict(record: EventRecord, exclude_id: str = "") -> bool {
    for item in [root -->][?:StoredCalendarEvent] {
        existing = item.record;
        if existing.workspace_id == record.workspace_id and existing.id != exclude_id {
            if not validate_event(existing).ok { raise ValueError("Calendar data needs repair."); }
            if datetime.fromisoformat(record.start) < datetime.fromisoformat(existing.end) and datetime.fromisoformat(record.end) > datetime.fromisoformat(existing.start) {
                return True;
            }
        }
    }
    return False;
}

def _event_node(workspace_id: str, event_id: str) -> (StoredCalendarEvent | None) {
    for item in [root -->][?:StoredCalendarEvent] {
        if item.record.workspace_id == workspace_id and item.record.id == event_id { return item; }
    }
    return None;
}

def _manual_event(workspace_id: str, title: str, start: str, end: str, request_id: str,
    event_id: str = "", expected_version: int = 0) -> WorkspaceEnvelope {
    if not valid_id(workspace_id) or not valid_id(request_id) { return _workspace_error("VALIDATION_ERROR","Invalid workspace/request ID."); }
    fingerprint = json.dumps([title.strip(),start,end,event_id,expected_version]);
    for request in [root -->][?:StoredEventRequest] {
        if request.workspace_id == workspace_id and request.request_id == request_id {
            if request.fingerprint != fingerprint { return _workspace_error("IDEMPOTENCY_CONFLICT","Request ID already used with different content."); }
            return _workspace(workspace_id);
        }
    }
    for item in [root -->][?:StoredCalendarEvent] {
        if item.record.workspace_id == workspace_id and item.request_id == request_id {
            if item.fingerprint != fingerprint { return _workspace_error("IDEMPOTENCY_CONFLICT","Request ID already used with different content."); }
            return _workspace(workspace_id);
        }
    }
    record = EventRecord(id=event_id or str(uuid4()),workspace_id=workspace_id,title=title.strip(),start=start,end=end);
    if not validate_event(record).ok { return _workspace_error("VALIDATION_ERROR","Use a title and increasing ISO timestamps with timezone offsets."); }
    target = _event_node(workspace_id,event_id) if event_id else None;
    if event_id and target is None { return _workspace_error("NOT_FOUND","Event not found in this workspace."); }
    if target is not None and target.record.version != expected_version { return _workspace_error("VERSION_CONFLICT","Event changed. Reload first."); }
    try { conflict = _event_conflict(record,event_id); }
    except ValueError { return _workspace_error("VALIDATION_ERROR","Existing calendar data needs repair."); }
    if conflict { return _workspace_error("CALENDAR_CONFLICT","This interval overlaps another event."); }
    if target is not None {
        record.version = target.record.version + 1; record.goal_id = target.record.goal_id;
        target.record = record; target.request_id = request_id; target.fingerprint = fingerprint;
    } else { root ++> StoredCalendarEvent(record=record,request_id=request_id,fingerprint=fingerprint); }
    root ++> StoredEventRequest(workspace_id=workspace_id,request_id=request_id,fingerprint=fingerprint);

    return _workspace(workspace_id);
}

def _task_status(workspace_id: str, task_id: str, expected_version: int, status: str) -> WorkspaceEnvelope {
    if status not in ["todo","in_progress","done"] { return _workspace_error("VALIDATION_ERROR","Invalid task status."); }
    for item in [root -->][?:StoredTask] {
        if item.workspace_id == workspace_id and item.id == task_id {
            if item.version != expected_version { return _workspace_error("VERSION_CONFLICT","Task changed. Reload first."); }
            item.status = status; item.version += 1;  return _workspace(workspace_id);
        }
    }
    return _workspace_error("NOT_FOUND","Task not found in this workspace.");
}

def _new_demo -> WorkspaceEnvelope {
    workspace_id = "review-" + str(uuid4());
    monday = datetime.now(ZoneInfo("Asia/Colombo")).date();
    monday += timedelta(days=7-monday.weekday());
    start = datetime.combine(monday,time(9),tzinfo=ZoneInfo("Asia/Colombo"));
    root ++> StoredCalendarEvent(record=EventRecord(id=str(uuid4()),workspace_id=workspace_id,title="Synthetic busy morning",start=start.isoformat(),end=(start+timedelta(hours=3)).isoformat()));
    root ++> StoredConfirmedPreference(id=str(uuid4()),workspace_id=workspace_id,key="availability",value="anytime",source="Synthetic review baseline");

    return _workspace(workspace_id);
}
