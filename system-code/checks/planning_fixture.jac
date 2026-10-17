# Test-only facade fixture. This entry is never imported by the production app.
import from contracts.models { EventRecord }
import from workspace.planning { StoredCalendarEvent, StoredConfirmedPreference, _planning_context }

def:pub seed_and_read -> dict {
    root ++> StoredCalendarEvent(record=EventRecord(id="busy",workspace_id="demo",title="Busy",
        start="2026-10-19T09:00:00+05:30",end="2026-10-19T11:00:00+05:30"));
    root ++> StoredCalendarEvent(record=EventRecord(id="other",workspace_id="other",title="Other workspace",
        start="2026-10-20T09:00:00+05:30",end="2026-10-20T17:00:00+05:30"));
    root ++> StoredConfirmedPreference(id="morning",workspace_id="demo",key="availability",value="morning",version=2);
    root ++> StoredConfirmedPreference(id="ignored",workspace_id="demo",key="unknown",value="unsupported",confirmed=False);
    return _planning_context("demo","Plan next week",120,"2026-10-17");
}
