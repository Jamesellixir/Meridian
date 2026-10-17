import from contracts.models { GoalRequest, EventRecord }
import from contracts.validation { validate_goal_request, validate_event, validate_review }
import from app.transport { unwrap_response }

test "goal input is trimmed without accepting an empty goal" {
    result = validate_goal_request(GoalRequest(text="  Plan our meetup  ", workspace_id="local", request_id="request-1"));
    assert result.ok;
    assert result.data["text"] == "Plan our meetup";
    assert not validate_goal_request(GoalRequest(text="  ", workspace_id="local", request_id="request-2")).ok;
}

test "goal identifiers and size are bounded" {
    assert not validate_goal_request(GoalRequest(text="x" * 4001, workspace_id="local", request_id="r")).ok;
    assert not validate_goal_request(GoalRequest(text="Plan", workspace_id="../other", request_id="r")).ok;
    assert not validate_goal_request(GoalRequest(text="Plan", workspace_id="local", request_id="")).ok;
}

test "calendar requires aware increasing timestamps and valid timezone" {
    event = EventRecord(id="event-1", workspace_id="local", title="Meetup", start="2026-10-19T09:00:00+05:30", end="2026-10-19T11:00:00+05:30");
    assert validate_event(event).ok, str(validate_event(event).error);
    event.end = event.start;
    assert not validate_event(event).ok;
    event.end = "2026-10-19T11:00:00";
    assert not validate_event(event).ok;
    event.end = "2026-10-19T11:00:00+05:30";
    event.timezone = "Made/Up";
    assert not validate_event(event).ok;
}

test "approval requires an exact revision hash and decision" {
    assert validate_review("proposal-1", 1, "a" * 64, "approve").ok;
    assert not validate_review("proposal-1", 0, "a" * 64, "approve").ok;
    assert not validate_review("proposal-1", 1, "bad", "approve").ok;
    assert not validate_review("proposal-1", 1, "a" * 64, "automatic").ok;
}

test "transport adapter accepts function and walker envelopes" {
    expected = {"ok": True, "data": {"status": "ready"}, "error": None};
    assert unwrap_response({"data": {"result": expected}}) == expected;
    assert unwrap_response({"data": {"reports": [expected]}}) == expected;
    assert unwrap_response({"reports": [expected]}) == expected;
    assert not unwrap_response({"data": {"reports": []}})["ok"];
    assert not unwrap_response({"data": {"result": {"status": "fake"}}})["ok"];
}
