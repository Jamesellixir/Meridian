# Opt-in only, outside test discovery. Never runs through `jac test`.
import from agent.model { create_live_model, interpret_with }
test "live OpenAI response is decoded and validated" {
    try {
        result = interpret_with(create_live_model(), "Plan a two-hour AI meetup next week", "2026-10-17", "Asia/Colombo");
        print("Live interpretation: " + result.intent + ", duration=" + str(result.duration_minutes));
        assert result.intent in ["plan_session", "clarify"];
        assert result.duration_minutes == 120;
        print("Live model typed-output smoke passed.");
    } except Exception as error {
        print("Live model smoke failed: " + type(error).__name__);
        assert False, "Live model smoke failed; no successful check recorded.";
    }
}
