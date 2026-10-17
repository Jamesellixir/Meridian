import from jaclang.byllm.lib { MockLLM, MockRawResponse, MockError }
import from agent.model { interpret_with, decode_goal }

test "typed model response follows the goal contract" {
    model = MockLLM(model_name="mockllm", config={"outputs": [MockRawResponse(content='{"title":"AI meetup","duration_minutes":120,"missing_information":[],"constraints":[],"intent":"plan_session"}')]});
    result = interpret_with(model, "Plan a two-hour AI meetup", "2026-10-17", "Asia/Colombo");
    assert result.duration_minutes == 120;
    assert result.title == "AI meetup";
}

test "malformed model output repairs once" {
    model = MockLLM(model_name="mockllm", config={"outputs": [
        MockRawResponse(content="{invalid"),
        MockRawResponse(content='{"title":"Study","duration_minutes":60,"missing_information":[],"constraints":[],"intent":"plan_session"}')
    ]});
    result = interpret_with(model, "Plan an hour of study", "2026-10-17", "Asia/Colombo");
    assert result.duration_minutes == 60;
    assert len(model.seen_prompts) == 2;
}

test "invalid model output cannot retry indefinitely" {
    model = MockLLM(model_name="mockllm", config={"outputs": [MockRawResponse(content="{bad"), MockRawResponse(content="{bad")]});
    failed = False;
    try {
        interpret_with(model, "Plan", "2026-10-17", "Asia/Colombo");
    } except Exception {
        failed = True;
    }
    assert failed;
    assert len(model.seen_prompts) == 2;
}

test "valid JSON cannot smuggle unknown fields or incorrect types" {
    for raw in [
        '{"title":"Study","duration_minutes":true,"missing_information":[],"constraints":[],"intent":"plan_session"}',
        '{"title":"Study","duration_minutes":60,"missing_information":[],"constraints":[],"intent":"approve_everything"}',
        '{"title":"Study","duration_minutes":60,"missing_information":[],"constraints":[],"intent":"plan_session","approved":true}'
    ] {
        failed = False;
        try { decode_goal(raw); } except ValueError { failed = True; }
        assert failed;
    }
}

test "provider errors do not trigger output repair calls" {
    model = MockLLM(model_name="mockllm", config={"outputs": [MockError(error=TimeoutError("synthetic timeout"))]});
    failed = False;
    try { interpret_with(model, "Plan an hour of study", "2026-10-17", "Asia/Colombo"); }
    except TimeoutError { failed = True; }
    assert failed;
    assert len(model.seen_prompts) == 1;
}
