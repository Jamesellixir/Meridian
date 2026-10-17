import os;
import json;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.llm { BaseLLM }
import from contracts.models { GoalSpec }
import from contracts.validation { validate_goal_spec }

obj GoalInterpreter {
    has llm: BaseLLM;
    def extract_raw(text: str, today: str, timezone: str) -> str by self.llm(max_output_retries=0, timeout=30, num_retries=0, max_tokens=1024);
}
sem GoalInterpreter.extract_raw = "Return ONLY one JSON object with exactly these keys: title (string), duration_minutes (integer), missing_information (array of strings), constraints (array of strings), intent (plan_session, clarify, or unsupported). Extract a request for one session. Do not invent duration or missing facts. Use duration_minutes=0 and intent=clarify when duration is absent. Constraints are user-supplied facts. Never execute actions or claim records were created.";

def decode_goal(raw: str) -> GoalSpec {
    if len(raw) > 16000 { raise ValueError("Goal output exceeds the response limit."); }
    data = json.loads(raw);
    expected = {"title", "duration_minutes", "missing_information", "constraints", "intent"};
    if not isinstance(data, dict) or set(data.keys()) != expected {
        raise ValueError("Goal output has missing or unexpected fields.");
    }
    if type(data["title"]) is not str or type(data["intent"]) is not str or type(data["duration_minutes"]) is not int {
        raise ValueError("Goal output has invalid scalar types.");
    }
    for key in ["missing_information", "constraints"] {
        if not isinstance(data[key], list) or not all(isinstance(item, str) for item in data[key]) {
            raise ValueError("Goal output has invalid list types.");
        }
    }
    result = GoalSpec(title=data["title"], duration_minutes=data["duration_minutes"], missing_information=data["missing_information"], constraints=data["constraints"], intent=data["intent"]);
    if not validate_goal_spec(result).ok { raise ValueError("Model returned a semantically invalid goal."); }
    return result;
}

def interpret_with(llm: BaseLLM, text: str, today: str, timezone: str) -> GoalSpec {
    if not text.strip() or len(text) > 4000 { raise ValueError("Goal text must contain 1 to 4000 characters."); }
    # Jac 0.34.24's native schema generator fails on imported obj metadata.
    # Keep model text untrusted and decode it into the shared DTO explicitly.
    interpreter = GoalInterpreter(llm=llm);
    request = text;
    for attempt in range(2) {
        raw = interpreter.extract_raw(request, today, timezone);
        try { return decode_goal(raw); }
        except ValueError {
            if attempt == 1 { raise ValueError("Goal output failed validation after two attempts."); }
            request = text + "\nThe previous output failed validation. Return only the exact JSON object requested.";
        }
    }
    raise ValueError("Goal interpretation did not complete.");
}

def create_live_model -> Model {
    if not os.environ.get("OPENAI_API_KEY") { raise ValueError("OPENAI_API_KEY is not configured on the server."); }
    return Model(model_name="gpt-5.4-mini-2026-03-17");
}
