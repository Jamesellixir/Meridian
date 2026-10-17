import re;
import from datetime { datetime, timedelta, time }
import from zoneinfo { ZoneInfo }
import from contracts.models { CandidateSlot, EventRecord }
import from contracts.validation { validate_event }
import from workspace.tasks { read_tasks }

# These stable storage types are the facade boundary for subsequent manual tools.
node StoredCalendarEvent { has record: EventRecord, request_id: str = "", fingerprint: str = ""; }
node StoredConfirmedPreference {
    has id: str, workspace_id: str, key: str, value: str, version: int = 1, confirmed: bool = True;
    has source: str = "explicit user confirmation", request_id: str = "";
}

def _slots(events: list[EventRecord], goal: str, duration: int, today: str, morning: bool = False) -> list[CandidateSlot] {
    current = datetime.fromisoformat(today).date();
    zone = ZoneInfo("Asia/Colombo");
    earliest = datetime.fromisoformat(today);
    if earliest.utcoffset() is None { earliest = earliest.replace(tzinfo=zone); }
    start_day = None;
    if "next week" in goal.lower() {
        start_day = current + timedelta(days=7-current.weekday());
    } else {
        dates = re.findall(r"\d{4}-\d{2}-\d{2}", goal);
        if len(dates) == 1 {
            try { start_day = datetime.fromisoformat(dates[0]).date(); }
            except ValueError { return []; }
        }
    }
    if start_day is None or start_day < current or (start_day-current).days > 60 or duration < 1 or duration > 480 { return []; }
    results: list[CandidateSlot] = [];
    for offset in range(5 if "next week" in goal.lower() else 1) {
        day = start_day + timedelta(days=offset);
        candidate = datetime.combine(day,time(9),tzinfo=zone);
        closing = datetime.combine(day,time(12 if morning else 17),tzinfo=zone);
        while candidate + timedelta(minutes=duration) <= closing {
            end = candidate + timedelta(minutes=duration);
            conflict = False;
            for event in events {
                if not validate_event(event).ok { raise ValueError("Invalid calendar record prevents reliable availability."); }
                if candidate < datetime.fromisoformat(event.end) and end > datetime.fromisoformat(event.start) { conflict = True; }
            }
            if not conflict and candidate >= earliest {
                results.append(CandidateSlot(start=candidate.isoformat(),end=end.isoformat()));
                if len(results) == 8 { return results; }
            }
            candidate += timedelta(minutes=30);
        }
    }
    return results;
}

def _planning_context(workspace_id: str, goal: str, duration: int, today: str, exclude_event_id: str = "") -> dict {
    events = [item.record for item in [root -->][?:StoredCalendarEvent] if item.record.workspace_id == workspace_id and item.record.id != exclude_event_id];
    preferences = [item for item in [root -->][?:StoredConfirmedPreference] if item.workspace_id == workspace_id and item.confirmed];
    morning = "morning" in goal.lower();
    dependencies: list[dict] = [];
    for preference in preferences {
        if preference.key == "availability" and preference.value in ["morning", "anytime"] {
            morning = morning or preference.value == "morning";
            dependencies.append({"id":preference.id,"version":preference.version});
        } else { raise ValueError("A confirmed preference needs a supported scheduling rule."); }
    }
    slots = _slots(events,goal,duration,today,morning);
    tasks = read_tasks(workspace_id).data.tasks;
    return {
        "slots":[{"start":slot.start,"end":slot.end,"timezone":slot.timezone} for slot in slots],
        "existing_tasks":[task.title for task in tasks][:50],
        "preference_dependencies":dependencies,
        "schedule_policy":"Asia/Colombo; next week means Monday-Friday; 09:00-17:00, or 09:00-12:00 for morning; exact ISO date means that day.",
        "calendar_event_count":len(events)
    };
}
