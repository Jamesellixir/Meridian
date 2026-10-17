import from contracts.models { EventRecord }
import from workspace.planning { _slots }
import from agent.planner { _decode_plan }
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.testing { JacTestClient }

test "availability excludes overlap and allows adjacent intervals" {
    event = EventRecord(id="busy",workspace_id="demo",title="Busy",start="2026-10-19T09:00:00+05:30",end="2026-10-19T11:00:00+05:30");
    slots = _slots([event],"Plan next week",120,"2026-10-17");
    assert slots[0].start == "2026-10-19T11:00:00+05:30";
    assert slots[0].end == "2026-10-19T13:00:00+05:30";
    assert len(slots) <= 8;
}

test "morning and no availability do not invent a slot" {
    slots = _slots([],"Plan next week",120,"2026-10-17",True);
    assert slots[0].start == "2026-10-19T09:00:00+05:30";
    assert _slots([],"Plan 2026-10-19",240,"2026-10-17",True) == [];
    assert _slots([],"Plan sometime",120,"2026-10-17") == [];
    assert _slots([],"Plan 2026-10-16",120,"2026-10-17") == [];
    later = _slots([],"Plan 2026-10-17",120,"2026-10-17T11:15:00+05:30");
    assert later[0].start == "2026-10-17T11:30:00+05:30";
}

test "untrusted drafts cannot select invented slots or approval fields" {
    for raw in [
        '{"note_title":"Agenda","note_body":"Discuss","tasks":[{"title":"Prepare","due_at":null}],"selected_slot_index":99,"explanation":"Chosen"}',
        '{"note_title":"Agenda","note_body":"Discuss","tasks":[{"title":"Prepare","due_at":null}],"selected_slot_index":true,"explanation":"Chosen"}',
        '{"note_title":"Agenda","note_body":"Discuss","tasks":[{"title":"Prepare","due_at":null}],"selected_slot_index":0,"explanation":"Chosen","approved":true}'
    ] {
        rejected = False;
        try { _decode_plan(raw,1); } except ValueError { rejected = True; }
        assert rejected;
    }
}

test "workspace facade reads persisted calendar and only confirmed scoped preferences" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("checks/planning_fixture.jac").resolve()),base_path=directory);
        try {
            response = client.post("/function/seed_and_read",json={});
            assert response.ok, response.text;
            context = response.json()["data"]["result"];
            assert context["slots"][0]["start"] == "2026-10-20T09:00:00+05:30", str(context);
            assert context["calendar_event_count"] == 1;
            assert context["preference_dependencies"] == [{"id":"morning","version":2}];
        } finally { client.close(); }
    }
}
