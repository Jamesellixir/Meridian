import from uuid { uuid4 }
import from contracts.models { Envelope, EventRecord, NoteRecord, success, failure }
import from contracts.validation { validate_event }
import from workspace.records { StoredNote, _event_node, _event_conflict }
import from workspace.tasks { StoredTask }
import from workspace.planning { StoredCalendarEvent, StoredConfirmedPreference }

def _execute(workspace_id: str, run_id: str, proposal: dict) -> Envelope {
    payload: dict = proposal["payload"];
    kind: str = proposal["kind"];
    if payload.get("workspace_id") != workspace_id or payload.get("goal_id") != run_id {
        return failure("VALIDATION_ERROR","Action does not belong to this run/workspace.");
    }
    for dependency in (proposal.get("preference_dependencies",[]) as list[dict]) {
        matches = [p for p in [root -->][?:StoredConfirmedPreference] if p.workspace_id == workspace_id and p.id == dependency["id"]];
        if len(matches) != 1 or not matches[0].confirmed or matches[0].version != dependency["version"] {
            return failure("STALE_PROPOSAL","A confirmed preference changed. Replan before approval.");
        }
    }
    raw_title = payload.get("title");
    if type(raw_title) is not str {
        return failure("VALIDATION_ERROR","Action title must be a string.");
    }
    title: str = (raw_title as str).strip();
    if not title or len(title) > 200 {
        return failure("VALIDATION_ERROR","Action title must have 1 to 200 characters.");
    }
    record_id = str(uuid4());
    if kind in ["create_event","update_event"] {
        expected_fields = {"workspace_id","title","start","end","timezone","goal_id"};
        if kind == "update_event" { expected_fields.add("id"); }
        if set(payload.keys()) != expected_fields or any(type(payload[key]) is not str for key in ["start","end","timezone"]) {
            return failure("VALIDATION_ERROR","Invalid event action fields.");
        }
        target = _event_node(workspace_id,payload["id"]) if kind == "update_event" else None;
        if kind == "update_event" and target is None { return failure("NOT_FOUND","Event no longer exists."); }
        if target is not None and (target.record.goal_id != run_id or target.record.version != proposal.get("expected_target_version")) {
            return failure("VERSION_CONFLICT","Event changed since this preview. Replan and review again.");
        }
        record_id = target.record.id if target is not None else record_id;
        record = EventRecord(id=record_id,workspace_id=workspace_id,title=title.strip(),start=payload["start"],end=payload["end"],timezone=payload["timezone"],goal_id=run_id,version=target.record.version+1 if target is not None else 1);
        if not validate_event(record).ok { return failure("VALIDATION_ERROR","Event timestamps/timezone are invalid."); }
        try { conflict = _event_conflict(record,record_id if target is not None else ""); }
        except ValueError { return failure("VALIDATION_ERROR","Calendar data prevents safe execution."); }
        if conflict { return failure("CALENDAR_CONFLICT","The reviewed slot is now busy. Replan for a new preview."); }
        for preference in [root -->][?:StoredConfirmedPreference] {
            if preference.workspace_id == workspace_id and preference.confirmed and preference.key == "availability" {
                captured = [d for d in proposal.get("preference_dependencies",[]) if d["id"] == preference.id and d["version"] == preference.version];
                if not captured { return failure("STALE_PROPOSAL","A new availability preference requires replanning."); }
            }
        }
        if target is not None { target.record = record; }
        else { root ++> StoredCalendarEvent(record=record); }
    } elif kind == "create_task" {
        if set(payload.keys()) != {"workspace_id","title","due_at","goal_id"} or payload["due_at"] is not None {
            return failure("VALIDATION_ERROR","Invalid task action fields.");
        }
        root ++> StoredTask(id=record_id,workspace_id=workspace_id,title=title.strip(),request_id=proposal["id"],goal_id=run_id);
    } elif kind == "create_note" {
        if set(payload.keys()) != {"workspace_id","title","body","goal_id"} or type(payload["body"]) is not str or not payload["body"].strip() or len(payload["body"]) > 8000 {
            return failure("VALIDATION_ERROR","Invalid note action fields.");
        }
        root ++> StoredNote(record=NoteRecord(id=record_id,workspace_id=workspace_id,title=title.strip(),body=payload["body"],goal_id=run_id));
    } else { return failure("VALIDATION_ERROR","Unsupported action kind."); }
    return success({"record_id":record_id});
}
